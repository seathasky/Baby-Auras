local _, addon = ...

local Widgets = {}
addon.GUIWidgets = Widgets

local Defaults = addon.Defaults

function Widgets.ApplyBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
end

function Widgets.SetButtonTextWhite(button)
    local fontString = button and button.GetFontString and button:GetFontString()
    if fontString then fontString:SetTextColor(1, 1, 1) end
end

function Widgets.CreateCheckbox(parent, labelText, hitWidth)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetHitRectInsets(0, -(hitWidth or 100), 0, 0)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    label:SetText(labelText)
    return checkbox, label
end

function Widgets.CreateSectionTitle(parent, text)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetText(text)
    title:SetTextColor(0.58, 0.90, 1)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", title, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    line:SetColorTexture(0.25, 0.50, 0.68, 0.45)
    return title, line
end

function Widgets.CreatePositionInputs(parent, labelText)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetText(labelText)
    label:SetWidth(95)
    label:SetJustifyH("LEFT")
    local xLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    xLabel:SetPoint("LEFT", label, "RIGHT", 6, 0)
    xLabel:SetText("X")
    local xBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    xBox:SetPoint("LEFT", xLabel, "RIGHT", 5, 0)
    xBox:SetSize(52, 24)
    xBox:SetAutoFocus(false)
    xBox:SetMaxLetters(4)
    local yLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    yLabel:SetPoint("LEFT", xBox, "RIGHT", 12, 0)
    yLabel:SetText("Y")
    local yBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    yBox:SetPoint("LEFT", yLabel, "RIGHT", 5, 0)
    yBox:SetSize(52, 24)
    yBox:SetAutoFocus(false)
    yBox:SetMaxLetters(4)
    return label, xLabel, xBox, yLabel, yBox
end

function Widgets.CreateColorButton(parent, labelText)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(105, 28)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.025, 0.045, 0.065, 0.96)
    button:SetBackdropBorderColor(0.25, 0.55, 0.72, 0.9)
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("LEFT", 7, 0)
    swatch:SetSize(16, 16)
    swatch:SetColorTexture(1, 1, 1, 1)
    local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
    label:SetText(labelText)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.2, 0.65, 1, 0.18)
    button.Swatch = swatch
    return button
end

function Widgets.CreateGlowSlider(parent, labelText, minValue, maxValue, settingKey, suffix)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetText(labelText)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(105, 16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minValue))
    slider.High:SetText(tostring(maxValue))
    slider.Text:SetText("")
    local valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    slider:SetScript("OnValueChanged", function(_, value)
        addon.GUI:OnGlowTuningChanged(settingKey, value, valueText, suffix)
    end)
    return label, slider, valueText
end

function Widgets.GetSavedColor(settings, settingKey, defaultKey)
    local color = settings and settings[settingKey]
    if type(color) ~= "table" then color = Defaults.soloAppearance[defaultKey] end
    return {
        Clamp(tonumber(color and color[1]) or 1, 0, 1),
        Clamp(tonumber(color and color[2]) or 1, 0, 1),
        Clamp(tonumber(color and color[3]) or 1, 0, 1),
        Clamp(tonumber(color and color[4]) or 1, 0, 1),
    }
end

function Widgets.SetColorButtonColor(button, color)
    if button and button.Swatch then button.Swatch:SetColorTexture(unpack(color)) end
end

function Widgets.CreateSectionToggle(parent, title, line, sectionKey)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(30, 26)
    button:SetPoint("CENTER", title, "LEFT", 305, 8)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.015, 0.07, 0.10, 0.98)
    button:SetBackdropBorderColor(0.25, 0.75, 0.95, 0.95)
    local symbol = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    symbol:SetPoint("CENTER", 0, 1)
    symbol:SetText("+")
    symbol:SetTextColor(0.65, 0.93, 1, 1)
    button.Symbol = symbol
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 2, -2)
    highlight:SetPoint("BOTTOMRIGHT", -2, 2)
    highlight:SetColorTexture(0.25, 0.75, 1, 0.28)
    if line then
        line:ClearAllPoints()
        line:SetPoint("LEFT", title, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", button, "LEFT", -5, -8)
    end
    button:SetScript("OnClick", function() addon.GUI:ToggleEditorSection(sectionKey) end)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.04, 0.20, 0.28, 1)
        self:SetBackdropBorderColor(0.45, 0.9, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Expand or collapse this section")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.015, 0.07, 0.10, 0.98)
        self:SetBackdropBorderColor(0.25, 0.75, 0.95, 0.95)
        GameTooltip_Hide()
    end)
    return button
end

function Widgets.CreateSectionBackground(parent)
    local panel = {}
    panel.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel.frame:EnableMouse(false)
    panel.frame:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    panel.frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    panel.frame:SetBackdropColor(0.075, 0.085, 0.095, 0.90)
    panel.leftDivider = panel.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    panel.leftDivider:SetColorTexture(0.20, 0.58, 0.72, 1)
    panel.leftDivider:SetWidth(2)

    function panel:SetShown(shown)
        self.frame:SetShown(shown)
        self.leftDivider:SetShown(shown)
    end
    return panel
end
