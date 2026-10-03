-- Sync: shares events (not totals) between addon users, so merging is a set union and
-- double-counting is impossible. Only this module touches the network.
--
-- Wire format: "<proto>~<type>~<body>"
--   H  HELLO    body: count|latest|addonVersion
--   E  EVENT    body: record               (live broadcast of a new summon; sender must be the caster)
--   R  REQUEST  body: since                (asks the whisper target for events with time > since)
--   B  BATCH    body: record               (one record per message, whispered in reply to R)
-- record = id|caster|target|assist1,assist2|mapID|subzone|time|confirmed|wrote
-- Fields are percent-escaped. Points and kind are never trusted from the wire: they are recomputed.
local ADDON, ST = ...
local Sync = {}
ST.Sync = Sync

local PREFIX = "SUMMONSYNC"
local PROTO = 1            -- major protocol version; messages from a higher one are ignored
local MAX_MSG = 250        -- addon message limit is 255 bytes
local MAX_NAME = 24
local MAX_SUBZONE = 40
local MAX_ASSISTANTS = 2
local MAX_BATCH = 500      -- most events sent in reply to one REQUEST
local SEND_INTERVAL = 0.34 -- about 3 messages per second
local REQUEST_COOLDOWN = 10
local HELLO_BACK_COOLDOWN = 30
local REQUEST_WINDOW = 120 -- how long after our REQUEST we accept a BATCH from that sender

local function newState()
    return { queue = {}, requested = {}, lastReq = {}, lastHelloBack = {}, added = 0 }
end
Sync.newState = newState
Sync.state = newState()
Sync.quiet = false

----------------------------------------------------------------------
-- Overridable seams (the self-test swaps these)
----------------------------------------------------------------------
function Sync.myName()
    return Sync.nameOverride or ST.Store.me()
end

function Sync.now()
    return GetTime()
end

