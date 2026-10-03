-- Detector: watches the player's Ritual of Summoning casts and snapshots roster and channel state.
-- Only the caster's client sees the cast; everyone else is credited from the snapshot.
local ADDON, ST = ...
local Detector = {}
ST.Detector = Detector

local RITUAL_ID = 698
local PENDING_TTL = 30
local TICK = 0.5
local pending

local function debug(msg)
    if ST.db and ST.db.settings.debug then ST.print("|cff888888[detect]|r " .. msg) end
end

local function ritualName()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(RITUAL_ID) end
    if GetSpellInfo then return (GetSpellInfo(RITUAL_ID)) end
end

local function isRitualID(spellID)
    return spellID ~= nil and not ST.isSecret(spellID) and spellID == RITUAL_ID
end

-- Plain string name, or nil if the value is missing or secret.
local function cleanName(v)
    if type(v) == "string" and not ST.isSecret(v) and v ~= "" then return v end
end

local function partyMembers()
    local out = {}
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local n = cleanName(UnitName(unit))
            if n then out[#out + 1] = n end
        end
    end
    return out
end
Detector.PartyMembers = partyMembers

-- Names of party members currently channeling the ritual.
local function channelers()
    local out = {}
    local rname = ritualName()
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
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
    end
    return out
end

local function snapshotHelpers()
    if not pending then return end
    for _, n in ipairs(channelers()) do
        if not pending.helpers[n] then
            pending.helpers[n] = true
            debug("helper seen channeling: " .. n)
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
    debug(string.format("pending: target=%s map=%s subzone=%s", tostring(pending.target),
        tostring(mapID), tostring(pending.subzone)))
end

local function report(id, ev, badges)
    local zenit = ST.Gag.IsZenit()
    ST.print(string.format("Summon logged: %s in %s%s%s", ev.target, ev.subzone ~= "" and ev.subzone or "?",
        zenit and "" or string.format(" (+%d, %s)", ev.points, ev.kind), ev.confirmed and "" or " [unconfirmed]"))
    if zenit then return end -- points and badges are hidden on Zenit's client
    for _, name in ipairs(badges) do ST.print("|cffffd100Badge earned:|r " .. name) end
end

-- Saves an event, asking the caster about assistants when the roster is unclear.
-- info: target, mapID, subzone, helpers (list of detected helper names)
function Detector.Finish(info)
    local me = ST.Store.me()
    local target = info.target or "Unknown"
    local candidates = {}
    for _, n in ipairs(partyMembers()) do
        if n ~= target and n ~= me then candidates[#candidates + 1] = n end
    end
    local function save(assistants, confirmed)
        local id, ev, badges = ST.Store.Add({
            caster = me, target = target, assistants = assistants,
            mapID = info.mapID, subzone = info.subzone or "", confirmed = confirmed,
        })
        report(id, ev, badges)
    end
    if #candidates == 0 then
        save({}, true) -- nobody could have helped
    elseif #info.helpers == 2 and info.target then
        save(info.helpers, true)
    else
        debug(string.format("%d helpers detected, asking caster", #info.helpers))
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
    debug(event)
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
