local ADDON, ST = ...

ST.name = ADDON
ST.prefix = "SUMMONCORE"
ST.version = "0.19.1"

local DB_VERSION = 1

local function print_(msg)
    print("|cff33ccffST|r " .. tostring(msg))
end
ST.print = print_

-- Errors are caught and said (design/lenses.md, Risk Mitigation). With script errors off, which is WoW's default, a bug in a
-- command or an event handler is otherwise silent: the feature just seems not to exist. Guard runs fn under pcall; a failure is
-- kept for /sc errors, said once in chat (per place and message), and still handed to the game's own error handler, so BugSack
-- and the red box behave as they always did. Returns ok and what fn returned.
ST.errors = {}
local MAX_ERRORS = 20
local told = {}
function ST.Guard(name, fn, ...)
    local results = { pcall(fn, ...) }
    if results[1] then return unpack(results) end
    local msg = tostring(results[2]):sub(1, 300)
    local log = ST.errors
    log[#log + 1] = { time = time(), name = name, msg = msg }
    if #log > MAX_ERRORS then table.remove(log, 1) end
    local key = name .. "|" .. msg
    if not told[key] then
        told[key] = true
        ST.print("|cffff6644hit a problem in " .. name .. ":|r " .. msg .. " (|cffffd100/sc errors|r lists them; please tell Aaron)")
    end
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, "Summon Core, " .. name .. ": " .. msg) end
    return false, msg
end

-- A function that always runs under Guard: for event handlers and scripts.
function ST.Safe(name, fn)
    return function(...) return ST.Guard(name, fn, ...) end
end

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

-- The admin is whoever is logged in to this Battle.net account. The check runs on the player's own computer, so
-- it keeps the debug tools and unreached chapters out of the way; it is not security.
ST.ADMIN_TAG = "Gravypower#1577"

-- This account's BattleTag, or nil if the game does not give it (ST.bnGetInfo is a seam for the self-test).
function ST.BattleTag()
    local get = ST.bnGetInfo or BNGetInfo
    if not get then return nil end
    local ok, _, tag = pcall(get)
    if ok and type(tag) == "string" and not ST.isSecret(tag) then return tag end
end

-- Do two BattleTags name the same account? Case and stray spaces do not matter; a missing tag matches nothing.
function ST.TagMatches(tag, expected)
    if type(tag) ~= "string" or type(expected) ~= "string" then return false end
    tag, expected = tag:match("^%s*(.-)%s*$"), expected:match("^%s*(.-)%s*$")
    return tag ~= "" and tag:lower() == expected:lower()
end

function ST.IsAdmin()
    return ST.TagMatches(ST.BattleTag(), ST.ADMIN_TAG)
end

-- Zennit's own Battle.net account: it is Zennit whichever character he is playing.
ST.ZENNIT_TAG = "Zennit#11523"

function ST.IsZennitAccount()
    return ST.TagMatches(ST.BattleTag(), ST.ZENNIT_TAG)
end

