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
local MAX_ALTS = 10        -- most alts of Zennit that we will learn
local MAX_BATCH = 500      -- most events sent in reply to one REQUEST
local SEND_INTERVAL = 0.34 -- about 3 messages per second
local REQUEST_COOLDOWN = 10
local HELLO_BACK_COOLDOWN = 30
local REQUEST_WINDOW = 120 -- how long after our REQUEST (or the last BATCH message) we accept more from that sender

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

-- An answer's flags as one digit: 1 = the place is on his list, 2 = he closed the Index with it, 4 = the silver was paid by a
-- punch of a card (Cards.lua). "" for none.
local function respFlags(r)
    local n = (r.listed and 1 or 0) + (r.closes and 2 or 0) + (r.card and 4 or 0)
    return n > 0 and tostring(n) or ""
end

-- The flags digit back into an answer's fields.
local function applyFlags(resp, digit)
    local n = tonumber(digit) or 0
    resp.listed = n % 2 == 1 or nil
    resp.closes = math.floor(n / 2) % 2 == 1 or nil
    resp.card = math.floor(n / 4) % 2 == 1 or nil
    return resp
end

-- The silver a demand asks for is a whole number of silver, 1 to MAX_SILVER.
local MAX_SILVER = 100000

-- Flags and the silver asked for, as the optional tail of an answer: ":flags[:silver]" ("" for neither). The flags digit is
-- always written when there is a silver amount.
local function respTail(r)
    local flags = respFlags(r)
    if r.amount then return ":" .. (flags ~= "" and flags or "0") .. ":" .. r.amount end
    return flags ~= "" and (":" .. flags) or ""
end

-- The tail back into flags and an amount. Returns false if it is malformed.
local function parseTail(tail)
    if tail == "" then return "", nil end
    local flags, amount = tail:match("^:(%d)$"), nil
    if not flags then
        flags, amount = tail:match("^:(%d):(%d+)$")
        if not flags then return false end
        amount = tonumber(amount)
        if amount < 1 or amount > MAX_SILVER then return false end
    end
    return flags, amount
end

-- Zennit's answer to a summon of him travels with the record as "result:zroll:sroll:time[:flags[:silver]]" (empty if none).
local function respString(r)
    if not r then return "" end
    return string.format("%s:%d:%d:%d%s", r.result, r.zroll or 0, r.sroll or 0, r.time, respTail(r))
end

-- nil for none, false for a malformed answer, otherwise the answer.
local function parseResp(str)
    if str == "" then return nil end
    local result, z, r, t, tail = str:match("^(%a+):(%d+):(%d+):(%d+)(.*)$")
    if not result or not ST.Store.RESULTS[result] then return false end
    z, r, t = tonumber(z), tonumber(r), tonumber(t)
    if z > 100 or r > 100 or t <= 0 or t > time() + 86400 then return false end
    local flags, amount = parseTail(tail)
    if flags == false then return false end
    if amount and result ~= "owed" and result ~= "paid" then return false end
    local resp = applyFlags({ result = result, zroll = z, sroll = r, time = t }, flags)
    resp.amount = amount
    return resp
end

-- The later of two answers (an answer can change: owes 50 silver, then paid).
local function laterResponse(a, b)
    if not a then return b end
    if not b then return a end
    return b.time > a.time and b or a
end

