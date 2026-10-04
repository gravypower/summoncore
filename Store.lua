-- Store: the only module that touches SummonTrackerDB. The event log is the source of truth;
-- tallies are always derived from it.
local ADDON, ST = ...
local Store = {}
ST.Store = Store

function Store.me()
    return UnitName("player")
end

local function newID(caster, t)
    local id = caster .. "-" .. t
    local n = 1
    while ST.db.events[id] do
        n = n + 1
        id = caster .. "-" .. t .. "-" .. n
    end
    return id
end

-- ev: caster, target, assistants (list), mapID, subzone, time, confirmed.
-- Returns the id, the event, and a list of badge names earned by this save.
-- localOnly keeps the event off the network (used for test events).
function Store.Add(ev, localOnly)
    ev.assistants = ev.assistants or {}
    ev.time = ev.time or time()
    ev.wrote = ev.wrote or time()
    ev.points, ev.kind = ST.Scoring.Score(ev.mapID, ev.subzone)
    local id = newID(ev.caster, ev.time)
    ST.db.events[id] = ev
    if Store.onAdd and not localOnly then Store.onAdd(id, ev) end
    return id, ev, ST.Scoring.EvaluateBadges()
end


-- Zennit's answer to a summon of him (set by his client, carried by sync): { result, zroll, sroll, time }.
-- A summon still counts unless it was refused, still owes the 50 silver, or he won the dice.
-- "excused" is a refusal of a destination on his secret list: no points for the summoner and no penalty for him.
Store.RESULTS = { accepted = true, refused = true, excused = true, owed = true, paid = true, won = true, lost = true }
local NO_POINTS = { refused = true, excused = true, owed = true, won = true }

function Store.Lands(ev)
    return not (ev.response and NO_POINTS[ev.response.result])
end

-- Points toward Zennit's goal (a week off from being summoned), from the summon's worth P (draft rules):
--   he wins the dice: +P        a plain refusal: -P
--   a summon that lands at a place on his list: +P bonus (response.listed, set by his client)
function Store.Goal(ev)
    local r, p = ev.response, ev.points or 0
    if not r then return 0 end
    if r.result == "won" then return p end
    if r.result == "refused" then return -p end
    if r.listed and Store.Lands(ev) then return p end
    return 0
end

function Store.SetResponse(id, resp)
    local ev = ST.db.events[id]
    if not ev then return false end
    ev.response = resp
    return true
end

function Store.Has(id) return ST.db.events[id] ~= nil end
function Store.Get(id) return ST.db.events[id] end

-- Writes an event received from sync, replacing any copy with the same id.
function Store.Put(id, ev)
    ST.db.events[id] = ev
end

function Store.Count()
    local n = 0
    for _, ev in pairs(ST.db.events) do
        if not ev.fake then n = n + 1 end
    end
    return n
end

function Store.Latest()
    local latest = 0
    for _, ev in pairs(ST.db.events) do
        if not ev.fake and ev.time > latest then latest = ev.time end
    end
    return latest
end

-- Events with time > t, oldest first.
function Store.Since(t)
    local list = {}
    for id, ev in pairs(ST.db.events) do
        if ev.time > t and not ev.fake then list[#list + 1] = { id = id, ev = ev } end
    end
    table.sort(list, function(a, b)
        if a.ev.time ~= b.ev.time then return a.ev.time < b.ev.time end
        return a.id < b.id
    end)
    return list
end

-- Events sorted newest first.
function Store.Recent(limit)
    local list = {}
    for id, ev in pairs(ST.db.events) do list[#list + 1] = { id = id, ev = ev } end
    table.sort(list, function(a, b) return a.ev.time > b.ev.time end)
    if limit and #list > limit then
        for i = #list, limit + 1, -1 do list[i] = nil end
    end
    return list
end

function Store.RemoveLast()
    local last = Store.Recent(1)[1]
    if last then ST.db.events[last.id] = nil end
    return last
end

-- Per-name tallies derived from the log. points count for the caster only.
function Store.Tallies()
    local t = {}
    local function row(name)
        t[name] = t[name] or { cast = 0, received = 0, assisted = 0, points = 0 }
        return t[name]
    end
    for _, ev in pairs(ST.db.events) do
        local c = row(ev.caster)
        c.cast = c.cast + 1
        if Store.Lands(ev) then c.points = c.points + (ev.points or 0) end
        local tr = row(ev.target)
        tr.received = tr.received + 1
        tr.points = tr.points + Store.Goal(ev)
        for _, a in ipairs(ev.assistants or {}) do row(a).assisted = row(a).assisted + 1 end
    end
    return t
end

-- Stats about the summons a given caster has cast, used by the badge rules.
function Store.Stats(caster)
    local s = { cast = 0, kinds = {}, distinctMaps = 0, points = 0 }
    local maps = {}
    for _, ev in pairs(ST.db.events) do
        if ev.caster == caster and Store.Lands(ev) then
            s.cast = s.cast + 1
            s.points = s.points + (ev.points or 0)
            if ev.kind then s.kinds[ev.kind] = (s.kinds[ev.kind] or 0) + 1 end
            if ev.mapID and not maps[ev.mapID] then
                maps[ev.mapID] = true
                s.distinctMaps = s.distinctMaps + 1
            end
        end
    end
    return s
end
