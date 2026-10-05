-- Silver: the money side of the game. Zennit's "50 silver, in cash, no receipt" is paid in person, by trade or by mail; this
-- module is where the addon learns to see that. So far it only has the probe: /sc probe listens for trade and mail events and
-- prints what the client lets an addon see (who, how much, or a secret value), so the detection can be built on what is real.
local ADDON, ST = ...
local Silver = {}
ST.Silver = Silver

local EVENTS = { "TRADE_SHOW", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "TRADE_REQUEST_CANCEL",
    "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "MAIL_SUCCESS", "MAIL_FAILED", "MAIL_SEND_SUCCESS" }

local function secret(v)
    return ST.isSecret and ST.isSecret(v)
end

local function shown(v)
    if secret(v) then return "<secret value>" end
    return tostring(v)
end

-- Copper as "1g 20s 5c".
local function coin(copper)
    if type(copper) ~= "number" or secret(copper) then return shown(copper) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function say(text)
    ST.print("|cff888888[probe]|r " .. text)
end

-- One call of a client function, as "name = value" or why it failed.
local function try(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return name .. ": not there" end
    local results = { pcall(fn, ...) }
    if not results[1] then return name .. ": error " .. tostring(results[2]) end
    local parts = {}
    for i = 2, #results do parts[#parts + 1] = shown(results[i]) end
    return name .. " = " .. (#parts > 0 and table.concat(parts, ", ") or "(nothing)")
end

local function onEvent(_, event, ...)
    if event:find("^TRADE") then
        local who = UnitName and UnitName("NPC")
        say(string.format("%s%s (args: %s)", event, who and (" with " .. shown(who)) or "", shown((...))))
        local function money(name)
            local fn = _G[name]
            return type(fn) == "function" and select(2, pcall(fn)) or nil
        end
        local target, player = money("GetTargetTradeMoney"), money("GetPlayerTradeMoney")
        say("   they offer " .. coin(target) .. ", you offer " .. coin(player))
    elseif event == "MAIL_INBOX_UPDATE" then
        local ok, count = pcall(function() return _G["GetInboxNumItems"]() end)
        say("MAIL_INBOX_UPDATE: " .. (ok and (shown(count) .. " in the inbox") or ("GetInboxNumItems failed: " .. tostring(count))))
        if ok and type(count) == "number" and not secret(count) then
            for i = 1, math.min(count, 10) do
                local info = { pcall(_G["GetInboxHeaderInfo"], i) }
                if info[1] then
                    -- classic order: packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, ...
                    say(string.format("   #%d from %s, %s, money %s", i, shown(info[4]), shown(info[5]), coin(info[6])))
                else
                    say("   #" .. i .. ": GetInboxHeaderInfo failed: " .. tostring(info[2]))
                end
            end
        end
    else
        say(event .. " (args: " .. shown((...)) .. ")")
    end
end

local frame

-- /sc probe: starts or stops the listener, and says what the client offers right now.
function Silver.Probe()
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", onEvent)
    end
    if frame.on then
        frame:UnregisterAllEvents()
        frame.on = false
        return say("stopped")
    end
    local missing = {}
    for _, event in ipairs(EVENTS) do
        if not pcall(frame.RegisterEvent, frame, event) then missing[#missing + 1] = event end
    end
    frame.on = true
    say("listening to trade and mail. Open a trade or the mailbox and move some money; run /sc probe again to stop.")
    if #missing > 0 then say("this client has no such event: " .. table.concat(missing, ", ")) end
    say(try("GetPlayerTradeMoney"))
    say(try("GetTargetTradeMoney"))
    say(try("GetInboxNumItems"))
    say(try("GetMoney"))
end
