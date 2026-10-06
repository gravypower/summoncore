-- Tour: /sc tour, a guided tour of the Summon Core window, narrated by the Index. It opens the real window, moves through
-- its tabs, and outlines each part as the narrator talks about it, with the words typed out in a box under the window.
-- One recording per line (Media\tour\<id>.ogg, lengths in TourClips.lua); a step lasts as long as its recording, so it
-- runs by itself, and Back, Pause and Next take over at any point. Zennit's client gets his own lines for the two tabs
-- that are closed to one side or the other.
-- Rebuild the recordings with tools/intro/build_tour_audio.py after changing LINES (.claude/skills/zenit-narrator-audio).
local ADDON, ST = ...
local Tour = {}
ST.Tour = Tour
local T = ST.Theme

local MEDIA = "Interface\\AddOns\\summoncore\\Media\\tour\\"
local GAP = 0.8      -- a breath between one line and the next
local CPS = 18       -- typing speed when a line has no recording (characters a second)

-- What the Index says, one id = "sentence" per line. The voice is given the same words, with /sc spelled "slash S C".
-- build_tour_audio.py reads this table, so keep each entry on one line in this form.
local LINES = {
    hello = "This is a short tour of Summon Core, conducted by the Index, which has been asked to be helpful and is doing its best. Close it whenever you like. The Index will not take it personally.",
    nothing_new = "First, the good news. You do not have to do anything new. Cast the ritual and click the portal as you always have, and the Index notices on its own.",
    caster = "One thing to remember. Whoever casts the ritual needs Summon Core, or the summons is not filed. The helpers are credited either way.",
    z_nothing_new = "First, the good news. You do not have to do anything new. Answer the game's summons prompt as you always have, and the Index takes that as your answer.",
    window = "This is the window. Type /sc and it opens. Everything the Index knows about you is in here, which is either reassuring or not.",
    season = "Along the top runs the season. Zennit in pink, the group in cyan. Each block is a week won, and the first side to five takes the season.",
    week = "On the right is this week: who leads, and by how much, how many summons are filed, and how many dice Zennit has left.",
    party = "The Party tab is yours. It has a summary of you, the tally of who has cast and who has helped, and the badges you have earned.",
    tally = "The tally ranks everyone by summons of Zennit this season, which is the only thing the race counts.",
    zennit = "The Zennit tab belongs to Zennit. Please do not open it. The Index has arranged a small deterrent.",
    z_party = "The Party tab belongs to the group, and is closed to you. The Index apologises in advance for what happens if you try.",
    z_zennit = "This tab is yours. Here you answer the summons waiting for you, keep your secret list of five places, and may close the Index once five summons are filed.",
    log = "The Log is every summons filed: who cast it, who helped, where it landed, and what Zennit said.",
    story = "The Story is a tree of chapters. Each weekly win unlocks the next chapter on that side. Click a lit chapter to watch it.",
    sync = "Sync keeps everyone's Index the same, through your party and your guild. It works on its own. You need do nothing.",
    tools = "Tools holds the rest: the rules with this week's numbers, the titles, the silver owed, and the record of past seasons.",
    writ = "If you expect Zennit to refuse, play a writ before you cast, with /sc writ. You have two a week. If he declines, it costs him the points.",
    status = "Along the bottom, the Index reports how many records it holds, and who it is talking to.",
    commands = "Three commands are worth remembering. /sc rules, for the race in a minute. /sc intro, for the story. And /sc help, for everything else.",
    goodbye = "That concludes the tour. The Index thanks you for your attention, which it has noted. Go and summon someone. Preferably Zennit.",
}
Tour.LINES = LINES

-- The tour, in order. tab: the window's tab to show (a Party section opens the Party tab on it); spot: what to outline
-- (Hub.Spot); only: "party" or "zennit", for the steps one side gets instead of the other.
local STEPS = {
    { line = "hello", spot = "window" },
    { line = "nothing_new", only = "party" },
    { line = "z_nothing_new", only = "zennit" },
    { line = "caster", only = "party" },
    { line = "window", spot = "window" },
    { line = "season", spot = "season" },
    { line = "week", spot = "week" },
    { line = "party", tab = "summary", spot = "tab:party", only = "party" },
    { line = "tally", tab = "tally", spot = "section:tally", only = "party" },
    { line = "zennit", spot = "tab:zennit", only = "party" },
    { line = "z_party", spot = "tab:party", only = "zennit" },
    { line = "z_zennit", tab = "zennit", spot = "tab:zennit", only = "zennit" },
    { line = "log", tab = "log", spot = "tab:log" },
    { line = "story", tab = "story", spot = "tab:story" },
    { line = "sync", tab = "sync", spot = "tab:sync" },
    { line = "tools", tab = "tools", spot = "tab:tools" },
    { line = "writ", only = "party" },
    { line = "status", spot = "status" },
    { line = "commands" },
    { line = "goodbye", spot = "window" },
}