function Sync.Encode(id, ev)
    local assist = {}
    for _, a in ipairs(ev.assistants or {}) do assist[#assist + 1] = esc(a) end
    return table.concat({
        esc(id), esc(ev.caster), esc(ev.target), table.concat(assist, ","),
        ev.mapID and tostring(ev.mapID) or "", esc((ev.subzone or ""):sub(1, MAX_SUBZONE)),
        tostring(ev.time), ev.confirmed and "1" or "0", tostring(ev.wrote or ev.time),
        respString(ev.response),
    }, "|")
end

local function validName(s)
    return type(s) == "string" and #s > 0 and #s <= MAX_NAME
end

-- Returns id, ev on success, or nil, reason. Never trusts the sender's field values.
function Sync.Decode(record)
    local f = split(record, "|")
    if #f ~= 9 and #f ~= 10 then return nil, "fields" end
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
    local resp = parseResp(f[10] or "")
    if resp == false then return nil, "response" end
    return id, {
        caster = caster, target = target, assistants = assistants, mapID = mapID,
        subzone = subzone, time = t, wrote = wrote, confirmed = f[8] == "1",
        response = resp,
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
    -- anything from before the last reset stays gone, even if another client still holds it
    if ST.db.resetAt and ev.time <= ST.db.resetAt then return "rejected:reset" end
    if store.IsDeleted(id) then return "rejected:deleted" end
    local cur = store.Get(id)
    if ev.caster == Sync.myName() then
        -- Nobody can write entries against the receiver. Our own copy is authoritative.
        if cur then
            if not opts.dryRun then cur.response = laterResponse(cur.response, ev.response) end
            return "kept"
        end
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
    if not opts.dryRun then
        if replace then
            ev.response = laterResponse(ev.response, cur.response)
            store.Put(id, ev)
        else
            cur.response = laterResponse(cur.response, ev.response)
        end
    end
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

-- "0.19.1" -> 0, 19 (major and minor; nil for anything that is not a version).
local function parseVersion(v)
    local major, minor = tostring(v or ""):match("^(%d+)%.(%d+)")
    if not major then return nil end
    return tonumber(major), tonumber(minor)
end

-- What to say when a friend's addon is not the same version as ours (major.minor; a patch does not matter), or nil. The answer
-- format changed in 0.19, so mixed versions read some answers wrongly (design/lenses.md, Risk Mitigation).
function Sync.VersionNote(sender, theirs, mine)
    local tm, tn = parseVersion(theirs)
    local mm, mn = parseVersion(mine)
    if not (tm and mm) or (tm == mm and tn == mn) then return nil end
    local older = tm < mm or (tm == mm and tn < mn)
    return string.format(older and "%s is on %s and you are on %s: ask them to update (answers and cards are read wrongly across versions)."
        or "%s is on %s, newer than your %s: update the addon (answers and cards are read wrongly across versions).",
        sender, theirs, mine)
end

local function helloBody()
    return string.format("%d|%d|%s|%d|%d", ST.Store.Count(), ST.Store.Latest(), ST.version, ST.Store.LatestResponse(),
        ST.db.resetAt or 0)
end

function Sync.Hello(channel, target)
    if channel then
        enqueue(channel, target, "H", helloBody())
    else
        for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "H", helloBody()) end
        if ST.IsZennitAccount() then
            Sync.SendAlt()
            Sync.SendCards()
        end
    end
end

function Sync.BroadcastEvent(id, ev)
    local rec = Sync.Encode(id, ev)
    for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "E", rec) end
end

-- Zennit tells everyone how he dealt with a summon of him.
function Sync.SendResponse(id, resp)
    -- the same optional tail as the record's answer, with "|" for ":"
    local body = string.format("%s|%s|%d|%d|%d%s", esc(id), resp.result, resp.zroll or 0, resp.sroll or 0, resp.time,
        (respTail(resp):gsub(":", "|")))
    for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "Z", body) end
end

-- A card Zennit has sold (Cards.lua): "id|holder|punches|silver|time". Only his own client sends them, and everyone keeps
-- them, so a holder can see their punches. They are sent when a card is sold, with his hello, and to anyone who asks for events.
local MAX_CARDS = 200
function Sync.SendCard(card, target)
    local body = string.format("%s|%s|%d|%d|%d", esc(card.id), esc(card.holder), card.punches, card.silver, card.time)
    if target then
        enqueue("WHISPER", target, "K", body)
    else
        for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "K", body) end
    end
end

-- Resends every card that still has a punch (up to 20), if this client is Zennit's.
function Sync.SendCards(target)
    if not (ST.Cards and ST.Week.IsZennit(Sync.myName())) then return end
    local sent = 0
    for _, card in ipairs(ST.Cards.Sorted()) do
        if sent >= 20 then break end
        if ST.Cards.PunchesLeft(card) > 0 then
            Sync.SendCard(card, target)
            sent = sent + 1
        end
    end
end

-- Zennit's own client says "the character I am playing is his": everyone else cannot see his Battle.net account,
-- so this is how they learn his alts. The sender is the character; nothing else is claimed.
function Sync.SendAlt()
    for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "A", "1") end
end

-- A deleted summon: only its caster can say so. `T` carries the id.
function Sync.SendTombstone(id)
    for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "T", esc(id)) end
end

-- Whispers our own tombstones to someone who may still hold what we deleted. Returns whether any were sent.
local MAX_TOMBSTONES = 50
local TOMBSTONE_COOLDOWN = 60
function Sync.SendTombstones(target)
    local st = Sync.state
    local now = Sync.now()
    st.lastTomb = st.lastTomb or {}
    if st.lastTomb[target] and now - st.lastTomb[target] < TOMBSTONE_COOLDOWN then return false end
    local sent = false
    for _, t in ipairs(ST.Store.OwnTombstones(MAX_TOMBSTONES)) do
        if enqueue("WHISPER", target, "T", esc(t.id)) then sent = true end
    end
    if sent then st.lastTomb[target] = now end
    return sent
