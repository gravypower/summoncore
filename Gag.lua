-- Gag: Zenit detection and the "ah-ah-ah" access-denied clip. A joke gate for friends, not security.
local ADDON, ST = ...
local Gag = {}
ST.Gag = Gag

-- Add clips here: { sound = ".ogg path", frames = { 256/512px power-of-two textures, ... } }.
-- Files live in Interface\AddOns\summoncore\Media\. One is picked at random per block.
Gag.clips = {
    -- { sound = "Interface\\AddOns\\summoncore\\Media\\ahah1.ogg",
    --   frames = { "Interface\\AddOns\\summoncore\\Media\\wag1_1", "Interface\\AddOns\\summoncore\\Media\\wag1_2" } },
}

local FALLBACK_FRAMES = { "Interface\\Icons\\Spell_Shadow_Teleport", "Interface\\Icons\\INV_Misc_QuestionMark" }
local FRAME_TIME = 0.2
local DURATION = 2.5

function Gag.IsZenit()
    local s = ST.db and ST.db.settings
    if not s then return false end
    if s.zenitTest then return true end
    local me = (UnitName("player") or ""):lower()
    for _, n in ipairs(s.zenitNames or {}) do
        if n:lower() == me then return true end
    end
    return false
end

local frame, ticker

function Gag.Play()
    local clip = #Gag.clips > 0 and Gag.clips[math.random(#Gag.clips)] or nil
    local willPlay = false
    if clip and clip.sound and ST.db.settings.soundOn ~= false then
        local ok, wp = pcall(PlaySoundFile, clip.sound, "Master")
        willPlay = ok and wp
    end
    if not willPlay and ST.db.settings.soundOn ~= false then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST or 857, "Master")
    end
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(128, 128)
        frame:SetPoint("CENTER", 0, 100)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame.tex = frame:CreateTexture(nil, "ARTWORK")
        frame.tex:SetAllPoints()
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -6)
        frame.text:SetText("Ah ah ah! You didn't say the magic word!")
    end
    local frames = (clip and clip.frames and #clip.frames > 0) and clip.frames or FALLBACK_FRAMES
    local n = 0
    if ticker then ticker:Cancel() end
    frame:Show()
    ticker = C_Timer.NewTicker(FRAME_TIME, function()
        n = n + 1
        frame.tex:SetTexture(frames[(n - 1) % #frames + 1])
        -- Mirror every other tick so a single image still wags left and right.
        if n % 2 == 0 then frame.tex:SetTexCoord(0, 1, 0, 1) else frame.tex:SetTexCoord(1, 0, 0, 1) end
        if n * FRAME_TIME >= DURATION then
            ticker:Cancel()
            frame:Hide()
        end
    end)
end

-- Returns true (after playing the gag) when the player is Zenit and the content is hidden.
function Gag.Blocked()
    if Gag.IsZenit() then
        Gag.Play()
        return true
    end
    return false
end
