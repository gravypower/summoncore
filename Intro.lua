-- Intro: /st intro plays "Zenit and the Index", an illustrated intro. Each scene is a 3-frame flipbook
-- (Media\intro_<n>, a 2048x1024 sheet of 1024x512 cells) flipped about six times a second, with the
-- narration shown as a caption. Rebuild the sheets with tools\intro\render_intro.ps1.
local ADDON, ST = ...
local Intro = {}
ST.Intro = Intro

local PATH = "Interface\\AddOns\\summoncore\\Media\\intro_"
local FPS = 6
local FRAMES = 3
local AUDIO = "Interface\\AddOns\\summoncore\\Media\\intro_"

-- Each scene lasts as long as its narration clip (measured) plus a short pause, so a clip is never cut off.
local PAUSE = 0.6
local scenes = {
    { label = "The Index", dur = 20.80 + PAUSE, text = [=[The Cosmic Index of Summonable Persons is, by general agreement, the most important document in Azeroth that nobody has ever read. It lists every being that may legally be summoned, in alphabetical order, and it was compiled by a single clerk who had, at the time, been on shift for nine thousand years.]=] },
    { label = "The sneeze", dur = 9.10 + PAUSE, text = [=[Somewhere around the letter Zed, the clerk sneezed. This is generally accepted to be the origin of the entire problem.]=] },
    { label = "The wrong ritual", dur = 25.10 + PAUSE, text = [=[As a result of the sneeze, a Licensed Summoning Liaison, Third Class, named Zenit was entered into the Index as the default recipient of every Ritual of Summoning completed within range of his name. This includes rituals meant for other people. It includes rituals meant for nobody. It includes at least one ritual intended for a goat.]=] },
    { label = "The missing form", dur = 23.00 + PAUSE, text = [=[Zenit did what any reasonable person would do. He looked for the form. The form turned out to be Form 27B slash 6, which is referenced throughout the Index and has never been seen. Several scholars believe it does not exist. Zenit believes that is exactly what a form would say.]=] },
    { label = "The attachment", dur = 20.40 + PAUSE, text = [=[Meanwhile, the Ritual of Summoning, a spell with a great deal of free time and a fragile sense of self, had formed an attachment. It does not want gold. It wants, in its own words, attention and closure. It will, however, accept fifty silver as a gesture.]=] },
    { label = "The debt", dur = 12.20 + PAUSE, text = [=[And so every completed summon is recorded as an installment on a debt Zenit never agreed to, cannot find the paperwork for, and is nevertheless making definite progress on.]=] },
    { label = "The party", dur = 13.10 + PAUSE, text = [=[You, meanwhile, are a party of friends who have noticed that Zenit is, technically, very easy to summon. The Index has no objection. The Index has never been asked.]=] },
    { label = "The week", dur = 13.30 + PAUSE, text = [=[This is the story of his week, and the week after that. If the form is ever found, you will be the first to know. Or the last. The Index is unclear.]=] },
}

local starts, total = {}, 0
for i, s in ipairs(scenes) do
    starts[i] = total
    total = total + s.dur
end

local frame, picture, caption, status, playBtn
local t, playing, shownScene, shownFrame = 0, false, 0, -1

local function fmt(sec)
    return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

local function sceneAt(sec)
    for i = #scenes, 1, -1 do
        if sec >= starts[i] then return i end
    end
    return 1
end

-- Narration: one clip per scene (PlaySoundFile cannot start mid-file), so pausing replays the scene.
local clipHandle, clipScene, clipToken, audioMissing

local function stopClip()
    clipToken = (clipToken or 0) + 1
    clipScene = nil
    if clipHandle then
        pcall(StopSound, clipHandle)
        clipHandle = nil
    end
end

-- natural: the scene advanced by itself, so let the previous clip finish instead of cutting it.
local function playClip(si, natural)
    if ST.db.settings.introMute or clipScene == si then return end
    if natural then
        clipToken = (clipToken or 0) + 1
        clipHandle = nil
    else
        stopClip()
    end
    clipScene = si
    local token = clipToken
    local function start()
        if token ~= clipToken then return end
        local ok, willPlay, handle = pcall(PlaySoundFile, AUDIO .. si .. ".ogg", "Dialog")
        audioMissing = not (ok and willPlay)
        clipHandle = handle
    end
    start()
