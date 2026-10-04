-- Hub: one window for everything the slash commands do. Tabs: Summary, Log, Answer, Tally, Badges, Story, Sync, Tools.
-- The slash commands still work; /st with no arguments opens this window. Zennit's client gets the gag
-- instead of the Summary, Tally and Badges tabs, the same as before. Drawn in the Neon Index look (Theme.lua):
-- a title strip, the tabs, the season race on every tab, and a command-prompt status line along the bottom.
local ADDON, ST = ...
local Hub = {}
ST.Hub = Hub
local T = ST.Theme

local ROW_H = 20
local ORDER = { "summary", "log", "answer", "tally", "badges", "story", "sync", "tools" }
local LABELS = { summary = "SUMMARY", log = "LOG", answer = "ANSWER", tally = "TALLY", badges = "BADGES", story = "STORY", sync = "SYNC", tools = "TOOLS" }
local GATED = { summary = true, tally = true, badges = true } -- hidden on Zennit's client

local window
local tabs = {}      -- name -> { button, frame, refresh }
local current
local chrome = {}    -- the season band and the status line

local function fmtTime(sec, pattern) return date(pattern or "%Y-%m-%d %H:%M", sec) end

-- A name in its colour: Zennit pink, everyone else cyan.
local function who(name)
    return T.Paint(ST.Week.IsZennit(name) and "pink" or "cyan", name)
end

-- Zennit's answer in its colour, or "" if there is none.
local ANSWER_COLORS = { accepted = "green", paid = "green", lost = "green", refused = "red", excused = "violet",
    owed = "amber", won = "pink" }
local function answerText(ev)
    local text = ST.Respond.Describe(ev)
    if not text then return "" end
    return T.Paint(ANSWER_COLORS[ev.response.result] or "amber", text)
end

----------------------------------------------------------------------
-- Building blocks
----------------------------------------------------------------------
local function button(parent, text, x, y, width, onClick, style)
    local b = T.Button(parent, text, width, 24, onClick, style)
    b:SetPoint("TOPLEFT", x, y)
    return b
end

-- A button along the bottom edge of a tab.
local function bottomButton(parent, text, x, width, onClick, style)
    local b = T.Button(parent, text, width, 24, onClick, style)
    b:SetPoint("BOTTOMLEFT", x, 4)
    return b
end

local function label(parent, text, x, y, color, size)
    local fs = T.Text(parent, size or 18, color or "dim")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function bodyText(parent, x, y, width, height)
    local fs = T.Text(parent, 18, "green")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetSize(width, height)
    fs:SetJustifyV("TOP")
    fs:SetSpacing(2)
    return fs
end

-- A scrolling table. columns = { { title, width, "LEFT"|"RIGHT" }, ... }; list.Set(rows) takes arrays of strings.
local function scrollList(parent, columns, bottomMargin)
    local list = { rows = {} }
    local xs, x = {}, 8
    for i, col in ipairs(columns) do
        xs[i] = x
        local head = T.Text(parent, 18, "dim")
        head:SetPoint("TOPLEFT", x, -6)
        head:SetWidth(col[2] - 6)
        head:SetJustifyH(col[3] or "LEFT")
        head:SetText(col[1]:upper())
        x = x + col[2]
    end
    local rule = T.Fill(parent, "line", 1)
    rule:SetPoint("TOPLEFT", 4, -25)
    rule:SetPoint("TOPRIGHT", -14, -25)
    rule:SetHeight(1)
    local sf, child = T.Scroll(parent)
    sf:SetPoint("TOPLEFT", 4, -30)
    sf:SetPoint("BOTTOMRIGHT", -14, bottomMargin or 8)
    child:SetSize(x, 1)
    list.empty = T.Text(parent, 18, "dim")
    list.empty:SetPoint("CENTER", sf, "CENTER")

    function list.Set(rows, emptyText)
        for i, row in ipairs(rows) do
            local r = list.rows[i]
            if not r then
                r = {}
                for c, col in ipairs(columns) do
                    local fs = T.Text(child, 18, "green", "OVERLAY")
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
    return string.format("Here: %s, %s (map %s) scores as %s, %s.", GetZoneText(),
        sub ~= "" and sub or "no subzone", ST.safe(mapID), kind, T.Paint("amber", pts .. " point" .. (pts == 1 and "" or "s")))
