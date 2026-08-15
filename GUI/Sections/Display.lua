local _, addon = ...

addon.GUISections = addon.GUISections or {}
local Display = {}
addon.GUISections.Display = Display

local Widgets = addon.GUIWidgets

local function CreateSlider(parent, minValue, maxValue, width)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(width or 105, 16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minValue))
    slider.High:SetText(tostring(maxValue))
    slider.Text:SetText("")
    return slider
end

function Display:Build(editor, frame)
    local GUI = addon.GUI
    local controls = {}
    local title, line = Widgets.CreateSectionTitle(editor, "DISPLAY")
    title:SetPoint("TOPLEFT", 0, -108)
    frame.DisplayTitle = title

    local panel = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    panel:SetSize(335, 44)
    Widgets.ApplyBackdrop(panel)
    panel:SetBackdropColor(0.02, 0.12, 0.17, 0.96)
    panel:SetBackdropBorderColor(0.2, 0.85, 1, 1)
    frame.SoloPanel = panel

    local solo, soloLabel = Widgets.CreateCheckbox(panel, "Solo this element", 150)
    solo:SetPoint("LEFT", 8, 0)
    solo:SetSize(30, 30)
    soloLabel:SetFontObject(GameFontNormalLarge)
    soloLabel:SetTextColor(0.35, 0.9, 1)
    solo:SetScript("OnClick", function() GUI:OnSoloClicked() end)
    frame.Solo, frame.SoloLabel = solo, soloLabel

    local onTop, onTopLabel = Widgets.CreateCheckbox(panel, "On top", 65)
    onTop:SetPoint("LEFT", panel, "LEFT", 190, 0)
    onTop:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloOnTop", self, "Solo layer preference")
    end)
    frame.SoloOnTop, frame.SoloOnTopLabel = onTop, onTopLabel

    local sizeLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sizeLabel:SetText("Icon size")
    sizeLabel:SetTextColor(1, 1, 1)
    local sizeValue = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sizeValue:SetText("100%")
    sizeValue:SetTextColor(0.42, 0.80, 1)
    local size = CreateSlider(editor, 50, 200, 150)
    size:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 4, -14)
    size:SetValueStep(5)
    sizeLabel:SetPoint("LEFT", size, "RIGHT", 28, 0)
    sizeValue:SetPoint("LEFT", sizeLabel, "RIGHT", 9, 0)
    size:SetScript("OnValueChanged", function(_, value) GUI:OnSoloSizeChanged(value) end)
    frame.SoloSize, frame.SoloSizeLabel, frame.SoloSizeValue = size, sizeLabel, sizeValue

    local cropEnabled, cropEnabledLabel = Widgets.CreateCheckbox(editor, "Icon crop", 100)
    cropEnabled:SetPoint("TOPLEFT", size, "BOTTOMLEFT", -4, -17)
    cropEnabled:SetScript("OnClick", function(self) GUI:OnSoloCropEnabledClicked(self) end)
    frame.SoloCropEnabled, frame.SoloCropEnabledLabel = cropEnabled, cropEnabledLabel

    local function CreateCropSlider(labelText, settingKey, anchor)
        local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -17)
        label:SetText(labelText)
        local slider = CreateSlider(editor, 0, 100, 150)
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        local value = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        value:SetText("0%")
        slider:SetScript("OnValueChanged", function(_, sliderValue)
            GUI:OnSoloCropChanged(settingKey, sliderValue, value, labelText)
        end)
        return label, slider, value
    end

    local cropBottomLabel, cropBottom, cropBottomValue =
        CreateCropSlider("Crop Icon Amount", "soloCropBottom", cropEnabled)
    frame.SoloCropBottom, frame.SoloCropBottomLabel, frame.SoloCropBottomValue =
        cropBottom, cropBottomLabel, cropBottomValue

    local function CreateBarSlider(labelText, settingKey, minValue, maxValue, x, y)
        local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetText(labelText)
        label:SetPoint("TOPLEFT", size, "BOTTOMLEFT", x, y)
        local slider = CreateSlider(editor, minValue, maxValue)
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -5)
        local valueText = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        slider:SetScript("OnValueChanged", function(_, value)
            GUI:OnSoloBarDimensionChanged(settingKey, value, valueText, labelText)
        end)
        return label, slider, valueText
    end

    local bar = {}
    bar.iconLabel, bar.icon, bar.iconValue = CreateBarSlider("Bar icon size", "soloBarIconSize", 16, 96, 0, -22)
    bar.widthLabel, bar.width, bar.widthValue = CreateBarSlider("Bar width", "soloBarWidth", 80, 400, 170, -22)
    bar.heightLabel, bar.height, bar.heightValue = CreateBarSlider("Bar height", "soloBarHeight", 4, 80, 0, -67)
    bar.textLabel, bar.text, bar.textValue = CreateBarSlider("Bar text size", "soloBarTextSize", 8, 32, 170, -67)
    frame.SoloBarIconSize, frame.SoloBarWidth, frame.SoloBarHeight, frame.SoloBarTextSize =
        bar.icon, bar.width, bar.height, bar.text
    bar.match, bar.matchLabel = Widgets.CreateCheckbox(editor, "Match icon to bar height", 180)
    bar.match:SetPoint("TOPLEFT", bar.height, "BOTTOMLEFT", -4, -15)
    bar.match:SetScript("OnClick", function() GUI:OnSoloBarMatchIconClicked() end)
    frame.SoloBarMatchIcon, frame.SoloBarMatchIconLabel = bar.match, bar.matchLabel
    frame.SoloBarIconSizeLabel, frame.SoloBarIconSizeValue = bar.iconLabel, bar.iconValue
    frame.SoloBarElements = {
        bar.iconLabel, bar.icon, bar.iconValue, bar.widthLabel, bar.width, bar.widthValue,
        bar.heightLabel, bar.height, bar.heightValue, bar.textLabel, bar.text, bar.textValue,
        bar.match, bar.matchLabel,
    }
    frame.SoloBarControls = { bar.icon, bar.width, bar.height, bar.text, bar.match }

    local showSwipe, showSwipeLabel = Widgets.CreateCheckbox(editor, "Timer wheel", 105)
    showSwipe:SetPoint("TOPLEFT", cropBottom, "BOTTOMLEFT", -4, -17)
    showSwipe:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloShowSwipe", self, "Timer wheel preference")
    end)
    frame.SoloShowSwipe, frame.SoloShowSwipeLabel = showSwipe, showSwipeLabel
    local showNumbers, showNumbersLabel = Widgets.CreateCheckbox(editor, "Cooldown text", 110)
    showNumbers:SetPoint("TOPLEFT", showSwipe, "TOPLEFT", 170, 0)
    showNumbers:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloShowNumbers", self, "Cooldown text preference")
        GUI:UpdateSoloControls()
    end)
    frame.SoloShowNumbers, frame.SoloShowNumbersLabel = showNumbers, showNumbersLabel
    local keepColored, keepColoredLabel = Widgets.CreateCheckbox(editor, "Keep colored", 110)
    keepColored:SetPoint("TOPLEFT", showSwipe, "BOTTOMLEFT", 0, -3)
    keepColored:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloKeepColored", self, "Cooldown saturation preference")
    end)
    frame.SoloKeepColored, frame.SoloKeepColoredLabel = keepColored, keepColoredLabel
    local classSwipe, classSwipeLabel = Widgets.CreateCheckbox(editor, "Class-color wheel", 125)
    classSwipe:SetPoint("TOPLEFT", keepColored, "TOPLEFT", 170, 0)
    classSwipe:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloClassSwipe", self, "Timer wheel color")
    end)
    frame.SoloClassSwipe, frame.SoloClassSwipeLabel = classSwipe, classSwipeLabel
    local activeBorder, activeBorderLabel = Widgets.CreateCheckbox(editor, "Active-state border", 140)
    activeBorder:SetPoint("TOPLEFT", keepColored, "BOTTOMLEFT", 0, -3)
    activeBorder:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloActiveBorder", self, "Active-state border")
    end)
    frame.SoloActiveBorder, frame.SoloActiveBorderLabel = activeBorder, activeBorderLabel
    local alwaysShow, alwaysShowLabel = Widgets.CreateCheckbox(editor, "Always show", 105)
    alwaysShow:SetPoint("TOPLEFT", activeBorder, "TOPLEFT", 170, 0)
    alwaysShow:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloAlwaysShow", self, "Always-show preference")
        GUI:UpdateSoloControls()
    end)
    frame.SoloAlwaysShow, frame.SoloAlwaysShowLabel = alwaysShow, alwaysShowLabel
    local desaturate, desaturateLabel = Widgets.CreateCheckbox(editor, "Desaturate inactive", 145)
    desaturate:SetPoint("TOPLEFT", activeBorder, "BOTTOMLEFT", 0, -3)
    desaturate:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloDesaturateInactive", self, "Inactive desaturation")
    end)
    frame.SoloDesaturateInactive, frame.SoloDesaturateInactiveLabel = desaturate, desaturateLabel
    local showStacks, showStacksLabel = Widgets.CreateCheckbox(editor, "Stack text", 90)
    showStacks:SetPoint("TOPLEFT", desaturate, "TOPLEFT", 170, 0)
    showStacks:SetScript("OnClick", function(self)
        GUI:OnAppearanceClicked("soloShowStacks", self, "Stack text preference")
        GUI:UpdateSoloControls()
    end)
    frame.SoloShowStacks, frame.SoloShowStacksLabel = showStacks, showStacksLabel

    local opacity = CreateSlider(editor, 0, 100, 150)
    opacity:SetPoint("TOPLEFT", desaturate, "BOTTOMLEFT", 4, -17)
    opacity:SetValueStep(5)
    opacity:SetScript("OnValueChanged", function(_, value) GUI:OnSoloOpacityChanged(value) end)
    frame.SoloOpacity = opacity
    local opacityLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    opacityLabel:SetPoint("LEFT", opacity, "RIGHT", 28, 0)
    opacityLabel:SetText("Icon opacity")
    opacityLabel:SetTextColor(1, 1, 1)
    frame.SoloOpacityLabel = opacityLabel
    local opacityValue = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityValue:SetPoint("LEFT", opacityLabel, "RIGHT", 9, 0)
    opacityValue:SetText("100%")
    opacityValue:SetTextColor(0.42, 0.80, 1)
    frame.SoloOpacityValue = opacityValue

    local function CreateTextSize(labelText, settingKey, defaultText, anchor, x)
        local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -17)
        label:SetText(labelText)
        local slider = CreateSlider(editor, 8, 32)
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 7, -7)
        local value = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        value:SetText(defaultText)
        slider:SetScript("OnValueChanged", function(_, sliderValue)
            GUI:OnSoloTextSizeChanged(settingKey, sliderValue, value, labelText:gsub(" size$", ""))
        end)
        return label, slider, value
    end

    local stackSizeLabel, stackSize, stackSizeValue =
        CreateTextSize("Stack text size", "soloStackFontSize", "14 px", opacity, -4)
    frame.SoloStackSizeLabel, frame.SoloStackSize, frame.SoloStackSizeValue = stackSizeLabel, stackSize, stackSizeValue
    local cooldownSizeLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cooldownSizeLabel:SetPoint("TOPLEFT", stackSizeLabel, "TOPLEFT", 175, 0)
    cooldownSizeLabel:SetText("Cooldown text size")
    local cooldownSize = CreateSlider(editor, 8, 32)
    cooldownSize:SetPoint("TOPLEFT", cooldownSizeLabel, "BOTTOMLEFT", 7, -7)
    local cooldownSizeValue = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cooldownSizeValue:SetPoint("LEFT", cooldownSize, "RIGHT", 8, 0)
    cooldownSizeValue:SetText("16 px")
    cooldownSize:SetScript("OnValueChanged", function(_, value)
        GUI:OnSoloTextSizeChanged("soloCooldownFontSize", value, cooldownSizeValue, "Cooldown text")
    end)
    frame.SoloCooldownSizeLabel, frame.SoloCooldownSize, frame.SoloCooldownSizeValue =
        cooldownSizeLabel, cooldownSize, cooldownSizeValue

    local function WirePosition(positionKey, xBox, yBox, label)
        xBox:SetScript("OnEscapePressed", xBox.ClearFocus)
        yBox:SetScript("OnEscapePressed", yBox.ClearFocus)
        xBox:SetScript("OnEnterPressed", xBox.ClearFocus)
        yBox:SetScript("OnEnterPressed", yBox.ClearFocus)
        xBox:SetScript("OnEditFocusLost", function()
            GUI:CommitSoloTextPosition(positionKey, xBox, yBox, label)
        end)
        yBox:SetScript("OnEditFocusLost", function()
            GUI:CommitSoloTextPosition(positionKey, xBox, yBox, label)
        end)
    end

    local stackPositionLabel, stackXLabel, stackX, stackYLabel, stackY =
        Widgets.CreatePositionInputs(editor, "Stack position")
    stackPositionLabel:SetPoint("TOPLEFT", stackSize, "BOTTOMLEFT", -7, -17)
    frame.SoloStackPositionLabel, frame.SoloStackXLabel = stackPositionLabel, stackXLabel
    frame.SoloStackX, frame.SoloStackYLabel, frame.SoloStackY = stackX, stackYLabel, stackY
    local cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownYLabel, cooldownY =
        Widgets.CreatePositionInputs(editor, "Cooldown position")
    cooldownPositionLabel:SetPoint("TOPLEFT", stackPositionLabel, "BOTTOMLEFT", 0, -13)
    frame.SoloCooldownPositionLabel, frame.SoloCooldownXLabel = cooldownPositionLabel, cooldownXLabel
    frame.SoloCooldownX, frame.SoloCooldownYLabel, frame.SoloCooldownY = cooldownX, cooldownYLabel, cooldownY
    WirePosition("soloStackPosition", stackX, stackY, "Stack text")
    WirePosition("soloCooldownPosition", cooldownX, cooldownY, "Cooldown text")

    local hotkeyLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hotkeyLabel:SetPoint("TOPLEFT", cooldownPositionLabel, "BOTTOMLEFT", 0, -17)
    hotkeyLabel:SetText("Hotkey text")
    frame.SoloHotkeyLabel = hotkeyLabel
    local hotkey = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    hotkey:SetPoint("TOPLEFT", hotkeyLabel, "BOTTOMLEFT", 4, -7)
    hotkey:SetSize(150, 26)
    hotkey:SetAutoFocus(false)
    hotkey:SetMaxLetters(16)
    hotkey:SetScript("OnEscapePressed", hotkey.ClearFocus)
    hotkey:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GUI:OnSoloHotkeyChanged() end)
    hotkey:SetScript("OnTextChanged", function() GUI:OnSoloHotkeyChanged() end)
    frame.SoloHotkey = hotkey
    local hotkeySizeLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hotkeySizeLabel:SetPoint("TOPLEFT", hotkeyLabel, "TOPLEFT", 175, 0)
    hotkeySizeLabel:SetText("Hotkey text size")
    frame.SoloHotkeySizeLabel = hotkeySizeLabel
    local hotkeySize = CreateSlider(editor, 8, 32)
    hotkeySize:SetPoint("TOPLEFT", hotkeySizeLabel, "BOTTOMLEFT", 7, -7)
    frame.SoloHotkeySize = hotkeySize
    local hotkeySizeValue = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hotkeySizeValue:SetPoint("LEFT", hotkeySize, "RIGHT", 8, 0)
    hotkeySizeValue:SetText("14 px")
    frame.SoloHotkeySizeValue = hotkeySizeValue
    hotkeySize:SetScript("OnValueChanged", function(_, value)
        GUI:OnSoloTextSizeChanged("soloHotkeyFontSize", value, hotkeySizeValue, "Hotkey text")
    end)
    local hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyYLabel, hotkeyY =
        Widgets.CreatePositionInputs(editor, "Hotkey position")
    hotkeyPositionLabel:SetPoint("TOPLEFT", hotkey, "BOTTOMLEFT", -4, -13)
    frame.SoloHotkeyPositionLabel, frame.SoloHotkeyXLabel = hotkeyPositionLabel, hotkeyXLabel
    frame.SoloHotkeyX, frame.SoloHotkeyYLabel, frame.SoloHotkeyY = hotkeyX, hotkeyYLabel, hotkeyY
    WirePosition("soloHotkeyPosition", hotkeyX, hotkeyY, "Hotkey text")

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "display")
    controls.title, controls.line, controls.toggle = title, line, toggle
    controls.panel, controls.solo, controls.soloLabel = panel, solo, soloLabel
    controls.onTop, controls.onTopLabel = onTop, onTopLabel
    controls.size, controls.sizeLabel, controls.sizeValue = size, sizeLabel, sizeValue
    controls.cropEnabled, controls.cropEnabledLabel = cropEnabled, cropEnabledLabel
    controls.cropBottom, controls.cropBottomLabel, controls.cropBottomValue = cropBottom, cropBottomLabel, cropBottomValue
    controls.bar = bar
    controls.showSwipe, controls.showSwipeLabel = showSwipe, showSwipeLabel
    controls.showNumbers, controls.showNumbersLabel = showNumbers, showNumbersLabel
    controls.keepColored, controls.keepColoredLabel = keepColored, keepColoredLabel
    controls.classSwipe, controls.classSwipeLabel = classSwipe, classSwipeLabel
    controls.activeBorder, controls.activeBorderLabel = activeBorder, activeBorderLabel
    controls.alwaysShow, controls.alwaysShowLabel = alwaysShow, alwaysShowLabel
    controls.desaturate, controls.desaturateLabel = desaturate, desaturateLabel
    controls.showStacks, controls.showStacksLabel = showStacks, showStacksLabel
    controls.opacity, controls.opacityLabel, controls.opacityValue = opacity, opacityLabel, opacityValue
    controls.stackSizeLabel, controls.stackSize, controls.stackSizeValue = stackSizeLabel, stackSize, stackSizeValue
    controls.cooldownSizeLabel, controls.cooldownSize, controls.cooldownSizeValue =
        cooldownSizeLabel, cooldownSize, cooldownSizeValue
    controls.stackPositionLabel, controls.stackXLabel, controls.stackX = stackPositionLabel, stackXLabel, stackX
    controls.stackYLabel, controls.stackY = stackYLabel, stackY
    controls.cooldownPositionLabel, controls.cooldownXLabel, controls.cooldownX =
        cooldownPositionLabel, cooldownXLabel, cooldownX
    controls.cooldownYLabel, controls.cooldownY = cooldownYLabel, cooldownY
    controls.hotkeyLabel, controls.hotkey, controls.hotkeySizeLabel = hotkeyLabel, hotkey, hotkeySizeLabel
    controls.hotkeySize, controls.hotkeySizeValue = hotkeySize, hotkeySizeValue
    controls.hotkeyPositionLabel, controls.hotkeyXLabel, controls.hotkeyX = hotkeyPositionLabel, hotkeyXLabel, hotkeyX
    controls.hotkeyYLabel, controls.hotkeyY = hotkeyYLabel, hotkeyY
    controls.descriptor = {
        key = "display", title = title, toggle = toggle, bottom = hotkeyPositionLabel,
        gap = -17, collapseHeight = 410,
        elements = {
            panel, solo, soloLabel, onTop, onTopLabel, size, sizeLabel, sizeValue,
            cropEnabled, cropEnabledLabel,
            cropBottomLabel, cropBottom, cropBottomValue,
            bar.iconLabel, bar.icon, bar.iconValue, bar.widthLabel, bar.width, bar.widthValue,
            bar.heightLabel, bar.height, bar.heightValue, bar.textLabel, bar.text, bar.textValue,
            bar.match, bar.matchLabel, showSwipe, showSwipeLabel, showNumbers, showNumbersLabel,
            keepColored, keepColoredLabel, classSwipe, classSwipeLabel, activeBorder, activeBorderLabel,
            alwaysShow, alwaysShowLabel, desaturate, desaturateLabel, showStacks, showStacksLabel,
            opacity, opacityLabel, opacityValue, stackSizeLabel, stackSize, stackSizeValue,
            cooldownSizeLabel, cooldownSize, cooldownSizeValue,
            stackPositionLabel, stackXLabel, stackX, stackYLabel, stackY,
            cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownYLabel, cooldownY,
            hotkeyLabel, hotkey, hotkeySizeLabel, hotkeySize, hotkeySizeValue,
            hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyYLabel, hotkeyY,
        },
    }
    return controls
end
