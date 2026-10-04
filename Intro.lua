-- Intro: /st intro plays "Zennit and the Index", an illustrated intro. Each scene is a 3-frame flipbook
-- (Media\intro_<n>, a 2048x1024 sheet of 1024x512 cells) flipped about six times a second, narrated, with a
-- quiet synth music bed. Key phrases are typed out over the picture, in sync with the narration, with
-- beeps and clicks (the full text is available behind the Text button). Rebuild the art with
-- tools\intro\render_intro.ps1 and the audio and cue timings with tools\intro\build_audio.ps1.
local ADDON, ST = ...
local Intro = {}
ST.Intro = Intro

local MEDIA = "Interface\\AddOns\\summoncore\\Media\\"
local SFX = MEDIA .. "sfx\\"
local FPS = 6
local FRAMES = 3
local CPS, HOLD = 26, 2.6 -- key phrase typing speed (characters a second) and how long each stays up
local HIGHLIGHT_HOLD = 3.2 -- how long a highlight box stays on something that was mentioned

-- Two renderings of the same scenes: neon line drawing (default) and the original storybook colours.
local LOOKS = { lines = "intro_l", storybook = "intro_" }
local LOOK_ORDER = { "lines", "storybook" }

local function look()
    local chosen = ST.db.settings.introLook
    if not LOOKS[chosen] then chosen = "lines" end -- the default; also covers a look that no longer exists
    return chosen
end

local function artPath(si)
    return MEDIA .. LOOKS[look()] .. si
end

-- With the music bed the clip is intro_<n>; without it, intro_<n>_voice.
local function audioPath(si)
    return MEDIA .. "intro_" .. si .. (ST.db.settings.introMusic == false and "_voice" or "") .. ".ogg"
end

-- Each scene lasts as long as its narration clip (measured) plus a short pause, so a clip is never cut off.
local PAUSE = 0.6
local scenes = {
    { label = "The Index", dur = 22.10 + PAUSE, text = [=[The Cosmic Index of Summonable Persons is, by general agreement, the most important document in Azeroth that nobody has ever read. It lists every being that may legally be summoned, in alphabetical order, and it was compiled by a single clerk who had, at the time, been on shift for nine thousand years.]=] },
    { label = "The sneeze", dur = 9.80 + PAUSE, text = [=[Somewhere around the letter Z, the clerk sneezed. This is generally accepted to be the origin of the entire problem.]=] },
    { label = "The wrong ritual", dur = 26.40 + PAUSE, text = [=[As a result of the sneeze, a Licensed Summoning Liaison, Third Class, named Zennit was entered into the Index as the default recipient of every Ritual of Summoning completed within range of his name. This includes rituals meant for other people. It includes rituals meant for nobody. It includes at least one ritual intended for a goat.]=] },
    { label = "The missing form", dur = 24.70 + PAUSE, text = [=[Zennit did what any reasonable person would do. He looked for the form. The form turned out to be Form 27B slash 6, which is referenced throughout the Index and has never been seen. Several scholars believe it does not exist. Zennit believes that is exactly what a form would say.]=] },
    { label = "The attachment", dur = 21.90 + PAUSE, text = [=[Meanwhile, the Ritual of Summoning, a spell with a great deal of free time and a fragile sense of self, had formed an attachment. It does not want gold. It wants, in its own words, attention and closure. It will, however, accept fifty silver as a gesture.]=] },
    { label = "The debt", dur = 12.50 + PAUSE, text = [=[And so every completed summon is recorded as an installment on a debt Zennit never agreed to, cannot find the paperwork for, and is nevertheless making definite progress on.]=] },
    { label = "The party", dur = 14.00 + PAUSE, text = [=[You, meanwhile, are a party of friends who have noticed that Zennit is, technically, very easy to summon. The Index has no objection. The Index has never been asked.]=] },
    { label = "The week", dur = 14.30 + PAUSE, text = [=[This is the story of his week, and the week after that. If the form is ever found, you will be the first to know. Or the last. The Index is unclear.]=] },
    { label = "The rules", dur = 26.70 + PAUSE, text = [=[The rules, such as they are. Each week, the group earns points by summoning Zennit, with more points for places that are remote, or dangerous, or frankly unreasonable. Zennit, for his part, holds a secret list, which he may complete at any time, and which he will not discuss. If the group has more points at the end of the week, the Index records a victory for persistence.]=] },
    { label = "The options", dur = 25.40 + PAUSE, text = [=[If Zennit completes his list first, he wins the week, and cannot be summoned for the seven days that follow. He may refuse a summons. He may demand fifty silver, in cash, with no receipt. Or he may suggest dice. The Index will accept any of these. The Index accepts most things.]=] },
    -- chapter 2, the week Zennit wins: played on its own with /st intro victory (or /st intro 11)
    { chapter = 2, label = "The count", dur = 24.00 + PAUSE, text = [=[At the end of the week, the Index counted. It counted the summons, and the places, and the refusals, and the dice, and then it counted them again, because the total was not the one it had expected. Zennit had won. He had won the dice when it mattered, and he had been summoned, entirely by accident, to several of the places on his list.]=] },
    { chapter = 2, label = "Leave", dur = 28.00 + PAUSE, text = [=[The Index informed Zennit by registered letter, which he did not trust, and which he read twice. For seven days, no ritual could find him. The party gathered in a circle and said his name, and the Index replied that the Licensed Summoning Liaison was, regrettably, on leave. Zennit spent the week doing nothing at all, which he had always suspected to be the correct amount.]=] },
    -- chapter 3, the week the group wins: /st intro group (or /st intro 13)
    { chapter = 3, label = "The group wins", dur = 27.00 + PAUSE, text = [=[The following week, the group won. Nobody was more surprised than the group. The Index counted the summons, and the places, and the refusals, and found that the party had finished ahead of Zennit, despite his head start, and despite a run of dice that had, until then, been entirely reliable. The Index checked the sum three times. It was not wrong.]=] },
    { chapter = 3, label = "The cake", dur = 26.00 + PAUSE, text = [=[A victory for persistence, as the rules had promised. The party celebrated in the traditional manner, by summoning Zennit to the celebration. He arrived, as he always did, slightly confused, and was handed a small cake, which he did not trust. The Index recorded the week as a narrow win for hope over paperwork, and began, quietly, to count the next one.]=] },
}

