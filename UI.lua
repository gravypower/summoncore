-- UI: tally and badge panel. Zenit's client gets the gag instead.
local ADDON, ST = ...
local UI = {}
ST.UI = UI

local panel

local function buildText()
    local me = ST.Store.me()
    local t = ST.Store.Tallies()[me] or { cast = 0, received = 0, assisted = 0, points = 0 }
    local lines = {
        string.format("|cffffd100%s|r", me),
        string.format("Summons cast: %d    Received: %d    Assisted: %d", t.cast, t.received, t.assisted),
        string.format("Points: %d", t.points),
        "",
        "|cffffd100Badges|r",
    }
    for _, b in ipairs(ST.Scoring.badges) do
        local got = ST.db.badges[b.id]
        lines[#lines + 1] = got and ("|cff33ff66[x]|r " .. b.name .. "  " .. date("%Y-%m-%d", got.earned))
            or ("|cff888888[ ] " .. b.name .. "|r")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100Recent summons|r"
    local recent = ST.Store.Recent(8)
    if #recent == 0 then lines[#lines + 1] = "none yet" end
    for _, r in ipairs(recent) do
        local ev = r.ev
        lines[#lines + 1] = string.format("%s  %s -> %s  (%s, +%d)", date("%m-%d %H:%M", ev.time), ev.caster,
            ev.target, ev.kind or "?", ev.points or 0)
    end
    return table.concat(lines, "\n")
end

local function build()
    panel = CreateFrame("Frame", "SummonCorePanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(380, 440)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel.TitleText:SetText("Summon Core")
    tinsert(UISpecialFrames, "SummonCorePanel")
    panel.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.text:SetPoint("TOPLEFT", 16, -34)
    panel.text:SetPoint("BOTTOMRIGHT", -16, 12)
    panel.text:SetJustifyH("LEFT")
    panel.text:SetJustifyV("TOP")
end

function UI.Toggle()
    if ST.Gag.Blocked() then return end
    if not panel then build() end
    if panel:IsShown() then panel:Hide() return end
    panel.text:SetText(buildText())
    panel:Show()
end
