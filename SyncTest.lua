-- /st synctest: exercises Sync encoding, merge rules and the HELLO/REQUEST/BATCH exchange with
-- fake events and simulated clients. Real data is never touched: each client gets a scratch DB.
local ADDON, ST = ...
local Sync, Store = ST.Sync, ST.Store
local T = {}
ST.SyncTest = T

local BASE = 1717000000
local clock = 1000
local realEventClosed -- set in T.Run (Week.lua loads after this file)

local function newClient(name)
    return {
        name = name, out = {}, state = Sync.newState(),
        db = { version = 1, events = {}, badges = {}, settings = {}, harness = {} },
    }
end

-- Runs fn with the addon globals pointed at client c, then restores them.
local function with(c, fn)
    local saved = {
        db = ST.db, state = Sync.state, name = Sync.nameOverride, transport = Sync.transport,
        channels = Sync.channels, quiet = Sync.quiet, now = Sync.now, onAdd = Store.onAdd, onRemove = Store.onRemove,
    }
    ST.db, Sync.state, Sync.nameOverride, Sync.quiet = c.db, c.state, c.name, true
    Sync.transport = function(channel, target, payload)
        c.out[#c.out + 1] = { channel = channel, target = target, payload = payload }
    end
    Sync.channels = function() return { "PARTY" } end
    Sync.now = function() return clock end
    Store.onAdd = function(id, ev) Sync.BroadcastEvent(id, ev) end
    Store.onRemove = function(id) Sync.SendTombstone(id) end
    local ok, a, b = pcall(fn)
    ST.db, Sync.state, Sync.nameOverride, Sync.transport = saved.db, saved.state, saved.name, saved.transport
    Sync.channels, Sync.quiet, Sync.now, Store.onAdd = saved.channels, saved.quiet, saved.now, saved.onAdd
    Store.onRemove = saved.onRemove
    if not ok then error(a, 0) end
    return a, b
end

-- Adds a confirmed summon cast by c. localOnly keeps it off the simulated network.
local function cast(c, i, localOnly, over)
    local ev = {
        caster = c.name, target = "Target" .. i, assistants = { "H1", "H2" }, mapID = 1436,
        subzone = "Sentinel Hill", time = BASE + i, confirmed = true,
    }
    for k, v in pairs(over or {}) do ev[k] = v end
    return with(c, function() return (Store.Add(ev, localOnly)) end)
end

-- Delivers queued messages between clients until the network is quiet.
local function settle(clients)
    local counts, rounds = { H = 0, E = 0, R = 0, B = 0 }, 0
    repeat
        local moved = 0
        for _, c in ipairs(clients) do with(c, function() Sync.Pump(100000) end) end
        for _, c in ipairs(clients) do
            local out = c.out
            c.out = {}
            for _, m in ipairs(out) do
                moved = moved + 1
                local typ = m.payload:match("^%d+~(%a)~")
                counts[typ] = (counts[typ] or 0) + 1
                for _, r in ipairs(clients) do
                    if r ~= c and (m.channel ~= "WHISPER" or m.target == r.name) then
                        with(r, function() Sync.OnMessage(m.payload, m.channel, c.name) end)
                    end
                end
            end
        end
        rounds = rounds + 1
    until moved == 0 or rounds > 40
    return counts, rounds
end

local function signature(c)
    local parts = {}
    for id, ev in pairs(c.db.events) do parts[#parts + 1] = Sync.Encode(id, ev) end
    table.sort(parts)
    return table.concat(parts, "\n"), #parts
end

local function sample(over)
    local ev = {
        caster = "Beta", target = "Tgt", assistants = { "A", "B" }, mapID = 1436, subzone = "Sentinel Hill",
        time = BASE + 100, wrote = BASE + 200, confirmed = true,
    }
    for k, v in pairs(over or {}) do ev[k] = v end
    return "Beta-" .. ev.time, ev
end

local function mutate(record, idx, value)
    local f = {}
    for part in (record .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end
    f[idx] = value
    return table.concat(f, "|")
end

local tests = {}
local function add(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

add("encode/decode round trip with awkward characters", function()
    local id, ev = sample({ target = "We|ird,%~x", assistants = { "A%b", "C,d" }, subzone = "Sub,Zone|x" })
    local rid, out = Sync.Decode(Sync.Encode(id, ev))
    if not rid then return false, "decode failed: " .. tostring(out) end
    local same = rid == id and out.target == ev.target and out.subzone == ev.subzone and out.assistants[1] == "A%b"
        and out.assistants[2] == "C,d" and out.time == ev.time and out.wrote == ev.wrote and out.confirmed == true
        and out.mapID == 1436
    return same, same and "" or "fields differ after round trip"
end)

add("typical record fits one addon message", function()
    local id, ev = sample({ caster = "Charactername", target = "Anothername", assistants = { "Helperone", "Helpertwo" },
        subzone = string.rep("s", 40) })
    id = "Charactername-" .. ev.time
    local len = #("1~B~" .. Sync.Encode(id, ev))
    return len <= 250, len .. " bytes"
end)

add("malformed records are rejected", function()
    local id, ev = sample()
    local rec = Sync.Encode(id, ev)
    local cases = {
        { rec .. "|x|y", "fields" },
        { mutate(rec, 7, "abc"), "time" },
        { mutate(rec, 7, tostring(time() + 10 * 86400)), "future" },
        { mutate(rec, 1, "Other-1717000100"), "id" },
        { mutate(rec, 2, string.rep("x", 30)), "name" },
        { mutate(rec, 5, "12x"), "map" },
        { mutate(rec, 8, "2"), "confirmed" },
        { mutate(rec, 4, "A,B,C"), "assistants" },
    }
    for _, c in ipairs(cases) do
        local ok, reason = Sync.Decode(c[1])
        if ok or reason ~= c[2] then return false, string.format("expected '%s', got %s", c[2], tostring(reason or "accepted")) end
    end
    return true, #cases .. " cases"
end)

add("newer protocol, garbage and own echoes are ignored", function()
    local a = newClient("Alpha")
    local r1 = with(a, function() return Sync.OnMessage("2~H~1|1|x", "GUILD", "Beta") end)
    local r2 = with(a, function() return Sync.OnMessage("garbage", "GUILD", "Beta") end)
    local r3 = with(a, function() return Sync.OnMessage("1~H~0|0|x", "GUILD", "Alpha") end)
    return r1 == "ignored:version" and r2 == "bad" and r3 == "ignored:self", r1 .. ", " .. r2 .. ", " .. r3
end)

add("new event added once; repeating adds nothing", function()
    local a = newClient("Alpha")
    local id, ev = sample()
    local r1 = with(a, function() return Sync.Merge(id, ev, "Beta", false) end)
    local _, ev2 = sample()
    local r2 = with(a, function() return Sync.Merge(id, ev2, "Beta", false) end)
    local _, n = signature(a)
    return r1 == "added" and r2 == "kept" and n == 1, r1 .. ", " .. r2 .. ", count " .. n
end)

add("points are recomputed locally, never trusted", function()
    local a = newClient("Alpha")
    local id, ev = sample({ mapID = 1453 }) -- Stormwind: a city
    ev.points, ev.kind = 999, "remote"
    with(a, function() Sync.Merge(id, ev, "Beta", false) end)
    local got = a.db.events[id]
    return got.points == 1 and got.kind == "city", "points=" .. tostring(got.points) .. " kind=" .. tostring(got.kind)
end)

add("live EVENT must come from its own caster", function()
    local a = newClient("Alpha")
    local id, ev = sample()
    local r = with(a, function() return Sync.OnMessage("1~E~" .. Sync.Encode(id, ev), "PARTY", "Gamma") end)
    local _, n = signature(a)
    return r == "rejected:sender" and n == 0, r
end)

add("nobody can forge entries against the receiver", function()
    local a = newClient("Alpha")
    local fid, fev = sample({ caster = "Alpha", target = "Fake" })
    fid = "Alpha-" .. fev.time
    local r1 = with(a, function() return Sync.Merge(fid, fev, "Beta", false) end)
    cast(a, 100, true, { target = "Real" })
    local realID = "Alpha-" .. (BASE + 100)
    local _, f2 = sample({ caster = "Alpha", target = "Fake", time = BASE + 100, wrote = 1 })
    local r2 = with(a, function() return Sync.Merge(realID, f2, "Beta", false) end)
    local ok = r1 == "rejected:self" and r2 == "kept" and a.db.events[realID].target == "Real"
    return ok, r1 .. ", " .. r2 .. ", target=" .. a.db.events[realID].target
end)

add("confirmed beats unconfirmed; earlier write wins a tie", function()
    local a = newClient("Alpha")
    local id, base = sample({ confirmed = false, wrote = 500 })
    with(a, function() Sync.Merge(id, base, "Beta", false) end)
    local steps = {
        { { confirmed = true, wrote = 600 }, "replaced", true },
        { { confirmed = false, wrote = 100 }, "kept", true },
        { { confirmed = true, wrote = 400 }, "replaced", true },
        { { confirmed = true, wrote = 700 }, "kept", true },
    }
    for i, s in ipairs(steps) do
        local _, ev = sample(s[1])
        local r = with(a, function() return Sync.Merge(id, ev, "Beta", false) end)
        if r ~= s[2] or a.db.events[id].confirmed ~= s[3] then return false, "step " .. i .. " gave " .. r end
    end
    return a.db.events[id].wrote == 400, "final wrote=" .. a.db.events[id].wrote
end)

add("unsolicited or non-whisper BATCH is refused", function()
    local a = newClient("Alpha")
    local id, ev = sample()
    local msg = "1~B~" .. Sync.Encode(id, ev)
    local r1 = with(a, function() return Sync.OnMessage(msg, "WHISPER", "Beta") end)
    a.state.requested["Beta"] = clock
    local r2 = with(a, function() return Sync.OnMessage(msg, "PARTY", "Beta") end)
    local r3 = with(a, function() return Sync.OnMessage(msg, "WHISPER", "Beta") end)
    return r1 == "rejected:unrequested" and r2 == "rejected:channel" and r3 == "added", r1 .. ", " .. r2 .. ", " .. r3
end)

add("REQUEST is rate limited per sender", function()
    local b = newClient("Beta")
    cast(b, 1, true)
    local r1 = with(b, function() return Sync.OnMessage("1~R~0", "WHISPER", "Alpha") end)
    local r2 = with(b, function() return Sync.OnMessage("1~R~0", "WHISPER", "Alpha") end)
    clock = clock + 11
    local r3 = with(b, function() return Sync.OnMessage("1~R~0", "WHISPER", "Alpha") end)
    return r1 == "batch:1" and r2 == "ignored:ratelimit" and r3 == "batch:1", r1 .. ", " .. r2 .. ", " .. r3
end)

add("a new summon broadcasts live and lands on the other client", function()
    local a, b = newClient("Alpha"), newClient("Beta")
    local id = cast(a, 1, false)
    local counts = settle({ a, b })
    local got = b.db.events[id]
    return got ~= nil and counts.E >= 1 and got.points == a.db.events[id].points,
        "E messages: " .. counts.E .. ", arrived: " .. tostring(got ~= nil)
end)

add("three clients with different logs converge, then stay quiet", function()
    local a, b, g = newClient("Alpha"), newClient("Beta"), newClient("Gamma")
    for i = 1, 3 do cast(a, i, true) end
    for i = 10, 11 do cast(b, i, true) end
    clock = clock + 100
    for _, c in ipairs({ a, b, g }) do with(c, function() Sync.Hello() end) end
    local c1, rounds = settle({ a, b, g })
    local sa, na = signature(a)
    local sb, nb = signature(b)
    local sg, ng = signature(g)
    if not (sa == sb and sb == sg and na == 5) then
        return false, string.format("counts a=%d b=%d g=%d (want 5, identical)", na, nb, ng)
    end
    clock = clock + 100
    for _, c in ipairs({ a, b, g }) do with(c, function() Sync.Hello() end) end
    local c2 = settle({ a, b, g })
    local quiet = c2.E == 0 and c2.B == 0 and c2.R == 0
    return quiet, string.format("first pass: %d rounds, %d batch msgs; repeat: R=%d B=%d E=%d", rounds, c1.B, c2.R, c2.B, c2.E)
end)

add("export codec round-trips text, including a full 12-bit dictionary", function()
    local Codec = ST.Export.Codec
    local samples = { "a", "ab", "abc", string.rep("Alpha-1717000001|Target|H1,H2|1436|Sentinel Hill|", 40) }
    local rnd = {}
    for i = 1, 20000 do rnd[i] = string.char(math.random(0, 255)) end
    samples[#samples + 1] = table.concat(rnd)
    for i, s in ipairs(samples) do
        local back, err = Codec.Unpack(Codec.Pack(s))
        if back ~= s then return false, string.format("sample %d failed: %s", i, tostring(err)) end
    end
    local empty = Codec.Unpack(Codec.Pack(""))
    return empty == "", #samples .. " samples"
end)

add("export strings: damage, truncation, newer versions and stray whitespace", function()
    local Codec = ST.Export.Codec
    local good = Codec.Pack(string.rep("hello world ", 30))
    local flipped = good:sub(1, -6) .. (good:sub(-5, -5) == "A" and "B" or "A") .. good:sub(-4)
    local cases = {
        { good:sub(1, #good - 8), false }, -- truncated
        { flipped, false },                -- one character changed
        { "!ST2!1!1!AAAA", false },        -- newer version
        { "hello", false },                -- not ours
        { "", false },
        { (good:gsub("(.......)", "%1\n ")), true }, -- whitespace is ignored
    }
    for i, c in ipairs(cases) do
        local text = Codec.Unpack(c[1])
        if (text ~= nil) ~= c[2] then return false, "case " .. i .. " gave " .. tostring(text ~= nil) end
    end
    return true, #cases .. " cases"
end)

add("export all, import on a fresh client, then re-import adds nothing", function()
    local a, b = newClient("Alpha"), newClient("Beta")
    for i = 1, 3 do cast(a, i, true) end
    with(a, function()
        local id, ev = sample()
        Sync.Merge(id, ev, "Beta", false)
    end)
    local str, n = with(a, function() return ST.Export.Build("all") end)
    local p = with(b, function() return ST.Export.Preview(str) end)
    -- Beta's own event is a restore for the client named Beta, so all four are new.
    if n ~= 4 or not p or p.counts.added ~= 4 then
        return false, "preview wrong: exported " .. tostring(n) .. ", added " .. tostring(p and p.counts.added)
    end
    with(b, function() ST.Export.Apply(p) end)
    local sa, sb = signature(a), signature(b)
    local again = with(b, function() return ST.Export.Preview(str) end)
    return sa == sb and again.counts.added == 0 and again.counts.replaced == 0,
        string.format("identical=%s, repeat: added=%d known=%d", tostring(sa == sb), again.counts.added, again.counts.kept)
end)

add("import restores your own lost events but never overwrites existing ones", function()
    local a = newClient("Alpha")
    for i = 1, 2 do cast(a, i, true) end
    local mine = with(a, function() return ST.Export.Build("mine") end)
    local lost = newClient("Alpha") -- same character, empty log (SavedVariables lost)
    local p = with(lost, function() return ST.Export.Preview(mine) end)
    with(lost, function() ST.Export.Apply(p) end)
    if signature(lost) ~= signature(a) then return false, "restore did not match the original" end
    -- A tampered copy of an event you already have must not replace it.
    local id = "Alpha-" .. (BASE + 1)
    local _, fake = sample({ caster = "Alpha", target = "Fake", time = BASE + 1, wrote = 1, confirmed = true })
    local forged = ST.Export.Codec.Pack(Sync.Encode(id, fake))
    local p2 = with(lost, function() return ST.Export.Preview(forged) end)
    with(lost, function() ST.Export.Apply(p2) end)
    local target = lost.db.events[id].target
    return target == "Target1" and p2.counts.kept == 1, "target=" .. target
end)

add("import ignores points in the string and rejects bad records", function()
    local b = newClient("Beta")
    local id, ev = sample({ caster = "Gamma", time = BASE + 5, mapID = 1453 })
    id = "Gamma-" .. ev.time
    local text = Sync.Encode(id, ev) .. "~" .. "garbage|record" .. "~" .. Sync.Encode("Other-1", ev)
    local p = with(b, function() return ST.Export.Preview(ST.Export.Codec.Pack(text)) end)
    with(b, function() ST.Export.Apply(p) end)
    local got = b.db.events[id]
    return p.counts.added == 1 and p.counts.rejected == 2 and got and got.points == 1,
        string.format("added=%d rejected=%d points=%s", p.counts.added, p.counts.rejected, tostring(got and got.points))
end)

add("voice clips: names parse, categories count, picks do not repeat", function()
    local Clips = ST.Clips
    local c, n, who = Clips.Parse("zenit_refuse_03_sam")
    if c ~= "zenit_refuse" or n ~= 3 or who ~= "sam" then return false, "parse gave " .. tostring(c) end
    if Clips.Parse("narrator_weekopen_01_lewis") ~= "narrator_weekopen" then return false, "multi-word category" end
    if Clips.Parse("notaclip") or Clips.Parse("_01_x") or Clips.Parse("wag_x_y") then return false, "bad names parsed" end
    Clips.SetList({ "wag_02_b", "wag_01_a", "ritual_01_c", "bad name" })
    local cats = Clips.Categories()
    local counted = #cats == 2 and cats[1][1] == "ritual" and cats[2][1] == "wag" and cats[2][2] == 2
    local repeated, prev = false, nil
    for _ = 1, 60 do
        local p = Clips.Pick("wag")
        if p == prev then repeated = true end
        prev = p
    end
    local missing = Clips.Pick("nothing") == nil
    Clips.SetList(ST.clipFiles) -- restore the real list
    return counted and not repeated and missing, string.format("counted=%s repeated=%s", tostring(counted), tostring(repeated))
end)

add("Zennit hears a recorded complaint when summoned live, not from history", function()
    local z = newClient("Zennit")
    z.db.settings.zenitTest = true
    local calls = {}
    local realPlay = ST.Clips.Play
    ST.Clips.Play = function(category) calls[#calls + 1] = category end
    local ok, err = pcall(function()
        local function record(target, i)
            local id, ev = sample({ caster = "Alpha", target = target, time = BASE + i })
            return "Alpha-" .. ev.time, ev
        end
        local id, ev = record("Zennit", 300)
        with(z, function() Sync.OnMessage("1~E~" .. Sync.Encode(id, ev), "PARTY", "Alpha") end)       -- live: yes
        id, ev = record("Zennit", 301)
        z.state.requested["Alpha"] = clock
        with(z, function() Sync.OnMessage("1~B~" .. Sync.Encode(id, ev), "WHISPER", "Alpha") end)     -- history: no
        id, ev = record("Someone", 302)
        with(z, function() Sync.OnMessage("1~E~" .. Sync.Encode(id, ev), "PARTY", "Alpha") end)       -- someone else: no
    end)
    ST.Clips.Play = realPlay
    if not ok then return false, tostring(err) end
    return #calls == 1 and calls[1] == "zenit_land", #calls .. " clip call(s)"
end)

add("intro key phrases: shown at the right time, typed out, and every cue falls inside its scene", function()
    local I = ST.Intro
    local cues = { { t = 1, text = "ONE" }, { t = 3, text = "TWO" } }
    local before = I.CueAt(cues, 0.5)
    local first, firstElapsed = I.CueAt(cues, 1.5)
    local stillFirst = I.CueAt(cues, 2.9)
    local second = I.CueAt(cues, 3.1)
    local expired = I.CueAt({ { t = 1, text = "X" } }, 6)
    local none = I.CueAt(nil, 1)
    if before or first ~= 1 or stillFirst ~= 1 or second ~= 2 or expired or none then
        return false, "cue lookup is wrong"
    end
    if math.abs(firstElapsed - 0.5) > 1e-6 then return false, "elapsed time is wrong" end
    if I.Typed("HELLO", 0) ~= "H" or I.Typed("HELLO", 0.1) ~= "HEL" or I.Typed("HELLO", 10) ~= "HELLO" then
        return false, "typing is wrong"
    end
    local bad = {}
    for si, list in pairs(ST.introCues or {}) do
        local length = ST.introLength and ST.introLength[si]
        local prev = -1
        for _, c in ipairs(list) do
            if c.t <= prev or (length and c.t >= length) or #c.text == 0 then bad[#bad + 1] = si .. ":" .. tostring(c.text) end
            prev = c.t
        end
    end
    return #bad == 0, #bad == 0 and "all generated cues are ordered and inside their scenes" or table.concat(bad, ", ")
end)

add("senders shown as 'Name Surname' or 'Name-Realm' are matched by their plain name", function()
    local a = newClient("Alpha")
    local id, ev = sample({ caster = "Beta", time = BASE + 400 })
    id = "Beta-" .. ev.time
    local r1 = with(a, function() return Sync.OnMessage("1~E~" .. Sync.Encode(id, ev), "PARTY", "Beta Mcbane") end)
    local id2, ev2 = sample({ caster = "Gamma", time = BASE + 401 })
    id2 = "Gamma-" .. ev2.time
    local r2 = with(a, function() return Sync.OnMessage("1~E~" .. Sync.Encode(id2, ev2), "GUILD", "Gamma-SomeRealm") end)
    local r3 = with(a, function() return Sync.OnMessage("1~H~0|0|x", "GUILD", "Alpha Zennit") end) -- our own echo
    return r1 == "added" and r2 == "added" and r3 == "ignored:self", r1 .. ", " .. r2 .. ", " .. r3
end)

add("plain names: first word only, nothing for unusable values", function()
    local b = ST.baseName
    local ok = b("Poogs Mcbane") == "Poogs" and b("Club-Zennit") == "Club" and b("Solo") == "Solo"
        and b("") == nil and b(nil) == nil and b(42) == nil and b(" x") == nil
    return ok, "Poogs Mcbane -> " .. tostring(b("Poogs Mcbane"))
end)

add("intro subtitles: the sentence being spoken, and the generated times are ordered", function()
    local I = ST.Intro
    local _, idx, since, span = I.SentenceAt({ { t = 1, text = "a" }, { t = 4, text = "b" } }, 2, 9)
    local _, lastIdx, _, lastSpan = I.SentenceAt({ { t = 1, text = "a" }, { t = 4, text = "b" } }, 5, 9)
    if idx ~= 1 or math.abs(since - 1) > 1e-6 or span ~= 3 or lastIdx ~= 2 or lastSpan ~= 5 then
        return false, "sentence index or span is wrong"
    end
    local fast, slow = I.SentenceSpeed(100, 5), I.SentenceSpeed(100, 20)
    if not (fast > slow) or I.SentenceSpeed(50, nil) ~= 26 or I.SentenceSpeed(1, 100) < 8 then
        return false, "typing speed is wrong"
    end
    local list = { { t = 0.4, text = "first" }, { t = 10, text = "second" } }
    if I.SentenceAt(list, 0) ~= nil or I.SentenceAt(list, 5) ~= "first" or I.SentenceAt(list, 10) ~= "second"
        or I.SentenceAt(list, 99) ~= "second" or I.SentenceAt(nil, 1) ~= nil then
        return false, "sentence lookup is wrong"
    end
    local bad = {}
    for si, sentences in pairs(ST.introSentences or {}) do
        local prev = -1
        for _, s in ipairs(sentences) do
            if s.t <= prev or #s.text == 0 then bad[#bad + 1] = si end
            prev = s.t
        end
    end
    return #bad == 0, #bad == 0 and "generated sentence times are ordered" or ("scenes " .. table.concat(bad, ","))
end)

add("hub window: builds and every tab refreshes without errors", function()
    local ok, err = ST.Hub.SelfCheck()
    return ok, ok and "every tab refreshed" or tostring(err)
end)

add("intro highlights: a box is up while its subject is mentioned, and the generated boxes fit the picture", function()
    local I = ST.Intro
    local list = { { t = 1, x = 0, y = 0, w = 10, h = 10 }, { t = 6, x = 5, y = 5, w = 10, h = 10 } }
    local before = I.HighlightAt(list, 0.5)
    local first = I.HighlightAt(list, 2)
    local expired = I.HighlightAt(list, 5)
    local second = I.HighlightAt(list, 6.5)
    if before or first ~= 1 or expired or second ~= 2 or I.HighlightAt(nil, 1) then
        return false, "highlight lookup is wrong"
    end
    local bad = {}
    for si, boxes in pairs(ST.introHighlights or {}) do
        local prev = -1
        for _, b in ipairs(boxes) do
            if b.t <= prev or b.w <= 0 or b.h <= 0 or b.x < 0 or b.y < 0 or b.x + b.w > 960 or b.y + b.h > 540 then
                bad[#bad + 1] = si
            end
            prev = b.t
        end
    end
    return #bad == 0, #bad == 0 and "all generated boxes are ordered and inside the picture" or ("scenes " .. table.concat(bad, ","))
end)

add("Zennit's answer rides on the record; malformed answers are rejected", function()
    local id, ev = sample({ target = "Zennit", response = { result = "won", zroll = 64, sroll = 31, time = BASE + 300 } })
    local rid, back = Sync.Decode(Sync.Encode(id, ev))
    local r = back and back.response
    if not (rid == id and r and r.result == "won" and r.zroll == 64 and r.sroll == 31 and r.time == BASE + 300) then
        return false, "answer lost in the round trip"
    end
    local rec = Sync.Encode(id, ev)
    for _, bad in ipairs({ "nonsense:1:2:3", "won:101:2:5", "dance:1:2:5", "won:1:2" }) do
        local ok, reason = Sync.Decode(mutate(rec, 10, bad))
        if ok or reason ~= "response" then return false, bad .. " gave " .. tostring(reason or "accepted") end
    end
    local plainID, plain = sample()
    local _, noAnswer = Sync.Decode(Sync.Encode(plainID, plain))
    return noAnswer ~= nil and noAnswer.response == nil, "4 bad answers refused; no answer stays no answer"
end)

add("points only count for summons that land", function()
    local a = newClient("Alpha")
    local results = { "accepted", "refused", "owed", "paid", "won", "lost" }
    for i, res in ipairs(results) do
        cast(a, 700 + i, true, { target = "Zennit", response = { result = res, zroll = 40, sroll = 10, time = BASE + 5 } })
    end
    cast(a, 800, true, { target = "Zennit" }) -- no answer yet: counts
    local tally, stats
    with(a, function()
        tally = ST.Store.Tallies().Alpha
        stats = ST.Store.Stats("Alpha")
    end)
    -- accepted, paid, lost and the unanswered one land: 4 summons x 3 points
    return tally.cast == 7 and tally.points == 12 and stats.cast == 4,
        string.format("cast=%d points=%d landed=%d", tally.cast, tally.points, stats.cast)
end)

add("a refusal costs Zennit the points unless the place is on his list", function()
    local a = newClient("Alpha")
    local plain = cast(a, 950, true, { target = "Zennit", response = { result = "refused", zroll = 0, sroll = 0, time = BASE + 5 } })
    local free = cast(a, 951, true, { target = "Zennit", response = { result = "excused", zroll = 0, sroll = 0, time = BASE + 5 } })
    local won = cast(a, 952, true, { target = "Zennit", response = { result = "won", zroll = 80, sroll = 20, time = BASE + 5 } })
    local listed = cast(a, 953, true, { target = "Zennit", response = { result = "accepted", zroll = 0, sroll = 0, time = BASE + 5, listed = true } })
    -- the listed flag survives the wire format
    local back = select(2, Sync.Decode(Sync.Encode(listed, a.db.events[listed])))
    if not (back and back.response and back.response.listed) then return false, "listed flag lost in the codec" end
    local onList, offList, tally
    with(a, function()
        ST.Respond.ListClear()
        ST.Respond.ListAdd("Stormwind")
        onList = ST.Respond.OnList({ subzone = "Trade District", mapID = 1453 }) -- zone name needs the client's map data
        offList = ST.Respond.OnList({ subzone = "Mudsprocket", mapID = 0 })
        ST.Respond.ListClear()
        tally = ST.Store.Tallies().Zennit
    end)
    local pts = a.db.events[plain].points
    -- refused -P, excused 0, dice won +P, accepted at a listed place +P
    local want = -pts + pts + pts
    return offList == false and onList ~= nil and tally.points == want and not Store.Lands(a.db.events[free])
        and won ~= nil, string.format("Zennit points=%d (expected %d), off-list=%s", tally.points, want, tostring(offList))
end)

add("the week: Zennit's head start wins small weeks, the group needs more, and a win is a week off", function()
    local a = newClient("Alpha")
    local W = ST.Week
    local out
    with(a, function()
        local last = W.Start() - 7 * 86400
        local function put(n, pts, extra)
            local ev = { caster = "Alpha", target = "Zennit", assistants = {}, time = last + 3600 * n, points = pts, kind = "zone" }
            for k, v in pairs(extra or {}) do ev[k] = v end
            a.db.events["w-" .. n] = ev
        end
        put(1, 3)
        local small = W.Score(last)
        for n = 2, 5 do put(n, 3) end
        local big = W.Score(last)
        a.db.events["w-5"].response = { result = "won", zroll = 80, sroll = 10, time = last + 20000 } -- he won a roll: -3 group, +3 him
        local rolled = W.Score(last)
        local immune = W.Immune(time())
        out = { small = small, big = big, rolled = rolled, immune = immune }
    end)
    local s, b, r = out.small, out.big, out.rolled
    return s.winner == "zennit" and b.group == 15 and b.winner == "group" and r.winner == "zennit" and out.immune == true
        and W.Start(W.Start() + 1) == W.Start(), string.format("small=%s big=%s/%d-%d rolled=%s", s.winner, b.winner, b.group, b.zennit, r.winner)
end)

add("the season: first to five weekly wins takes the finale, then the count starts again", function()
    local a = newClient("Alpha")
    local season
    with(a, function()
        local this = ST.Week.Start()
        -- seven finished weeks, oldest first: five Zennit wins (3 points loses to his 10 head start), a group win
        -- (20 points), then another Zennit win
        local points = { 3, 3, 3, 3, 3, 20, 3 }
        for i, pts in ipairs(points) do
            a.db.events["s-" .. i] = { caster = "Alpha", target = "Target1", assistants = {}, points = pts, kind = "zone",
                time = this - (8 - i) * 7 * 86400 + 3600 }
        end
        season = ST.Week.Season()
    end)
    local c = season.chapters
    return #c == 7 and c[5].key == "z5" and c[6].key == "g1" and c[7].key == "z1" and #season.finales == 1
        and season.finales[1].side == "zennit" and season.zennit == 1 and season.group == 1,
        string.format("%d chapters, %d finale(s), season z%d g%d", #c, #season.finales, season.zennit, season.group)
end)

add("BattleTags: the admin and Zennit's account are told apart, case and spaces ignored", function()
    return ST.TagTest()
end)

add("reset: wipes the log, refuses older events afterwards, and a request only asks", function()
    local a, b = newClient("Alpha"), newClient("Beta")
    local id1 = cast(a, 1, false)
    cast(a, 2, false)
    settle({ a, b })
    local had = 0
    for _ in pairs(b.db.events) do had = had + 1 end
    local stamp = BASE + 50
    local removed = with(b, function() return ST.Reset.Apply(stamp) end)
    local left = 0
    for _ in pairs(b.db.events) do left = left + 1 end
    local _, old = Sync.Decode(Sync.Encode(id1, a.db.events[id1]))
    local late = with(b, function() return Sync.Merge(id1, old, "Alpha", false) end)
    local asked, from, forStamp
    local realAsk = Sync.onReset
    Sync.onReset = function(sender, s) asked, from, forStamp = true, sender, s end
    local ask = with(a, function() return Sync.OnMessage("1~X~" .. (BASE + 60), "PARTY", "Beta") end)
    local stale = with(b, function() return Sync.OnMessage("1~X~" .. stamp, "PARTY", "Alpha") end)
    local bad = with(a, function() return Sync.OnMessage("1~X~soon", "PARTY", "Beta") end)
    Sync.onReset = realAsk
    local keptOwn = 0
    for _ in pairs(a.db.events) do keptOwn = keptOwn + 1 end
    return had == 2 and removed == 2 and left == 0 and late == "rejected:reset" and ask == "asked" and asked and from == "Beta"
        and forStamp == BASE + 60 and stale == "kept" and bad == "bad" and keptOwn == 2,
        string.format("had %d removed %d left %d, late=%s ask=%s stale=%s bad=%s, requester kept %d", had, removed, left, late, ask, stale, bad, keptOwn)
end)

add("only Zennit can answer for himself, and a newer answer wins", function()
    local a, z = newClient("Alpha"), newClient("Zennit")
    local id = cast(a, 900, false, { target = "Zennit" })
    settle({ a, z })
    with(z, function() ST.Respond.Decide(id, "refused") end)
    settle({ a, z })
    local first = a.db.events[id].response
    if not (first and first.result == "refused") then return false, "the refusal did not reach the summoner" end
    local landsAfterRefusal = with(a, function() return Store.Lands(a.db.events[id]) end)
    local body = id .. "|accepted|0|0|"
    local forged = with(a, function() return Sync.OnMessage("1~Z~" .. body .. (time() + 5), "PARTY", "Gamma") end)
    local old = with(a, function() return Sync.OnMessage("1~Z~" .. body .. (first.time - 100), "PARTY", "Zennit") end)
    local newer = with(a, function() return Sync.OnMessage("1~Z~" .. body .. (first.time + 100), "PARTY", "Zennit") end)
    return forged == "rejected:sender" and old == "kept" and newer == "applied" and a.db.events[id].response.result == "accepted"
        and not landsAfterRefusal, string.format("%s, %s, %s", forged, old, newer)
end)

add("a friend who missed Zennit's answer gets it from the next HELLO", function()
    local a, b, z = newClient("Alpha"), newClient("Beta"), newClient("Zennit")
    local id = cast(a, 910, false, { target = "Zennit" })
    settle({ a, b, z })
    with(z, function() ST.Respond.Decide(id, "owed") end)
    settle({ a, z }) -- Beta is offline for the broadcast
    if b.db.events[id].response then return false, "Beta should have missed the answer" end
    with(a, function() Sync.Hello() end)
    settle({ a, b, z })
    local got = b.db.events[id].response
    return got ~= nil and got.result == "owed", got and got.result or "still missing"
end)

add("a closed week is frozen: Zennit can no longer answer into it and a late summon cannot flip it", function()
    local a = newClient("Alpha")
    local W = ST.Week
    local fake = W.EventClosed
    W.EventClosed = realEventClosed -- the other tests use old summons, so Run turns closing off
    local ok, res = pcall(with, a, function()
        local id = Store.Add({ caster = "Alpha", target = "Zennit", assistants = {}, mapID = 1436, subzone = "Sentinel Hill",
            time = BASE + 3600, confirmed = true }, true)
        a.db.events[id].points, a.db.events[id].kind = 3, "zone"
        local week = W.Start(BASE + 3600)
        local answered = ST.Respond.Decide(id, "refused")
        W.Freeze()
        a.db.events["late-1"] = { caster = "Alpha", target = "Other", assistants = {}, points = 50, kind = "zone",
            time = BASE + 7200 }
        return { answered = answered, winner = W.Score(week).winner, closed = W.Closed(week),
            frozen = a.db.settings.weekFrozen[week], pending = #ST.Respond.Pending() }
    end)
    W.EventClosed = fake
    if not ok then return false, tostring(res) end
    return res.answered == nil and res.closed and res.frozen == "zennit" and res.winner == "zennit" and res.pending == 0,
        string.format("answered=%s winner=%s frozen=%s pending=%d", tostring(res.answered), tostring(res.winner), tostring(res.frozen), res.pending)
end)

add("undo only removes your own summon, and the deletion sticks across sync, even for a friend who was offline", function()
    local a, b = newClient("Alpha"), newClient("Beta")
    local mine = cast(a, 920, false)
    local theirs = cast(b, 921, false)
    settle({ a, b })
    local removed = with(a, function() return Store.RemoveLast() end)
    if not removed or removed.id ~= mine then return false, "undo removed " .. tostring(removed and removed.id) end
    settle({ a }) -- Beta is offline when the deletion is broadcast
    if not b.db.events[mine] then return false, "Beta should still hold it" end
    with(b, function() Sync.Hello() end)
    settle({ a, b })
    local gone = b.db.events[mine] == nil and a.db.events[theirs] ~= nil
    -- it must not come back by sync from a client that still holds it
    local c = newClient("Gamma")
    local back = with(c, function()
        local _, ev = Sync.Decode(Sync.Encode(mine, { caster = "Alpha", target = "Target920", assistants = {}, time = BASE + 920, confirmed = true }))
        c.db.deleted = { [mine] = 1 }
        return Sync.Merge(mine, ev, "Beta", false)
    end)
    local forged = with(b, function() return Sync.OnMessage("1~T~" .. theirs, "PARTY", "Gamma") end)
    return gone and back == "rejected:deleted" and forged == "rejected:sender" and b.db.events[theirs] ~= nil,
        string.format("gone=%s back=%s forged=%s", tostring(gone), back, forged)
end)

add("a reset a client missed is asked again from the next HELLO", function()
    local a, b = newClient("Alpha"), newClient("Beta")
    cast(a, 930, false)
    settle({ a, b })
    local stamp = BASE + 5000
    with(a, function() ST.Reset.Apply(stamp) end) -- Beta never hears the request
    local asked
    local realAsk = Sync.onReset
    Sync.onReset = function(_, s) asked = s end
    with(b, function() Sync.OnMessage("1~H~0|0|x|0|" .. stamp, "WHISPER", "Alpha") end)
    Sync.onReset = realAsk
    return asked == stamp, tostring(asked)
end)

add("Zennit's alts are learned from his own client, and only a few", function()
    local a, z = newClient("Alpha"), newClient("Zennit")
    local savedGet = ST.bnGetInfo
    ST.bnGetInfo = function() return 1, ST.ZENNIT_TAG end
    with(z, function() Sync.Hello() end)
    ST.bnGetInfo = savedGet
    local sentA
    for _, m in ipairs(z.out) do if m.payload:match("^%d+~A~") then sentA = m.payload end end
    if not sentA then return false, "Zennit's client did not announce itself" end
    local before = with(a, function() return ST.Week.IsZennit("Bankalt") end)
    local r1 = with(a, function() return Sync.OnMessage(sentA, "PARTY", "Bankalt") end)
    local r2 = with(a, function() return Sync.OnMessage(sentA, "PARTY", "Bankalt") end)
    local after = with(a, function() return ST.Week.IsZennit("Bankalt-SomeRealm") end)
    local other = with(a, function() return ST.Week.IsZennit("Gamma") end)
    local capped
    with(a, function() for i = 1, 12 do capped = Sync.OnMessage(sentA, "PARTY", "Alt" .. i) end end)
    return not before and r1 == "learned" and r2 == "kept" and after and not other and capped == "rejected:full",
        string.format("before=%s %s %s after=%s other=%s capped=%s", tostring(before), r1, r2, tostring(after), tostring(other), tostring(capped))
end)

add("test summons are not counted in tallies or badge stats", function()
    local a = newClient("Alpha")
    cast(a, 940, true)
    cast(a, 941, true, { fake = true })
    local tally, stats
    with(a, function()
        tally = ST.Store.Tallies().Alpha
        stats = ST.Store.Stats("Alpha")
    end)
    return tally.cast == 1 and stats.cast == 1, string.format("tally %d, stats %d", tally.cast, stats.cast)
end)

add("assistants prompt in a raid: helpers from any subgroup come first, the list is capped, target and caster are left out", function()
    local members = {}
    for i = 1, 30 do members[i] = "Raider" .. i end
    members[#members + 1] = "Target"
    members[#members + 1] = "Me"
    local list = ST.Detector.PickCandidates(members, { "Raider28", "Raider3", "Gone" }, "Target", "Me", 12)
    local seen = {}
    for _, n in ipairs(list) do seen[n] = (seen[n] or 0) + 1 end
    local dupes = false
    for _, c in pairs(seen) do if c > 1 then dupes = true end end
    return #list == 12 and list[1] == "Raider28" and list[2] == "Raider3" and not seen.Target and not seen.Me
        and not seen.Gone and not dupes, table.concat(list, ",")
end)

add("scoring: cities, far-flung maps and dungeon entrances score by kind, and a dungeon subzone beats its map", function()
    local S = ST.Scoring
    local city, cityPts = S.Score(1453, "Trade District")
    local zone = S.Score(1436, "Sentinel Hill")
    local remote, remotePts = S.Score(1451, "Cenarion Hold")
    local dungeon, dungeonPts = S.Score(1451, "The Deadmines")
    local wc = S.Kind(1413, "Wailing Caverns")
    local ok = city == "city" and cityPts == 1 and zone == 3 and remote == "remote" and remotePts == 10
        and dungeon == "dungeon" and dungeonPts == 5 and wc == "dungeon"
    return ok, string.format("%s %s %s %s", tostring(city), tostring(remote), tostring(dungeon), tostring(wc))
end)

add("dice: Zennit rolls, the summoner rolls back, higher wins and a tie goes to Zennit", function()
    if ST.Respond.Resolve(64, 31) ~= "won" or ST.Respond.Resolve(20, 80) ~= "lost" or ST.Respond.Resolve(50, 50) ~= "won"
        or ST.Respond.Resolve(45, 50) ~= "won" or ST.Respond.Resolve(30, 50) ~= "lost" then -- his +10 edge
        return false, "Resolve is wrong"
    end
    local a, z = newClient("Alpha"), newClient("Zennit")
    local realDice = Sync.onDice
    local summonerRoll
    Sync.onDice = function(id, ev, zroll) Sync.SendDiceReply(id, summonerRoll, ev.target) end -- the summoner's side, rolling back
    local out = {}
    local ok, err = pcall(function()
        for i, c in ipairs({ { 64, 31, "won" }, { 20, 80, "lost" }, { 50, 50, "won" } }) do
            local id = cast(a, 910 + i, false, { target = "Zennit" })
            settle({ a, z })
            summonerRoll = c[2]
            with(z, function() ST.Respond.StartDice(id, c[1]) end)
            settle({ a, z })
            local resp = a.db.events[id].response
            out[#out + 1] = resp and (resp.result .. " " .. resp.zroll .. "-" .. resp.sroll) or "no answer"
            if not (resp and resp.result == c[3] and resp.zroll == c[1] and resp.sroll == c[2]) then
                error("roll " .. i .. " gave " .. out[#out])
            end
        end
    end)
    Sync.onDice = realDice
    return ok, ok and table.concat(out, ", ") or tostring(err)
end)

add("dice challenges and replies are only accepted from the right player", function()
    local a, z = newClient("Alpha"), newClient("Zennit")
    local id = cast(a, 930, false, { target = "Zennit" })
    settle({ a, z })
    local seen = {}
    local realDice, realReply = Sync.onDice, Sync.onDiceReply
    Sync.onDice = function() seen.dice = (seen.dice or 0) + 1 end
    Sync.onDiceReply = function() seen.reply = (seen.reply or 0) + 1 end
    local r = {}
    r[1] = with(a, function() return Sync.OnMessage("1~D~" .. id .. "|50", "WHISPER", "Gamma") end)   -- not the target
    r[2] = with(a, function() return Sync.OnMessage("1~D~" .. id .. "|50", "WHISPER", "Zennit") end)  -- the real thing
    r[3] = with(z, function() return Sync.OnMessage("1~S~" .. id .. "|50", "WHISPER", "Gamma") end)   -- not the summoner
    r[4] = with(z, function() return Sync.OnMessage("1~S~" .. id .. "|50", "WHISPER", "Alpha") end)   -- the real thing
    r[5] = with(a, function() return Sync.OnMessage("1~D~" .. id .. "|500", "WHISPER", "Zennit") end)  -- out of range
    Sync.onDice, Sync.onDiceReply = realDice, realReply
    local ok = r[1] == "rejected:sender" and r[2] == "dice" and r[3] == "rejected:sender" and r[4] == "dice-reply"
        and r[5] == "rejected:values" and seen.dice == 1 and seen.reply == 1
    return ok, table.concat(r, ", ")
end)

add("test summons never count for sync or export", function()
    local a = newClient("Alpha")
    cast(a, 1, true)
    with(a, function() ST.AddFake("Bob", {}) end)
    local count = with(a, function() return Store.Count() end)
    local since = with(a, function() return #Store.Since(0) end)
    local _, exported = with(a, function() return ST.Export.Build("all") end)
    return count == 1 and since == 1 and exported == 1,
        string.format("count=%d since=%d exported=%s", count, since, tostring(exported))
end)

add("pending summons: the unanswered and the ones owing silver, newest first", function()
    local a = newClient("Alpha")
    local me = ST.Store.me()
    cast(a, 940, true, { target = me })
    cast(a, 941, true, { target = me, response = { result = "owed", zroll = 0, sroll = 0, time = BASE + 1 } })
    cast(a, 942, true, { target = me, response = { result = "accepted", zroll = 0, sroll = 0, time = BASE + 2 } })
    cast(a, 943, true, { target = "Somebody" })
    local pending = with(a, function() return ST.Respond.Pending() end)
    local ok = #pending == 2 and pending[1].ev.time == BASE + 941 and pending[2].ev.time == BASE + 940
    return ok, ok and "2 waiting: the one owing silver, then the unanswered one" or ("found " .. #pending)
end)

function T.Run()
    realEventClosed = ST.Week.EventClosed
    ST.Week.EventClosed = function() return false end -- the other tests use old summons
    local pass = 0
    local results = {}
    for _, t in ipairs(tests) do
        local ok, good, detail = pcall(t.fn)
        if not ok then good, detail = false, "ERROR " .. tostring(good) end
        results[#results + 1] = { name = t.name, ok = good and true or false, detail = detail or "" }
        if good then pass = pass + 1 end
    end
    for _, r in ipairs(results) do
        ST.print(string.format("%s %s%s", r.ok and "|cff33ff66PASS|r" or "|cffff4444FAIL|r", r.name,
            r.detail ~= "" and ("  (" .. r.detail .. ")") or ""))
    end
    ST.Week.EventClosed = realEventClosed
    ST.print(string.format("sync self-test: %d/%d passed", pass, #tests))
end
