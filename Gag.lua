-- Gag: Zennit detection and the "ah-ah-ah" access-denied clip. A joke gate for friends, not security.
local ADDON, ST = ...
local Gag = {}
ST.Gag = Gag

local MEDIA = "Interface\\AddOns\\summoncore\\Media\\"

-- Each clip is a sprite sheet (all frames in one power-of-two texture) plus an optional sound:
--   sheet = { file = <path without extension>, cols = n, rows = n, frames = n, fps = n }
--   sound = ".ogg path" (optional; a built-in sound plays if missing)
-- Frames run left to right, top to bottom. One clip is picked at random per block, so add more entries
-- as friends record them. Convert each recording outside the game into an .ogg plus a sheet (.tga/.blp).
Gag.clips = {
    { sheet = { file = MEDIA .. "gag_wag_sheet", cols = 4, rows = 2, frames = 8, fps = 8 } },
}

local DURATION = 2.5
local SHOW_SIZE = 192
local CAPTION = "Ah ah ah! You didn't say the magic word!"

function Gag.IsZennit()
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

-- Points the texture at one cell of the sheet.
local function setFrame(tex, sheet, index)
    local col = index % sheet.cols
    local row = math.floor(index / sheet.cols)
    tex:SetTexCoord(col / sheet.cols, (col + 1) / sheet.cols, row / sheet.rows, (row + 1) / sheet.rows)
end

local function playSound(clip)
    if ST.db.settings.soundOn == false then return end
    if clip and clip.sound then
        local ok, willPlay = pcall(PlaySoundFile, clip.sound, "Master")
        if ok and willPlay then return end
    end
    if ST.Clips.Play("wag") then return end -- a recorded "ah-ah-ah" from Media/clips
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST or 857, "Master")
end

function Gag.Play()
    local clip = Gag.clips[math.random(#Gag.clips)]
    local sheet = clip.sheet
    playSound(clip)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(SHOW_SIZE, SHOW_SIZE)
        frame:SetPoint("CENTER", 0, 100)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame.tex = frame:CreateTexture(nil, "ARTWORK")
        frame.tex:SetAllPoints()
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -6)
        frame.text:SetText(CAPTION)
    end
    frame.tex:SetTexture(sheet.file)
    local n = 0
    setFrame(frame.tex, sheet, 0)
    if ticker then ticker:Cancel() end
    frame:Show()
    ticker = C_Timer.NewTicker(1 / sheet.fps, function()
        n = n + 1
        if n / sheet.fps >= DURATION then
            ticker:Cancel()
            frame:Hide()
            return
        end
        setFrame(frame.tex, sheet, n % sheet.frames)
    end)
end

-- Returns true (after playing the gag) when the player is Zennit and the content is hidden.
function Gag.Blocked()
    if Gag.IsZennit() then
        Gag.Play()
        return true
    end
    return false
end