end

local function show(sec)
    local si = sceneAt(sec)
    local fi = math.floor(sec * FPS) % FRAMES
    if si ~= shownScene then
        shownScene = si
        picture:SetTexture(PATH .. si)
        caption:SetText(scenes[si].text)
        shownFrame = -1
        if playing then playClip(si, true) end
    end
    if fi ~= shownFrame then
        shownFrame = fi
        local l, tp = (fi % 2) * 0.5, math.floor(fi / 2) * 0.5
        picture:SetTexCoord(l, l + 0.5, tp, tp + 0.5)
    end
    status:SetText(string.format("Scene %d/%d: %s     %s / %s%s", si, #scenes, scenes[si].label, fmt(sec),
        fmt(total), audioMissing and "     (narration files missing)" or ""))
end

local function setPlaying(p)
    playing = p
    if p then
        -- Audio cannot resume mid-clip, so resuming replays the current scene from its start.
        t = starts[sceneAt(t)]
        playClip(sceneAt(t))
    else
        stopClip()
    end
    playBtn:SetText(p and "Pause" or (t >= total and "Replay" or "Play"))
end

local function seek(sec)
    t = math.max(0, math.min(total - 0.01, sec))
    stopClip()
    shownScene = 0
    show(t)
end

local function button(parent, text, width, x, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    b:SetPoint("BOTTOMLEFT", x, 10)
    b:SetScript("OnClick", onClick)
    return b
end

local function build()
    local h = math.min(UIParent:GetHeight() * 0.6, 540)
    local w = h * 16 / 9
    frame = CreateFrame("Frame", "SummonCoreIntro", UIParent)
    frame:SetSize(w + 24, h + 24 + 130 + 44)
    frame:SetPoint("CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SummonCoreIntro")

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.07, 0.06, 0.1, 0.96)

    picture = frame:CreateTexture(nil, "ARTWORK")
    picture:SetSize(w, h)
    picture:SetPoint("TOP", 0, -12)

    caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    caption:SetPoint("TOPLEFT", picture, "BOTTOMLEFT", 4, -10)
    caption:SetWidth(w - 8)
    caption:SetHeight(120)
    caption:SetJustifyH("LEFT")
    caption:SetJustifyV("TOP")

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("BOTTOMRIGHT", -14, 16)

    button(frame, "<", 30, 12, function() seek(starts[math.max(1, sceneAt(t) - 1)]) end)
    playBtn = button(frame, "Play", 70, 46, function()
        if t >= total - 0.05 then seek(0) end
        setPlaying(not playing)
    end)
    button(frame, ">", 30, 120, function()
        local nxt = sceneAt(t) + 1
        if nxt <= #scenes then seek(starts[nxt]) end
    end)
    button(frame, "Restart", 70, 154, function() seek(0) setPlaying(true) end)
    button(frame, "Close", 70, 228, function() frame:Hide() end)
    local soundBtn
    soundBtn = button(frame, "", 90, 302, function()
        ST.db.settings.introMute = not ST.db.settings.introMute
        if ST.db.settings.introMute then stopClip() elseif playing then playClip(sceneAt(t)) end
        soundBtn:SetText(ST.db.settings.introMute and "Sound: off" or "Sound: on")
    end)
    soundBtn:SetText(ST.db.settings.introMute and "Sound: off" or "Sound: on")

    frame:SetScript("OnUpdate", function(_, elapsed)
        if not playing then return end
        t = t + elapsed
        if t >= total then
            t = total - 0.01
            setPlaying(false)
        end
        show(t)
    end)
    frame:SetScript("OnHide", function() setPlaying(false) end)
end

function Intro.Toggle(arg)
    if not frame then build() end
    if frame:IsShown() then frame:Hide() return end
    frame:Show()
    local si = tonumber(arg)
    seek(si and starts[math.max(1, math.min(#scenes, si))] or 0)
    setPlaying(true)
end

-- Mention the intro once, the first time the addon loads.
local hint = CreateFrame("Frame")
hint:RegisterEvent("PLAYER_LOGIN")
hint:SetScript("OnEvent", function()
    if ST.db and not ST.db.settings.introSeen then
        ST.db.settings.introSeen = true
        ST.print("New here? Type |cffffd100/st intro|r for the story so far.")
    end
end)