-- A chapter is a run of scenes that plays on its own and ends with the fade to "THE END".
local firstOf, lastOf = {}, {}
for i, s in ipairs(scenes) do
    s.chapter = s.chapter or 1
    firstOf[s.chapter] = firstOf[s.chapter] or i
    lastOf[s.chapter] = i
end

-- Scene lengths come from IntroCues.lua (measured from the narration); the table above is the fallback.
local ENDING = ST.introEnding or 3.2 -- after the last line: the music fades out, the picture fades to black, "THE END"
local starts, total = {}, 0
for i, s in ipairs(scenes) do
    if ST.introLength and ST.introLength[i] then s.dur = ST.introLength[i] + PAUSE end
    if i == lastOf[s.chapter] then s.dur = s.dur + ENDING end
    starts[i] = total
    total = total + s.dur
end
local lo, hi = 1, lastOf[1] -- the scenes of the chapter being played

-- The story after the intro is a race: z<n> is the chapter for Zennit's nth win of the season, g<n> for the group's.
-- The fifth win of either side is that side's finale. victory and group are the first win of each.
local CHAPTER_KEYS = { victory = 2, group = 3, z1 = 2, g1 = 3, z2 = 4, g2 = 5, z3 = 6, g3 = 7, z4 = 8, g4 = 9, z5 = 10, g5 = 11 }
function Intro.HasChapter(key) return firstOf[CHAPTER_KEYS[key] or 0] ~= nil end

local function endTime() return starts[hi] + scenes[hi].dur end

local frame, picture, status, playBtn, tape, tapeText, terminal, terminalText, glow, endText
local pictureH, pictureW, buttonsWidth = 300, 533, 700
local t, playing, shownScene, shownFrame, lastCue = 0, false, 0, -1, nil

local function fmt(sec)
    return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

local function sceneAt(sec)
    for i = #scenes, 1, -1 do
        if sec >= starts[i] then return i end
    end
    return 1
end

