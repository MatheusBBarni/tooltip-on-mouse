-- TooltipOnMouse: shows tooltips next to the mouse instead of the corner of the screen.
--
-- Every tooltip placed in the default corner goes through one Blizzard function,
-- including tooltips for units and objects in the world. The game has no anchor
-- for above or below the cursor, so the addon moves those tooltips itself.
--
-- Tooltips are moved with ClearAllPoints and SetPoint, never SetOwner. SetOwner
-- would clear a tooltip that is being built, running Blizzard's clear scripts as
-- addon code. That taint can leave it blank when its data is hidden from addons.

local ADDON_NAME = ...

local DISPLAY_NAME = "Tooltip On Mouse"
local DEFAULT_POSITION = "top"

-- Right and down have bigger gaps because the cursor image hangs below and to
-- the right of its tip, and would cover the tooltip otherwise.
local POSITIONS = {
    { key = "left", label = "Left", point = "RIGHT", x = -16, y = 0 },
    { key = "top", label = "Top", point = "BOTTOM", x = 0, y = 16 },
    { key = "right", label = "Right", point = "LEFT", x = 32, y = 0 },
    { key = "down", label = "Down", point = "TOP", x = 0, y = -36 },
}

local POSITION_BY_KEY = {}
for _, position in ipairs(POSITIONS) do
    POSITION_BY_KEY[position.key] = position
end

local db
local panel
local frame = CreateFrame("Frame")

-- True while a tooltip follows the mouse. False once it has been given another
-- owner. A tooltip that is in the table already has its hooks.
local following = {}

local function PlaceAtCursor(tooltip)
    local position = POSITION_BY_KEY[db.position]
    local cursorX, cursorY = GetCursorPosition()
    local scale = tooltip:GetEffectiveScale()
    tooltip:ClearAllPoints()
    tooltip:SetPoint(
        position.point, UIParent, "BOTTOMLEFT",
        cursorX / scale + position.x,
        cursorY / scale + position.y
    )
end

-- Blizzard adds its corner anchor without clearing older ones, so the mouse
-- anchor must go first or the tooltip stretches between the two. Other anchor
-- types are left alone because the game has already placed the tooltip by now.
local function StopFollowing(tooltip, _, anchor)
    if following[tooltip] and anchor == "ANCHOR_NONE" then
        tooltip:ClearAllPoints()
    end
    following[tooltip] = false
end

-- Blizzard fades a tooltip for a few seconds once the mouse leaves its target.
local function SkipFade(tooltip)
    if following[tooltip] then
        tooltip:Hide()
    end
end

-- Runs right after Blizzard has placed the tooltip in its normal position, so
-- leaving it alone is all that showing it there takes.
local function StartFollowing(tooltip)
    if following[tooltip] == nil then
        hooksecurefunc(tooltip, "SetOwner", StopFollowing)
        hooksecurefunc(tooltip, "FadeOut", SkipFade)
    end
    following[tooltip] = not (db.normalInCombat and InCombatLockdown())
    if following[tooltip] then
        PlaceAtCursor(tooltip)
    end
end

local function UpdateTooltips()
    for tooltip, isFollowing in pairs(following) do
        if isFollowing and tooltip:IsShown() then
            PlaceAtCursor(tooltip)
        end
    end
end

local function CreatePanel()
    local window = CreateFrame("Frame", "TooltipOnMousePanel", UIParent, "DefaultPanelFlatTemplate")
    window:SetSize(250, 205)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    window.TitleContainer.TitleText:SetText(DISPLAY_NAME)
    CreateFrame("Button", nil, window, "UIPanelCloseButtonDefaultAnchors")
    tinsert(UISpecialFrames, window:GetName())

    local heading = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 20, -38)
    heading:SetText("Tooltip position")

    local radios = {}

    local combatCheckbox = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    combatCheckbox:SetPoint("TOPLEFT", 16, -160)
    combatCheckbox:SetScript("OnClick", function(self)
        db.normalInCombat = self:GetChecked()
    end)

    local combatLabel = combatCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    combatLabel:SetPoint("LEFT", combatCheckbox, "RIGHT", 2, 0)
    combatLabel:SetText("Normal position in combat")
    combatCheckbox:SetHitRectInsets(0, -(combatLabel:GetStringWidth() + 2), 0, 0)

    function window:Refresh()
        for key, radio in pairs(radios) do
            radio:SetChecked(key == db.position)
        end
        combatCheckbox:SetChecked(db.normalInCombat)
    end

    for index, position in ipairs(POSITIONS) do
        local radio = CreateFrame("CheckButton", nil, window, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 22, -38 - index * 24)
        radio.text:SetFontObject("GameFontHighlight")
        radio.text:SetText(position.label)
        -- Makes the label clickable too.
        radio:SetHitRectInsets(0, -(radio.text:GetStringWidth() + 5), 0, 0)
        radio:SetScript("OnClick", function()
            db.position = position.key
            window:Refresh()
        end)
        radios[position.key] = radio
    end

    window:SetScript("OnShow", window.Refresh)
    return window
end

local function TogglePanel()
    panel = panel or CreatePanel()
    panel:SetShown(not panel:IsShown())
end

SLASH_TOOLTIPONMOUSE1 = "/tooltiponmouse"
SLASH_TOOLTIPONMOUSE2 = "/tom"
SlashCmdList.TOOLTIPONMOUSE = TogglePanel

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    frame:UnregisterEvent("ADDON_LOADED")

    TooltipOnMouseDB = TooltipOnMouseDB or {}
    db = TooltipOnMouseDB
    if not POSITION_BY_KEY[db.position] then
        db.position = DEFAULT_POSITION
    end
    if db.normalInCombat == nil then
        db.normalInCombat = true
    end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", StartFollowing)
    frame:SetScript("OnUpdate", UpdateTooltips)
end)
