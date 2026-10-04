-- Hub: one window for everything the slash commands do. Tabs: Summary, Log, Answer, Tally, Badges, Story, Sync, Tools.
-- The slash commands still work; /st with no arguments opens this window. Zennit's client gets the gag
-- instead of the Summary, Tally and Badges tabs, the same as before.
local ADDON, ST = ...
local Hub = {}
ST.Hub = Hub

local ROW_H = 18
local ORDER = { "summary", "log", "answer", "tally", "badges", "story", "sync", "tools" }
local LABELS = { summary = "Summary", log = "Log", answer = "Answer", tally = "Tally", badges = "Badges", story = "Story", sync = "Sync", tools = "Tools" }
local GATED = { summary = true, tally = true, badges = true } -- hidden on Zennit's client

local window
local tabs = {}      -- name -> { button, frame, refresh }
local current

local function fmtTime(sec, pattern) return date(pattern or "%Y-%m-%d %H:%M", sec) end

----------------------------------------------------------------------
-- Building blocks
----------------------------------------------------------------------
local function button(parent, text, x, y, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    b:SetPoint("TOPLEFT", x, y)
    b:SetScript("OnClick", onClick)
    return b
end

local function label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function bodyText(parent, x, y, width, height)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetSize(width, height)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

-- A scrolling table. columns = { { title, width, "LEFT"|"RIGHT" }, ... }; list.Set(rows) takes arrays of strings.
local function scrollList(parent, columns, bottomMargin)
    local list = { rows = {} }
    local xs, x = {}, 8
    for i, col in ipairs(columns) do
        xs[i] = x
        local head = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        head:SetPoint("TOPLEFT", x, -6)
        head:SetWidth(col[2] - 6)
        head:SetJustifyH(col[3] or "LEFT")
        head:SetText(col[1])
        x = x + col[2]
    end
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -24)
    sf:SetPoint("BOTTOMRIGHT", -26, bottomMargin or 8)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(x, 1)
    sf:SetScrollChild(child)
    list.empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    list.empty:SetPoint("CENTER", sf, "CENTER")

    function list.Set(rows, emptyText)
        for i, row in ipairs(rows) do
            local r = list.rows[i]
            if not r then
                r = {}
                for c, col in ipairs(columns) do
                    local fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    fs:SetPoint("TOPLEFT", xs[c], -(i - 1) * ROW_H - 2)
                    fs:SetWidth(col[2] - 6)
                    fs:SetJustifyH(col[3] or "LEFT")
                    fs:SetWordWrap(false)
                    r[c] = fs
                end
                list.rows[i] = r
            end
            for c = 1, #columns do
                r[c]:SetText(row[c] or "")
                r[c]:Show()
            end
        end
        for i = #rows + 1, #list.rows do
            for _, fs in ipairs(list.rows[i]) do fs:Hide() end
        end
        child:SetHeight(math.max(1, #rows * ROW_H + 4))
        list.empty:SetText(#rows == 0 and (emptyText or "Nothing here yet.") or "")
    end
    return list
end

----------------------------------------------------------------------
-- Tab contents
----------------------------------------------------------------------
local function whereText()
    local mapID, sub = C_Map.GetBestMapForUnit("player"), GetSubZoneText()
    local pts, kind = ST.Scoring.Score(mapID, sub)
    return string.format("Here: %s, %s (map %s) scores as %s, %d point%s.", GetZoneText(),
        sub ~= "" and sub or "no subzone", ST.safe(mapID), kind, pts, pts == 1 and "" or "s")
end

local function buildSummary(f)
    local text = bodyText(f, 16, -12, 720, 400)
    return function()
        local me = ST.Store.me()
        local t = ST.Store.Tallies()[me] or { cast = 0, received = 0, assisted = 0, points = 0 }
        local lines = {
            "|cffffd100" .. me .. "|r",
            string.format("Summons cast: %d    Received: %d    Assisted: %d    Points: %d", t.cast, t.received,
                t.assisted, t.points),
            whereText(),
            "",
            "|cffffd100Badges|r",
        }
        for _, b in ipairs(ST.Scoring.badges) do
            local got = ST.db.badges[b.id]
            lines[#lines + 1] = got and ("|cff33ff66[x]|r " .. b.name .. "  " .. fmtTime(got.earned, "%Y-%m-%d"))
                or ("|cff888888[ ] " .. b.name .. "|r")
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cffffd100Recent summons|r"
        local recent = ST.Store.Recent(6)
        if #recent == 0 then lines[#lines + 1] = "none yet" end
        for _, r in ipairs(recent) do
            local ev = r.ev
            lines[#lines + 1] = string.format("%s  %s -> %s  (%s, +%d)", fmtTime(ev.time, "%m-%d %H:%M"), ev.caster,
                ev.target, ev.kind or "?", ev.points or 0)
        end
        text:SetText(table.concat(lines, "\n"))
    end
end

local function buildLog(f)
    local list = scrollList(f, { { "When", 100 }, { "Summoner -> target", 190 }, { "Helpers", 140 },
        { "Zennit's answer", 170 }, { "Kind", 60 }, { "Pts", 40, "RIGHT" } }, 40)
    local status = label(f, "", 520, -420, "GameFontDisableSmall")
    local function refresh()
        local zenit = ST.Gag.IsZennit()
        local rows = {}
        for _, r in ipairs(ST.Store.Recent(300)) do
            local ev = r.ev
            rows[#rows + 1] = {
                fmtTime(ev.time, "%m-%d %H:%M"),
                ev.caster .. " -> " .. ev.target .. (ev.confirmed and "" or " ?") .. (ev.fake and " (test)" or ""),
                #ev.assistants > 0 and table.concat(ev.assistants, ", ") or "-",
                ST.Respond.Describe(ev) or "",
                zenit and "" or (ev.kind or ""),
                zenit and "" or tostring(ev.points or 0),
            }
        end
        list.Set(rows, "No summons logged yet.")
        status:SetText(string.format("%d summon%s in the log", ST.Store.Count(), ST.Store.Count() == 1 and "" or "s"))
    end
    button(f, "Undo last", 8, -420, 100, function()
        local last = ST.Store.RemoveLast()
        ST.print(last and ("removed " .. last.ev.caster .. " -> " .. last.ev.target) or "nothing to undo")
        Hub.Refresh()
    end)
    button(f, "Add test summon", 114, -420, 130, function()
        local names = { "Bob", "Al", "Cy", "Di", "Ed" }
        local n = ST.Store.Count() % #names + 1
        ST.AddFake(names[n], { names[n % #names + 1], names[(n + 1) % #names + 1] })
        Hub.Refresh()
    end)
    button(f, "Answer a summon", 250, -420, 140, function() Hub.Open("answer") end)
    return refresh
end

local function buildAnswer(f)
    local info = label(f, "", 16, -12, "GameFontNormal")
    local counter = label(f, "", 252, -306, "GameFontDisableSmall")
    local surface
    surface = ST.Respond.NewSurface(f, 16, -40, 704, function()
        ST.Respond.Clear(surface)
        Hub.Refresh()
    end)

    -- the summons already answered, below
    local recentFrame = CreateFrame("Frame", nil, f)
    recentFrame:SetPoint("TOPLEFT", 0, -338)
    recentFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    local recent = scrollList(recentFrame, { { "When", 100 }, { "Summoner", 150 }, { "Your answer", 300 }, { "Pts", 60, "RIGHT" } }, 8)

    local function indexOf(pending, id)
        for i, r in ipairs(pending) do if r.id == id then return i end end
    end

    local function go(step)
        local pending = ST.Respond.Pending()
        if #pending == 0 then return end
        local at = surface.current and indexOf(pending, surface.current.id)
        local target = at and ((at - 1 + step) % #pending) + 1 or (step > 0 and 1 or #pending)
        ST.Respond.Select(surface, pending[target].id, pending[target].ev)
        Hub.Refresh()
    end
    button(f, "< Previous", 16, -300, 110, function() go(-1) end)
    button(f, "Next >", 132, -300, 110, function() go(1) end)

    -- his secret list: refusing a summon to one of these costs him nothing (kept on this client only)
    label(f, "Secret list", 360, -304, "GameFontNormalSmall")
    local entry = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    entry:SetSize(150, 22)
    entry:SetPoint("TOPLEFT", 440, -301)
    entry:SetAutoFocus(false)
    local function addEntry()
        if ST.Respond.ListAdd(entry:GetText()) then entry:SetText("") end
        entry:ClearFocus()
        Hub.Refresh()
    end
    entry:SetScript("OnEnterPressed", addEntry)
    button(f, "Add", 600, -300, 50, addEntry)
    button(f, "Clear", 654, -300, 56, function() ST.Respond.ListClear() Hub.Refresh() end)
    local listText = label(f, "", 360, -326, "GameFontDisableSmall")

    return function()
        local list = ST.Respond.List()
        listText:SetText(#list == 0 and "empty: refusing always costs points" or table.concat(list, ", "))
        local pending = ST.Respond.Pending()
        local current = surface.current
        -- keep what is on show (a summon being answered, or its outcome) until the user moves on
        if not (current and (indexOf(pending, current.id) or ST.Respond.Stage(surface) == "done")) then
            if #pending > 0 then
                ST.Respond.Select(surface, pending[1].id, pending[1].ev)
            else
                ST.Respond.Clear(surface)
            end
        end
        local n = #pending
        if n == 0 and not ST.Gag.IsZennit() then
            info:SetText("This tab is for Zennit's character: summons of him wait here for his answer. Try it with Tools > Test a summoning.")
        else
            info:SetText(n == 0 and "Nothing is waiting for your answer." or
                string.format("%d summon%s waiting for your answer", n, n == 1 and "" or "s"))
        end
        local at = surface.current and indexOf(pending, surface.current.id)
        counter:SetText(at and string.format("showing %d of %d", at, n) or "")

        local me, rows = ST.Store.me(), {}
        for _, r in ipairs(ST.Store.Recent(200)) do
            local ev = r.ev
            if ev.target == me and ev.response and ev.response.result ~= "owed" and #rows < 40 then
                rows[#rows + 1] = { fmtTime(ev.time, "%m-%d %H:%M"), ev.caster .. (ev.fake and " (test)" or ""),
                    ST.Respond.Describe(ev) or "", ST.Store.Lands(ev) and tostring(ev.points or 0) or "0" }
            end
        end
        recent.Set(rows, "No answered summons yet.")
    end
end

local function buildTally(f)
    local list = scrollList(f, { { "Player", 220 }, { "Cast", 80, "RIGHT" }, { "Received", 90, "RIGHT" },
        { "Assisted", 90, "RIGHT" }, { "Points", 90, "RIGHT" } })
    return function()
        local rows = {}
        for name, t in pairs(ST.Store.Tallies()) do rows[#rows + 1] = { name, t } end
        table.sort(rows, function(a, b)
            if a[2].points ~= b[2].points then return a[2].points > b[2].points end
            return a[1] < b[1]
        end)
        local out = {}
        for _, r in ipairs(rows) do
            out[#out + 1] = { r[1], tostring(r[2].cast), tostring(r[2].received), tostring(r[2].assisted),
                tostring(r[2].points) }
        end
        list.Set(out, "No summons logged yet.")
    end
end

local function buildBadges(f)
    local list = scrollList(f, { { "Badge", 240 }, { "Status", 90 }, { "Earned", 160 } })
    return function()
        local rows = {}
        for _, b in ipairs(ST.Scoring.badges) do
            local got = ST.db.badges[b.id]
            rows[#rows + 1] = { b.name, got and "|cff33ff66earned|r" or "|cff888888locked|r",
                got and fmtTime(got.earned) or "" }
        end
        list.Set(rows)
    end
end

-- Every chapter of the story: the intro, then one for each win of the season race (z = Zennit's, g = the group's).
local STORY = {
    { "1", "The intro: Zennit and the Index" },
    { "z1", "Zennit's 1st win: the week off" },
    { "g1", "The group's 1st win: the cake" },
    { "z2", "Zennit's 2nd win: the key to the side door" },
    { "g2", "The group's 2nd win: the carbon copy of the Form" },
    { "z3", "Zennit's 3rd win: the list is training modules" },
    { "g3", "The group's 3rd win: the Ritual holds the Form" },
    { "z4", "Zennit's 4th win: the clerk shows him the desk" },
    { "g4", "The group's 4th win: the Ritual names its price" },
    { "z5", "FINALE, Zennit: he becomes the clerk" },
    { "g5", "FINALE, the group: the receipt, and Zennit is freed" },
}

local function buildStory(f)
    local head = label(f, "Every chapter of the story. Each win in the weekly race plays its own; replay any that is written.", 16, -10, "GameFontDisableSmall")
    local rows = {}
    for i, c in ipairs(STORY) do
        local y = -34 - (i - 1) * 32
        local row = {
            title = label(f, c[2], 16, y - 4, "GameFontHighlight"),
            status = label(f, "", 470, y - 4, "GameFontNormalSmall"),
        }
        row.play = button(f, "Play", 640, y + 2, 80, function()
            window:Hide() -- the viewer sits under this window
            ST.Intro.Play(c[1])
        end)
        rows[i] = row
    end
    head:SetWidth(700)
    return function()
        local reached = {}
        for _, c in ipairs(ST.Week.Season().chapters) do reached[c.key] = true end
        for i, c in ipairs(STORY) do
            local written = ST.Intro.HasChapter(c[1]) or c[1] == "1"
            local row = rows[i]
            row.status:SetText(not written and "|cff888888not written yet|r" or
                ((reached[c[1]] or c[1] == "1") and "|cff33ff66reached|r" or "ready"))
            row.play:SetEnabled(written)
        end
    end
end

local function buildSync(f)
    local info = bodyText(f, 16, -14, 720, 120)
    local out = bodyText(f, 16, -250, 720, 140)
    button(f, "Say hello now", 16, -140, 150, function()
        ST.Sync.Hello()
        Hub.Refresh()
    end)
    button(f, "Run self-test", 172, -140, 150, function()
        ST.SyncTest.Run()
        out:SetText("Self-test results are in the chat window.")
    end)
    button(f, "Import / Export", 328, -140, 150, function() ST.Export.Open("import") end)
    label(f, "Sync shares your summons with other Summon Core users in your party, raid and guild.\n" ..
        "'Say hello now' announces your log size so anyone with newer or older entries swaps them with you.", 16, -184,
        "GameFontDisableSmall"):SetWidth(720)
    return function()
        local st = ST.Sync.state
        local channels = ST.Sync.channels()
        info:SetText(string.format(
            "Summons in your log: %d\nLatest: %s\nQueued to send: %d\nChannels right now: %s",
            ST.Store.Count(), ST.Store.Latest() > 0 and fmtTime(ST.Store.Latest()) or "never", #st.queue,
            #channels > 0 and table.concat(channels, ", ") or "none (not in a group or guild)"))
    end
end

local function buildTools(f)
    local out = bodyText(f, 16, -262, 720, 150)
    local function show(text) out:SetText(text) end

    -- left column
    label(f, "Windows", 16, -10)
    button(f, "Diagnostics", 16, -34, 170, function() ST.ToggleTests("") end)
    button(f, "Import / Export", 16, -64, 170, function() ST.Export.Open("import") end)
    button(f, "Play the intro", 16, -94, 170, function() window:Hide() ST.Intro.Toggle("") end)
    button(f, "Large-image test", 16, -124, 170, function() ST.Comic.Toggle("") end)

    -- middle column
    label(f, "Try things", 210, -10)
    button(f, "Preview Zennit gag", 210, -34, 170, function() ST.Gag.Play() end)
    button(f, "Intro sound check", 210, -64, 170, function() ST.Intro.Check() end)
    button(f, "Test a summoning", 404, -124, 200, function() ST.Respond.Test() end)
    button(f, "Assistants prompt demo", 210, -94, 170, function()
        ST.Prompt.Ask("Target", { "Alice", "Bob", "Cara" }, {}, function(names, confirmed)
            show(string.format("Prompt result: %s (%s)", #names > 0 and table.concat(names, ", ") or "nobody",
                confirmed and "confirmed" or "unconfirmed"))
        end)
    end)
    button(f, "Where am I?", 210, -124, 170, function() show(whereText()) end)

    -- right column: switches
    label(f, "Switches", 404, -10)
    local function switch(y, name, get, set)
        local b
        local function paint() b:SetText(name .. ": " .. (get() and "on" or "off")) end
        b = button(f, "", 404, y, 200, function()
            set(not get())
            paint()
        end)
        paint()
    end
    switch(-34, "Zennit test mode", function() return ST.db.settings.zenitTest == true end,
        function(v) ST.db.settings.zenitTest = v end)
    switch(-64, "Detector messages", function() return ST.db.settings.debug == true end,
        function(v) ST.db.settings.debug = v end)
    switch(-94, "Sounds", function() return ST.db.settings.soundOn ~= false end,
        function(v) ST.db.settings.soundOn = v end)

    -- ping and voice clips
    label(f, "Ping a player", 16, -168)
    local ping = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    ping:SetSize(150, 22)
    ping:SetPoint("TOPLEFT", 130, -166)
    ping:SetAutoFocus(false)
    button(f, "Send ping", 292, -164, 100, function()
        ST.SendPings(ping:GetText())
        show("Ping sent. Replies appear in Diagnostics > Addon messages.")
    end)
    label(f, "Voice clip", 410, -168)
    local clip = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    clip:SetSize(140, 22)
    clip:SetPoint("TOPLEFT", 490, -166)
    clip:SetAutoFocus(false)
    button(f, "Play", 640, -164, 70, function()
        local file = ST.Clips.Play(clip:GetText())
        show(file and ("Played " .. file) or "Nothing to play. Type a category or file name.")
    end)
    button(f, "List voice clips", 16, -198, 170, function()
        local cats = ST.Clips.Categories()
        if #cats == 0 then
            return show("No voice clips yet: put .ogg files named <category>_<NN>_<who> in Media/clips, run " ..
                "tools/build_clip_manifest.ps1, then /reload.")
        end
        local lines = {}
        for _, c in ipairs(cats) do lines[#lines + 1] = string.format("%s: %d", c[1], c[2]) end
        show("Voice clips: " .. table.concat(lines, ",  "))
    end)
    return function() end
end

local BUILDERS = { summary = buildSummary, log = buildLog, answer = buildAnswer, tally = buildTally, badges = buildBadges, story = buildStory,
    sync = buildSync, tools = buildTools }

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local function selectTab(name)
    if GATED[name] and ST.Gag.Blocked() then return false end
    current = name
    for key, tab in pairs(tabs) do
        local on = key == name
        tab.frame:SetShown(on)
        tab.button:SetText((on and "|cff33ff66" or "") .. LABELS[key])
    end
    tabs[name].refresh()
    return true
end

local function build()
    window = CreateFrame("Frame", "SummonCoreHub", UIParent, "BasicFrameTemplateWithInset")
    window:Hide() -- a new frame is visible; Hub.Open shows it when asked
    window:SetSize(780, 540)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window.TitleText:SetText("Summon Core  v" .. ST.version)
    tinsert(UISpecialFrames, "SummonCoreHub")

    for i, name in ipairs(ORDER) do
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", 12, -62)
        content:SetPoint("BOTTOMRIGHT", -12, 12)
        content:Hide()
        local tabButton = button(window, LABELS[name], 14 + (i - 1) * 90, -32, 86, function() selectTab(name) end)
        tabs[name] = { button = tabButton, frame = content, refresh = BUILDERS[name](content) }
    end
    window:SetScript("OnShow", function() if current then tabs[current].refresh() end end)
end

-- Refreshes the open tab (call after anything that changes the log).
function Hub.Refresh()
    if window and window:IsShown() and current and tabs[current] then tabs[current].refresh() end
end

-- Opens the window on a tab (default: the last one used, or Summary).
function Hub.Open(name)
    if not window then build() end
    if name and not tabs[name] then name = nil end
    local zenit = ST.Gag.IsZennit()
    if name and GATED[name] and zenit then
        ST.Gag.Play() -- Zennit asked for a hidden tab: the gag, then the log instead
        name = "log"
    end
    name = name or current or (zenit and "log" or "summary")
    if zenit and GATED[name] then name = "log" end
    if not window:IsShown() then window:Show() end
    selectTab(name)
end

function Hub.Toggle()
    if window and window:IsShown() then window:Hide() else Hub.Open() end
end

-- Builds the window if needed and refreshes every tab, returning true or false, error.
-- Used by the self-test to catch mistakes in the window code without showing it.
function Hub.SelfCheck()
    if not window then build() end
    for _, name in ipairs(ORDER) do
        local ok, err = pcall(tabs[name].refresh)
        if not ok then return false, name .. ": " .. tostring(err) end
    end
    return true
end