-- Index of the key phrase showing `rel` seconds into a scene, and how long it has been up; nil if none.
-- A phrase stays up for HOLD seconds or until the next one starts.
function Intro.CueAt(cues, rel)
    if not cues then return nil end
    local index
    for i, c in ipairs(cues) do
        if c.t <= rel then index = i else break end
    end
    if not index then return nil end
    local elapsed = rel - cues[index].t
    if elapsed > HOLD then return nil end
    return index, elapsed
end

-- The sentence being spoken `rel` seconds into a scene: the last one that has started. Returns its text, its
-- index and how long it has been going; nil before the first. `length` is the scene's narration length.
function Intro.SentenceAt(sentences, rel, length)
    local index
    for i, s in ipairs(sentences or {}) do
        if s.t <= rel then index = i else break end
    end
    if not index then return nil end
    local s, nextStart = sentences[index], sentences[index + 1] and sentences[index + 1].t or length
    return s.text, index, rel - s.t, nextStart and (nextStart - s.t) or nil
end

-- The highlight box showing `rel` seconds into a scene, and how long it has been up; nil if none. Each entry is
-- { t, x, y, w, h } with the box in the 960x540 picture, and it stays for HIGHLIGHT_HOLD seconds or until the next.
function Intro.HighlightAt(list, rel)
    if not list then return nil end
    local index
    for i, h in ipairs(list) do
        if h.t <= rel then index = i else break end
    end
    if not index then return nil end
    local elapsed = rel - list[index].t
    if elapsed > HIGHLIGHT_HOLD then return nil end
    return index, elapsed
end

