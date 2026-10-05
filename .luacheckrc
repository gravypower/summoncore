-- Luacheck config for a WoW addon. Only syntax errors and global-variable mistakes (typos, accidental
-- globals) are reported for now; widen `only` once the code has been run through luacheck locally.
std = "lua51"
max_line_length = false
self = false
only = { "0", "1" }

-- Globals this addon defines.
globals = {
    "SummonTrackerDB",
    "StaticPopupDialogs",
    "SlashCmdList",
    "SLASH_SUMMONCORE1",
    "SLASH_SUMMONCORE2",
}

-- WoW API used by the addon.
read_globals = {
    "Ambiguate", "C_ChatInfo", "C_Map", "C_Spell", "C_Timer", "ChatFontNormal", "CreateFrame",
    "GetBuildInfo", "GetNormalizedRealmName", "GetPhysicalScreenSize", "GetSpellInfo", "GetSubZoneText",
    "GetTime", "GetUnitName", "GetZoneText", "IsInGroup", "IsInGuild", "IsInInstance", "IsInRaid",
    "PlaySound", "PlaySoundFile", "RANDOM_ROLL_RESULT", "RandomRoll", "StopSound", "SOUNDKIT", "UIParent", "UISpecialFrames", "UnitChannelInfo",
    "UnitExists", "UnitFullName", "UnitGUID", "UnitHealth", "UnitInRange", "UnitIsConnected", "UnitName",
    "BNGetInfo", "CreateFont", "GameTooltip", "GetNumGroupMembers", "UnitIsUnit", "StaticPopup_Show", "UnitSpellTargetName", "date", "issecretvalue", "time", "tinsert", "hooksecurefunc", "geterrorhandler", "SendChatMessage", "C_SummonInfo",
}