-- The steps this client gets: Zennit's lines on his client, the party's on everyone else's.
function Tour.Steps(zennit)
    local list = {}
    for _, s in ipairs(STEPS) do
        if not s.only or (s.only == "zennit") == (zennit and true or false) then list[#list + 1] = s end
    end
    return list
end

-- How long a step lasts: its recording and a breath, or, with no recording, long enough to read it.
function Tour.Length(id)
    local len = ST.tourClips and ST.tourClips[id]
    if len then return len + GAP end
    return #LINES[id] / CPS + 1.5
end

local panel, text, counter, playBtn, glow
local steps, at, t, playing = {}, 1, 0, false
local handle, missing

local function stopVoice()
    if handle then
        pcall(StopSound, handle)
        handle = nil
    end
end

local function muted() return ST.db.settings.introSound == false end

local function outline(region)
    if not region then return glow:Hide() end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", region, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 4, -4)
    glow:Show()
end

-- Shows step i: its tab, its outline, its line typed from the start, and its recording.
local function go(i)
    at = math.max(1, math.min(#steps, i))
    t = 0
    local s = steps[at]
    for k = at, 1, -1 do -- the tab this step is on: its own, or the last one opened before it (so Back puts it right)
        if steps[k].tab then
            ST.Hub.Open(steps[k].tab)
            break
        end
    end
    outline(s.spot and ST.Hub.Spot(s.spot))
    counter:SetText(string.format("TOUR.EXE  %d/%d", at, #steps))
    stopVoice()
    if playing and not muted() then
        local ok, willPlay, h = pcall(PlaySoundFile, MEDIA .. s.line .. ".ogg", "Dialog")
        missing = not (ok and willPlay)
        handle = h
    end
end

local function setPlaying(p)
    playing = p
    playBtn:SetText(p and "PAUSE" or "PLAY")
    if p then go(at) else stopVoice() end -- a recording cannot resume mid-way: playing again starts the line over
end

local function build()
    panel = CreateFrame("Frame", "SummonCoreTour", UIParent)
    panel:Hide()
    panel:SetSize(800, 132)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    T.Panel(panel, { fill = "ground", color = "amber", width = 2, glow = true })
    tinsert(UISpecialFrames, "SummonCoreTour")

    counter = T.Text(panel, 18, "amber")
    counter:SetPoint("TOPLEFT", 12, -8)
    local cursor = T.Cursor(panel)
    cursor:SetPoint("LEFT", counter, "RIGHT", 6, 0)
    text = T.Text(panel, 20, "green")
    text:SetPoint("TOPLEFT", 12, -30)
    text:SetPoint("TOPRIGHT", -12, -30)
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)

    local x = 12
    local function btn(label, width, onClick, style)
        local b = T.Button(panel, label, width, 24, onClick, style)
        b:SetPoint("BOTTOMLEFT", x, 10)
        x = x + width + 6
        return b
    end
    btn("< BACK", 90, function() go(at - 1) end)
    playBtn = btn("PAUSE", 90, function() setPlaying(not playing) end, "primary")
    btn("NEXT >", 90, function()
        if at < #steps then go(at + 1) else panel:Hide() end
    end)
    local sound
    sound = btn("", 120, function()
        ST.db.settings.introSound = muted()
        ST.db.settings.introMute = muted() -- the story viewer's copy of the same switch
        sound:SetText("SOUND: " .. (muted() and "OFF" or "ON"))
        if muted() then stopVoice() elseif playing then go(at) end
    end)
    sound:SetText("SOUND: " .. (muted() and "OFF" or "ON"))
    local close = T.Button(panel, "END TOUR", 110, 24, function() panel:Hide() end, "danger")
    close:SetPoint("BOTTOMRIGHT", -12, 10)

    -- the outline: amber, over the window, pulsing gently
    glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata("DIALOG")
    glow:EnableMouse(false)
    T.Border(glow, "amber", 1, 3)
    T.Border(glow, "amber", 0.3, 3, 3)
    glow:Hide()
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.6)
    glow:SetScript("OnShow", function() pulse:Play() end)

    panel:SetScript("OnUpdate", ST.Safe("the tour", function(_, elapsed)
        local window = ST.Hub.Window()
        if not (window and window:IsShown()) then return panel:Hide() end -- closing the window ends the tour
        local s = steps[at]
        if playing then
            t = t + elapsed
            if t >= Tour.Length(s.line) then
                if at < #steps then return go(at + 1) end
                setPlaying(false)
            end
        end
        -- typed slightly faster than it is said, so the words are all there before the voice finishes
        local line = LINES[s.line]
        local cps = math.max(CPS, #line / (math.max(1, Tour.Length(s.line) - GAP) * 0.8))
        local typed = playing and line:sub(1, math.floor(t * cps) + 1) or line
        text:SetText(typed .. (missing and not muted() and T.Paint("dim", "   (recording missing: restart WoW fully)") or ""))
    end))
    panel:SetScript("OnHide", function()
        playing = false
        stopVoice()
        glow:Hide()
    end)
end

-- /sc tour: opens the window and starts the tour from the top (again: stops it). /sc tour <n> starts at step n.
function Tour.Start(arg)
    if not panel then build() end
    if panel:IsShown() and not tonumber(arg or "") then return panel:Hide() end
    steps = Tour.Steps(ST.Gag.IsZennit())
    ST.Hub.Open()
    local window = ST.Hub.Window()
    panel:ClearAllPoints()
    panel:SetPoint("TOP", window, "BOTTOM", 0, -6)
    panel:SetWidth(window:GetWidth())
    panel:Show()
    missing = false
    at = tonumber(arg or "") or 1
    setPlaying(true)
end

function Tour.IsShown() return panel and panel:IsShown() or false end
