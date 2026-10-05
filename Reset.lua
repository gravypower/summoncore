-- Reset: wipes the summons, the badges and, with them, the story (the season is worked out from the log).
-- It asks first. The admin can also ask everyone else to reset (/sc reset all): each user is shown a prompt and
-- nothing is changed on their client until they agree. A reset leaves a mark (db.resetAt); anything older than it
-- is refused by sync, so another client still holding the old log cannot put it back.
local ADDON, ST = ...
local Reset = {}
ST.Reset = Reset

StaticPopupDialogs["SUMMONCORE_RESET"] = {
    text = "%s",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(_, data) if data then data() end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Wipes this client now. `stamp` is the moment of the reset (default: now); returns how many summons went.
function Reset.Apply(stamp)
    stamp = stamp or time()
    local removed = 0
    for id, ev in pairs(ST.db.events) do
        if ev.time <= stamp then
            ST.db.events[id] = nil
            removed = removed + 1
        end
    end
    ST.db.resetAt = stamp
    ST.db.badges = {}
    ST.db.deleted = nil -- tombstones older than the reset are redundant
    ST.db.cards = nil   -- a card's punches are counted from the summons, so with them gone every card would be full again
    if ST.db.settings then ST.db.settings.weekSeen, ST.db.settings.weekFrozen = nil, nil; ST.db.settings.weekAnnounced = nil end
    if ST.Hub then ST.Hub.Refresh() end
    return removed
end

-- Asks this user, then resets; with everyone = true (admin only) also asks everyone else to do the same.
function Reset.Ask(everyone)
    if everyone and not ST.IsAdmin() then return ST.print("that is an admin tool") end
    local text = everyone and
        "Reset all summons, badges and the story on THIS client, and ask everyone else running Summon Core to do the same?" or
        "Reset all summons, badges and the story on this client? This cannot be undone."
    StaticPopup_Show("SUMMONCORE_RESET", text, nil, function()
        local stamp = time()
        local removed = Reset.Apply(stamp)
        ST.print(string.format("reset: %d summon%s removed, badges and story cleared.", removed, removed == 1 and "" or "s"))
        if everyone then
            ST.Sync.SendReset(stamp)
            ST.print("asked everyone else to reset too.")
        end
    end)
end

-- Another user (the admin) asks us to reset; they were not verified, so we ask before doing anything.
local asked = {}
ST.Sync.onReset = function(sender, stamp)
    if asked[stamp] then return end
    asked[stamp] = true
    StaticPopup_Show("SUMMONCORE_RESET",
        sender .. " asks everyone to reset all summons, badges and the story. Do it on this client?", nil, function()
            local removed = Reset.Apply(stamp)
            ST.print(string.format("reset by request of %s: %d summon%s removed.", sender, removed, removed == 1 and "" or "s"))
        end)
end
