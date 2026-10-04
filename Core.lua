local ADDON, ST = ...

ST.name = ADDON
ST.prefix = "SUMMONCORE"
ST.version = "0.16.0"

local DB_VERSION = 1

local function print_(msg)
    print("|cff33ccffST|r " .. tostring(msg))
end
ST.print = print_

-- Stringify anything safely, including 12.0 secret values and errors.
function ST.safe(v)
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    local ok, s = pcall(tostring, v)
    return ok and s or "<error>"
end

function ST.isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- A character name as the addon stores it: just the first word. This client shows names as "Name Surname"
-- (and other clients may use "Name-Realm"), but the plain UnitName is a single word, so that is what events,
-- tallies and sender checks all compare. nil for anything that is not a usable name.
function ST.baseName(name)
    if type(name) ~= "string" or ST.isSecret(name) then return nil end
    return name:match("^[^%s%-]+")
end

ST.RITUAL_ID = 698 -- Ritual of Summoning (classic ID; confirm with /st test)

-- Spell name for an ID, or nil if unknown, secret or the lookup fails.
function ST.SpellName(id)
    if not id or ST.isSecret(id) then return nil end
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not fn then return nil end
    local ok, name = pcall(fn, id)
    return ok and name or nil
end

local function initDB()
    SummonTrackerDB = SummonTrackerDB or {}
    local db = SummonTrackerDB
    db.version = db.version or DB_VERSION
    db.events = db.events or {}
    db.badges = db.badges or {}
    db.settings = db.settings or { zenitNames = { "Zennit" }, soundOn = true }
    -- The name is spelt Zennit; earlier versions defaulted to "Zenit", so fix saved settings too.
    local names, seen = db.settings.zenitNames or {}, false
    for i, name in ipairs(names) do
        if name:lower() == "zenit" then names[i] = "Zennit" end
        if names[i]:lower() == "zennit" then seen = true end
    end
    if not seen then names[#names + 1] = "Zennit" end
    db.settings.zenitNames = names
    db.harness = db.harness or {}
    ST.db = db
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        initDB()
        -- Remember what the previous session left behind for the save/reload test.
        ST.previousToken = ST.db.harness.token
    elseif event == "PLAYER_LOGIN" then
        if ST.OnLogin then ST.OnLogin() end
        print_("loaded v" .. ST.version .. ". /st for commands.")
    end
end)