function Sync.channels()
    local out = {}
    if IsInRaid() then out[#out + 1] = "RAID" elseif IsInGroup() then out[#out + 1] = "PARTY" end
    if IsInGuild() then out[#out + 1] = "GUILD" end
    return out
end

function Sync.transport(channel, target, payload)
    return pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, channel, target)
end

----------------------------------------------------------------------
-- Encoding
----------------------------------------------------------------------
local function esc(s)
    return (tostring(s):gsub("[%%|,~%c]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function unesc(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function split(s, sep)
    local out, pos = {}, 1
    while true do
        local i = s:find(sep, pos, true)
        if not i then out[#out + 1] = s:sub(pos) break end
        out[#out + 1] = s:sub(pos, i - 1)
        pos = i + 1
    end
    return out
end

function Sync.Encode(id, ev)
    local assist = {}
    for _, a in ipairs(ev.assistants or {}) do assist[#assist + 1] = esc(a) end
    return table.concat({
        esc(id), esc(ev.caster), esc(ev.target), table.concat(assist, ","),
        ev.mapID and tostring(ev.mapID) or "", esc((ev.subzone or ""):sub(1, MAX_SUBZONE)),
        tostring(ev.time), ev.confirmed and "1" or "0", tostring(ev.wrote or ev.time),
    }, "|")
end

local function validName(s)
    return type(s) == "string" and #s > 0 and #s <= MAX_NAME
end

-- Returns id, ev on success, or nil, reason. Never trusts the sender's field values.
function Sync.Decode(record)
    local f = split(record, "|")
    if #f ~= 9 then return nil, "fields" end
    local id, caster, target = unesc(f[1]), unesc(f[2]), unesc(f[3])
    if not validName(caster) or not validName(target) then return nil, "name" end
    if #id > 48 or id:sub(1, #caster + 1) ~= caster .. "-" then return nil, "id" end
    local assistants = {}
    if f[4] ~= "" then
        for _, a in ipairs(split(f[4], ",")) do
            a = unesc(a)
            if not validName(a) then return nil, "assistant" end
            assistants[#assistants + 1] = a
        end
    end
    if #assistants > MAX_ASSISTANTS then return nil, "assistants" end
    local mapID
    if f[5] ~= "" then
        mapID = tonumber(f[5])
        if not mapID or mapID < 0 or mapID ~= math.floor(mapID) then return nil, "map" end
    end
    local subzone = unesc(f[6])
    if #subzone > MAX_SUBZONE then return nil, "subzone" end
    local t, wrote = tonumber(f[7]), tonumber(f[9])
    if not t or not wrote or t <= 0 or wrote <= 0 then return nil, "time" end
    if t > time() + 86400 or wrote > time() + 86400 then return nil, "future" end
    if f[8] ~= "0" and f[8] ~= "1" then return nil, "confirmed" end
    return id, {
        caster = caster, target = target, assistants = assistants, mapID = mapID,
        subzone = subzone, time = t, wrote = wrote, confirmed = f[8] == "1",
    }
end

----------------------------------------------------------------------
-- Merge (pure rules; the only DB access is through Store)
----------------------------------------------------------------------
-- live: the record arrived as an EVENT broadcast, so the sender must be the caster.
-- opts.dryRun: report what would happen without writing.
-- opts.allowSelf: accept your own events that you do not have (a user-initiated import restoring a
--   lost log); an existing copy of your own event is still never overwritten.
-- Returns "added", "replaced", "kept" or "rejected:<why>".
function Sync.Merge(id, ev, sender, live, opts)
    opts = opts or {}
    local store = ST.Store
    if live and ev.caster ~= sender then return "rejected:sender" end
    local cur = store.Get(id)
    if ev.caster == Sync.myName() then
        -- Nobody can write entries against the receiver. Our own copy is authoritative.
        if cur then return "kept" end
        if not opts.allowSelf then return "rejected:self" end
    end
    ev.points, ev.kind = ST.Scoring.Score(ev.mapID, ev.subzone)
    if not cur then
        if not opts.dryRun then store.Put(id, ev) end
        return "added"
    end
    local replace
    if ev.confirmed ~= cur.confirmed then
        replace = ev.confirmed -- keep the confirmed copy
    else
        replace = (ev.wrote or ev.time) < (cur.wrote or cur.time) -- both confirmed or both not: earlier write
    end
    if replace and not opts.dryRun then store.Put(id, ev) end
    return replace and "replaced" or "kept"
end

----------------------------------------------------------------------
-- Sending
----------------------------------------------------------------------
local function enqueue(channel, target, typ, body)
    local payload = PROTO .. "~" .. typ .. "~" .. body
    if #payload > MAX_MSG then return false end
    local q = Sync.state.queue
    q[#q + 1] = { channel = channel, target = target, payload = payload }
    return true
end

-- Sends up to max queued messages. The ticker calls this with 1 about three times a second.
function Sync.Pump(max)
    local n = 0
    local q = Sync.state.queue
    while n < max and #q > 0 do
        local m = table.remove(q, 1)
        Sync.transport(m.channel, m.target, m.payload)
        n = n + 1
    end
    return n
end

local function helloBody()
    return string.format("%d|%d|%s", ST.Store.Count(), ST.Store.Latest(), ST.version)
end

function Sync.Hello(channel, target)
    if channel then
        enqueue(channel, target, "H", helloBody())
    else
        for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "H", helloBody()) end
    end
end

function Sync.BroadcastEvent(id, ev)
    local rec = Sync.Encode(id, ev)
    for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "E", rec) end
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
local function short(name)
    if type(name) ~= "string" then return "" end
    return Ambiguate and Ambiguate(name, "short") or name:match("^[^-]+") or name
end

local function announceSoon()
    local st = Sync.state
    if Sync.quiet or st.announcing then return end
    st.announcing = true
    C_Timer.After(2, function()
        st.announcing = false
        if st.added > 0 then
            ST.print(string.format("Sync: received %d new summon%s.", st.added, st.added == 1 and "" or "s"))
            st.added = 0
        end
    end)
end

-- Returns a short result string describing what happened (used by the self-test).
function Sync.OnMessage(text, channel, sender)
    sender = short(sender)
    if sender == Sync.myName() or sender == "" then return "ignored:self" end
    local proto, typ, body = tostring(text):match("^(%d+)~(%a)~(.*)$")
    if not proto then return "bad" end
    if tonumber(proto) > PROTO then return "ignored:version" end
    local st = Sync.state
    local now = Sync.now()

    if typ == "H" then
        local count, latest = body:match("^(%d+)|(%d+)|")
        count, latest = tonumber(count), tonumber(latest)
        if not count then return "bad" end
        local myCount, myLatest = ST.Store.Count(), ST.Store.Latest()
        local actions = {}
        -- They may hold something we lack: ask for everything (set union makes repeats harmless).
        if count > myCount or latest > myLatest or (count == myCount and latest ~= myLatest) then
            st.requested[sender] = now
            enqueue("WHISPER", sender, "R", "0")
            actions[#actions + 1] = "request"
        end
        -- We hold more than they do: tell them so they can ask us.
        if count < myCount or latest < myLatest then
            if not st.lastHelloBack[sender] or now - st.lastHelloBack[sender] >= HELLO_BACK_COOLDOWN then
                st.lastHelloBack[sender] = now
                enqueue("WHISPER", sender, "H", helloBody())
                actions[#actions + 1] = "hello-back"
            end
        end
        return #actions > 0 and table.concat(actions, "+") or "in-sync"

    elseif typ == "R" then
        local since = tonumber(body)
        if not since then return "bad" end
        if st.lastReq[sender] and now - st.lastReq[sender] < REQUEST_COOLDOWN then return "ignored:ratelimit" end
        st.lastReq[sender] = now
        local sent = 0
        for _, r in ipairs(ST.Store.Since(since)) do
            if sent >= MAX_BATCH then break end
            if enqueue("WHISPER", sender, "B", Sync.Encode(r.id, r.ev)) then sent = sent + 1 end
        end
        return "batch:" .. sent

    elseif typ == "E" or typ == "B" then
        if typ == "B" then
            if channel ~= "WHISPER" then return "rejected:channel" end
            if not st.requested[sender] or now - st.requested[sender] > REQUEST_WINDOW then
                return "rejected:unrequested"
            end
        end
        local id, ev = Sync.Decode(body)
        if not id then return "rejected:" .. tostring(ev) end
        local result = Sync.Merge(id, ev, sender, typ == "E")
        if result == "added" then
            st.added = st.added + 1
            announceSoon()
        end
        return result
    end
    return "bad"
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------
function Sync.Status()
    local st = Sync.state
    ST.print(string.format("Sync: %d summons, latest %s, %d queued, channels: %s", ST.Store.Count(),
        ST.Store.Latest() > 0 and date("%Y-%m-%d %H:%M", ST.Store.Latest()) or "never", #st.queue,
        #Sync.channels() > 0 and table.concat(Sync.channels(), ",") or "none"))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
local grouped = false
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        ST.Store.onAdd = function(id, ev) Sync.BroadcastEvent(id, ev) end
        C_Timer.NewTicker(SEND_INTERVAL, function() Sync.Pump(1) end)
        C_Timer.After(5, function() Sync.Hello() end)
        grouped = IsInGroup()
    elseif event == "GROUP_ROSTER_UPDATE" then
        local now = IsInGroup()
        if now and not grouped then C_Timer.After(2, function() Sync.Hello() end) end
        grouped = now
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX then Sync.OnMessage(text, channel, sender) end
    end
end)
