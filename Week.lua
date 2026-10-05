-- Week: the weekly contest. Each Monday (UTC) to the next, the group's landed summon points are set against
-- Zennit's points toward a week off (see Store.Goal). He starts every week with a head start, and a tie goes to
-- him. When he wins, the seven days that follow are his: no summons. From October 2026 the race follows
-- Week.RULES: the group has to beat Zennit at his own answers, and he no longer wins most weeks by default.
-- Everything is derived from the event log, so every client reaches the same result.
-- A week closes two days after it ends: its winner is then frozen and Zennit can no longer answer into it.
local ADDON, ST = ...
local Week = {}
ST.Week = Week

local DAY = 86400
local LENGTH = 7 * DAY
local MONDAY = 4 * DAY       -- 1970-01-05 00:00 UTC was a Monday
Week.HEADSTART = 10          -- points Zennit starts each week with

-- Start of the week containing t (default: now), a Unix time.
function Week.Start(t)
    t = t or time()
    return t - ((t - MONDAY) % LENGTH)
end

-- Zennit's characters: the listed names, plus the alts his own client has announced over sync (settings.zenitAlts).
local function isZennit(name)
    local base = ST.baseName(name)
    if not base then return false end
    local s = ST.db.settings
    for _, list in ipairs({ s and s.zenitNames or { "Zennit" }, s and s.zenitAlts or {} }) do
        for _, n in ipairs(list) do
            if ST.baseName(n) and ST.baseName(n):lower() == base:lower() then return true end
        end
    end
    return false
end
Week.IsZennit = isZennit

-- A week closes GRACE after it ends, leaving time for late answers and late syncs. Once closed, its winner is
-- frozen on this client (Week.Check), so a stray old answer or late-synced summon cannot flip a decided week.
Week.GRACE = 2 * DAY

function Week.Closed(start, now)
    return (now or time()) >= start + LENGTH + Week.GRACE
end

function Week.EventClosed(ev)
    return Week.Closed(Week.Start(ev.time))
end

local function frozen()
    return ST.db and ST.db.settings and ST.db.settings.weekFrozen
end

-- The race from the week of Monday 5 October 2026 (UTC) on: beating Zennit means beating his answers (see
-- design/lenses.md). Only summons OF Zennit count, up to `cap` of them each week; once `minimum` have been filed and
-- the latest answered, he may close the Index for the rest of the week (an answer with `closes` set). He has `dice`
-- rolls a week; each helper (up to `helpersMax`) adds `helperBonus` to the summoner's roll. Weeks before `from` keep the
-- rules they were played under, so the season and the chapters already reached do not change.
Week.RULES = { from = 1791158400, headstart = 2, minimum = 5, cap = 10, dice = 3, helperBonus = 5, helpersMax = 2,
    -- Catch-up (design/lenses.md, the Interest Curve): when one side is this many wins ahead in the season, the Index
    -- moves Zennit's edge on the dice by this much for the side that is behind, and the other way for the side ahead.
    -- A lead of 1 changes nothing; a lead past the last step uses the last step.
    catchup = { [2] = 5, [3] = 10 },
    -- The whim of the week (design/lenses.md, Surprise): about half the weeks, the Index draws one small twist.
    whims = true,
    -- A summons of Zennit unanswered for this many seconds is "waiting for his answer": the group is told, so it can chase him
    -- (design/lenses.md, Community).
    overdue = 3600 }

-- Each whim moves one rule for one week, by a few points of the group's chance (about +6 or -5 in a normal week), so no
-- week is much easier or harder than another. `show` is the rule whose number the text names, when it does.
Week.WHIMS = {
    distracted = { name = "The Index is distracted", rules = { edge = -5 }, text = "Zennit's edge on the dice is 5 lower this week." },
    attentive = { name = "The Index is attentive", rules = { edge = 5 }, text = "Zennit's edge on the dice is 5 higher this week." },
    feast = { name = "A helpers' feast", rules = { helperBonus = 3 }, show = "helperBonus",
        text = "Each helper adds +%d to the summoner's roll this week." },
    tired = { name = "The helpers are tired", rules = { helperBonus = -3 }, show = "helperBonus",
        text = "Each helper adds only +%d to the summoner's roll this week." },
}
-- Half the weeks have none. The week number picks one, the same on every client, so nothing is synced or kept.
local DECK = { false, "distracted", false, "feast", false, "attentive", false, "tired" }

