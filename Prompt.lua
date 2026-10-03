-- Prompt: caster confirmation dialog for ritual assistants.
local ADDON, ST = ...
local Prompt = {}
ST.Prompt = Prompt

local MAX_ASSISTANTS = 2
local ROW_H = 26
local frame, open

local function build()
    frame = CreateFrame("Frame", "SummonCorePrompt", UIParent, "BasicFrameTemplateWithInset")
    frame:SetWidth(320)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText("Summon logged")
    frame.question = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.question:SetPoint("TOPLEFT", 16, -34)
    frame.question:SetWidth(288)
    frame.question:SetJustifyH("LEFT")
    frame.checks = {}

    local ok = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ok:SetSize(110, 24)
    ok:SetText("Confirm")
    ok:SetPoint("BOTTOMLEFT", 16, 12)
    ok:SetScript("OnClick", function() Prompt.Finish(true) end)
    local skip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    skip:SetSize(110, 24)
    skip:SetText("Save unconfirmed")
    skip:SetPoint("BOTTOMRIGHT", -16, 12)
    skip:SetScript("OnClick", function() Prompt.Finish(false) end)
    frame:SetScript("OnHide", function() if open then Prompt.Finish(false) end end)
end

local function checkedNames()
    local out = {}
    for _, cb in ipairs(frame.checks) do
        if cb:IsShown() and cb:GetChecked() then out[#out + 1] = cb.name end
    end
    return out
end

-- Ends the dialog and hands the chosen names to the callback.
function Prompt.Finish(confirmed)
    if not open then return end
    local session = open
    open = nil
    local names = checkedNames()
    frame:Hide()
    session.onDone(names, confirmed)
end

-- candidates: party member names. preselected: names ticked to start with.
-- onDone(assistants, confirmed) is always called exactly once.
function Prompt.Ask(target, candidates, preselected, onDone)
    if not frame then build() end
    if open then Prompt.Finish(false) end
    open = { onDone = onDone }
    local pre = {}
    for _, n in ipairs(preselected or {}) do pre[n] = true end
    frame.question:SetText(string.format("Credit these two as ritual assistants for the summon of %s?", target))
    for i, name in ipairs(candidates) do
        local cb = frame.checks[i]
        if not cb then
            cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 20, -62 - (i - 1) * ROW_H)
            cb:SetScript("OnClick", function(self)
                if self:GetChecked() and #checkedNames() > MAX_ASSISTANTS then self:SetChecked(false) end
            end)
            frame.checks[i] = cb
        end
        cb.name = name
        cb.Text:SetText(name)
        cb:SetChecked(pre[name] or false)
        cb:Show()
    end
    for i = #candidates + 1, #frame.checks do frame.checks[i]:Hide() end
    frame:SetHeight(110 + #candidates * ROW_H)
    frame:Show()
end