-- Checks the BattleTag matching with sample tags, then through the ST.bnGetInfo seam as the game would report them.
-- Returns true or false and a short description.
function ST.TagTest()
    local cases = {
        { "Gravypower#1577", ST.ADMIN_TAG, true }, { "  gravypower#1577 ", ST.ADMIN_TAG, true },
        { "GRAVYPOWER#1577", ST.ADMIN_TAG, true }, { "Gravypower#1578", ST.ADMIN_TAG, false },
        { "Gravypower", ST.ADMIN_TAG, false }, { "Zennit#11523", ST.ZENNIT_TAG, true },
        { "zennit#11523", ST.ZENNIT_TAG, true }, { "Zennit#1152", ST.ZENNIT_TAG, false },
        { "Zennit#11523", ST.ADMIN_TAG, false }, { "", ST.ADMIN_TAG, false }, { nil, ST.ADMIN_TAG, false },
        { 5, ST.ADMIN_TAG, false },
    }
    for i, c in ipairs(cases) do
        if ST.TagMatches(c[1], c[2]) ~= c[3] then return false, "sample " .. i .. " matched wrongly" end
    end
    -- as the game would report them: id, tag, ...
    local saved = ST.bnGetInfo
    local function report(tag) return function() return 1, tag end end
    local out
    ST.bnGetInfo = report("Gravypower#1577")
    if not (ST.IsAdmin() and not ST.IsZennitAccount()) then out = "the admin account is not recognised" end
    ST.bnGetInfo = report("Zennit#11523")
    if not out and not (ST.IsZennitAccount() and not ST.IsAdmin()) then out = "Zennit's account is not recognised" end
    ST.bnGetInfo = report("Someone#1")
    if not out and (ST.IsAdmin() or ST.IsZennitAccount()) then out = "a stranger is recognised" end
    ST.bnGetInfo = function() error("no Battle.net") end
    if not out and (ST.BattleTag() ~= nil or ST.IsAdmin()) then out = "a failing lookup is not handled" end
    ST.bnGetInfo = saved
    if out then return false, out end
    return true, string.format("%d samples and 4 account lookups behave. Live: %s", #cases, ST.TagReport())
end

-- One line saying what the game reports for this account and what the addon makes of it.
function ST.TagReport()
    local tag = ST.BattleTag()
    if not tag then return "BattleTag: the game does not report one (admin: no, Zennit's account: no)" end
    return string.format("BattleTag %s: admin %s, Zennit's account %s", tag, ST.IsAdmin() and "yes" or "no",
        ST.IsZennitAccount() and "yes" or "no")
end

ST.RITUAL_ID = 698 -- Ritual of Summoning (classic ID; confirm with /sc test)

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
frame:SetScript("OnEvent", ST.Safe("the login", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        initDB()
        -- Remember what the previous session left behind for the save/reload test.
        ST.previousToken = ST.db.harness.token
    elseif event == "PLAYER_LOGIN" then
        if ST.OnLogin then ST.OnLogin() end
        print_("loaded v" .. ST.version .. ". /sc for commands.")
    end
end))

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

-- What each place is worth, with every map ID checked against the game's own name for it.
function commands.places()
    local lines = ST.Scoring.Places(function(id)
        local ok, info = pcall(C_Map.GetMapInfo, id)
        return ok and type(info) == "table" and type(info.name) == "string" and info.name or nil
    end)
    for _, l in ipairs(lines) do print_(l) end
end

-- Adds a test summon at your current location. It is never put on the network.
function ST.AddFake(target, assistants)
    local _, ev, badges = ST.Store.Add({
        caster = ST.Store.me(), target = target, assistants = assistants or {},
        mapID = C_Map.GetBestMapForUnit("player"), subzone = GetSubZoneText(), confirmed = true,
        fake = true, -- test summons stay on this client: not counted for sync, not sent, not exported
    }, true)
    return ev, badges
end

-- Solo testing: /sc fake <target> [helper1 helper2]
function commands.fake(rest)
    local w = words(rest)
    if not w[1] then return print_("usage: /sc fake <target> [helper1 helper2]") end
    local assistants = {}
    for i = 2, math.min(#w, 3) do assistants[#assistants + 1] = w[i] end
    local ev, badges = ST.AddFake(w[1], assistants)
    print_(string.format("fake summon saved: %s in %s (+%d, %s)", ev.target, ev.subzone, ev.points, ev.kind))
    for _, name in ipairs(badges) do print_("|cffffd100Badge earned:|r " .. name) end
end

-- Opens the assistants prompt without a party: /sc fakeprompt <target> <member> <member> ...
function commands.fakeprompt(rest)
    local w = words(rest)
    if #w < 2 then return print_("usage: /sc fakeprompt <target> <member> [member ...]") end
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
function commands.zenit(rest)
    local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    if sub ~= "list" and not ST.IsAdmin() then return print_("that is an admin tool") end
    if sub == "list" then
        -- his secret list: /sc zennit list [add <place> | remove <n> | clear]
        local R = ST.Respond
        local verb, what = arg:match("^(%S*)%s*(.-)$")
        if verb == "add" then
            local ok, why = R.ListAdd(what)
            print_(ok and ("added '" .. what .. "'") or why)
        elseif verb == "remove" then print_(R.ListRemove(what) and "removed" or "no such entry")
        elseif verb == "clear" then R.ListClear() print_("list cleared") end
        local list = R.List()
        print_(#list == 0 and "secret list is empty" or "secret list: " .. table.concat(list, "; "))
        if #R.ListActive() < #list then
            print_(string.format("only the first %d entries of %d letters or more count", R.LIST_MAX, R.LIST_MIN))
        end
        if ST.Hub then ST.Hub.Refresh() end
        return
    end
    ST.db.settings.zenitTest = not ST.db.settings.zenitTest
    if ST.db.settings.zenitTest then ST.db.settings.partyTest = false end -- the two test modes exclude each other
    print_("Zennit test mode " .. (ST.db.settings.zenitTest and "on" or "off"))
end

-- Test switch: makes this character behave as an ordinary party member (even the admin, or Zennit's own account),
-- so the party's gag on Zennit's tab can be tried solo.
function commands.party()
    if not ST.IsAdmin() then return print_("that is an admin tool") end
    ST.db.settings.partyTest = not ST.db.settings.partyTest
    if ST.db.settings.partyTest then ST.db.settings.zenitTest = false end
    print_("party test mode " .. (ST.db.settings.partyTest and "on" or "off"))
end
commands.zennit = commands.zenit -- either spelling works

function commands.tally()
    if ST.Gag.Blocked() then return end
    local rows = ST.Store.Ranked(ST.Store.Tallies(), ST.Ledger.Facts().casters)
    if #rows == 0 then return print_("no summons logged yet") end
    for i = 1, math.min(#rows, 15) do
        local name, t, ofZennit = rows[i][1], rows[i][2], rows[i][3]
        print_(string.format("%s: cast %d (%d of Zennit this season), received %d, assisted %d, %d pts", name, t.cast, ofZennit,
            t.received, t.assisted, t.points))
    end
end

function commands.badges()
    if ST.Gag.Blocked() then return end
    for _, b in ipairs(ST.Scoring.badges) do
        local got = ST.db.badges[b.id]
        print_(string.format("%s %s%s", got and "|cff33ff66[x]|r" or "[ ]", b.name,
            got and (" (" .. fmtTime(got.earned) .. ")") or (b.how and (": " .. b.how) or "")))
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
        return print_("/sc clip <category or file name> plays one")
    end
    local file = ST.Clips.Play(rest)
    print_(file and ("played " .. file) or ("nothing to play for '" .. rest .. "'"))
end

-- The weekly contest: how this week is going and how the last one ended.
function commands.week(rest)
    local W = ST.Week
    if rest == "victory" or rest == "group" or rest:match("^[zg]%d$") then return ST.Intro.Toggle(rest) end
    if rest == "say" then
        local ok, text = W.SayWeek({
            channel = function() return IsInRaid() and "RAID" or IsInGroup() and "PARTY" or nil end,
            send = function(msg, channel) SendChatMessage(msg, channel) end,
        })
        return print_(ok and ("Told the group: " .. text) or text)
    end
    local this, last = W.Score(W.Start()), W.Score(W.Start() - 7 * 86400)
    print_("This week: " .. W.Describe(this))
    print_("Last week: " .. W.Describe(last))
    local whim = W.WhimLine(W.Start())
    if whim and not W.IsOff(W.Start()) then print_("This week's whim: " .. whim) end
    local season = W.Season()
    print_(string.format("Season: Zennit %d of %d wins, the group %d of %d. Finales so far: %d.", season.zennit, W.WINS,
        season.group, W.WINS, #season.finales))
    local immune, untilT = W.Immune(time())
    if immune then print_("Zennit is on his week off until " .. date("%a %d %b", untilT) .. ". /sc week victory plays the story.") end
end

-- Summon cards (the coffee card): prepaid silver, sold by Zennit. /sc cards lists the balances; /sc card sell <name> [punches
-- [silver]] and /sc card offer <punches> <silver> are his.
function commands.cards()
    for _, line in ipairs(ST.Cards.Lines()) do print_(line) end
end

function commands.card(rest)
    local verb, a, b, c = (rest or ""):match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    if verb == "sell" then
        local offer = ST.Cards.Offers()[1]
        local punches = tonumber(b) or offer.punches
        local silver = tonumber(c) or math.floor(offer.silver * punches / offer.punches + 0.5) -- the usual price per punch
        local card, why = ST.Cards.Issue(a, punches, silver)
        if not card then print_(why) end
    elseif verb == "offer" then
        if ST.Cards.SetOffer(a, b) then
            print_(string.format("offer: %d punches for %d silver", ST.Cards.Offers()[1].punches, ST.Cards.Offers()[1].silver))
        else
            print_("usage: /sc card offer <punches> <silver>")
        end
    else
        local offer = ST.Cards.Offers()[1]
        print_(string.format("A card is prepaid silver. Zennit sells %d punches for %d silver; each time he demands the fifty silver from the holder, a punch pays it.", offer.punches, offer.silver))
        print_("/sc cards lists who holds what; his: /sc card sell <name> [punches [silver]], /sc card offer <punches> <silver>")
    end
end

-- Listens to trade and mail events and prints what the client lets an addon see, to learn how silver could be detected.
function commands.probe()
    ST.Silver.Probe()
end

-- The problems this session has caught (see ST.Guard): the last ten, newest last; "clear" forgets them.
function commands.errors(rest)
    if rest == "clear" then
        for i = #ST.errors, 1, -1 do ST.errors[i] = nil end
        return print_("errors cleared")
    end
    if #ST.errors == 0 then return print_("No problems caught this session.") end
    for i = math.max(1, #ST.errors - 9), #ST.errors do
        local e = ST.errors[i]
        print_(string.format("%s  %s: %s", date("%H:%M:%S", e.time), e.name, e.msg))
    end
end

-- The Monday tip on or off.
function commands.tips(rest)
    local s = ST.db.settings
    if rest == "off" then s.tipsOff = true elseif rest == "on" then s.tipsOff = nil end
    print_("Monday tips are " .. (s.tipsOff and "off" or "on") .. ". /sc tips " .. (s.tipsOff and "on" or "off") .. " changes it.")
end

-- The titles as they stand in this season (the Index names them for good at the finale).
function commands.titles()
    for _, line in ipairs(ST.Ledger.Standings()) do print_(line) end
end

-- The tab: who owes Zennit what (his client), or what you owe (everyone else's).
function commands.tab()
    for _, line in ipairs(ST.Silver.Lines()) do print_(line) end
end

-- What the log says about how the race is being played (for a playtest).
function commands.report()
    for _, line in ipairs(ST.Report.Lines()) do print_(line) end
end

-- The rules of the race, with this week's live numbers.
function commands.rules()
    for _, line in ipairs(ST.Week.RulesCard()) do print_(line) end
end

-- The Index's keepsake of each finished season, newest first.
function commands.seasons()
    local seasons = ST.Ledger.Seasons()
    if #seasons == 0 then return print_("No season has finished yet. The Index is keeping the file open.") end
    for _, s in ipairs(seasons) do
        for _, line in ipairs(s.lines) do print_(line) end
    end
end

function commands.respond(rest)
    if rest == "test" then
        if not ST.IsAdmin() then return print_("that is an admin tool") end
        ST.Respond.Test()
    else
        ST.Respond.Open()
    end
end

-- Says whether this account is the admin, and what the game reports as its BattleTag.
function commands.admin()
    print_(ST.TagReport())
end

-- /sc reset - wipes this client's summons, badges and story progress (asks first).
-- /sc reset all - the admin also asks every other Summon Core user in the party, raid and guild to do the same.
function commands.reset(rest)
    local everyone = rest == "all"
    if everyone and not ST.IsAdmin() then return print_("that is an admin tool") end
    ST.Reset.Ask(everyone)
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

-- What a player needs: five lines. /sc help all has the rest (design/lenses.md, Interface).
local HELP_SHORT = {
    "/sc - the Summon Core window: the party's tally and badges, Zennit's answers, the log, the story and the tools",
    "/sc rules - the rules of the race, with this week's live numbers    /sc week - how this week and the season stand (/sc week say tells the group)",
    "/sc tab - what is owed in silver    /sc cards - who holds a summon card    /sc titles - who leads the season's titles",
    "/sc report - how the race is going (paste it to the group)    /sc seasons - the record of every finished season",
    "/sc help all - every command (the rest are for setting up, testing and Zennit)    /sc tips off - stop the Monday tip",
}

local HELP = {
    "/sc - open the Summon Core window (everything below is also in it)    /sc help - the short list    /sc help all - this list",
    "/sc test - diagnostics panel (/sc test ping <name>)",
    "/sc log [n] - recent summons    /sc tally - counts and points    /sc badges",
    "/sc panel - open the window on the Party tab    /sc zenit - toggle Zennit test mode    /sc party - toggle party test mode",
    "/sc where - current map, subzone and how it scores    /sc places - what every place is worth, checked against the game",
    "/sc fake <target> [h1 h2] - add a test summon    /sc fakeprompt <target> <members...>",
    "/sc sync - say hello to party/guild and show sync status    /sc synctest - run the merge self-test",
    "/sc export / /sc import - copy-paste strings of the summon log",
    "/sc intro [scene] - play the illustrated intro (/sc intro check tests its sound files)",
    "/sc clip [category|file] - list or play voice clips from Media/clips",
    "/sc zennit list [add <place>|remove <n>|clear] - his secret list: refusing a summon there is free",
    "/sc admin - what the game reports as this account's BattleTag, and whether it is the admin or Zennit's",
    "/sc reset [all] - wipe summons, badges and the story (all: the admin asks everyone to do the same)",
    "/sc week [say|z1..z5|g1..g5] - the weekly contest and the season (first to 5 wins); say tells the group, a key plays that chapter of the story",
    "/sc titles - who leads each of the season's titles so far (heaviest hand, best supporting role, ...)",
    "/sc tab - who owes Zennit what (on his client), or what you owe him (on everyone else's)",
    "/sc cards - who holds a summon card and how many punches are left; /sc card - how cards work (Zennit sells them)",
    "/sc probe - listen to trade and mail events and print what the client shows (how silver could be detected)",
    "/sc report - what the log says about how the race is being played (for a playtest)",
    "/sc rules - the rules of the race, with this week's live numbers",
    "/sc seasons - the Index's keepsake of each finished season (who was there, the silver, the moments)",
    "/sc respond [test] - Zennit answers a summon of him (accept, refuse, ask for silver, dice); test tries it",
    "/sc tips [on|off] - the one-line tip about a command, at the Monday login",
    "/sc errors [clear] - problems the addon caught in itself this session (tell Aaron what they say)",
    "/sc gag - preview the Zennit gag",
    "/sc comic [256|512|1024|2048] - large-image test pattern viewer",
    "/sc undo - remove the latest summon    /sc debug - toggle detector messages",
}

-- Debug and test tools are for the admin's account only.
for _, name in ipairs({ "test", "fake", "fakeprompt", "comic", "synctest", "debug", "gag" }) do
    local run = commands[name]
    commands[name] = function(...)
        if not ST.IsAdmin() then return print_("that is an admin tool") end
        return run(...)
    end
end

SLASH_SUMMONCORE1 = "/sc"
SLASH_SUMMONCORE2 = "/summoncore"
SlashCmdList["SUMMONCORE"] = function(input)
    local cmd, rest = (input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" then
        ST.Guard("the window", ST.Hub.Toggle) -- no arguments: the window with everything in it
    elseif commands[cmd] then
        ST.Guard("/sc " .. cmd, commands[cmd], rest)
    else
        if cmd ~= "" and cmd ~= "help" then print_("unknown command '" .. cmd .. "'") end
        print_("v" .. ST.version)
        local all = cmd == "help" and rest:lower() == "all"
        for _, l in ipairs(all and HELP or HELP_SHORT) do print_(l) end
    end
end
