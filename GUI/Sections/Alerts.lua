local _, addon = ...

addon.GUISections = addon.GUISections or {}
local Alerts = {}
addon.GUISections.Alerts = Alerts

local Widgets = addon.GUIWidgets

function Alerts:Build(editor, anchor, frame)
    local GUI = addon.GUI
    local title, line = Widgets.CreateSectionTitle(editor, "ALERT EFFECTS")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    frame.EffectsTitle = title

    local glow, glowLabel = Widgets.CreateCheckbox(editor, "Glow alert", 105)
    glow:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    glow:SetScript("OnClick", function() GUI:OnGlowClicked() end)
    frame.Glow = glow
    local styleLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("LEFT", glow, "LEFT", 115, 0)
    styleLabel:SetText("Style")
    frame.GlowStyleLabel = styleLabel
    local style = FrameUtil.CreateFrame(nil, editor, "WowStyle1DropdownTemplate")
    style:SetPoint("LEFT", styleLabel, "RIGHT", 7, 0)
    style:SetSize(180, 26)
    style:SetSelectionText(function() return addon.Glow:GetLabel(GUI:GetGlowStyle()) end)
    style:SetupMenu(function(_, rootDescription)
        for _, optionData in ipairs(addon.Glow.styles) do
            local option = rootDescription:CreateRadio(optionData.label, function(value)
                return GUI:GetGlowStyle() == value
            end, function(value)
                GUI:SetGlowStyle(value)
            end, optionData.key)
                    if optionData.key == "blizzard" and GUI.frame.ActiveSoloCropped then
                option:SetEnabled(false)
                option:SetTitleAndTextTooltip("Blizzard Proc unavailable",
                            GUI.frame.ActiveSoloCropped
                                and "Cropped icons support Pixel Glow and Extended Glow."
                                or "Tracked bars support Pixel Glow and Extended Glow. Other icon categories can use Blizzard Proc.")
            end
        end
    end)
    style:EnableRegenerateOnResponse()
    frame.GlowStyle = style

    local durationLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    durationLabel:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 4, -7)
    durationLabel:SetText("Duration")
    frame.DurationLabel = durationLabel
    local duration = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    duration:SetPoint("LEFT", durationLabel, "RIGHT", 8, 0)
    duration:SetSize(55, 26)
    duration:SetAutoFocus(false)
    duration:SetScript("OnEscapePressed", duration.ClearFocus)
    duration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GUI:CommitEditor() end)
    duration:SetScript("OnTextChanged", function() GUI:ScheduleAutoSave() end)
    frame.Duration = duration
    local durationHint = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    durationHint:SetPoint("TOP", duration, "BOTTOM", 0, -1)
    durationHint:SetText("0 = held")
    frame.DurationHint = durationHint

    local color = Widgets.CreateColorButton(editor, "Glow color")
    color:SetPoint("LEFT", duration, "RIGHT", 24, 0)
    color:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    color:SetScript("OnClick", function(_, button)
        if button == "RightButton" then GUI:ResetGlowColor() else GUI:OpenGlowColor() end
    end)
    color:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Glow color")
        GameTooltip:AddLine("Left-click to choose a color. Right-click to reset it.", 0.75, 0.85, 1, true)
        GameTooltip:Show()
    end)
    color:SetScript("OnLeave", GameTooltip_Hide)
    frame.GlowColor = color

    local tuning = {}
    tuning.countLabel, tuning.count, tuning.countValue =
        Widgets.CreateGlowSlider(editor, "Pixel count", 2, 64, "glowCount", "")
    tuning.countLabel:SetPoint("TOPLEFT", durationLabel, "BOTTOMLEFT", 0, -24)
    tuning.count:SetPoint("TOPLEFT", tuning.countLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowCountLabel, frame.GlowCount, frame.GlowCountValue = tuning.countLabel, tuning.count, tuning.countValue

    tuning.speedLabel, tuning.speed, tuning.speedValue =
        Widgets.CreateGlowSlider(editor, "Speed", 1, 10, "glowSpeed", "")
    tuning.speedLabel:SetPoint("TOPLEFT", tuning.countLabel, "TOPLEFT", 175, 0)
    tuning.speed:SetPoint("TOPLEFT", tuning.speedLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowSpeedLabel, frame.GlowSpeed, frame.GlowSpeedValue = tuning.speedLabel, tuning.speed, tuning.speedValue

    tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue =
        Widgets.CreateGlowSlider(editor, "Thickness", 1, 8, "glowThickness", " px")
    tuning.thicknessLabel:SetPoint("TOPLEFT", tuning.count, "BOTTOMLEFT", -7, -20)
    tuning.thickness:SetPoint("TOPLEFT", tuning.thicknessLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowThicknessLabel, frame.GlowThickness, frame.GlowThicknessValue =
        tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue

    tuning.paddingLabel, tuning.padding, tuning.paddingValue =
        Widgets.CreateGlowSlider(editor, "Padding / size", 0, 20, "glowPadding", " px")
    tuning.paddingLabel:SetPoint("TOPLEFT", tuning.thicknessLabel, "TOPLEFT", 175, 0)
    tuning.padding:SetPoint("TOPLEFT", tuning.paddingLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowPaddingLabel, frame.GlowPadding, frame.GlowPaddingValue =
        tuning.paddingLabel, tuning.padding, tuning.paddingValue

    frame.GlowTuningControls = { tuning.count, tuning.speed, tuning.thickness, tuning.padding }
    frame.GlowTuningElements = {
        tuning.countLabel, tuning.count, tuning.countValue,
        tuning.speedLabel, tuning.speed, tuning.speedValue,
        tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue,
        tuning.paddingLabel, tuning.padding, tuning.paddingValue,
    }

    local reset = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    reset:SetSize(190, 24)
    reset:SetPoint("TOPLEFT", tuning.thickness, "BOTTOMLEFT", -7, -22)
    reset:SetText("Reset Alert Effects")
    reset:GetFontString():SetTextColor(1, 0.30, 0.30)
    reset:SetScript("OnClick", function() GUI:ResetAlertEffects() end)
    frame.ResetAlertEffects = reset

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "effects")
    return {
        title = title, line = line, toggle = toggle,
        glow = glow, glowLabel = glowLabel, styleLabel = styleLabel, style = style,
        durationLabel = durationLabel, duration = duration, durationHint = durationHint,
        color = color, tuning = tuning, reset = reset,
        descriptor = {
            key = "effects", title = title, toggle = toggle, bottom = reset,
            gap = -14, collapseHeight = 192,
            elements = {
                glow, glowLabel, styleLabel, style, durationLabel, duration, durationHint, color,
                tuning.countLabel, tuning.count, tuning.countValue,
                tuning.speedLabel, tuning.speed, tuning.speedValue,
                tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue,
                tuning.paddingLabel, tuning.padding, tuning.paddingValue, reset,
            },
        },
    }
end
