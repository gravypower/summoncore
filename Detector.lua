-- Detector: watches the player's Ritual of Summoning casts and snapshots roster and channel state.
-- Only the caster's client sees the cast; everyone else is credited from the snapshot.
local ADDON, ST = ...
local Detector = {}
ST.Detector = Detector

local PENDING_TTL = 30
local TICK = 0.5
local MAX_CANDIDATES = 12 -- longest list the assistants prompt offers
local pending

local function dbg(msg)
    if ST.db and ST.db.settings.debug then ST.print("|cff888888[detect]|r " .. msg) end
end

local function isRitualID(spellID)
    return spellID ~= nil and not ST.isSecret(spellID) and spellID == ST.RITUAL_ID
end

-- Plain string name, or nil if the value is missing or secret.
local function cleanName(v)
    return ST.baseName(v)
end

-- Unit tokens for everyone else in the group: party1-4, or the whole raid (helpers may be in any subgroup).
local function groupUnits()
    local out = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then out[#out + 1] = unit end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then out[#out + 1] = unit end
        end
    end
    return out
end

local function partyMembers()
    local out = {}
    for _, unit in ipairs(groupUnits()) do
        local n = cleanName(UnitName(unit))
        if n then out[#out + 1] = n end
    end
    return out
end
Detector.PartyMembers = partyMembers

-- Names of group members currently channeling the ritual.
local function channelers()
    local out = {}
    local rname = ST.SpellName(ST.RITUAL_ID)
    for _, unit in ipairs(groupUnits()) do
        local ok, cname, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, unit)
        if ok then
            local match = isRitualID(spellID)
            if not match and rname and type(cname) == "string" and not ST.isSecret(cname) then
                match = cname == rname
            end
            if match then
                local n = cleanName(UnitName(unit))
                if n then out[#out + 1] = n end
            end
        end
    end
    return out
end

-- The names offered in the assistants prompt: not the target or the caster, detected helpers first, at most `max`
-- (a raid can be 40 people, far too many to tick through).
function Detector.PickCandidates(members, helpers, target, me, max)
    local out, seen = {}, {}
    local function add(n)
        if n ~= target and n ~= me and not seen[n] and #out < max then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    local present = {}
    for _, n in ipairs(members) do present[n] = true end
    for _, n in ipairs(helpers) do if present[n] then add(n) end end
    for _, n in ipairs(members) do add(n) end
    return out
end

local function snapshotHelpers()
    if not pending then return end
    for _, n in ipairs(channelers()) do
        if not pending.helpers[n] then
            pending.helpers[n] = true
            dbg("helper seen channeling: " .. n)
        end
    end
end

local function clearPending()
    if pending and pending.ticker then pending.ticker:Cancel() end
    pending = nil
end

local function startPending(target)
    clearPending()
    local mapID = C_Map.GetBestMapForUnit("player")
    pending = {
        target = cleanName(target) or cleanName(UnitName("target")),
        mapID = mapID, subzone = GetSubZoneText(), started = time(), helpers = {},
    }
    local ticks = 0
    pending.ticker = C_Timer.NewTicker(TICK, function()
        ticks = ticks + 1
        snapshotHelpers()
        if ticks * TICK > PENDING_TTL then clearPending() end
    end)
    dbg(string.format("pending: target=%s map=%s subzone=%s", tostring(pending.target),
        tostring(mapID), tostring(pending.subzone)))
end

local function report(ev, badges)
    if ST.Hub then ST.Hub.Refresh() end
    local zenit = ST.Gag.IsZennit()
    ST.print(string.format("Summon logged: %s in %s%s%s", ev.target, ev.subzone ~= "" and ev.subzone or "?",
        zenit and "" or string.format(" (+%d, %s)", ev.points, ev.kind), ev.confirmed and "" or " [unconfirmed]"))
    if zenit then return end -- points and badges are hidden on Zennit's client
    for _, name in ipairs(badges) do ST.print("|cffffd100Badge earned:|r " .. name) end
end

-- Saves an event, asking the caster about assistants when the roster is unclear.
-- info: target, mapID, subzone, helpers (list of detected helper names)
function Detector.Finish(info)
    local me = ST.Store.me()
    local target = info.target or "Unknown"
    local candidates = Detector.PickCandidates(partyMembers(), info.helpers, target, me, MAX_CANDIDATES)
    local function save(assistants, confirmed)
        local _, ev, badges = ST.Store.Add({
            caster = me, target = target, assistants = assistants,
            mapID = info.mapID, subzone = info.subzone or "", confirmed = confirmed,
        })
        report(ev, badges)
    end
    if #candidates == 0 then
        save({}, true) -- nobody could have helped
    elseif #info.helpers == 2 and info.target then
        save(info.helpers, true)
    else
        dbg(string.format("%d helpers detected, asking caster", #info.helpers))
        ST.Prompt.Ask(target, candidates, info.helpers, save)
    end
end

local function commit()
    if not pending then startPending() end
    snapshotHelpers()
    local info = {
        target = pending.target, mapID = pending.mapID, subzone = pending.subzone,
        helpers = {},
    }
    for n in pairs(pending.helpers) do info.helpers[#info.helpers + 1] = n end
    table.sort(info.helpers)
    clearPending()
    Detector.Finish(info)
end

local lastCommit = 0
local frame = CreateFrame("Frame")
for _, ev in ipairs({
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
}) do
    pcall(frame.RegisterUnitEvent, frame, ev, "player")
end

frame:SetScript("OnEvent", function(_, event, _, a2, a3, a4)
    -- SENT args: unit, target, castGUID, spellID. Others: unit, castGUID, spellID.
    local spellID = (event == "UNIT_SPELLCAST_SENT") and a4 or a3
    if not isRitualID(spellID) then return end
    dbg(event)
    if event == "UNIT_SPELLCAST_SENT" then
        startPending(a2)
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if not pending then startPending() end
        snapshotHelpers()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Guard against a second SUCCEEDED for the same cast.
        if GetTime() - lastCommit < 5 then return end
        lastCommit = GetTime()
        commit()
    else
        clearPending() -- interrupted or failed
    end
end)
