local _, addon = ...

addon.GUISections = addon.GUISections or {}
local ThemeSection = {}
addon.GUISections.Theme = ThemeSection

local Widgets = addon.GUIWidgets
local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

function ThemeSection:Build(editor, anchor, frame)
    local GUI = addon.GUI
    local title, line = Widgets.CreateSectionTitle(editor, "THEME")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -28)
    frame.ThemeTitle = title

    local border, borderLabel = Widgets.CreateCheckbox(editor, "Black border", 105)
    border:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    border:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloBlackBorder", self, "Solo black border")
        GUI:UpdateSoloControls()
    end)
    frame.SoloBlackBorder, frame.SoloBlackBorderLabel = border, borderLabel

    local borderSize = CreateFrame("Slider", nil, editor, "OptionsSliderTemplate")
    borderSize:SetPoint("LEFT", border, "LEFT", 170, 0)
    borderSize:SetSize(105, 16)
    borderSize:SetMinMaxValues(1, 3)
    borderSize:SetValueStep(1)
    borderSize:SetObeyStepOnDrag(true)
    borderSize.Low:SetText("1")
    borderSize.High:SetText("3")
    borderSize.Text:SetText("")
    borderSize:SetScript("OnValueChanged", function(_, value) GUI:OnSoloBorderSizeChanged(value) end)
    frame.SoloBorderSize = borderSize
    local borderSizeValue = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    borderSizeValue:SetPoint("LEFT", borderSize, "RIGHT", 9, 0)
    borderSizeValue:SetText("1 px")
    frame.SoloBorderSizeValue = borderSizeValue

    local bar = {}
    bar.color = Widgets.CreateColorButton(editor, "Bar background")
    bar.color:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -5)
    bar.color:SetScript("OnClick", function()
        GUI:OpenSoloTextColor("soloBarFillColor", "barFillColor", bar.color, "Tracked bar background", true)
    end)
    bar.color:SetWidth(150)
    frame.SoloBarFillColor = bar.color
    bar.progress = Widgets.CreateColorButton(editor, "Bar progress")
    bar.progress:SetPoint("LEFT", bar.color, "RIGHT", 10, 0)
    bar.progress:SetScript("OnClick", function()
        GUI:OpenSoloTextColor("soloBarProgressColor", "barProgressColor", bar.progress, "Tracked bar progress", true)
    end)
    bar.progress:SetWidth(150)
    frame.SoloBarProgressColor = bar.progress
    frame.SoloBarThemeElements = { bar.color, bar.progress }

    local fontLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 4, -10)
    fontLabel:SetText("Text font")
    fontLabel:SetTextColor(1, 1, 1)
    frame.SoloFontLabel = fontLabel
    local font = FrameUtil.CreateFrame(nil, editor, "WowStyle1DropdownTemplate")
    font:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -4, -5)
    font:SetSize(250, 26)
    font:SetSelectionText(function() return GUI:GetSoloFontName() end)
    font:SetupMenu(function(_, rootDescription)
        local fonts = SharedMedia and SharedMedia:List("font") or {}
        for _, fontName in ipairs(fonts) do
            rootDescription:CreateRadio(fontName, function(value)
                return GUI:GetSoloFontName() == value
            end, function(value)
                GUI:SetSoloFont(value)
            end, fontName)
        end
    end)
    font:EnableRegenerateOnResponse()
    frame.SoloFont = font

    local colorsLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    colorsLabel:SetPoint("TOPLEFT", font, "BOTTOMLEFT", 4, -12)
    colorsLabel:SetText("Text colors")
    colorsLabel:SetTextColor(1, 1, 1)
    frame.SoloTextColorsLabel = colorsLabel

    local stackColor = Widgets.CreateColorButton(editor, "Stack")
    stackColor:SetPoint("TOPLEFT", colorsLabel, "BOTTOMLEFT", -4, -5)
    stackColor:SetScript("OnClick", function()
        GUI:OpenSoloTextColor("soloStackColor", "stackColor", stackColor, "Stack text")
    end)
    frame.SoloStackColor = stackColor
    local cooldownColor = Widgets.CreateColorButton(editor, "Cooldown")
    cooldownColor:SetPoint("LEFT", stackColor, "RIGHT", 5, 0)
    cooldownColor:SetScript("OnClick", function()
        GUI:OpenSoloTextColor("soloCooldownColor", "cooldownColor", cooldownColor, "Cooldown text")
    end)
    frame.SoloCooldownColor = cooldownColor
    local hotkeyColor = Widgets.CreateColorButton(editor, "Hotkey")
    hotkeyColor:SetPoint("LEFT", cooldownColor, "RIGHT", 5, 0)
    hotkeyColor:SetScript("OnClick", function()
        GUI:OpenSoloTextColor("soloHotkeyColor", "hotkeyColor", hotkeyColor, "Hotkey text")
    end)
    frame.SoloHotkeyColor = hotkeyColor
    local barTextColor = Widgets.CreateColorButton(editor, "Bar text")
    barTextColor:SetPoint("TOPLEFT", stackColor, "BOTTOMLEFT", 0, -7)
    barTextColor:SetScript("OnClick", function()
        GUI:OpenSoloTextColor("soloBarTextColor", "barTextColor", barTextColor, "Tracked bar text")
    end)
    frame.SoloBarTextColor = barTextColor

    local reset = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", stackColor, "BOTTOMLEFT", 0, -7)
    reset:SetSize(150, 24)
    reset:SetText("Reset Text Colors")
    Widgets.SetButtonTextWhite(reset)
    reset:SetScript("OnClick", function() GUI:ResetSoloTextColors() end)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset text colors")
        GameTooltip:AddLine("Restores stack, cooldown, and hotkey text to their default colors for this icon.", 0.75, 0.85, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", GameTooltip_Hide)
    frame.ResetSoloTextColors = reset

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "theme")
    return {
        title = title, line = line, toggle = toggle,
        border = border, borderLabel = borderLabel, borderSize = borderSize, borderSizeValue = borderSizeValue,
        bar = bar, fontLabel = fontLabel, font = font, colorsLabel = colorsLabel,
        stackColor = stackColor, cooldownColor = cooldownColor, hotkeyColor = hotkeyColor,
        barTextColor = barTextColor, reset = reset,
        descriptor = {
            key = "theme", title = title, toggle = toggle, bottom = reset,
            gap = -16, collapseHeight = 192,
            elements = {
                border, borderLabel, borderSize, borderSizeValue, bar.color, bar.progress,
                fontLabel, font, colorsLabel, stackColor, cooldownColor, hotkeyColor, barTextColor, reset,
            },
        },
    }
end