end

-- Asks everyone to wipe their summons and the story as of `stamp` (each user is asked before it happens).
function Sync.SendReset(stamp)
    for _, ch in ipairs(Sync.channels()) do enqueue(ch, nil, "X", tostring(stamp)) end
end

-- Dice: Zennit's roll goes to the summoner, who rolls back; both by whisper.
function Sync.SendDice(id, zroll, toName)
    enqueue("WHISPER", toName, "D", esc(id) .. "|" .. zroll)
end

function Sync.SendDiceReply(id, sroll, toName)
    enqueue("WHISPER", toName, "S", esc(id) .. "|" .. sroll)
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
local function short(name)
    return ST.baseName(name) or ""
end

local function announceSoon()
    local st = Sync.state
    if Sync.quiet or st.announcing then return end
    st.announcing = true
    C_Timer.After(2, function()
        st.announcing = false
        if st.added > 0 then
            ST.print(string.format("Sync: received %d new summon%s.", st.added, st.added == 1 and "" or "s"))
            if ST.Hub then ST.Hub.Refresh() end
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
        local count, latest, respT, theirReset = body:match("^(%d+)|(%d+)|[^|]*|?(%d*)|?(%d*)")
        count, latest, respT, theirReset = tonumber(count), tonumber(latest), tonumber(respT) or 0, tonumber(theirReset) or 0
        if not count then return "bad" end
        local myCount, myLatest, myResp = ST.Store.Count(), ST.Store.Latest(), ST.Store.LatestResponse()
        local actions = {}
        -- a friend on another version: say so once
        st.versionNoted = st.versionNoted or {}
        if not st.versionNoted[sender] then
            local note = Sync.VersionNote(sender, body:match("^%d+|%d+|([^|]*)"), ST.version)
            if note then
                st.versionNoted[sender] = true
                if not Sync.quiet then ST.print("|cffffd100Version:|r " .. note) end
                actions[#actions + 1] = "version"
            end
        end
        -- They may hold something we lack: ask for everything (set union makes repeats harmless).
        if count > myCount or latest > myLatest or (count == myCount and latest ~= myLatest) or respT > myResp then
            st.requested[sender] = now
            enqueue("WHISPER", sender, "R", tostring(ST.db.resetAt or 0)) -- never ask for what a reset removed
            actions[#actions + 1] = "request"
        end
        -- We hold more than they do: tell them so they can ask us.
        if count < myCount or latest < myLatest or respT < myResp then
            if not st.lastHelloBack[sender] or now - st.lastHelloBack[sender] >= HELLO_BACK_COOLDOWN then
                st.lastHelloBack[sender] = now
                enqueue("WHISPER", sender, "H", helloBody())
                actions[#actions + 1] = "hello-back"
            end
        end
        -- They reset after us (we were offline, or said no): ask our user again.
        if theirReset > (ST.db.resetAt or 0) and theirReset <= time() + 86400 and Sync.onReset then
            Sync.onReset(sender, theirReset)
            actions[#actions + 1] = "reset-asked"
        end
        -- They hold more than we do: some of it may be summons we deleted, so tell them (rate limited).
        if count > myCount or latest > myLatest then
            if Sync.SendTombstones(sender) then actions[#actions + 1] = "tombstones" end
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
        Sync.SendTombstones(sender)
        Sync.SendCards(sender)
        return "batch:" .. sent

    elseif typ == "E" or typ == "B" then
        if typ == "B" then
            if channel ~= "WHISPER" then return "rejected:channel" end
            if not st.requested[sender] or now - st.requested[sender] > REQUEST_WINDOW then
                return "rejected:unrequested"
            end
            st.requested[sender] = now -- sliding window: a long batch keeps itself open
        end
        local id, ev = Sync.Decode(body)
        if not id then return "rejected:" .. tostring(ev) end
        local result = Sync.Merge(id, ev, sender, typ == "E")
        if result == "added" then
            st.added = st.added + 1
            announceSoon()
            -- Zennit hears a recorded complaint when a friend summons him (live events only, not history).
            if typ == "E" and ev.target == Sync.myName() and ST.Gag.IsZennit() then
                ST.Clips.Play("zenit_land")
                if ST.Respond then ST.Respond.Incoming(id, ev) end
            end
        end
        return result
    elseif typ == "Z" then
        -- Zennit's answer: only he can answer for himself
        local rid, result, z, r, rt, tail = body:match("^([^|]+)|(%a+)|(%d+)|(%d+)|(%d+)(.*)$")
        if not rid then return "bad" end
        local flags, amount = parseTail((tail:gsub("|", ":")))
        if flags == false or (amount and result ~= "owed" and result ~= "paid") then return "bad" end
        rid = unesc(rid)
        local ev = ST.Store.Get(rid)
        if not ev then return "rejected:unknown" end
        if sender ~= ev.target then return "rejected:sender" end
        if not ST.Store.RESULTS[result] then return "rejected:result" end
        local resp = applyFlags({ result = result, zroll = tonumber(z), sroll = tonumber(r), time = tonumber(rt) }, flags)
        resp.amount = amount
        if resp.zroll > 100 or resp.sroll > 100 or resp.time > time() + 86400 then return "rejected:values" end
        if laterResponse(ev.response, resp) ~= resp then return "kept" end
        local before = ev.response
        ST.Store.SetResponse(rid, resp)
        if Sync.onResponse then Sync.onResponse(rid, ev, resp, before) end
        return "applied"

    elseif typ == "K" then
        -- a card Zennit sold: only his characters can issue one
        if not ST.Week.IsZennit(sender) then return "rejected:sender" end
        local cid, holder, punches, silver, ct = body:match("^([^|]+)|([^|]+)|(%d+)|(%d+)|(%d+)$")
        if not cid then return "bad" end
        cid, holder, punches, silver, ct = unesc(cid), unesc(holder), tonumber(punches), tonumber(silver), tonumber(ct)
        if #cid > 48 or not validName(holder) or punches < 1 or punches > 50 or silver > 100000 or ct <= 0 or ct > time() + 86400 then
            return "rejected:values"
        end
        ST.db.cards = ST.db.cards or {}
        if ST.db.cards[cid] then return "kept" end
        local count = 0
        for _ in pairs(ST.db.cards) do count = count + 1 end
        if count >= MAX_CARDS then return "rejected:full" end
        ST.db.cards[cid] = { id = cid, holder = holder, punches = punches, silver = silver, time = ct }
        if Sync.onCard then Sync.onCard(ST.db.cards[cid]) end
        return "card"

    elseif typ == "A" then
        if not validName(sender) then return "bad" end
        local s = ST.db.settings
        if not s then return "bad" end
        s.zenitAlts = s.zenitAlts or {}
        if ST.Week.IsZennit(sender) then return "kept" end
        if #s.zenitAlts >= MAX_ALTS then return "rejected:full" end
        s.zenitAlts[#s.zenitAlts + 1] = sender
        return "learned"

    elseif typ == "T" then
        -- the caster deleted this summon: nobody else can, so the sender must be the one named in the id
        local id = unesc(body)
        if #id > 48 or id:sub(1, #sender + 1) ~= sender .. "-" then return "rejected:sender" end
        ST.db.deleted = ST.db.deleted or {}
        if ST.db.deleted[id] then return "kept" end
        ST.db.deleted[id] = now
        ST.db.events[id] = nil
        return "deleted"

    elseif typ == "X" then
        -- a request to reset: nothing happens until this user agrees
        local stamp = tonumber(body:match("^(%d+)$"))
        if not stamp or stamp > time() + 86400 then return "bad" end
        if stamp <= (ST.db.resetAt or 0) then return "kept" end
        if Sync.onReset then Sync.onReset(sender, stamp) end
        return "asked"

    elseif typ == "D" then
        -- Zennit suggests dice for a summon of him, and has rolled; we are the summoner
        local rid, z = body:match("^([^|]+)|(%d+)$")
        if not rid then return "bad" end
        rid, z = unesc(rid), tonumber(z)
        local ev = ST.Store.Get(rid)
        if not ev then return "rejected:unknown" end
        if sender ~= ev.target or ev.caster ~= Sync.myName() then return "rejected:sender" end
        if z < 1 or z > 100 then return "rejected:values" end
        if Sync.onDice then Sync.onDice(rid, ev, z) end
        return "dice"

    elseif typ == "S" then
        -- the summoner's roll, back to Zennit
        local rid, sroll = body:match("^([^|]+)|(%d+)$")
        if not rid then return "bad" end
        rid, sroll = unesc(rid), tonumber(sroll)
        local ev = ST.Store.Get(rid)
        if not ev then return "rejected:unknown" end
        if sender ~= ev.caster or ev.target ~= Sync.myName() then return "rejected:sender" end
        if sroll < 1 or sroll > 100 then return "rejected:values" end
        if Sync.onDiceReply then Sync.onDiceReply(rid, ev, sroll) end
        return "dice-reply"
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
frame:SetScript("OnEvent", ST.Safe("sync", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        ST.Store.onAdd = function(id, ev) Sync.BroadcastEvent(id, ev) end
        ST.Store.onRemove = function(id) Sync.SendTombstone(id) end
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
end))
