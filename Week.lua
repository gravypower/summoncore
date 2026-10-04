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
Week.RULES = { from = 1791158400, headstart = 2, minimum = 5, cap = 10, dice = 3, helperBonus = 5, helpersMax = 2 }

function Week.NewRules(start)
    return start >= Week.RULES.from
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
local function filed(start)
    local list = summonsOfZennit(start)
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
    if not isZennit(ev.target) then return false end
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

-- What the summoner adds to their dice roll for this summon: a bonus per helper (0 under the old rules).
function Week.HelperBonus(ev)
    if not Week.NewRules(Week.Start(ev.time)) then return 0 end
    return math.min(#(ev.assistants or {}), Week.RULES.helpersMax) * Week.RULES.helperBonus
end

-- The score for the week starting at `start`: { start, group, zennit, summons, winner, over, new, counted, extra,
-- closed }. winner is "zennit", "group", or nil when there were no summons that week. Under the new rules, counted is
-- how many summons of Zennit count toward the week, extra how many came after those, and closed whether he closed
-- the Index.
function Week.Score(start)
    local new = Week.NewRules(start)
    local r = { start = start, group = 0, zennit = new and Week.RULES.headstart or Week.HEADSTART, summons = 0,
        over = time() >= start + LENGTH, new = new, counted = 0, extra = 0 }
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
        local list, counted, closed = filed(start)
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
    if r.summons > 0 then r.winner = r.zennit >= r.group and "zennit" or "group" end
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
    if r.summons == 0 then return "no summons that week" end
    if not r.over then
        return "this week so far: " .. lines(r) .. (r.zennit >= r.group and ", Zennit is ahead" or ", the group is ahead")
    end
    return (r.winner == "zennit" and "Zennit won the week: " or "the group won the week: ") .. lines(r)
end

-- The season is a race: the first side to WINS weekly wins takes the finale, then the count starts again.
-- Worked out from the log, one completed week at a time, so every client reaches the same story.
-- Returns { zennit, group (wins so far this season), finales = { { start, side } }, chapters = { { start, side, n, key } } }
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
    while start < current do
        local r = Week.Score(start)
        local side = r.winner
        if side then
            s[side] = s[side] + 1
            s.chapters[#s.chapters + 1] = { start = start, side = side, n = s[side], key = (side == "zennit" and "z" or "g") .. s[side] }
            if s[side] >= Week.WINS then
                s.finales[#s.finales + 1] = { start = start, side = side }
                s.zennit, s.group = 0, 0
            end
        end
        start = start + LENGTH
    end
    return s
end

-- Says once when a finished week has been won, and points to that win's chapter of the story.
function Week.Check()
    if not ST.db or not ST.db.settings then return end
    Week.Freeze()
    local last = Week.Score(Week.Start() - LENGTH)
    if not last.winner or ST.db.settings.weekSeen == last.start then return end
    ST.db.settings.weekSeen = last.start
    ST.Clips.Play("narrator_weekopen")
    local season = Week.Season()
    local chapter = season.chapters[#season.chapters]
    local key = chapter and chapter.start == last.start and chapter.key
    local story = ""
    if key then
        story = ST.Intro.HasChapter(key) and (" The story: |cffffd100/st intro " .. key .. "|r") or " (That chapter of the story is not written yet.)"
        if chapter.n >= Week.WINS then
            story = story .. " That was the finale. The season starts again."
        end
    end
    if last.winner == "zennit" then
        ST.print("|cffffd100Zennit won the week|r (" .. lines(last) .. "). He is on leave until next Monday." .. story)
    else
        ST.print("The group won the week (" .. lines(last) .. "). Zennit is back on the list." .. story)
    end
    ST.print(string.format("Season: Zennit %d of %d, the group %d of %d.", season.zennit, Week.WINS, season.group, Week.WINS))
end

-- The caster is told when they summon Zennit during his week off, or after he has closed the Index for the week.
function Week.Warn(ev)
    if ev.fake or not isZennit(ev.target) then return end
    if Week.Immune(ev.time) then
        ST.print(ev.target .. " is on his week off. The Index has noted the summons, and is not hopeful.")
    elseif not Week.Counts(ev) then
        ST.print(ev.target .. (Week.IsClosed(Week.Start(ev.time)) and " has closed the Index for the week" or
            " has had all the summons that count this week") .. ". The Index has filed yours under 'enthusiasm'.")
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() C_Timer.After(60, Week.Check) end) -- 60s: let the login sync bring in late summons first
