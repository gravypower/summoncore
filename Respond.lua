-- Respond: how Zennit deals with a summon of him, and the dice.
--
-- When a live summon of Zennit reaches his client, a dialog gives him four choices (the same choices are in the
-- hub window's Answer tab):
--   Accept          the summon counts.
--   Refuse          the summon does not count.
--   50 silver       the summon counts once he says the silver was paid ("owes" until then).
--   Dice            he rolls 1-100 (a real /roll, so the party sees it); the summoner is asked to roll back;
--                   Zennit adds 10 to his roll, higher wins and a tie goes to him. If he wins, the summon does not count.
-- His answer is stored on the event and sent to everyone (message Z); only his own client can answer for him.
-- The dice use messages D (his roll, to the summoner) and S (the summoner's roll, back to him).
local ADDON, ST = ...
local Respond = {}
ST.Respond = Respond
local T = ST.Theme

local SILVER = 50
local WAIT = 90         -- seconds to wait for the summoner to roll back
local ROLL_WINDOW = 15  -- seconds after pressing Roll in which a /roll result is accepted

local state = {}        -- Zennit's side: id -> { zroll } while waiting for the summoner's roll
local pendingRoll       -- { kind = "zennit" | "summoner", id, expires }
local diceCurrent       -- the dice prompt on the summoner's side: { id, ev, zroll }
local diceDlg           -- that prompt's window (built when first needed)
local surfaces = {}     -- every place the four choices are drawn (the popup and the hub's Answer tab)
local dlg, dlgSurface   -- the popup

----------------------------------------------------------------------
-- Rules
----------------------------------------------------------------------
-- The dice are loaded his way, so the story keeps moving: Zennit adds EDGE to his roll, and a tie goes to him.
-- "won" means Zennit won, so the summon does not count.
Respond.EDGE = 10
function Respond.Resolve(zroll, sroll)
    return zroll + Respond.EDGE >= sroll and "won" or "lost"
end

-- A short outcome for the log, or nil if Zennit has not answered.
function Respond.Describe(ev)
    local r = ev.response
    if not r then return nil end
    if r.result == "accepted" then return "accepted" end
    if r.result == "refused" then return "refused (-" .. (ev.points or 0) .. ")" end
    if r.result == "excused" then return "refused (on his list)" end
    if r.result == "owed" then return "owes " .. SILVER .. " silver" end
    if r.result == "paid" then return "paid " .. SILVER .. " silver" end
    if r.result == "won" then return string.format("won the dice %d-%d", r.zroll, r.sroll) end
    if r.result == "lost" then return string.format("lost the dice %d-%d", r.zroll, r.sroll) end
end

local function plural(n) return n == 1 and "" or "s" end

-- One line for the chat window when Zennit has answered.
function Respond.Announce(ev, resp)
    local who, pts = ev.target, ev.points or 0
    local r = resp.result
    local bonus = ""
    if resp.listed and ST.Store.Lands({ response = resp }) then
        bonus = string.format(" It is on his list: +%d point%s toward his week off.", pts, plural(pts))
    end
    if r == "accepted" then return string.format("%s accepted the summon from %s. +%d point%s.%s", who, ev.caster, pts, plural(pts), bonus) end
    if r == "refused" then return string.format("%s refused the summon from %s. No points for them, and %s loses %d point%s toward his goal.", who, ev.caster, who, pts, plural(pts)) end
    if r == "excused" then return string.format("%s refused the summon from %s. No points, but the destination is on his list, so it costs him nothing.", who, ev.caster) end
    if r == "owed" then return string.format("%s demands %d silver, in cash, with no receipt. The points land when he says it was paid.", who, SILVER) end
    if r == "paid" then return string.format("%s says the %d silver was paid. +%d point%s.%s", who, SILVER, pts, plural(pts), bonus) end
    if r == "won" then return string.format("%s won the dice (%d to %d): the summon does not count, and he gains %d point%s toward his week off.", who, resp.zroll, resp.sroll, pts, plural(pts)) end
    if r == "lost" then return string.format("%s lost the dice (%d to %d): the summon counts. +%d point%s.%s", who, resp.zroll, resp.sroll, pts, plural(pts), bonus) end
end

-- Zennit's secret list for the week: destination words kept on his client only (never synced or exported).
function Respond.List()
    ST.db.settings.zennitList = ST.db.settings.zennitList or {}
    return ST.db.settings.zennitList
end

function Respond.ListAdd(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return false end
    local list = Respond.List()
    list[#list + 1] = text
    return true
end

function Respond.ListRemove(n)
    return table.remove(Respond.List(), tonumber(n) or 0) ~= nil
end

function Respond.ListClear()
    local list = Respond.List()
    for i = #list, 1, -1 do list[i] = nil end
end

-- Is the summon's destination (zone or subzone name) on the list? A word on the list matches any part of the name.
function Respond.OnList(ev)
    local zone = ev.mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(ev.mapID)
    local where = ((ev.subzone or "") .. " " .. ((zone and zone.name) or "")):lower()
    for _, word in ipairs(Respond.List()) do
        if where:find(word:lower(), 1, true) then return true end
    end
    return false
end

-- Summons of this character that still need an answer (none yet, or owing the silver), newest first.
function Respond.Pending()
    local me, out = ST.Store.me(), {}
    for _, r in ipairs(ST.Store.Recent(200)) do
        local res = r.ev.response and r.ev.response.result
        if r.ev.target == me and (not res or res == "owed") then out[#out + 1] = r end
    end
    return out
end

----------------------------------------------------------------------
-- Zennit's decisions
----------------------------------------------------------------------
local refreshSurfaces

-- Records Zennit's decision on this client and tells everyone (test summons stay local).
function Respond.Decide(id, result, zroll, sroll)
    local ev = ST.Store.Get(id)
    if not ev or not ST.Store.RESULTS[result] then return nil end
    local resp = { result = result, zroll = zroll or 0, sroll = sroll or 0, time = time(),
        listed = Respond.OnList(ev) or nil }
    ST.Store.SetResponse(id, resp)
    if not ev.fake then ST.Sync.SendResponse(id, resp) end
    ST.print(Respond.Announce(ev, resp))
    refreshSurfaces(id, "done")
    if ST.Hub then ST.Hub.Refresh() end
    return resp
end

-- Zennit has rolled: ask the summoner to roll back.
function Respond.StartDice(id, zroll)
    local ev = ST.Store.Get(id)
    if not ev then return end
    state[id] = { zroll = zroll }
    if ev.fake then
        -- a test summon: a pretend summoner rolls back after a moment
        C_Timer.After(1.5, function() Respond.OnDiceReply(id, ev, math.random(100)) end)
    else
        ST.Sync.SendDice(id, zroll, ev.caster)
    end
    refreshSurfaces(id, "waiting", zroll)
    C_Timer.After(WAIT, function()
        if state[id] and state[id].zroll == zroll then
            state[id] = nil
            refreshSurfaces(id, "noanswer")
        end
    end)
end

-- The summoner's roll has come back (Sync calls this): decide the dice.
function Respond.OnDiceReply(id, ev, sroll)
    local st = state[id]
    if not st then return end
    state[id] = nil
    Respond.Decide(id, Respond.Resolve(st.zroll, sroll), st.zroll, sroll)
end

----------------------------------------------------------------------
-- Rolls: a real /roll 1-100, picked up from the system message
----------------------------------------------------------------------
local function rollPattern()
    local fmt = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    local p = (fmt:gsub("[%(%)%.%-%+%?%*%[%]%^%$]", "%%%0"))
    p = p:gsub("%%s", "(.+)")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

-- A roll for `kind` ("zennit" or "summoner") has come in with this value.
function Respond.GotRoll(kind, id, value)
    local ev = ST.Store.Get(id)
    if not ev then return end
    if kind == "zennit" then
        Respond.StartDice(id, value)
    elseif kind == "summoner" then
        ST.Sync.SendDiceReply(id, value, ev.target)
        if diceDlg and diceCurrent and diceCurrent.id == id then
            diceDlg.text:SetText(string.format("You rolled %d. Waiting for %s's decision...", value, ev.target))
            diceDlg.rollBtn:Hide()
        end
    end
end

function Respond.RequestRoll(kind, id)
    pendingRoll = { kind = kind, id = id, expires = GetTime() + ROLL_WINDOW }
    if RandomRoll then RandomRoll(1, 100) else Respond.GotRoll(kind, id, math.random(100)) end
end

local rollFrame = CreateFrame("Frame")
rollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
rollFrame:SetScript("OnEvent", function(_, _, message)
    if not pendingRoll or type(message) ~= "string" or ST.isSecret(message) then return end
    if GetTime() > pendingRoll.expires then pendingRoll = nil return end
    local name, value, lo, hi = message:match(rollPattern())
    if not name or tonumber(lo) ~= 1 or tonumber(hi) ~= 100 then return end
    if ST.baseName(name) ~= ST.Store.me() then return end
    local p = pendingRoll
    pendingRoll = nil
    Respond.GotRoll(p.kind, p.id, tonumber(value))
end)

----------------------------------------------------------------------
-- The summoner's side: Zennit suggested dice
----------------------------------------------------------------------
local function buildDiceDialog()
    diceDlg = T.Window("SummonCoreDice", 400, 200, { strata = "DIALOG", escape = false })
    diceDlg:ClearAllPoints()
    diceDlg:SetPoint("TOP", 0, -180)
    diceDlg.TitleText:SetText("DICE!")
    diceDlg.text = T.Text(diceDlg, 18, "green")
    diceDlg.text:SetPoint("TOPLEFT", 18, -40)
    diceDlg.text:SetSize(364, 90)
    diceDlg.text:SetJustifyV("TOP")
    diceDlg.rollBtn = T.Button(diceDlg, "ROLL 1-100", 170, 28, function()
        if diceCurrent then
            Respond.RequestRoll("summoner", diceCurrent.id)
            diceDlg.text:SetText("Rolling...")
        end
    end, "primary")
    diceDlg.rollBtn:SetPoint("BOTTOMLEFT", 18, 16)
    local close = T.Button(diceDlg, "CLOSE", 170, 28, function() diceDlg:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -18, 16)
end

-- Sync calls this when Zennit has rolled and suggests dice for our summon of him.
function Respond.OnDiceChallenge(id, ev, zroll)
    if not diceDlg then buildDiceDialog() end
    diceCurrent = { id = id, ev = ev, zroll = zroll }
    diceDlg.text:SetText(string.format("%s suggests dice for your summon of him, and has rolled %d.\n\nRoll 1-100: beat his roll plus 10 and the summon counts. A tie goes to him.",
        ev.target, zroll))
    diceDlg.rollBtn:Show()
    diceDlg:Show()
end

-- Sync calls this when Zennit's answer arrives. Tell the chat, and finish the dice prompt if we have one.
function Respond.OnResponse(id, ev, resp)
    local line = Respond.Announce(ev, resp)
    if line then ST.print(line) end
    if ST.Hub then ST.Hub.Refresh() end
    if diceDlg and diceCurrent and diceCurrent.id == id then
        diceDlg.text:SetText(line or "")
        diceDlg.rollBtn:Hide()
    end
end

ST.Sync.onResponse = Respond.OnResponse
ST.Sync.onDice = Respond.OnDiceChallenge
ST.Sync.onDiceReply = Respond.OnDiceReply

----------------------------------------------------------------------
-- The four choices, drawn wherever they are wanted
----------------------------------------------------------------------
local function summonText(ev)
    local where = (ev.subzone and ev.subzone ~= "") and ev.subzone or "somewhere"
    local helpers = #ev.assistants > 0 and table.concat(ev.assistants, ", ") or "nobody"
    return string.format("%s has summoned you to %s.\n(%s, %s. Helped by %s.)", T.Paint("cyan", ev.caster), where,
        ev.kind or "?", T.Paint("amber", (ev.points or 0) .. " point" .. plural(ev.points or 0)), helpers)
end

local function setButtons(s, list)
    for i, b in ipairs(s.buttons) do
        local item = list[i]
        if item then
            b:SetText(item[1]:upper())
            b:SetScript("OnClick", item[2])
            b:Show()
        else
            b:Hide()
        end
    end
end

-- Draws one stage on a surface: "choose", "roll", "waiting" (extra = Zennit's roll), "noanswer" or "done".
local function render(s, stage, extra)
    if not s.current then return end
    local id, ev = s.current.id, s.current.ev
    s.stage = stage
    if stage == "choose" then
        local free = Respond.OnList(ev)
        local cost = free and "On your list: accepting earns you the points again for your week off; refusing costs nothing." or
            string.format("Refusing costs you %d point%s.", ev.points or 0, plural(ev.points or 0))
        s.text:SetText(summonText(ev) .. "\n" .. cost .. "\n\nHow will you deal with it?")
        setButtons(s, {
            { "Accept it", function() Respond.Decide(id, "accepted") end },
            { free and "Refuse (free)" or "Refuse", function() Respond.Decide(id, Respond.OnList(ev) and "excused" or "refused") end },
            { "Demand " .. SILVER .. " silver, in cash, no receipt", function() Respond.Decide(id, "owed") end },
            { "Suggest dice (1-100)", function() render(s, "roll") end },
        })
    elseif stage == "roll" then
        s.text:SetText(string.format("Dice. You roll 1-100, then %s rolls back. You add 10 to your roll, higher wins and a tie goes to you.\n\nIf you win, the summon does not count.",
            ev.caster))
        setButtons(s, {
            { "Roll 1-100", function()
                Respond.RequestRoll("zennit", id)
                render(s, "waiting")
            end },
            { "Back", function() render(s, "choose") end },
        })
    elseif stage == "waiting" then
        s.text:SetText(extra and string.format("You rolled %d. Waiting for %s to roll back...", extra, ev.caster) or "Rolling...")
        setButtons(s, { { "Choose something else", function() state[id] = nil render(s, "choose") end } })
    elseif stage == "noanswer" then
        s.text:SetText(string.format("%s did not roll back.\n\nChoose again.", ev.caster))
        setButtons(s, { { "Back", function() render(s, "choose") end } })
    else -- done
        local resp = ev.response or { result = "accepted", zroll = 0, sroll = 0 }
        s.text:SetText(Respond.Announce(ev, resp) or "")
        if resp.result == "owed" then
            setButtons(s, { { "They paid", function() Respond.Decide(id, "paid") end }, { "Close", s.close } })
        else
            setButtons(s, { { "Close", s.close } })
        end
    end
end

function refreshSurfaces(id, stage, extra)
    for _, s in ipairs(surfaces) do
        if s.current and s.current.id == id and s.text:IsVisible() then render(s, stage, extra) end
    end
end

-- A place to draw the choices: some text and four buttons inside `parent`, in `columns` columns (default 1).
-- closeFn runs for the Close button.
function Respond.NewSurface(parent, x, y, width, closeFn, columns)
    columns = columns or 1
    local s = { buttons = {}, close = closeFn or function() end }
    s.text = T.Text(parent, 18, "green")
    s.text:SetPoint("TOPLEFT", x, y)
    s.text:SetSize(width, 110)
    s.text:SetJustifyV("TOP")
    s.text:SetSpacing(2)
    local bw = (width - (columns - 1) * 8) / columns
    for i = 1, 4 do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local b = T.Button(parent, "", bw, 28, nil, i == 1 and "primary" or nil)
        b:SetPoint("TOPLEFT", x + col * (bw + 8), y - 116 - row * 34)
        s.buttons[i] = b
    end
    surfaces[#surfaces + 1] = s
    return s
end

-- Show a summon on a surface: its choices if it is waiting, or its outcome if it has been answered.
function Respond.Select(s, id, ev)
    s.current = { id = id, ev = ev }
    render(s, ev.response and "done" or "choose")
end

-- Empty a surface.
function Respond.Clear(s)
    s.current, s.stage = nil, nil
    s.text:SetText("")
    setButtons(s, {})
end

function Respond.Stage(s) return s.stage end

----------------------------------------------------------------------
-- The popup, and opening it
----------------------------------------------------------------------
local function buildDialog()
    dlg = T.Window("SummonCoreRespond", 440, 300, { strata = "DIALOG", escape = false })
    dlg:ClearAllPoints()
    dlg:SetPoint("TOP", 0, -140)
    dlg.TitleText:SetText("A SUMMONING!")
    dlgSurface = Respond.NewSurface(dlg, 18, -40, 404, function() dlg:Hide() end)
end

-- A live summon of Zennit has arrived on his client (Sync calls this).
function Respond.Incoming(id, ev)
    if not dlg then buildDialog() end
    Respond.Select(dlgSurface, id, ev)
    dlg:Show()
    if ST.Hub then ST.Hub.Refresh() end
end

-- Re-open the popup for the latest summon of me that is still waiting (or owes silver).
function Respond.Open()
    local first = Respond.Pending()[1]
    if first then
        Respond.Incoming(first.id, first.ev)
        return true
    end
    ST.print("No summon of you is waiting for an answer.")
    return false
end

-- A pretend summon of me, to try the choices without a second player. Nothing leaves this client.
function Respond.Test()
    local id, ev = ST.Store.Add({
        caster = "Tester", target = ST.Store.me(), assistants = { "Helper" },
        mapID = C_Map.GetBestMapForUnit("player"), subzone = GetSubZoneText(), confirmed = true, fake = true,
    }, true)
    Respond.Incoming(id, ev)
end
