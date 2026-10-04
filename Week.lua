-- Week: the weekly contest. Each Monday (UTC) to the next, the group's landed summon points are set against
-- Zennit's points toward a week off (see Store.Goal). He starts every week with a head start, and a tie goes to
-- him, so he wins more weeks than he loses. When he wins, the seven days that follow are his: no summons.
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

-- The score for the week starting at `start`: { start, group, zennit, summons, winner, over }.
-- winner is "zennit", "group", or nil when there were no summons that week.
function Week.Score(start)
    local r = { start = start, group = 0, zennit = Week.HEADSTART, summons = 0, over = time() >= start + LENGTH }
    for _, ev in pairs(ST.db.events) do
        if not ev.fake and ev.time >= start and ev.time < start + LENGTH then
            r.summons = r.summons + 1
            if ST.Store.Lands(ev) then r.group = r.group + (ev.points or 0) end
            if isZennit(ev.target) then r.zennit = r.zennit + ST.Store.Goal(ev) end
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
    return string.format("group %d, Zennit %d (including a %d point head start)", r.group, r.zennit, Week.HEADSTART)
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

-- The caster is told when they summon Zennit during his week off.
function Week.Warn(ev)
    if ev.fake or not isZennit(ev.target) then return end
    if Week.Immune(ev.time) then
        ST.print(ev.target .. " is on his week off. The Index has noted the summons, and is not hopeful.")
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() C_Timer.After(60, Week.Check) end) -- 60s: let the login sync bring in late summons first
