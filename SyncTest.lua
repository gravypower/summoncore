-- /st synctest: exercises Sync encoding, merge rules and the HELLO/REQUEST/BATCH exchange with
-- fake events and simulated clients. Real data is never touched: each client gets a scratch DB.
local ADDON, ST = ...
local Sync, Store = ST.Sync, ST.Store
local T = {}
ST.SyncTest = T

local BASE = 1717000000
local clock = 1000

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
        channels = Sync.channels, quiet = Sync.quiet, now = Sync.now, onAdd = Store.onAdd,
    }
    ST.db, Sync.state, Sync.nameOverride, Sync.quiet = c.db, c.state, c.name, true
    Sync.transport = function(channel, target, payload)
        c.out[#c.out + 1] = { channel = channel, target = target, payload = payload }
    end
    Sync.channels = function() return { "PARTY" } end
    Sync.now = function() return clock end
    Store.onAdd = function(id, ev) Sync.BroadcastEvent(id, ev) end
    local ok, a, b = pcall(fn)
    ST.db, Sync.state, Sync.nameOverride, Sync.transport = saved.db, saved.state, saved.name, saved.transport
    Sync.channels, Sync.quiet, Sync.now, Store.onAdd = saved.channels, saved.quiet, saved.now, saved.onAdd
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
        { rec .. "|x", "fields" },
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

add("Zenit hears a recorded complaint when summoned live, not from history", function()
    local z = newClient("Zenit")
    z.db.settings.zenitTest = true
    local calls = {}
    local realPlay = ST.Clips.Play
    ST.Clips.Play = function(category) calls[#calls + 1] = category end
    local ok, err = pcall(function()
        local function record(target, i)
            local id, ev = sample({ caster = "Alpha", target = target, time = BASE + i })
            return "Alpha-" .. ev.time, ev
        end
        local id, ev = record("Zenit", 300)
        with(z, function() Sync.OnMessage("1~E~" .. Sync.Encode(id, ev), "PARTY", "Alpha") end)       -- live: yes
        id, ev = record("Zenit", 301)
        z.state.requested["Alpha"] = clock
        with(z, function() Sync.OnMessage("1~B~" .. Sync.Encode(id, ev), "WHISPER", "Alpha") end)     -- history: no
        id, ev = record("Someone", 302)
        with(z, function() Sync.OnMessage("1~E~" .. Sync.Encode(id, ev), "PARTY", "Alpha") end)       -- someone else: no
    end)
    ST.Clips.Play = realPlay
    if not ok then return false, tostring(err) end
    return #calls == 1 and calls[1] == "zenit_land", #calls .. " clip call(s)"
end)

function T.Run()
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
    ST.print(string.format("sync self-test: %d/%d passed", pass, #tests))
end
