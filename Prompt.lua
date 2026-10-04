-- Prompt: caster confirmation dialog for ritual assistants.
local ADDON, ST = ...
local Prompt = {}
ST.Prompt = Prompt
local T = ST.Theme

local MAX_ASSISTANTS = 2
local ROW_H = 26
local frame, open

local function build()
    frame = T.Window("SummonCorePrompt", 320, 110, { strata = "DIALOG", escape = false })
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", 0, 120)
    frame.TitleText:SetText("SUMMON LOGGED")
    frame.question = T.Text(frame, 18, "green")
    frame.question:SetPoint("TOPLEFT", 16, -36)
    frame.question:SetWidth(288)
    frame.checks = {}
    frame.hint = T.Text(frame, 16, "amber")
    frame.hint:SetPoint("BOTTOMLEFT", 16, 42)
    frame.hint:SetWidth(288)

    local ok = T.Button(frame, "CONFIRM", 110, 24, function() Prompt.Finish(true) end, "primary")
    ok:SetPoint("BOTTOMLEFT", 16, 12)
    local skip = T.Button(frame, "SAVE UNCONFIRMED", 150, 24, function() Prompt.Finish(false) end)
    skip:SetPoint("BOTTOMRIGHT", -16, 12)
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
    frame.question:SetText(string.format("Who helped with the summon of %s? Tick up to two ritual assistants.",
        T.Paint("cyan", target)))
    frame.hint:SetText("")
    for i, name in ipairs(candidates) do
        local cb = frame.checks[i]
        if not cb then
            cb = T.Check(frame, 280)
            cb:SetPoint("TOPLEFT", 20, -82 - (i - 1) * ROW_H)
            cb:SetScript("OnClick", function(self)
                if self:GetChecked() and #checkedNames() > MAX_ASSISTANTS then
                    self:SetChecked(false)
                    frame.hint:SetText("Only two can be credited. Untick one first.")
                else
                    frame.hint:SetText("")
                end
            end)
            frame.checks[i] = cb
        end
        cb.name = name
        cb.Text:SetText(name)
        cb:SetChecked(pre[name] or false)
        cb:Show()
    end
    for i = #candidates + 1, #frame.checks do frame.checks[i]:Hide() end
    frame:SetHeight(148 + #candidates * ROW_H)
    frame:Show()
end