-- How much of a phrase has been typed after `elapsed` seconds (at least one character), at `cps` characters
-- a second (default: the key-phrase speed).
function Intro.Typed(text, elapsed, cps)
    return text:sub(1, math.min(#text, math.floor(elapsed * (cps or CPS)) + 1))
end

-- Typing speed for narrating a sentence of `chars` characters that is spoken over `span` seconds: slightly
-- faster than the voice, so the text is complete just before the next sentence starts.
function Intro.SentenceSpeed(chars, span)
    if not span or span <= 0.5 then return CPS end
    return math.max(8, chars / (span * 0.8))
end

-- Narration: one clip per scene (PlaySoundFile cannot start mid-file), so pausing replays the scene.
local clipHandle, clipScene, clipToken, audioMissing

-- Key clicks run for as long as the text is typing. PlaySoundFile cannot loop or be cut short, so a long clip is
-- started with the sentence and stopped when the typing is done (or the scene is stopped).
local keysHandle
local function stopKeys()
    if keysHandle then
        pcall(StopSound, keysHandle)
        keysHandle = nil
    end
end

local function stopClip()
    stopKeys()
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
    local ok, willPlay, handle = pcall(PlaySoundFile, audioPath(si), "Dialog")
    audioMissing = not (ok and willPlay)
    clipHandle = handle
end

-- A chirp as a key phrase appears, followed a moment later by a burst of key clicks as it types out.
local function cueSound(cueIndex)
    if ST.db.settings.introMute then return end
    stopKeys()
    pcall(PlaySoundFile, SFX .. "sfx_chirp_" .. math.random(3) .. ".ogg", "SFX")
    C_Timer.After(0.1, function()
        if playing and lastCue == cueIndex then
            local ok, willPlay, handle = pcall(PlaySoundFile, SFX .. "sfx_keys_long.ogg", "SFX")
            if ok and willPlay then keysHandle = handle end
        end
    end)
end

local function show(sec)
    local si = sceneAt(sec)
    local fi = math.floor(sec * FPS) % FRAMES
    if si ~= shownScene then
        shownScene = si
        picture:SetTexture(artPath(si))
        shownFrame = -1
        lastCue = nil
        if playing then
            playClip(si, true)
            if si > lo and not ST.db.settings.introMute then pcall(PlaySoundFile, SFX .. "sfx_pop.ogg", "SFX") end
        end
    end
    if fi ~= shownFrame then
        shownFrame = fi
        local l, tp = (fi % 2) * 0.5, math.floor(fi / 2) * 0.5
        picture:SetTexCoord(l, l + 0.5, tp, tp + 0.5)
    end

    local rel = sec - starts[si]
    -- the ending: after the last line the picture and text fade to black and "THE END" fades in
    local fade = 1
    if si == hi then
        local left = starts[si] + scenes[si].dur - sec
        if left < ENDING then fade = math.max(0, left / (ENDING * 0.75)) end
    end
    picture:SetAlpha(fade)
    terminal:SetAlpha(fade)
    tape:SetAlpha(fade)
    endText:SetAlpha(1 - fade)

    -- highlight: a pulsing box round whatever the narrator is talking about
    local boxes = ST.introHighlights and ST.introHighlights[si]
    local boxIndex, boxElapsed = Intro.HighlightAt(boxes, rel)
    if boxIndex then
        local r = boxes[boxIndex]
        local sx, sy = pictureW / 960, pictureH / 540
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", picture, "TOPLEFT", r.x * sx, -r.y * sy)
        glow:SetSize(r.w * sx, r.h * sy)
        glow:SetAlpha(math.min(1, boxElapsed / 0.15) * (0.7 + 0.3 * math.sin(boxElapsed * 8)) * fade)
        glow:Show()
    else
        glow:Hide()
    end

    local mode = ST.db.settings.introTextMode or "full"
    local cursor = (sec * 4) % 1 < 0.5 and "_" or " "

    if mode == "full" then
        -- the whole narration, a sentence at a time, typed out in the terminal box under the picture
        tape:Hide()
        local sentences = ST.introSentences and ST.introSentences[si] or { { t = 0, text = scenes[si].text } }
        local text, index, elapsed, span = Intro.SentenceAt(sentences, rel, ST.introLength and ST.introLength[si])
        if text then
            if index ~= lastCue then
                lastCue = index
                if playing then cueSound(index) end
            end
            local cps = Intro.SentenceSpeed(#text, span)
            terminalText:SetText(Intro.Typed(text, elapsed, cps) .. cursor)
            if elapsed * cps >= #text then stopKeys() end -- finished typing: the clicks stop with it
        else
            terminalText:SetText("")
            stopKeys()
        end
    elseif mode == "key" then
        -- just the punchlines, flashed over the picture
        local cues = ST.introCues and ST.introCues[si]
        local index, elapsed = Intro.CueAt(cues, rel)
        if index then
            tape:Show()
            if index ~= lastCue then
                lastCue = index
                -- size the strip for the whole phrase first, so it does not jump while it types
                tapeText:SetText(cues[index].text)
                tape:SetHeight(math.max(pictureH * 0.075, tapeText:GetStringHeight() + 14))
                if playing then cueSound(index) end
            end
            tapeText:SetText(Intro.Typed(cues[index].text, elapsed) .. cursor)
            if elapsed * CPS >= #cues[index].text then stopKeys() end
        else
            tape:Hide()
            stopKeys()
        end
    else
        tape:Hide()
        stopKeys()
    end

    status:SetText(string.format("Scene %d/%d: %s     %s / %s%s", si - lo + 1, hi - lo + 1, scenes[si].label,
        fmt(sec - starts[lo]), fmt(endTime() - starts[lo]), audioMissing and "     (narration files missing)" or ""))
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
    playBtn:SetText(p and "Pause" or (t >= endTime() - 0.05 and "Replay" or "Play"))
end

local function seek(sec)
    t = math.max(starts[lo], math.min(endTime() - 0.01, sec))
    stopClip()
    shownScene = 0
    show(t)
end

-- Button helper: lays buttons out left to right along the bottom.
local nextX = 12
local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    b:SetPoint("BOTTOMLEFT", nextX, 10)
    b:SetScript("OnClick", onClick)
    nextX = nextX + width + 6
    return b
end

local SIZES = { small = 0.36, medium = 0.46, large = 0.6 } -- picture height as a fraction of the screen height
local SIZE_ORDER = { "small", "medium", "large" }
local FONT = "Fonts\\FRIZQT__.TTF"

-- Sizes everything from the Size and Text settings. Runs once built, then again when either changes.
local function layout()
    local settings = ST.db.settings
    local h = math.min(UIParent:GetHeight() * (SIZES[settings.introSize] or SIZES.medium), 540)
    local w = h * 16 / 9
    pictureH, pictureW = h, w
    picture:SetSize(w, h)
    local mode = settings.introTextMode or "full"
    -- the terminal box under the picture holds four lines of the narration
    local fontSize = math.max(11, math.floor(h * 0.04))
    local boxHeight = math.ceil(fontSize * 1.4) * 4 + 16
    terminal:SetShown(mode == "full")
    terminal:SetSize(w, boxHeight)
    terminalText:SetFont(FONT, fontSize, "OUTLINE")
    tape:SetWidth(w * 0.8)
    tape:SetPoint("BOTTOM", picture, "BOTTOM", 0, h * 0.03)
    tapeText:SetFont(FONT, fontSize, "OUTLINE")
    if mode ~= "key" then tape:Hide() end
    frame:SetSize(math.max(w + 24, buttonsWidth), h + 24 + 44 + (mode == "full" and boxHeight + 8 or 0))
end

-- A button that flips a setting and shows its state in its label.
local function toggle(parent, width, label, key, default, onChange)
    local function get()
        local v = ST.db.settings[key]
        if v == nil then v = default end
        return v
    end
    local b
    local function paint() b:SetText(label .. ": " .. (get() and "on" or "off")) end
    b = button(parent, "", width, function()
        ST.db.settings[key] = not get()
        paint()
        onChange()
    end)
    paint()
    return b
end

local function build()
    local h, w = 300, 533 -- placeholders: layout() sets the real sizes once everything exists
    frame = CreateFrame("Frame", "SummonCoreIntro", UIParent)
    frame:Hide() -- a new frame is visible; start hidden so the toggle below shows it on the first command
    ST.db.settings.introMute = ST.db.settings.introSound == false
    frame:SetSize(w + 24, h + 24 + 44)
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

    -- two green-on-black boxes, like an old terminal: one under the picture that types out the whole
    -- narration, and a small strip over the picture for the punchlines ("key" mode)
    local function terminalBox(alpha)
        local box = CreateFrame("Frame", nil, frame)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        boxBg:SetColorTexture(0, 0.04, 0.01, alpha)
        for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
            { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
            local line = box:CreateTexture(nil, "BORDER")
            line:SetColorTexture(0.25, 1, 0.45, 0.9)
            line:SetPoint(edge[1])
            line:SetPoint(edge[2])
            if edge[3] then line:SetHeight(1.5) else line:SetWidth(1.5) end
        end
        local text = box:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT, 14, "OUTLINE")
        text:SetTextColor(0.4, 1, 0.55)
        text:SetPoint("TOPLEFT", 12, -6)
        text:SetPoint("BOTTOMRIGHT", -10, 6)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
        return box, text
    end
    endText = frame:CreateFontString(nil, "OVERLAY")
    endText:SetFont(FONT, 30, "OUTLINE")
    endText:SetTextColor(0.4, 1, 0.55)
    endText:SetPoint("CENTER", picture, "CENTER")
    endText:SetText("THE END")
    endText:SetAlpha(0)

    -- highlight box: a bright outline with a faint fill, moved over the picture by show()
    glow = CreateFrame("Frame", nil, frame)
    local glowFill = glow:CreateTexture(nil, "BACKGROUND")
    glowFill:SetAllPoints()
    glowFill:SetColorTexture(1, 0.92, 0.45, 0.12)
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local line = glow:CreateTexture(nil, "BORDER")
        line:SetColorTexture(1, 0.95, 0.55, 1)
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then line:SetHeight(2.5) else line:SetWidth(2.5) end
    end
    glow:Hide()

    tape, tapeText = terminalBox(0.82)
    tape:SetSize(w * 0.88, h * 0.14)
    tape:SetPoint("BOTTOM", picture, "BOTTOM", 0, h * 0.05)
    tape:Hide()
    terminal, terminalText = terminalBox(0.95)
    terminal:SetPoint("TOPLEFT", picture, "BOTTOMLEFT", 0, -6)
    terminalText:SetJustifyV("TOP")

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("BOTTOMRIGHT", -14, 16)

    nextX = 12
    button(frame, "<", 30, function() seek(starts[math.max(lo, sceneAt(t) - 1)]) end)
    playBtn = button(frame, "Play", 70, function()
        if t >= endTime() - 0.05 then seek(starts[lo]) end
        setPlaying(not playing)
    end)
    button(frame, ">", 30, function()
        local nxt = sceneAt(t) + 1
        if nxt <= hi then seek(starts[nxt]) end
    end)
    button(frame, "Restart", 70, function() seek(starts[lo]) setPlaying(true) end)
    button(frame, "Close", 60, function() frame:Hide() end)
    toggle(frame, 86, "Sound", "introSound", true, function()
        ST.db.settings.introMute = not ST.db.settings.introSound
        if ST.db.settings.introMute then stopClip() elseif playing then setPlaying(true) end
    end)
    toggle(frame, 86, "Music", "introMusic", true, function()
        stopClip()
        if playing then setPlaying(true) end -- replay this scene's clip with or without the music bed
    end)
    -- Text: the whole narration typed out under the picture ("full"), just the punchlines over it ("key"), or none
    local textBtn
    local TEXT_MODES = { "full", "key", "off" }
    textBtn = button(frame, "", 90, function()
        local current = ST.db.settings.introTextMode or "full"
        for i, name in ipairs(TEXT_MODES) do
            if name == current then ST.db.settings.introTextMode = TEXT_MODES[i % #TEXT_MODES + 1] break end
        end
        textBtn:SetText("Text: " .. ST.db.settings.introTextMode)
        lastCue = nil
        layout()
        show(t)
    end)
    textBtn:SetText("Text: " .. (ST.db.settings.introTextMode or "full"))
    local lookBtn
    lookBtn = button(frame, "", 120, function()
        local current = look()
        for i, name in ipairs(LOOK_ORDER) do
            if name == current then ST.db.settings.introLook = LOOK_ORDER[i % #LOOK_ORDER + 1] break end
        end
        lookBtn:SetText("Look: " .. look())
        shownScene = 0 -- reload the picture in the new look
        show(t)
    end)
    lookBtn:SetText("Look: " .. look())
    local sizeBtn
    sizeBtn = button(frame, "", 100, function()
        local current = ST.db.settings.introSize or "medium"
        for i, name in ipairs(SIZE_ORDER) do
            if name == current then ST.db.settings.introSize = SIZE_ORDER[i % #SIZE_ORDER + 1] break end
        end
        sizeBtn:SetText("Size: " .. ST.db.settings.introSize)
        layout()
    end)
    sizeBtn:SetText("Size: " .. (ST.db.settings.introSize or "medium"))
    buttonsWidth = nextX + 6

    frame:SetScript("OnUpdate", function(_, elapsed)
        if not playing then return end
        t = t + elapsed
        if t >= endTime() then
            t = endTime() - 0.01
            setPlaying(false)
        end
        show(t)
    end)
    frame:SetScript("OnHide", function() setPlaying(false) end)
    layout()
end

-- /st intro check: tries every narration and effect file and reports the ones the game cannot play.
function Intro.Check()
    local bad = 0
    local function try(name)
        local ok, willPlay, handle = pcall(PlaySoundFile, name, "Dialog")
        if handle then pcall(StopSound, handle) end
        if not (ok and willPlay) then
            bad = bad + 1
            ST.print("cannot play: " .. name:match("[^\\]+$"))
        end
    end
    for i = 1, #scenes do
        try(MEDIA .. "intro_" .. i .. ".ogg")
        try(MEDIA .. "intro_" .. i .. "_voice.ogg")
    end
    for _, name in ipairs({ "sfx_chirp_1", "sfx_chirp_2", "sfx_chirp_3", "sfx_keys_long", "sfx_pop" }) do
        try(SFX .. name .. ".ogg")
    end
    if bad == 0 then
        ST.print("all intro sound files play. If the pictures are blank, try Terminal art: on/off, or tell me.")
    else
        ST.print(bad .. " file(s) failed. If files were added or replaced while WoW was running, quit WoW completely and start it again: /reload does not pick up new media files.")
    end
end

function Intro.Toggle(arg)
    if arg == "check" then return Intro.Check() end
    if not frame then build() end
    if frame:IsShown() then frame:Hide() return end
    frame:Show()
    local si
    local key = CHAPTER_KEYS[arg or ""]
    if key then
        if not firstOf[key] then return ST.print("that chapter of the story has not been written yet") end
        si = firstOf[key]
    else
        si = tonumber(arg) or 1
    end
    si = math.max(1, math.min(#scenes, si))
    lo, hi = firstOf[scenes[si].chapter], lastOf[scenes[si].chapter]
    shownScene = 0
    seek(starts[si])
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
