-- Scoring: zone value table, points and badge rules. Placeholder values to argue about.
local ADDON, ST = ...
local Scoring = {}
ST.Scoring = Scoring

Scoring.kindPoints = { city = 1, zone = 3, dungeon = 5, remote = 10 }
Scoring.defaultKind = "zone"

-- Keyed by uiMapID. Unlisted maps score as the default kind.
-- Capital cities (classic uiMapIDs; confirm in game with /st where).
Scoring.mapKinds = {
    [1453] = "city", -- Stormwind
    [1455] = "city", -- Ironforge
    [1457] = "city", -- Darnassus
    [1454] = "city", -- Orgrimmar
    [1456] = "city", -- Thunder Bluff
    [1458] = "city", -- Undercity
}

-- Far-flung places: a long way from anywhere a friend would be, so a summon there is worth the most.
-- Classic uiMapIDs written from memory: confirm each with /st where before trusting it.
local remote = {
    [1451] = "Silithus", [1452] = "Winterspring", [1447] = "Azshara", [1448] = "Felwood",
    [1449] = "Un'Goro Crater", [1423] = "Eastern Plaguelands", [1428] = "Burning Steppes",
    [1419] = "Blasted Lands", [1430] = "Deadwind Pass", [1450] = "Moonglade",
}
for id in pairs(remote) do Scoring.mapKinds[id] = "remote" end
Scoring.remoteNames = remote -- for reference and the self-test

-- A dungeon entrance sits in an ordinary outdoor map, so it is matched by subzone text
-- (lowercase). Stand at the spot and run /st where to learn the exact string, then add it.
Scoring.subzoneKinds = {
    ["the deadmines"] = "dungeon",
    -- Outdoor dungeon entrances, from memory (unverified): confirm each with /st where and fix the text here.
    ["wailing caverns"] = "dungeon",
    ["shadowfang keep"] = "dungeon",
    ["blackfathom deeps"] = "dungeon",
    ["gnomeregan"] = "dungeon",
    ["razorfen kraul"] = "dungeon",
    ["razorfen downs"] = "dungeon",
    ["scarlet monastery"] = "dungeon",
    ["uldaman"] = "dungeon",
    ["zul'farrak"] = "dungeon",
    ["maraudon"] = "dungeon",
    ["the temple of atal'hakkar"] = "dungeon",
    ["blackrock mountain"] = "dungeon",
}

function Scoring.Kind(mapID, subzone)
    local sz = type(subzone) == "string" and subzone:lower() or nil
    return (sz and Scoring.subzoneKinds[sz]) or Scoring.mapKinds[mapID] or Scoring.defaultKind
end

function Scoring.Score(mapID, subzone)
    local kind = Scoring.Kind(mapID, subzone)
    return Scoring.kindPoints[kind] or Scoring.kindPoints[Scoring.defaultKind], kind
end

-- Badges: threshold rules over the summons the player cast. stats comes from Store.Stats.
Scoring.badges = {
    { id = "first-summon", name = "First Summon", test = function(s) return s.cast >= 1 end },
    { id = "summons-10", name = "Ten Summons", test = function(s) return s.cast >= 10 end },
    { id = "summons-50", name = "Fifty Summons", test = function(s) return s.cast >= 50 end },
    { id = "dungeon-1", name = "Dungeon Doorman", test = function(s) return (s.kinds.dungeon or 0) >= 1 end },
    { id = "far-flung-1", name = "Far Flung", test = function(s) return (s.kinds.remote or 0) >= 1 end },
    { id = "variety-5", name = "Well Travelled", test = function(s) return s.distinctMaps >= 5 end },
}

-- Awards any newly met badges. Returns a list of the badge names earned just now.
function Scoring.EvaluateBadges()
    local stats = ST.Store.Stats(ST.Store.me())
    local earned = {}
    for _, b in ipairs(Scoring.badges) do
        if not ST.db.badges[b.id] and b.test(stats) then
            ST.db.badges[b.id] = { earned = time() }
            earned[#earned + 1] = b.name
        end
    end
    return earned
end