function Week.Whim(start)
    if not Week.RULES.whims or not Week.NewRules(start) then return nil end
    local n = math.floor((start - MONDAY) / LENGTH)
    local x = (n * 1103515245 + 12345) % 2147483648
    local id = DECK[math.floor(x / 65536) % #DECK + 1]
    return id and Week.WHIMS[id] or nil, id
end

-- A rule's value for the week starting at `start`: its base value, moved by the week's whim (never below 0).
function Week.Rule(name, start)
    local base = name == "edge" and ST.Respond.EDGE or Week.RULES[name]
    local whim = Week.Whim(start)
    return math.max(0, base + (whim and whim.rules[name] or 0))
end

-- The week's whim in one sentence ("The Index is distracted. Zennit's edge on the dice is 5 lower this week."), or nil.
function Week.WhimLine(start)
    local whim = Week.Whim(start)
    if not whim then return nil end
    return whim.name .. ". " .. (whim.show and string.format(whim.text, Week.Rule(whim.show, start)) or whim.text)
end

function Week.NewRules(start)
    return start >= Week.RULES.from
end

-- Is the week starting at `start` Zennit's week off? From the new rules on, a week off is real: he won the week before,
-- so summons of him are filler (logged, answered and gagged as usual, but the race ignores them) and nobody wins the
-- week: a win for Zennit is a pause, not a head start. The search back through the weeks ends at the first real summon
-- or at a week whose winner is frozen.
function Week.IsOff(start)
    if not Week.NewRules(start) then return false end
    local prev, first = start - LENGTH, nil
    for _, ev in pairs(ST.db.events) do
        if not ev.fake and (not first or ev.time < first) then first = ev.time end
    end
    if not first or prev < Week.Start(first) then return false end
    local f = frozen() and frozen()[prev]
    if f then return f == "zennit" end
    return Week.Score(prev).winner == "zennit"
end

-- Why a summon of Zennit in the week starting at `start` does not count, and what the Index files it under. `you` words
-- it for Zennit's own client.
function Week.Why(start, you)
    if Week.IsOff(start) then return you and "It is your week off" or "It is his week off", "filler" end
    if Week.IsClosed(start) then
        return you and "You have closed the Index for the week" or "He has closed the Index for the week", "enthusiasm"
    end
    return string.format(you and "It is past the %d summons of you that count this week" or
        "It is past the %d summons of him that count this week", Week.RULES.cap), "enthusiasm"
end

-- The real summons of Zennit in the week starting at `start`, oldest first: { { id, ev }, ... }.
local function summonsOfZennit(start)
    local list = {}
    for id, ev in pairs(ST.db.events) do
        if not ev.fake and ev.time >= start and ev.time < start + LENGTH and isZennit(ev.target) then
            list[#list + 1] = { id = id, ev = ev }
        end
    end
    table.sort(list, function(a, b)
        if a.ev.time ~= b.ev.time then return a.ev.time < b.ev.time end
        return tostring(a.id) < tostring(b.id)
    end)
    return list
end

-- The summons of Zennit filed toward the week starting at `start`: the list (oldest first), how many of them count
-- (up to `cap`, or up to the one whose answer closed the Index), and whether he closed it.
local function filed(start, off)
    local list = summonsOfZennit(start)
    if off == nil then off = Week.IsOff(start) end
    if off then return list, 0, false end
    local limit, closed = Week.RULES.cap, false
    for i, s in ipairs(list) do
        if i > limit then break end
        if i >= Week.RULES.minimum and s.ev.response and s.ev.response.closes then
            limit, closed = i, true
            break
        end
    end
    return list, math.min(limit, #list), closed
end

-- Has Zennit closed the Index for the week starting at `start`?
function Week.IsClosed(start)
    if not Week.NewRules(start) then return false end
    return (select(3, filed(start)))
end

-- Summons of Zennit in the week starting at `start` that he has not answered. With `minAge`, only those at least that old.
function Week.Unanswered(start, minAge)
    local n, now = 0, time()
    for _, s in ipairs(summonsOfZennit(start)) do
        if not s.ev.response and (not minAge or now - s.ev.time >= minAge) then n = n + 1 end
    end
    return n
end

-- Summons of Zennit in the week starting at `start` whose silver he has asked for and not yet had. Returns how many, and the silver.
function Week.Owed(start)
    local n, silver = 0, 0
    for _, s in ipairs(summonsOfZennit(start)) do
        if s.ev.response and s.ev.response.result == "owed" then
            n, silver = n + 1, silver + ST.Respond.AmountOf(s.ev.response)
        end
    end
    return n, silver
end

-- Waiting for his answer for longer than RULES.overdue.
function Week.Overdue(start)
    return Week.Unanswered(start, Week.RULES.overdue)
end

-- The summon Zennit can close the Index on, in the week starting at `start` (nil if he can't yet): the latest
-- answered summon that counts, once at least `minimum` have been filed.
function Week.CloseTarget(start)
    if not Week.NewRules(start) then return nil end
    local list, counted, closed = filed(start)
    if closed or counted < Week.RULES.minimum then return nil end
    for i = counted, Week.RULES.minimum, -1 do
        if list[i].ev.response then return list[i].id, list[i].ev end
    end
end

-- Does this summon count toward its week? Under the new rules: a summon of Zennit among those filed (a test summon is
-- placed among the real ones by its time). Under the old rules every summon counts.
function Week.Counts(ev)
    local start = Week.Start(ev.time)
    if not Week.NewRules(start) then return true end
    if not isZennit(ev.target) or Week.IsOff(start) then return false end
    local list, counted, closed = filed(start)
    local before = 0
    for i, s in ipairs(list) do
        if s.ev == ev then return i <= counted end
        if s.ev.time <= ev.time then before = before + 1 end
    end
    return before < (closed and counted or Week.RULES.cap)
end

-- Dice Zennit has left in the week starting at `start`, or nil when there is no limit (the old rules).
function Week.DiceLeft(start)
    if not Week.NewRules(start) then return nil end
    local used = 0
    for _, s in ipairs(summonsOfZennit(start)) do
        local res = s.ev.response and s.ev.response.result
        if res == "won" or res == "lost" then used = used + 1 end
    end
    return math.max(0, Week.RULES.dice - used)
end

-- Zennit's edge on the dice for the week starting at `start`: Respond.EDGE, moved by the season's lead (RULES.catchup).
-- Zennit ahead by wins: the edge shrinks, so the group has a way back; the group ahead: it grows. It is worked out from
-- the weeks before `start`, so it does not change during the week. Second value: how far it moved (negative: in the
-- group's favour).
function Week.Edge(start)
    local base = Week.Rule("edge", start)
    if not Week.NewRules(start) then return base, 0 end
    local season = Week.Season(start)
    local lead = season.zennit - season.group -- Zennit's lead in weekly wins
    local steps, top = Week.RULES.catchup, 0
    for lead_ in pairs(steps) do top = math.max(top, lead_) end
    local by = steps[math.min(math.abs(lead), top)] or 0
    if lead == 0 or by == 0 then return base, 0 end
    local moved = lead > 0 and -by or by
    if base + moved < 0 then moved = -base end -- never a handicap for Zennit
    return base + moved, moved
end

-- What the summoner adds to their dice roll for this summon: a bonus per helper (0 under the old rules).
function Week.HelperBonus(ev)
    if not Week.NewRules(Week.Start(ev.time)) then return 0 end
    return math.min(#(ev.assistants or {}), Week.RULES.helpersMax) * Week.Rule("helperBonus", Week.Start(ev.time))
end

-- The score for the week starting at `start`: { start, group, zennit, summons, winner, over, new, counted, extra,
-- closed }. winner is "zennit", "group", or nil when there were no summons that week. Under the new rules, counted is
-- how many summons of Zennit count toward the week, extra how many came after those, and closed whether he closed
-- the Index.
function Week.Score(start)
    local new = Week.NewRules(start)
    local r = { start = start, group = 0, zennit = new and Week.RULES.headstart or Week.HEADSTART, summons = 0,
        over = time() >= start + LENGTH, new = new, counted = 0, extra = 0, off = new and Week.IsOff(start) }
    for _, ev in pairs(ST.db.events) do
        if not ev.fake and ev.time >= start and ev.time < start + LENGTH then
            r.summons = r.summons + 1
            if not new then
                if ST.Store.Lands(ev) then r.group = r.group + (ev.points or 0) end
                if isZennit(ev.target) then r.zennit = r.zennit + ST.Store.Goal(ev) end
            end
        end
    end
    if new then
        local list, counted, closed = filed(start, r.off)
        r.closed = closed
        for i, s in ipairs(list) do
            if i <= counted then
                r.counted = r.counted + 1
                if ST.Store.Lands(s.ev) then r.group = r.group + (s.ev.points or 0) end
                r.zennit = r.zennit + ST.Store.Goal(s.ev)
            else
                r.extra = r.extra + 1
            end
        end
    end
    if r.summons > 0 and not r.off then r.winner = r.zennit >= r.group and "zennit" or "group" end
    local f = frozen() and frozen()[start]
    if f then r.winner = f ~= "none" and f or nil end
    return r
end

-- Freezes the winner of every closed week not yet frozen, from the first summon on.
function Week.Freeze()
    local settings = ST.db and ST.db.settings
    if not settings then return end
    local first
    for _, ev in pairs(ST.db.events) do
        if not ev.fake and (not first or ev.time < first) then first = ev.time end
    end
    if not first then return end
    settings.weekFrozen = settings.weekFrozen or {}
    local start = Week.Start(first)
    while Week.Closed(start) do
        if not settings.weekFrozen[start] then
            settings.weekFrozen[start] = Week.Score(start).winner or "none"
        end
        start = start + LENGTH
    end
end

-- Is Zennit on his week off right now? True when he won last week. Returns the end time as the second value.
function Week.Immune(now)
    local current = Week.Start(now)
    local last = Week.Score(current - LENGTH)
    return last.winner == "zennit", current + LENGTH
end

local function lines(r)
    local text = string.format("group %d, Zennit %d (including a %d point head start)", r.group, r.zennit,
        r.new and Week.RULES.headstart or Week.HEADSTART)
    if r.new then
        text = text .. string.format("; %d of up to %d summons of Zennit filed", r.counted, Week.RULES.cap)
        if r.closed then text = text .. ", and he closed the Index" end
        if r.extra > 0 then text = text .. string.format(", %d more filed under 'enthusiasm'", r.extra) end
    end
    return text
end

-- One line saying how the week is going, or how it ended.
function Week.Describe(r)
    if r.off then
        return (r.over and "Zennit's week off: " or "Zennit's week off, ") .. (r.summons == 0 and "nobody summoned him" or
            string.format("%d summon%s filed as filler", r.summons, r.summons == 1 and "" or "s")) ..
            ", and the race skipped the week"
    end
    if r.summons == 0 then return "no summons that week" end
    if not r.over then
        return "this week so far: " .. lines(r) .. (r.zennit >= r.group and ", Zennit is ahead" or ", the group is ahead")
    end
    return (r.winner == "zennit" and "Zennit won the week: " or "the group won the week: ") .. lines(r)
end

-- The season is a race: the first side to WINS weekly wins takes the finale, then the count starts again.
-- Worked out from the log, one completed week at a time, so every client reaches the same story.
-- Returns { zennit, group (wins so far this season), since (the season's first week), finales = { { start, side, from } }, chapters = { { start, side, n, key } } }
-- where key is the story chapter that win plays: z<n> or g<n> (n = 5 is the finale).
Week.WINS = 5

function Week.Season(now)
    now = now or time()
    local s = { zennit = 0, group = 0, finales = {}, chapters = {} }
    local first
    for _, ev in pairs(ST.db.events) do
        if not ev.fake and (not first or ev.time < first) then first = ev.time end
    end
    if not first then return s end
    local start, current = Week.Start(first), Week.Start(now)
    s.since = start -- the first week of the season in progress (each finale lists its own as `from`)
    while start < current do
        local r = Week.Score(start)
        local side = r.winner
        if side then
            s[side] = s[side] + 1
            s.chapters[#s.chapters + 1] = { start = start, side = side, n = s[side], key = (side == "zennit" and "z" or "g") .. s[side] }
            if s[side] >= Week.WINS then
                s.finales[#s.finales + 1] = { start = start, side = side, from = s.since }
                s.zennit, s.group = 0, 0
                s.since = start + LENGTH
            end
        end
        start = start + LENGTH
    end
    return s
end

-- Says once a week what the whim of this week is (nothing in a week off, or when there is none).
function Week.AnnounceWhim()
    local settings = ST.db and ST.db.settings
    local start = Week.Start()
    if not settings or settings.whimSeen == start then return end
    local line = Week.WhimLine(start)
    if not line or Week.IsOff(start) then return end
    settings.whimSeen = start
    ST.print("|cffffd100This week's whim:|r " .. line)
end

-- Says once when a finished week has been won, and points to that win's chapter of the story.
-- The keepsake of the season that has just ended, in chat.
local function printKeepsake()
    local seasons = ST.Ledger.Seasons()
    if seasons[1] then
        for _, line in ipairs(seasons[1].lines) do ST.print(line) end
    end
end

-- A result announced as provisional is settled once its week has closed: said again as final, or as changed.
local function settleLastWeek()
    local settings = ST.db.settings
    local a = settings.weekAnnounced
    if not (a and a.provisional and Week.Closed(a.start)) then return end
    a.provisional = nil
    local now = Week.Score(a.start).winner
    local who = { zennit = "Zennit", group = "the group" }
    if now == a.winner then
        ST.print(string.format("The week of %s is now final: it stays with %s.", date("%d %b", a.start), who[now] or "nobody"))
    else
        ST.print(string.format("|cffffd100The week of %s changed|r after Zennit's late answers: it went to %s, not %s.",
            date("%d %b", a.start), who[now] or "nobody", who[a.winner] or "nobody"))
    end
    local season = Week.Season()
    local f = season.finales[#season.finales]
    if now == a.winner and f and f.start == a.start then printKeepsake() end
end

local function checkLastWeek()
    if not ST.db or not ST.db.settings then return end
    Week.Freeze()
    settleLastWeek() -- an earlier provisional result, now that its week has closed
    local last = Week.Score(Week.Start() - LENGTH)
    if last.off and ST.db.settings.weekSeen ~= last.start then
        ST.db.settings.weekSeen = last.start
        ST.print("Zennit's week off is over. He is back on the list, and the Index has filed the week as filler.")
        return
    end
    if not last.winner or ST.db.settings.weekSeen == last.start then return end
    ST.db.settings.weekSeen = last.start
    ST.Clips.Play("narrator_weekopen")
    local season = Week.Season()
    local chapter = season.chapters[#season.chapters]
    local key = chapter and chapter.start == last.start and chapter.key
    -- while he can still answer into the week (two days after it ends), the result is provisional
    local waiting = Week.Unanswered(last.start)
    local provisional = waiting > 0 and not Week.Closed(last.start)
    ST.db.settings.weekAnnounced = { start = last.start, winner = last.winner, provisional = provisional or nil }
    local story = ""
    if key then
        story = ST.Intro.HasChapter(key) and (" The story: |cffffd100/sc intro " .. key .. "|r") or " (That chapter of the story is not written yet.)"
        if chapter.n >= Week.WINS then
            story = story .. " That was the finale. The season starts again. |cffffd100/sc seasons|r keeps the Index's record of it."
        end
    end
    if last.winner == "zennit" then
        ST.print(ST.Voice.Say("week.zennit", {
            "|cffffd100Zennit won the week|r (%s). He is on leave until next Monday.%s",
            "|cffffd100Zennit has won the week|r (%s). He is on leave until Monday, and the Index has been told not to look for him.%s",
            "|cffffd100The week was Zennit's|r (%s). He is on leave until next Monday.%s" }, lines(last), story))
    else
        ST.print(ST.Voice.Say("week.group", {
            "The group won the week (%s). Zennit is back on the list.%s",
            "The group took the week (%s). Zennit is back on the list, and has been told.%s",
            "The week went to the group (%s). Zennit is back on the list.%s" }, lines(last), story))
    end
    ST.print(string.format("Season: Zennit %d of %d, the group %d of %d.", season.zennit, Week.WINS, season.group, Week.WINS))
    if provisional then
        ST.print(string.format("|cffffd100Provisional:|r %d summons of him %s still waiting for his answer, and the week closes on %s. " ..
            "The Index will say again if it changes.", waiting, waiting == 1 and "is" or "are",
            date("%A", last.start + LENGTH + Week.GRACE)))
    elseif chapter and chapter.start == last.start and chapter.n >= Week.WINS then
        printKeepsake() -- a finale just landed: the Index's keepsake of the season, with who was there
    end
end

-- The rules of the race on one card, with this week's live numbers (the base rules, the whim and the catch-up already
-- applied), so there is one place that says them all and it cannot go stale. A list of lines.
function Week.RulesCard(start)
    start = start or Week.Start()
    local R, kinds = Week.RULES, ST.Scoring.kindPoints
    if not Week.NewRules(start) then
        return { "The race runs on the old rules this week: every landed summon counts for the group, and Zennit starts with " ..
            Week.HEADSTART .. " points." }
    end
    local edge, moved = Week.Edge(start)
    local bonus = Week.Rule("helperBonus", start)
    local card = {
        "THE RACE, this week",
        string.format("Counts: only summons of Zennit, up to %d a week. Any more are filed under 'enthusiasm'. Once %d are filed and " ..
            "the latest is answered, he may close the Index for the week.", R.cap, R.minimum),
        string.format("Points: a city %d, a zone %d, a dungeon %d, a far-flung place %d. The group scores the summons that land; " ..
            "Zennit scores the dice he wins and the places on his list that land. Zennit starts the week with %d, and a tie is his.",
            kinds.city, kinds.zone, kinds.dungeon, kinds.remote, R.headstart),
        string.format("Dice: he has %d a week and adds +%d to his roll; each helper (two at most) adds +%d to the summoner's. " ..
            "When they are gone he can only accept, refuse or ask for the silver.", Week.Rule("dice", start), edge, bonus),
        string.format("His list: up to %d places of %d letters or more. Accepting a summon there earns him the points; refusing it is free.",
            ST.Respond.LIST_MAX, ST.Respond.LIST_MIN),
        string.format("Catch-up: when a side leads the season by two wins, his edge moves %d toward the side that is behind; by three, %d.%s",
            R.catchup[2] or 0, R.catchup[3] or 0, moved ~= 0 and string.format(" This week it has moved %+d.", moved) or ""),
        string.format("The season: win %d weeks to take its finale. A week he wins is followed by his week off, when summons of him are filler.",
            Week.WINS),
    }
    local whim = Week.WhimLine(start)
    card[#card + 1] = whim and ("This week's whim: " .. whim) or "No whim this week."
    if Week.IsOff(start) then card[#card + 1] = "This is his week off: summons of him are filler, and nobody wins the week." end
    return card
end

-- At login: how the last week ended, then this week's whim, and (on Zennit's client) what is waiting for his answer.
function Week.Check()
    checkLastWeek()
    Week.AnnounceWhim()
    if ST.Gag.IsZennit() then
        local waiting = ST.Respond.Waiting()
        if waiting > 0 then
            ST.print(string.format("%d summons %s waiting for your answer. |cffffd100/sc respond|r opens the latest.", waiting,
                waiting == 1 and "is" or "are"))
        end
        local n, silver = ST.Respond.Owed("target")
        if n > 0 then
            ST.print(string.format("You are owed %d silver for %d summons (in cash, with no receipt). Mark each paid in the Answer tab.", silver, n))
        end
    else
        local n, silver = ST.Respond.Owed("caster")
        if n > 0 then
            ST.print(string.format("You owe Zennit %d silver for %d summons: fifty each, in cash, no receipt. The Ritual is keeping count.",
                silver, n))
        end
    end
end

-- Who is ahead in a week's score, and by how much: "group" or "zennit" (a tie is his, so "zennit" with 0).
function Week.Lead(r)
    if r.group > r.zennit then return "group", r.group - r.zennit end
    return "zennit", r.zennit - r.group
end

-- The lead in words; `you` words it for Zennit's own client.
local function leadText(r, you)
    local side, by = Week.Lead(r)
    if side == "group" then return string.format("the group leads by %d", by) end
    if by == 0 then return you and "it is level, and a tie is yours" or "it is level, and a tie goes to Zennit" end
    return string.format(you and "you lead by %d" or "Zennit leads by %d", by)
end

local function diceText(n)
    return string.format("%d %s left", n, n == 1 and "die" or "dice")
end

-- The line for the moment Zennit's last die of the week is spent, or nil: from then on every summon is certain, which is
-- when the group's ordering of its summons pays off (design/lenses.md, Skill and Chance). `you` words it for Zennit.
function Week.LastDie(ev, you)
    local res = ev.response and ev.response.result
    local start = Week.Start(ev.time)
    if ev.fake or (res ~= "won" and res ~= "lost") or Week.DiceLeft(start) ~= 0 then return nil end
    if Week.IsOff(start) or Week.IsClosed(start) then return nil end
    if you then
        return ST.Voice.Say("lastdie.you", {
            "That was your last die this week. From here you can only accept, refuse or ask for the silver.",
            "That was your last die of the week. From here it is accept, refuse or the silver.",
            "Your dice are spent for the week. From here you can only accept, refuse or ask for the silver." })
    end
    return ST.Voice.Say("lastdie.them", {
        "That was Zennit's last die this week. Every summon from here is certain: he can only accept, refuse or ask for the silver.",
        "That was Zennit's last die of the week. Every summon from here is certain: he can only accept, refuse or ask for the silver.",
        "Zennit's dice are spent for the week. Every summon from here is certain: he can only accept, refuse or ask for the silver." })
end

-- One line on where the week starting at `start` stands (default: this week), for the chat after a summon of Zennit
-- or an answer: "Week: the group leads by 1, 4 of 10 filed, 1 die left." nil under the old rules.
function Week.StatusLine(start, you)
    start = start or Week.Start()
    if not Week.NewRules(start) then return nil end
    local r = Week.Score(start)
    if r.off then return "Week: Zennit's week off, so summons of him are filler and nothing counts." end
    local parts = { leadText(r, you), string.format("%d of %d filed", r.counted, Week.RULES.cap),
        r.closed and "the Index is closed" or diceText(Week.DiceLeft(start)) }
    local edge, moved = Week.Edge(start)
    if moved ~= 0 and not r.closed then parts[#parts + 1] = string.format("his dice edge is +%d", edge) end
    local waiting = Week.Overdue(start)
    if waiting > 0 then
        parts[#parts + 1] = string.format(you and "%d waiting for your answer" or "%d waiting for his answer", waiting)
    end
    local _, silver = Week.Owed(start)
    if silver > 0 then
        parts[#parts + 1] = string.format(you and "%d silver owed to you" or "%d silver owed to him", silver)
    end
    return ST.Voice.Say("week.status", { "Week: %s.", "The Index's tally for the week: %s.", "Standing: %s." },
        table.concat(parts, ", "))
end

-- What the caster should know as a ritual on `target` begins, or nil when it is not Zennit or the old rules apply:
-- whether it will count, where the week stands, his dice, and what helpers add.
function Week.Briefing(target)
    if not isZennit(target) then return nil end
    local now = time()
    local start = Week.Start(now)
    if not Week.NewRules(start) then return nil end
    if Week.IsOff(start) then
        return target .. " is on his week off. The Index will file this summon as filler: it will not count, and it is not hopeful."
    end
    if Week.Immune(now) then return target .. " is on his week off. The Index will note the summons, and is not hopeful." end
    local r = Week.Score(start)
    if r.closed then return target .. " has closed the Index for the week: this summon will not count." end
    if r.counted >= Week.RULES.cap then
        return target .. " has had all the summons that count this week: this one will not count."
    end
    local dice = Week.DiceLeft(start)
    local edge, moved = Week.Edge(start)
    local text = string.format("Summoning %s: summon %d of %d this week, and %s. He has %s%s", target, r.counted + 1,
        Week.RULES.cap, leadText(r), diceText(dice), dice == 0 and ": he must accept, refuse or ask for the silver." or
        string.format("; each helper adds +%d to your roll if he suggests dice (two helpers at most).", Week.Rule("helperBonus", start)))
    if moved ~= 0 and dice > 0 then
        text = text .. string.format(" The Index, which takes no sides, has %s his edge on the dice to +%d this week.",
            moved < 0 and "cut" or "raised", edge)
    end
    local whim = Week.WhimLine(start)
    if whim then text = text .. " This week's whim: " .. whim end
    local waiting = Week.Overdue(start)
    if waiting > 0 then
        text = text .. string.format(" %d earlier summons of him %s still waiting for his answer: a word to him might help.", waiting,
            waiting == 1 and "is" or "are")
    end
    return text
end

-- The caster is told when they summon Zennit during his week off, or after he has closed the Index for the week.
function Week.Warn(ev)
    if ev.fake or not isZennit(ev.target) then return end
    if Week.IsOff(Week.Start(ev.time)) then
        ST.print(ev.target .. " is on his week off. The Index has filed the summons as filler, and is not hopeful: it does not count.")
    elseif Week.Immune(ev.time) then
        ST.print(ev.target .. " is on his week off. The Index has noted the summons, and is not hopeful.")
    elseif not Week.Counts(ev) then
        ST.print(ev.target .. (Week.IsClosed(Week.Start(ev.time)) and " has closed the Index for the week" or
            " has had all the summons that count this week") .. ". The Index has filed yours under 'enthusiasm'.")
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() C_Timer.After(60, Week.Check) end) -- 60s: let the login sync bring in late summons first