end

local function buildSummary(f)
    local text = bodyText(f, 16, -8, 740, 440)
    return function()
        local me = ST.Store.me()
        local t = ST.Store.Tallies()[me] or { cast = 0, received = 0, assisted = 0, points = 0 }
        local lines = {
            T.Paint("dim", "C:\\INDEX> whoami"),
            who(me),
            string.format("Cast %s    Received %s    Assisted %s    Points %s", T.Paint("amber", t.cast),
                T.Paint("amber", t.received), T.Paint("amber", t.assisted), T.Paint("amber", t.points)),
            whereText(),
            "",
            T.Paint("dim", "BADGES.SYS"),
        }
        for _, b in ipairs(ST.Scoring.badges) do
            local got = ST.db.badges[b.id]
            lines[#lines + 1] = got and ("[X] " .. b.name .. "  " .. T.Paint("dim", fmtTime(got.earned, "%Y-%m-%d")))
                or T.Paint("dim", "[ ] " .. b.name)
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = T.Paint("dim", "RECENT.LOG")
        local recent = ST.Store.Recent(6)
        if #recent == 0 then lines[#lines + 1] = T.Paint("dim", "none yet") end
        for _, r in ipairs(recent) do
            local ev = r.ev
            lines[#lines + 1] = string.format("%s  %s => %s  (%s, +%d)", T.Paint("dim", fmtTime(ev.time, "%m-%d %H:%M")),
                who(ev.caster), who(ev.target), ev.kind or "?", ev.points or 0)
        end
        text:SetText(table.concat(lines, "\n"))
    end
end

local function buildLog(f)
    local list = scrollList(f, { { "When", 100 }, { "Summoner => target", 190 }, { "Helpers", 140 },
        { "Zennit says", 190 }, { "Kind", 70 }, { "Pts", 40, "RIGHT" } }, 36)
    local function refresh()
        local zenit = ST.Gag.IsZennit()
        local rows = {}
        for _, r in ipairs(ST.Store.Recent(300)) do
            local ev = r.ev
            rows[#rows + 1] = {
                T.Paint("dim", fmtTime(ev.time, "%m-%d %H:%M")),
                who(ev.caster) .. " => " .. who(ev.target) .. (ev.confirmed and "" or " ?") .. (ev.fake and T.Paint("dim", " (test)") or ""),
                #ev.assistants > 0 and table.concat(ev.assistants, ", ") or T.Paint("dim", "-"),
                answerText(ev),
                zenit and "" or (ev.kind or ""),
                zenit and "" or T.Paint("amber", ev.points or 0),
            }
        end
        list.Set(rows, "No summons logged yet.")
    end
    bottomButton(f, "UNDO LAST", 4, 120, function()
        local last = ST.Store.RemoveLast()
        ST.print(last and ("removed " .. last.ev.caster .. " -> " .. last.ev.target) or "nothing to undo")
        Hub.Refresh()
    end)
    local addTest = bottomButton(f, "ADD TEST SUMMON", 130, 160, function()
        local names = { "Bob", "Al", "Cy", "Di", "Ed" }
        local n = ST.Store.Count() % #names + 1
        ST.AddFake(names[n], { names[n % #names + 1], names[(n + 1) % #names + 1] })
        Hub.Refresh()
    end)
    local answer = bottomButton(f, "ANSWER A SUMMON", 296, 160, function() Hub.Open("answer") end, "primary")
    return function()
        local admin = ST.IsAdmin()
        addTest:SetShown(admin) -- an admin tool
        answer:ClearAllPoints()
        answer:SetPoint("BOTTOMLEFT", admin and 296 or 130, 4)
        refresh()
    end
end

local function buildAnswer(f)
    local info = label(f, "", 16, -8, "green")
    info:SetWidth(740)
    local surface
    surface = ST.Respond.NewSurface(f, 16, -36, 740, function()
        ST.Respond.Clear(surface)
        Hub.Refresh()
    end, 2)
    local counter = label(f, "", 252, -232, "dim")

    -- the summons already answered, below
    local recentFrame = CreateFrame("Frame", nil, f)
    recentFrame:SetPoint("TOPLEFT", 0, -282)
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
    button(f, "< PREV", 16, -228, 110, function() go(-1) end)
    button(f, "NEXT >", 132, -228, 110, function() go(1) end)

    -- his secret list: refusing a summon to one of these costs him nothing (kept on this client only, so it is
    -- only shown on Zennit's client, and the admin's to try it)
    local secret = CreateFrame("Frame", nil, f)
    secret:SetAllPoints()
    label(secret, "SECRET LIST", 360, -231, "dim")
    local entry = T.EditBox(secret, 150, 22)
    entry:SetPoint("TOPLEFT", 460, -229)
    local function addEntry()
        if ST.Respond.ListAdd(entry:GetText()) then entry:SetText("") end
        entry:ClearFocus()
        Hub.Refresh()
    end
    entry:SetScript("OnEnterPressed", addEntry)
    button(secret, "ADD", 616, -228, 60, addEntry)
    button(secret, "CLEAR", 682, -228, 74, function() ST.Respond.ListClear() Hub.Refresh() end, "danger")
    local listText = label(secret, "", 360, -256, "violet")
    listText:SetWidth(396)
    listText:SetWordWrap(false)

    return function()
        secret:SetShown(ST.Gag.IsZennit() or ST.IsAdmin())
        local list = ST.Respond.List()
        listText:SetText(#list == 0 and T.Paint("dim", "empty: refusing always costs points") or table.concat(list, ", "))
        local pending = ST.Respond.Pending()
        local cur = surface.current
        -- keep what is on show (a summon being answered, or its outcome) until the user moves on
        if not (cur and (indexOf(pending, cur.id) or ST.Respond.Stage(surface) == "done")) then
            if #pending > 0 then
                ST.Respond.Select(surface, pending[1].id, pending[1].ev)
            else
                ST.Respond.Clear(surface)
            end
        end
        local n = #pending
        if n == 0 and not ST.Gag.IsZennit() then
            info:SetText("This tab is for Zennit's character: summons of him wait here for his answer." ..
                (ST.IsAdmin() and " Try it with Tools > Test a summoning." or ""))
        else
            info:SetText(n == 0 and "Nothing is waiting for your answer." or
                string.format("%s summon%s waiting for your answer", T.Paint("amber", n), n == 1 and "" or "s"))
        end
        local at = surface.current and indexOf(pending, surface.current.id)
        counter:SetText(at and string.format("%d of %d", at, n) or "")

        local me, rows = ST.Store.me(), {}
        for _, r in ipairs(ST.Store.Recent(200)) do
            local ev = r.ev
            if ev.target == me and ev.response and ev.response.result ~= "owed" and #rows < 40 then
                rows[#rows + 1] = { T.Paint("dim", fmtTime(ev.time, "%m-%d %H:%M")), who(ev.caster) .. (ev.fake and T.Paint("dim", " (test)") or ""),
                    answerText(ev), T.Paint("amber", ST.Store.Lands(ev) and (ev.points or 0) or 0) }
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
            out[#out + 1] = { who(r[1]), tostring(r[2].cast), tostring(r[2].received), tostring(r[2].assisted),
                T.Paint("amber", r[2].points) }
        end
        list.Set(out, "No summons logged yet.")
    end
end

local function buildBadges(f)
    local list = scrollList(f, { { "Badge", 260 }, { "Status", 110 }, { "Earned", 180 } })
    return function()
        local rows = {}
        for _, b in ipairs(ST.Scoring.badges) do
            local got = ST.db.badges[b.id]
            rows[#rows + 1] = { got and ("[X] " .. b.name) or T.Paint("dim", "[ ] " .. b.name),
                got and "EARNED" or T.Paint("dim", "LOCKED"), got and T.Paint("dim", fmtTime(got.earned)) or "" }
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
    label(f, "Every chapter of the story. Each win in the weekly race plays its own; replay any that is written.", 16, -8):SetWidth(740)
    local rows = {}
    for i, c in ipairs(STORY) do
        local y = -34 - (i - 1) * 32
        local row = {
            title = label(f, c[2], 16, y - 4, "green"),
            status = label(f, "", 470, y - 4),
        }
        row.play = button(f, "> PLAY", 656, y, 90, function()
            window:Hide() -- the viewer sits under this window; it comes back when the viewer is closed
            ST.Intro.Play(c[1], function() Hub.Open("story") end)
        end)
        rows[i] = row
    end
    return function()
        local reached = {}
        local admin = ST.IsAdmin()
        for _, c in ipairs(ST.Week.Season().chapters) do reached[c.key] = true end
        for i, c in ipairs(STORY) do
            local written = ST.Intro.HasChapter(c[1]) or c[1] == "1"
            local isReached = reached[c[1]] or c[1] == "1"
            local row = rows[i]
            -- the part after the colon gives the chapter away, so it stays hidden until the race gets there
            local title = c[2]
            if not (isReached or admin) then title = title:match("^(.-:)") .. " ???" end
            row.title:SetText(title)
            row.status:SetText(not written and "not written yet" or
                (isReached and T.Paint("green", "REACHED") or (admin and T.Paint("amber", "not reached (admin)") or "not reached yet")))
            row.play:SetEnabled(written and (isReached or admin))
        end
    end
end

local function buildSync(f)
    local info = bodyText(f, 16, -10, 740, 120)
    local out = bodyText(f, 16, -250, 740, 140)
    button(f, "SAY HELLO NOW", 16, -140, 160, function()
        ST.Sync.Hello()
        Hub.Refresh()
    end, "primary")
    local selfTest = button(f, "RUN SELF-TEST", 182, -140, 160, function()
        ST.SyncTest.Run()
        out:SetText("Self-test results are in the chat window.")
    end)
    local importExport = button(f, "IMPORT / EXPORT", 348, -140, 160, function() ST.Export.Open("import") end)
    label(f, "Sync shares your summons with other Summon Core users in your party, raid and guild.\n" ..
        "'Say hello now' announces your log size so anyone with newer or older entries swaps them with you.", 16, -184):SetWidth(740)
    return function()
        local admin = ST.IsAdmin()
        selfTest:SetShown(admin) -- an admin tool
        importExport:ClearAllPoints()
        importExport:SetPoint("TOPLEFT", admin and 348 or 182, -140)
        local st = ST.Sync.state
        local channels = ST.Sync.channels()
        info:SetText(string.format(
            "Summons in your log: %s\nLatest: %s\nQueued to send: %s\nChannels right now: %s",
            T.Paint("amber", ST.Store.Count()), ST.Store.Latest() > 0 and fmtTime(ST.Store.Latest()) or "never",
            T.Paint("amber", #st.queue),
            #channels > 0 and T.Paint("cyan", table.concat(channels, ", ")) or T.Paint("dim", "none (not in a group or guild)")))
    end
end

-- Tools: four columns of buttons. Admin-only tools are hidden for everyone else, and the columns close up
-- around them, so nobody sees gaps.
local function buildTools(f)
    local COL_W, STEP = 180, 30
    local columns = {}
    local function column(x, title)
        local col = { x = x, items = {} }
        label(f, title, x, -8)
        columns[#columns + 1] = col
        return col
    end
    local function add(col, widget, adminOnly) col.items[#col.items + 1] = { widget = widget, admin = adminOnly } end
    local function tool(col, text, onClick, adminOnly, style)
        local b = T.Button(f, text, COL_W, 24, onClick, style)
        add(col, b, adminOnly)
        return b
    end

    local out = bodyText(f, 16, -300, 740, 140)
    local function show(text) out:SetText(text) end

    local windows = column(16, "WINDOWS")
    tool(windows, "IMPORT / EXPORT", function() ST.Export.Open("import") end)
    tool(windows, "PLAY THE INTRO", function()
        window:Hide()
        ST.Intro.Play("1", function() Hub.Open("tools") end)
    end)
    tool(windows, "DIAGNOSTICS", function() ST.ToggleTests("") end, true)
    tool(windows, "LARGE-IMAGE TEST", function() ST.Comic.Toggle("") end, true)

    local try = column(204, "TRY THINGS")
    tool(try, "WHERE AM I?", function() show(whereText()) end)
    tool(try, "WEEK AND SEASON", function()
        local W = ST.Week
        local season = W.Season()
        local immune, untilT = W.Immune(time())
        show(table.concat({
            "This week: " .. W.Describe(W.Score(W.Start())),
            "Last week: " .. W.Describe(W.Score(W.Start() - 7 * 86400)),
            string.format("Season: Zennit %d of %d wins, the group %d of %d. Finales so far: %d.", season.zennit, W.WINS,
                season.group, W.WINS, #season.finales),
            immune and ("Zennit is on his week off until " .. date("%a %d %b", untilT) .. ".") or "Zennit is on the list.",
        }, "\n"))
    end)
    tool(try, "BATTLE.NET CHECK", function() show(ST.TagReport()) end)
    tool(try, "LIST VOICE CLIPS", function()
        local cats = ST.Clips.Categories()
        if #cats == 0 then
            return show("No voice clips yet: put .ogg files named <category>_<NN>_<who> in Media/clips, run " ..
                "tools/build_clip_manifest.ps1, then /reload.")
        end
        local lines = {}
        for _, c in ipairs(cats) do lines[#lines + 1] = string.format("%s: %d", c[1], c[2]) end
        show("Voice clips: " .. table.concat(lines, ",  "))
    end)
    tool(try, "TEST A SUMMONING", function() ST.Respond.Test() end, true)
    tool(try, "ASSISTANTS PROMPT", function()
        ST.Prompt.Ask("Target", { "Alice", "Bob", "Cara" }, {}, function(names, confirmed)
            show(string.format("Prompt result: %s (%s)", #names > 0 and table.concat(names, ", ") or "nobody",
                confirmed and "confirmed" or "unconfirmed"))
        end)
    end, true)
    tool(try, "PREVIEW ZENNIT GAG", function() ST.Gag.Play() end, true)
    tool(try, "INTRO SOUND CHECK", function() ST.Intro.Check() end, true)

    local switches = column(392, "SWITCHES")
    local function switch(name, get, set, adminOnly)
        local b
        local function paint() b:SetText(name .. ": " .. (get() and "ON" or "OFF")) end
        b = tool(switches, "", function()
            set(not get())
            paint()
        end, adminOnly)
        paint()
    end
    switch("SOUNDS", function() return ST.db.settings.soundOn ~= false end,
        function(v) ST.db.settings.soundOn = v end)
    switch("ZENNIT TEST", function() return ST.db.settings.zenitTest == true end,
        function(v) ST.db.settings.zenitTest = v end, true)
    switch("DETECTOR MSGS", function() return ST.db.settings.debug == true end,
        function(v) ST.db.settings.debug = v end, true)

    local data = column(580, "YOUR DATA")
    tool(data, "UNDO LAST SUMMON", function()
        local last = ST.Store.RemoveLast()
        show(last and string.format("Removed %s -> %s (badges already earned are kept).", last.ev.caster, last.ev.target) or
            "Nothing to undo.")
        Hub.Refresh()
    end)
    tool(data, "RESET MY DATA...", function() ST.Reset.Ask(false) end, nil, "danger")
    tool(data, "RESET EVERYONE...", function() ST.Reset.Ask(true) end, true, "danger")
    tool(data, "ADD TEST SUMMON", function()
        local ev = ST.AddFake("Tester", {})
        show(string.format("Test summon saved: %s in %s (+%d, %s). It stays on this client.", ev.target, ev.subzone ~= "" and ev.subzone or "nowhere", ev.points, ev.kind))
        Hub.Refresh()
    end, true)
    tool(data, "SYNC SELF-TEST", function()
        ST.SyncTest.Run()
        show("Self-test results are in the chat window.")
    end, true)
    tool(data, "RUN TAG TESTS", function()
        local ok, detail = ST.TagTest()
        show((ok and T.Paint("green", "PASS ") or T.Paint("red", "FAIL ")) .. detail)
    end, true)

    -- a row for playing a voice clip, and (admin) one for pinging a player; they sit under the columns
    local clipRow = CreateFrame("Frame", nil, f)
    clipRow:SetSize(740, 24)
    label(clipRow, "VOICE CLIP", 0, -3)
    local clip = T.EditBox(clipRow, 170, 22)
    clip:SetPoint("TOPLEFT", 110, -1)
    local function playClip()
        local file = ST.Clips.Play(clip:GetText())
        show(file and ("Played " .. file) or "Nothing to play. Type a category or file name.")
    end
    clip:SetScript("OnEnterPressed", playClip)
    button(clipRow, "PLAY", 288, 0, 80, playClip)

    local pingRow = CreateFrame("Frame", nil, f)
    pingRow:SetSize(740, 24)
    label(pingRow, "PING PLAYER", 0, -3)
    local ping = T.EditBox(pingRow, 170, 22)
    ping:SetPoint("TOPLEFT", 110, -1)
    button(pingRow, "SEND PING", 288, 0, 120, function()
        ST.SendPings(ping:GetText())
        show("Ping sent. Replies appear in Diagnostics > Addon messages.")
    end)

    return function()
        local admin = ST.IsAdmin()
        local lowest = 0
        for _, col in ipairs(columns) do
            local y = -32
            for _, item in ipairs(col.items) do
                local visible = admin or not item.admin
                item.widget:SetShown(visible)
                if visible then
                    item.widget:ClearAllPoints()
                    item.widget:SetPoint("TOPLEFT", col.x, y)
                    y = y - STEP
                end
            end
            lowest = math.min(lowest, y)
        end
        local y = lowest - 8
        clipRow:ClearAllPoints()
        clipRow:SetPoint("TOPLEFT", 16, y)
        y = y - STEP
        pingRow:SetShown(admin)
        if admin then
            pingRow:ClearAllPoints()
            pingRow:SetPoint("TOPLEFT", 16, y)
            y = y - STEP
        end
        out:ClearAllPoints()
        out:SetPoint("TOPLEFT", 16, y - 8)
        out:SetPoint("BOTTOMRIGHT", -16, 4)
    end
end

local BUILDERS = { summary = buildSummary, log = buildLog, answer = buildAnswer, tally = buildTally, badges = buildBadges, story = buildStory,
    sync = buildSync, tools = buildTools }

----------------------------------------------------------------------
-- The season band and the status line, shown on every tab
----------------------------------------------------------------------
local function buildChrome()
    local band = CreateFrame("Frame", nil, window)
    band:SetPoint("TOPLEFT", 12, -64)
    band:SetPoint("TOPRIGHT", -12, -64)
    band:SetHeight(26)
    T.Panel(band)
    local head = T.Text(band, 18, "dim")
    head:SetPoint("LEFT", 8, 0)
    head:SetText("SEASON.DAT")

    -- one side of the race: its name, a block per weekly win needed, and the count
    local function meter(anchor, name, color)
        local fs = T.Text(band, 18, color)
        fs:SetPoint("LEFT", anchor, "RIGHT", 18, 0)
        fs:SetText(name)
        local m = { blocks = {}, color = color }
        local prev = fs
        for i = 1, ST.Week.WINS do
            local b = T.Fill(band, color, 1)
            b:SetSize(14, 10)
            b:SetPoint("LEFT", prev, "RIGHT", i == 1 and 8 or 3, 0)
            m.blocks[i], prev = b, b
        end
        m.count = T.Text(band, 18, color)
        m.count:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        return m
    end
    chrome.zennit = meter(head, "ZENNIT", "pink")
    chrome.group = meter(chrome.zennit.count, "GROUP", "cyan")
    chrome.week = T.Text(band, 18, "green")
    chrome.week:SetPoint("RIGHT", -8, 0)

    -- the bottom line: a command prompt with a blinking cursor, and the log and sync counts
    local prompt = T.Text(window, 18, "dim")
    prompt:SetPoint("BOTTOMLEFT", 14, 10)
    prompt:SetText("C:\\INDEX>")
    T.Cursor(window):SetPoint("LEFT", prompt, "RIGHT", 6, 0)
    chrome.status = T.Text(window, 18, "dim")
    chrome.status:SetPoint("BOTTOMRIGHT", -14, 10)
    chrome.status:SetJustifyH("RIGHT")
end

local function refreshChrome()
    local W = ST.Week
    local season = W.Season()
    for _, side in ipairs({ "zennit", "group" }) do
        local m, wins = chrome[side], season[side]
        for i, b in ipairs(m.blocks) do b:SetAlpha(i <= wins and 1 or 0.2) end
        m.count:SetText(string.format("%d/%d", wins, W.WINS))
    end
    local immune, untilT = W.Immune(time())
    if immune then
        chrome.week:SetText(T.Paint("amber", "ZENNIT IS ON HIS WEEK OFF UNTIL " .. date("%a %d %b", untilT):upper()))
    else
        local week = W.Score(W.Start())
        chrome.week:SetText(string.format("THIS WEEK  %s / %s", T.Paint("cyan", "GROUP " .. week.group),
            T.Paint("pink", "ZENNIT " .. week.zennit)))
    end
    local channels = ST.Sync.channels()
    chrome.status:SetText(string.format("%d RECORDS · %d QUEUED · LINK: %s", ST.Store.Count(), #ST.Sync.state.queue,
        #channels > 0 and table.concat(channels, ", "):upper() or "NONE"))
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local function selectTab(name)
    if GATED[name] and ST.Gag.Blocked() then return false end
    current = name
    for key, tab in pairs(tabs) do
        local on = key == name
        tab.frame:SetShown(on)
        tab.button:SetSelected(on)
    end
    tabs[name].refresh()
    refreshChrome()
    return true
end

local function build()
    window = T.Window("SummonCoreHub", 800, 590)
    window.TitleText:SetText("SUMMON_CORE.EXE  ·  v" .. ST.version)
    buildChrome()

    for i, name in ipairs(ORDER) do
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", 12, -98)
        content:SetPoint("BOTTOMRIGHT", -12, 34)
        content:Hide()
        local tabButton = T.Button(window, i .. " " .. LABELS[name], 90, 24, function()
            if current ~= name then T.Beep() end
            selectTab(name)
        end, "tab")
        tabButton:SetPoint("TOPLEFT", 12 + (i - 1) * 96, -34)
        tabs[name] = { button = tabButton, frame = content, refresh = BUILDERS[name](content) }
    end
    window:SetScript("OnShow", function()
        if current then
            tabs[current].refresh()
            refreshChrome()
        end
    end)
end

-- Refreshes the open tab (call after anything that changes the log).
function Hub.Refresh()
    if window and window:IsShown() and current and tabs[current] then
        tabs[current].refresh()
        refreshChrome()
    end
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
    local ok, err = pcall(refreshChrome)
    if not ok then return false, "season band: " .. tostring(err) end
    return true
end