local function words(str)
    local out = {}
    for w in (str or ""):gmatch("%S+") do out[#out + 1] = w end
    return out
end

local function fmtTime(t)
    return date("%Y-%m-%d %H:%M", t)
end

local commands = {}

function commands.test(rest)
    if ST.ToggleTests then ST.ToggleTests(rest) end
end

function commands.where()
    local mapID, sub = C_Map.GetBestMapForUnit("player"), GetSubZoneText()
    local pts, kind = ST.Scoring.Score(mapID, sub)
    print_(string.format("mapID=%s zone=%s subzone='%s' -> %s (%d pts)", ST.safe(mapID), GetZoneText(), sub, kind, pts))
end

-- Adds a test summon at your current location. It is never put on the network.
function ST.AddFake(target, assistants)
    local _, ev, badges = ST.Store.Add({
        caster = ST.Store.me(), target = target, assistants = assistants or {},
        mapID = C_Map.GetBestMapForUnit("player"), subzone = GetSubZoneText(), confirmed = true,
    }, true)
    return ev, badges
end

-- Solo testing: /st fake <target> [helper1 helper2]
function commands.fake(rest)
    local w = words(rest)
    if not w[1] then return print_("usage: /st fake <target> [helper1 helper2]") end
    local assistants = {}
    for i = 2, math.min(#w, 3) do assistants[#assistants + 1] = w[i] end
    local ev, badges = ST.AddFake(w[1], assistants)
    print_(string.format("fake summon saved: %s in %s (+%d, %s)", ev.target, ev.subzone, ev.points, ev.kind))
    for _, name in ipairs(badges) do print_("|cffffd100Badge earned:|r " .. name) end
end

-- Opens the assistants prompt without a party: /st fakeprompt <target> <member> <member> ...
function commands.fakeprompt(rest)
    local w = words(rest)
    if #w < 2 then return print_("usage: /st fakeprompt <target> <member> [member ...]") end
    local target = table.remove(w, 1)
    ST.Prompt.Ask(target, w, {}, function(names, confirmed)
        print_(string.format("prompt result: %s, confirmed=%s", #names > 0 and table.concat(names, ", ") or "none",
            tostring(confirmed)))
    end)
end

function commands.log(rest)
    local list = ST.Store.Recent(tonumber(rest) or 10)
    if #list == 0 then return print_("no summons logged yet") end
    for _, r in ipairs(list) do
        local ev = r.ev
        print_(string.format("%s  %s -> %s  helpers: %s  [%s %d pts]%s", fmtTime(ev.time), ev.caster, ev.target,
            #ev.assistants > 0 and table.concat(ev.assistants, ", ") or "none", ev.kind or "?", ev.points or 0,
            ev.confirmed and "" or " unconfirmed"))
    end
end

function commands.panel()
    ST.Hub.Open("summary")
end

function commands.hub()
    ST.Hub.Toggle()
end

-- Test switch: makes this character behave as Zennit's so the gag can be tried solo.
function commands.zenit()
    ST.db.settings.zenitTest = not ST.db.settings.zenitTest
    print_("Zennit test mode " .. (ST.db.settings.zenitTest and "on" or "off"))
end
commands.zennit = commands.zenit -- either spelling works

function commands.tally()
    if ST.Gag.Blocked() then return end
    local rows = {}
    for name, t in pairs(ST.Store.Tallies()) do rows[#rows + 1] = { name = name, t = t } end
    table.sort(rows, function(a, b)
        if a.t.points ~= b.t.points then return a.t.points > b.t.points end
        return a.name < b.name
    end)
    if #rows == 0 then return print_("no summons logged yet") end
    for i = 1, math.min(#rows, 15) do
        local r = rows[i]
        print_(string.format("%s: cast %d, received %d, assisted %d, %d pts", r.name, r.t.cast, r.t.received,
            r.t.assisted, r.t.points))
    end
end

function commands.badges()
    if ST.Gag.Blocked() then return end
    for _, b in ipairs(ST.Scoring.badges) do
        local got = ST.db.badges[b.id]
        print_(string.format("%s %s%s", got and "|cff33ff66[x]|r" or "[ ]", b.name,
            got and (" (" .. fmtTime(got.earned) .. ")") or ""))
    end
end

function commands.undo()
    local last = ST.Store.RemoveLast()
    if last then
        print_(string.format("removed %s -> %s (badges already earned are kept)", last.ev.caster, last.ev.target))
    else
        print_("nothing to undo")
    end
end

function commands.sync()
    ST.Sync.Hello()
    ST.Sync.Status()
end

function commands.export()
    ST.Export.Open("export")
end

function commands.import()
    ST.Export.Open("import")
end

function commands.intro(rest)
    ST.Intro.Toggle(rest)
end

function commands.clip(rest)
    if rest == "" then
        local cats = ST.Clips.Categories()
        if #cats == 0 then
            return print_("no voice clips yet: put .ogg files named <category>_<NN>_<who> in Media/clips, run tools/build_clip_manifest.ps1, then /reload")
        end
        for _, c in ipairs(cats) do print_(string.format("%s: %d clip%s", c[1], c[2], c[2] == 1 and "" or "s")) end
        return print_("/st clip <category or file name> plays one")
    end
    local file = ST.Clips.Play(rest)
    print_(file and ("played " .. file) or ("nothing to play for '" .. rest .. "'"))
end

function commands.gag()
    ST.Gag.Play()
end

function commands.comic(rest)
    ST.Comic.Toggle(rest)
end

function commands.synctest()
    ST.SyncTest.Run()
end

function commands.debug()
    ST.db.settings.debug = not ST.db.settings.debug
    print_("detector debug " .. (ST.db.settings.debug and "on" or "off"))
end

local HELP = {
    "/st - open the Summon Core window (everything below is also in it)    /st help - this list",
    "/st test - diagnostics panel (/st test ping <name>)",
    "/st log [n] - recent summons    /st tally - counts and points    /st badges",
    "/st panel - tally and badge window    /st zenit - toggle Zennit test mode",
    "/st where - current map, subzone and how it scores",
    "/st fake <target> [h1 h2] - add a test summon    /st fakeprompt <target> <members...>",
    "/st sync - say hello to party/guild and show sync status    /st synctest - run the merge self-test",
    "/st export / /st import - copy-paste strings of the summon log",
    "/st intro [scene] - play the illustrated intro (/st intro check tests its sound files)",
    "/st clip [category|file] - list or play voice clips from Media/clips",
    "/st gag - preview the Zennit gag",
    "/st comic [256|512|1024|2048] - large-image test pattern viewer",
    "/st undo - remove the latest summon    /st debug - toggle detector messages",
}

SLASH_SUMMONCORE1 = "/st"
SLASH_SUMMONCORE2 = "/summoncore"
SlashCmdList["SUMMONCORE"] = function(input)
    local cmd, rest = (input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" then
        ST.Hub.Toggle() -- no arguments: the window with everything in it
    elseif commands[cmd] then
        commands[cmd](rest)
    else
        if cmd ~= "" and cmd ~= "help" then print_("unknown command '" .. cmd .. "'") end
        print_("v" .. ST.version)
        for _, l in ipairs(HELP) do print_(l) end
    end
end
