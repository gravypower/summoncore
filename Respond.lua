-- Respond: how Zennit deals with a summon of him, and the dice.
--
-- When a live summon of Zennit reaches his client, a dialog gives him four choices (the same choices are in the
-- hub window's Zennit tab):
--   Accept          the summon counts.
--   Refuse          the summon does not count.
--   50 silver       the summon counts once he says the silver was paid ("owes" until then).
--   Dice            he rolls 1-100 (a real /roll, so the party sees it); the summoner is asked to roll back;
--                   Zennit adds 10 to his roll (a little less or more as the season's catch-up moves it), higher wins and a tie goes to him. If he wins, the summon does not count.
-- His answer is stored on the event and sent to everyone (message Z); only his own client can answer for him.
-- The dice use messages D (his roll, to the summoner) and S (the summoner's roll, back to him).
local ADDON, ST = ...
local Respond = {}
ST.Respond = Respond
local T = ST.Theme

local SILVER = 50
Respond.SILVER = SILVER
local WAIT = 90         -- seconds to wait for the summoner to roll back
local ROLL_WINDOW = 15  -- seconds after pressing Roll in which a /roll result is accepted

local state = {}        -- Zennit's side: id -> { zroll } while waiting for the summoner's roll
local pendingRoll       -- { kind = "zennit" | "summoner", id, expires }
local diceCurrent       -- the dice prompt on the summoner's side: { id, ev, zroll }
local diceDlg           -- that prompt's window (built when first needed)
local surfaces = {}     -- every place the four choices are drawn (the popup and the hub's Zennit tab)
local dlg, dlgSurface   -- the popup

----------------------------------------------------------------------
-- Rules
----------------------------------------------------------------------
-- The dice are loaded his way: Zennit adds EDGE to his roll, and a tie goes to him. Under the new race rules the
-- summoner adds `bonus` (Week.HelperBonus: so much per helper), so a well-organised summon can beat his edge.
-- "won" means Zennit won, so the summon does not count.
Respond.EDGE = 10
function Respond.Resolve(zroll, sroll, bonus, edge)
    return zroll + (edge or Respond.EDGE) >= sroll + (bonus or 0) and "won" or "lost"
end

-- His edge on the dice for the week of this summon: EDGE, moved by the season's catch-up (Week.Edge).
local function edgeFor(ev)
    return (ST.Week.Edge(ST.Week.Start(ev.time)))
end

-- The summoner's roll as shown: "58", or "58+10" with the helpers' bonus.
local function summonerRoll(ev, sroll)
    local bonus = ST.Week.HelperBonus(ev)
    return bonus > 0 and (sroll .. "+" .. bonus) or tostring(sroll)
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
    if r.result == "won" then return string.format("won the dice %d-%s", r.zroll, summonerRoll(ev, r.sroll)) end
    if r.result == "lost" then return string.format("lost the dice %d-%s", r.zroll, summonerRoll(ev, r.sroll)) end
end

local function plural(n) return n == 1 and "" or "s" end

-- When the helpers' bonus is what beat him (he would have won the roll without it), the line that names them:
-- " Al and Cy's +10 tipped it." Otherwise "".
local function tippedBy(ev, resp)
    local bonus = ST.Week.HelperBonus(ev)
    if bonus == 0 or resp.result ~= "lost" or Respond.Resolve(resp.zroll, resp.sroll, 0, edgeFor(ev)) ~= "won" then return "" end
    local names = {}
    for i = 1, math.min(#ev.assistants, ST.Week.RULES.helpersMax) do names[i] = ev.assistants[i] end
    return string.format(" %s's +%d tipped it.", table.concat(names, " and "), bonus)
end

-- Where a summon landed, as a key to tell places apart: the subzone text, else the map.
local function placeKey(ev)
    local zone = (ev.subzone or ""):lower()
    if zone ~= "" then return zone end
    return ev.mapID and ("map " .. ev.mapID) or nil
end

local ORDINAL = { [3] = "third", [4] = "fourth", [5] = "fifth", [6] = "sixth" }

-- How many summons of Zennit to this place, this one included, have landed on his list (his answers say so: `listed`).
function Respond.ListHits(ev, resp)
    local key = placeKey(ev)
    if not key or not (resp and resp.listed) then return 0 end
    local n = 1
    for _, other in pairs(ST.db.events) do
        if other ~= ev and not other.fake and other.time < ev.time and other.response and other.response.listed
            and ST.Week.IsZennit(other.target) and placeKey(other) == key then
            n = n + 1
        end
    end
    return n
end

-- When a place on his list comes up again, the Index notices: "Darnassus again." Never for the first time, so the list
-- keeps its secret until it hits. Empty when there is nothing to add.
local function listNote(ev, resp)
    local n = Respond.ListHits(ev, resp)
    if n < 2 then return "" end
    local place = (ev.subzone or "") ~= "" and ev.subzone or "That place"
    if n == 2 then return string.format(" %s again. The Index is beginning to see a pattern.", place) end
    return string.format(" %s for the %s time. The Index has stopped pretending it is a coincidence.", place,
        ORDINAL[n] or (n .. "th"))
end

-- What Zennit did, for a summon past the week's limit (Announce has no points to report for those).
local DID = { accepted = "accepted", refused = "refused", excused = "refused", owed = "demanded 50 silver for",
    paid = "was paid for", won = "won the dice on", lost = "lost the dice on" }

-- One line for the chat window when Zennit has answered.
function Respond.Announce(ev, resp)
    local who, pts = ev.target, ev.points or 0
    local r = resp.result
    if not ST.Week.Counts(ev) then
        local why, filing = ST.Week.Why(ST.Week.Start(ev.time))
        return string.format("%s %s the summon from %s. %s, so the race ignores it: the Index files it under '%s'.",
            who, DID[r] or "answered", ev.caster, why, filing)
    end
    local sroll = summonerRoll(ev, resp.sroll or 0)
    local bonus = ""
    if resp.listed and ST.Store.Lands({ response = resp }) then
        bonus = string.format(" It is on his list: +%d point%s toward his week off.", pts, plural(pts)) .. listNote(ev, resp)
    end
    local say = ST.Voice.Say
    if r == "accepted" then
        return say("answer.accepted", {
            "%s accepted the summon from %s. +%d point%s.%s",
            "%s accepted the summon from %s, without comment. +%d point%s.%s",
            "The Index records that %s accepted the summon from %s. +%d point%s.%s" }, who, ev.caster, pts, plural(pts), bonus)
    end
    if r == "refused" then
        return say("answer.refused", {
            "%s refused the summon from %s. No points for them, and %s loses %d point%s toward his goal.",
            "%s refused the summon from %s, with some dignity. No points for them, and %s loses %d point%s toward his goal.",
            "The Index records that %s refused the summon from %s. No points, and %s loses %d point%s toward his goal." },
            who, ev.caster, who, pts, plural(pts))
    end
    if r == "excused" then
        return say("answer.excused", {
            "%s refused the summon from %s. No points, but the destination is on his list, so it costs him nothing.%s",
            "%s declined the summon from %s. No points, but the place is on his list, so it costs him nothing.%s",
            "%s refused the summon from %s at no cost to himself: the destination is on his list. No points.%s" },
            who, ev.caster, listNote(ev, resp))
    end
    if r == "owed" then
        return say("answer.owed", {
            "%s demands %d silver, in cash, with no receipt. The points land when he says it was paid.",
            "%s asks for %d silver, in cash, and would prefer no receipt. The points land when he says it was paid.",
            "%s has named his price: %d silver, in cash, no receipt. The points land when he says it was paid." }, who, SILVER)
    end
    if r == "paid" then
        return say("answer.paid", {
            "%s says the %d silver was paid. +%d point%s.%s",
            "%s confirms the %d silver arrived. +%d point%s.%s",
            "%s has been paid the %d silver, and says so. +%d point%s.%s" }, who, SILVER, pts, plural(pts), bonus)
    end
    if r == "won" then
        return say("answer.won", {
            "%s won the dice (%d to %s): the summon does not count, and he gains %d point%s toward his week off.",
            "%s won the dice (%d to %s). The summon does not count, and he gains %d point%s toward his week off.",
            "The dice favoured %s (%d to %s): the summon does not count, and he gains %d point%s toward his week off. The Index checked the dice." },
            who, resp.zroll, sroll, pts, plural(pts))
    end
    if r == "lost" then
        return say("answer.lost", {
            "%s lost the dice (%d to %s): the summon counts. +%d point%s.%s%s",
            "%s lost the dice (%d to %s), and the summon counts. +%d point%s.%s%s",
            "The dice went against %s (%d to %s): the summon counts. +%d point%s.%s%s" },
            who, resp.zroll, sroll, pts, plural(pts), bonus, tippedBy(ev, resp))
    end
end

-- Zennit's secret list for the week: destination words kept on his client only (never synced or exported).
function Respond.List()
    ST.db.settings.zennitList = ST.db.settings.zennitList or {}
    return ST.db.settings.zennitList
end

-- The list is bounded (design/lenses.md, Elegance): an entry matches any part of a place's name, so a single letter would
-- match most places and decide every week. Only the first LIST_MAX entries count, and only those of LIST_MIN letters or more.
Respond.LIST_MAX, Respond.LIST_MIN = 5, 4

-- The entries that count, in order.
function Respond.ListActive()
    local out = {}
    for _, word in ipairs(Respond.List()) do
        if #out < Respond.LIST_MAX and #word >= Respond.LIST_MIN then out[#out + 1] = word end
    end
    return out
end

-- Adds a place. Returns true, or false and why it was refused.
function Respond.ListAdd(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return false, "add what?" end
    if #text < Respond.LIST_MIN then
        return false, string.format("'%s' is too short: a place needs at least %d letters", text, Respond.LIST_MIN)
    end
    local list = Respond.List()
    if #Respond.ListActive() >= Respond.LIST_MAX then
        return false, string.format("the list holds %d places: remove one first", Respond.LIST_MAX)
    end
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
    for _, word in ipairs(Respond.ListActive()) do
        if where:find(word:lower(), 1, true) then return true end
    end
    return false
end

-- Summons of this character that still need an answer (none yet, or owing the silver), newest first.
function Respond.Pending()
    local me, out = ST.Store.me(), {}
    for _, r in ipairs(ST.Store.Recent(200)) do
        local res = r.ev.response and r.ev.response.result
        if r.ev.target == me and (not res or res == "owed") and not ST.Week.EventClosed(r.ev) then out[#out + 1] = r end
    end
    return out
end

----------------------------------------------------------------------
-- Zennit's decisions
----------------------------------------------------------------------
local refreshSurfaces

-- A recorded line for how Zennit answered (a refusal, or winning the dice); silent when no clip is recorded.
local function playAnswerClip(resp)
    if not resp then return end
    if resp.result == "refused" or resp.result == "excused" then
        ST.Clips.Play("zenit_refuse")
    elseif resp.result == "won" then
        ST.Clips.Play("zenit_win")
    end
end

-- Where the week stands after an answer to this summon, in chat (test summons don't move it).
local function printWeek(ev, you)
    local line = not ev.fake and ST.Week.StatusLine(ST.Week.Start(ev.time), you)
    if line then ST.print(line) end
    local last = ST.Week.LastDie(ev, you)
    if last then ST.print(last) end
end

-- Records Zennit's decision on this client and tells everyone (test summons stay local).
function Respond.Decide(id, result, zroll, sroll)
    local ev = ST.Store.Get(id)
    if not ev or not ST.Store.RESULTS[result] then return nil end
    if ST.Week.EventClosed(ev) then return nil end -- that week is over; answers no longer change it
    -- a new answer is always later than the one it replaces, or other clients keep the old one (sync takes the later)
    local resp = { result = result, zroll = zroll or 0, sroll = sroll or 0,
        time = math.max(time(), ev.response and ev.response.time + 1 or 0),
        listed = Respond.OnList(ev) or nil, closes = ev.response and ev.response.closes or nil }
    ST.Store.SetResponse(id, resp)
    if not ev.fake then ST.Sync.SendResponse(id, resp) end
    ST.print(Respond.Announce(ev, resp))
    printWeek(ev, true)
    playAnswerClip(resp)
    refreshSurfaces(id, "done")
    if ST.Hub then ST.Hub.Refresh() end
    return resp
end

-- The chat line for Zennit closing the Index on the week of this summon.
local function closedLine(ev)
    local r = ST.Week.Score(ST.Week.Start(ev.time))
    return string.format("%s has closed the Index for the week after %d summons of him. Any more are filed under " ..
        "'enthusiasm' until Monday.", ev.target, r.counted)
end

-- Zennit closes the Index for the week of `start` (default: this week): no more summons of him count until Monday.
-- Allowed once the week's minimum has been filed and the latest of them answered. Returns true if it closed.
function Respond.CloseIndex(start)
    local id, ev = ST.Week.CloseTarget(start or ST.Week.Start())
    if not id or ST.Week.EventClosed(ev) then return false end
    local old = ev.response
    local resp = { result = old.result, zroll = old.zroll, sroll = old.sroll, time = math.max(time(), old.time + 1),
        listed = old.listed, closes = true }
    ST.Store.SetResponse(id, resp)
    ST.Sync.SendResponse(id, resp)
    ST.print(closedLine(ev))
    printWeek(ev, true)
    if ST.Hub then ST.Hub.Refresh() end
    return true
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
    local target = ST.Store.Get(id) or ev
    Respond.Decide(id, Respond.Resolve(st.zroll, sroll, ST.Week.HelperBonus(target), edgeFor(target)), st.zroll, sroll)
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
    local bonus = ST.Week.HelperBonus(ev)
    diceDlg.text:SetText(string.format("%s suggests dice for your summon of him, and has rolled %d.\n\nRoll 1-100: beat his roll plus %d and the summon counts. A tie goes to him.%s",
        ev.target, zroll, edgeFor(ev), bonus > 0 and string.format(" Your helpers add +%d to your roll.", bonus) or ""))
    diceDlg.rollBtn:Show()
    diceDlg:Show()
end

-- Sync calls this when Zennit's answer arrives. Tell the chat, and finish the dice prompt if we have one.
function Respond.OnResponse(id, ev, resp, before)
    local line = Respond.Announce(ev, resp)
    if resp.closes and before and not before.closes and before.result == resp.result then
        line = closedLine(ev) -- the same answer again, now closing the Index: only that is news
    end
    playAnswerClip(resp)
    if line then ST.print(line) end
    printWeek(ev, false)
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
            b:SetEnabled(not item[3])
            b:Show()
        else
            b:Hide()
        end
    end
end

-- Dice Zennit has left for the week of this summon (nil: no limit), not counting rolls still being decided.
local function diceLeft(id, ev)
    local start = ST.Week.Start(ev.time)
    local left = ST.Week.DiceLeft(start)
    if not left then return nil end
    for other in pairs(state) do
        local o = ST.Store.Get(other)
        if other ~= id and o and not o.fake and ST.Week.Start(o.time) == start then left = left - 1 end
    end
    return math.max(0, left)
end

-- Draws one stage on a surface: "choose", "roll", "waiting" (extra = Zennit's roll), "noanswer" or "done".
local function render(s, stage, extra)
    if not s.current then return end
    local id, ev = s.current.id, s.current.ev
    s.stage = stage
    if stage == "choose" then
        local free = Respond.OnList(ev)
        local cost
        if not ST.Week.Counts(ev) then
            local why, filing = ST.Week.Why(ST.Week.Start(ev.time), true)
            cost = string.format("%s, so the race ignores it: the Index files it under '%s'. Answer however you like.", why, filing)
        else
            cost = free and "On your list: accepting earns you the points again for your week off; refusing costs nothing." or
                string.format("Refusing costs you %d point%s.", ev.points or 0, plural(ev.points or 0))
        end
        local dice = diceLeft(id, ev) -- the week line below says how many are left
        local week = ST.Week.StatusLine(ST.Week.Start(ev.time), ST.Gag.IsZennit())
        s.text:SetText(summonText(ev) .. "\n" .. cost .. "\n" .. (week and (week .. " ") or "") .. "How will you deal with it? (Ignore it and it counts as accepted.)")
        setButtons(s, {
            { "Accept it", function() Respond.Decide(id, "accepted") end },
            { free and "Refuse (free)" or "Refuse", function() Respond.Decide(id, Respond.OnList(ev) and "excused" or "refused") end },
            { "Demand " .. SILVER .. " silver, in cash, no receipt", function() Respond.Decide(id, "owed") end },
            dice == 0 and { "No dice left this week", function() end, true }
                or { "Suggest dice (1-100)", function() render(s, "roll") end },
        })
    elseif stage == "roll" then
        local bonus = ST.Week.HelperBonus(ev)
        s.text:SetText(string.format("Dice. You roll 1-100, then %s rolls back. You add %d to your roll%s; higher wins and a tie goes to you.\n\nIf you win, the summon does not count.",
            ev.caster, edgeFor(ev), bonus > 0 and string.format(", and %s's helpers add %d to theirs", ev.caster, bonus) or ""))
        setButtons(s, {
            { "Roll 1-100", function()
                if diceLeft(id, ev) == 0 then return render(s, "choose") end -- the last die went on another summon
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
        local text = Respond.Announce(ev, resp) or ""
        local buttons = {}
        if resp.result == "owed" then buttons[#buttons + 1] = { "They paid", function() Respond.Decide(id, "paid") end } end
        buttons[#buttons + 1] = { "Done", s.close }
        if not ev.fake and ST.Week.CloseTarget(ST.Week.Start(ev.time)) then
            text = text .. "\n\nThat makes enough summons for the Index to accept a closure. You may close it for the week."
            buttons[#buttons + 1] = { "Close the Index", function()
                Respond.CloseIndex(ST.Week.Start(ev.time))
                render(s, "done")
            end }
        end
        s.text:SetText(text)
        setButtons(s, buttons)
    end
end

function refreshSurfaces(id, stage, extra)
    for _, s in ipairs(surfaces) do
        if s.current and s.current.id == id and s.text:IsVisible() then render(s, stage, extra) end
    end
end

-- A place to draw the choices: some text and four buttons inside `parent`, in `columns` columns (default 1).
-- closeFn runs for the Close button.
function Respond.NewSurface(parent, x, y, width, closeFn, columns, textHeight)
    columns, textHeight = columns or 1, textHeight or 110
    local s = { buttons = {}, close = closeFn or function() end }
    s.text = T.Text(parent, 18, "green")
    s.text:SetPoint("TOPLEFT", x, y)
    s.text:SetSize(width, textHeight)
    s.text:SetJustifyV("TOP")
    s.text:SetSpacing(2)
    local bw = (width - (columns - 1) * 8) / columns
    for i = 1, 4 do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local b = T.Button(parent, "", bw, 28, nil, i == 1 and "primary" or nil)
        b:SetPoint("TOPLEFT", x + col * (bw + 8), y - textHeight - 6 - row * 34)
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
    dlg = T.Window("SummonCoreRespond", 440, 380, { strata = "DIALOG", escape = false })
    dlg:ClearAllPoints()
    dlg:SetPoint("TOP", 0, -140)
    dlg.TitleText:SetText("A SUMMONING!")
    dlgSurface = Respond.NewSurface(dlg, 18, -40, 404, function() dlg:Hide() end, 1, 190)
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
