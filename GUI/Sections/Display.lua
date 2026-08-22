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
    title:SetPoint("TOPLEFT", 0, -130)
    frame.DisplayTitle = title

    local panel = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    panel:SetSize(395, 44)
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
    sizeLabel:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 4, -12)
    local size = CreateSlider(editor, 50, 200, 145)
    size:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 7, -7)
    size:SetValueStep(5)
    size:SetScript("OnValueChanged", function(_, value) GUI:OnSoloSizeChanged(value) end)
    local sizeValue = Widgets.AttachSliderInput(editor, size, { suffix = "%" })
    frame.SoloSize, frame.SoloSizeLabel, frame.SoloSizeValue = size, sizeLabel, sizeValue

    local crop, cropLabel = Widgets.CreateCheckbox(editor, "Crop icon from bottom", 155)
    crop:SetPoint("TOPLEFT", size, "BOTTOMLEFT", -4, -20)
    crop:SetScript("OnClick", function() GUI:OnSoloCropClicked() end)
    frame.SoloCrop, frame.SoloCropLabel = crop, cropLabel
    local cropAmount = CreateSlider(editor, 0, 50, 80)
    cropAmount:SetPoint("TOPLEFT", crop, "TOPLEFT", 185, 2)
    cropAmount:SetValueStep(5)
    cropAmount:SetScript("OnValueChanged", function(_, value) GUI:OnSoloCropChanged(value) end)
    frame.SoloCropAmount = cropAmount
    local cropValue = Widgets.AttachSliderInput(editor, cropAmount, { suffix = "%", width = 40 })
    frame.SoloCropValue = cropValue

    local function CreateBarSlider(labelText, settingKey, minValue, maxValue, x, y)
        local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetText(labelText)
        label:SetPoint("TOPLEFT", size, "BOTTOMLEFT", x, y)
        local slider = CreateSlider(editor, minValue, maxValue)
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -5)
        local valueText
        slider:SetScript("OnValueChanged", function(_, value)
            GUI:OnSoloBarDimensionChanged(settingKey, value, valueText, labelText)
        end)
        valueText = Widgets.AttachSliderInput(editor, slider, { suffix = " px", width = 46 })
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
    frame.SoloBarControls = {
        bar.icon, bar.iconValue, bar.width, bar.widthValue,
        bar.height, bar.heightValue, bar.text, bar.textValue, bar.match,
    }

    local showSwipe, showSwipeLabel = Widgets.CreateCheckbox(editor, "Timer wheel", 105)
    showSwipe:SetPoint("TOPLEFT", crop, "BOTTOMLEFT", 0, -3)
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

    local opacityLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    opacityLabel:SetPoint("TOPLEFT", desaturate, "BOTTOMLEFT", 4, -17)
    opacityLabel:SetText("Icon opacity")
    opacityLabel:SetTextColor(1, 1, 1)
    frame.SoloOpacityLabel = opacityLabel
    local opacity = CreateSlider(editor, 0, 100, 145)
    opacity:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 7, -7)
    opacity:SetValueStep(5)
    opacity:SetScript("OnValueChanged", function(_, value) GUI:OnSoloOpacityChanged(value) end)
    frame.SoloOpacity = opacity
    local opacityValue = Widgets.AttachSliderInput(editor, opacity, { suffix = "%" })
    frame.SoloOpacityValue = opacityValue

    local function CreateTextSize(labelText, settingKey, anchor, x)
        local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -28)
        label:SetText(labelText)
        local slider = CreateSlider(editor, 8, 32)
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 7, -7)
        local value
        slider:SetScript("OnValueChanged", function(_, sliderValue)
            GUI:OnSoloTextSizeChanged(settingKey, sliderValue, value, labelText:gsub(" size$", ""))
        end)
        value = Widgets.AttachSliderInput(editor, slider, { suffix = " px", width = 46 })
        return label, slider, value
    end

    local stackSizeLabel, stackSize, stackSizeValue =
        CreateTextSize("Stack text size", "soloStackFontSize", opacity, -4)
    frame.SoloStackSizeLabel, frame.SoloStackSize, frame.SoloStackSizeValue = stackSizeLabel, stackSize, stackSizeValue
    local cooldownSizeLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cooldownSizeLabel:SetPoint("TOPLEFT", stackSizeLabel, "TOPLEFT", 175, 0)
    cooldownSizeLabel:SetText("Cooldown text size")
    local cooldownSize = CreateSlider(editor, 8, 32)
    cooldownSize:SetPoint("TOPLEFT", cooldownSizeLabel, "BOTTOMLEFT", 7, -7)
    local cooldownSizeValue
    cooldownSize:SetScript("OnValueChanged", function(_, value)
        GUI:OnSoloTextSizeChanged("soloCooldownFontSize", value, cooldownSizeValue, "Cooldown text")
    end)
    cooldownSizeValue = Widgets.AttachSliderInput(editor, cooldownSize, { suffix = " px", width = 46 })
    frame.SoloCooldownSizeLabel, frame.SoloCooldownSize, frame.SoloCooldownSizeValue =
        cooldownSizeLabel, cooldownSize, cooldownSizeValue

    local function WirePositionSliders(positionKey, xSlider, xInput, ySlider, yInput, label)
        local syncing
        local sliderMin, sliderMax = Widgets.TEXT_POSITION_SLIDER_MIN, Widgets.TEXT_POSITION_SLIDER_MAX
        local function CommitSlider(slider, input)
            if GUI.refreshing or syncing then return end
            syncing = true
            input:SetText(tostring(math.floor((slider:GetValue() or 0) + 0.5)))
            syncing = nil
            GUI:CommitSoloTextPosition(positionKey, xInput, yInput, label)
        end
        local function CommitInput()
            if GUI.refreshing or syncing then return end
            GUI:CommitSoloTextPosition(positionKey, xInput, yInput, label)
            local x, y = tonumber(xInput:GetText()), tonumber(yInput:GetText())
            if not x or not y then return end
            syncing = true
            xSlider:SetValue(Clamp(x, sliderMin, sliderMax))
            ySlider:SetValue(Clamp(y, sliderMin, sliderMax))
            syncing = nil
        end
        xSlider:SetScript("OnValueChanged", function() CommitSlider(xSlider, xInput) end)
        ySlider:SetScript("OnValueChanged", function() CommitSlider(ySlider, yInput) end)
        for _, input in ipairs({ xInput, yInput }) do
            input:SetScript("OnEscapePressed", input.ClearFocus)
            input:SetScript("OnEnterPressed", input.ClearFocus)
            input:SetScript("OnEditFocusLost", CommitInput)
        end
    end

    local stackPositionLabel, stackXLabel, stackX, stackXValue, stackYLabel, stackY, stackYValue =
        Widgets.CreatePositionSliders(editor, "Stack text position")
    stackPositionLabel:SetPoint("TOPLEFT", stackSize, "BOTTOMLEFT", -7, -28)
    frame.SoloStackPositionLabel, frame.SoloStackXLabel = stackPositionLabel, stackXLabel
    frame.SoloStackX, frame.SoloStackXValue, frame.SoloStackYLabel, frame.SoloStackY, frame.SoloStackYValue =
        stackX, stackXValue, stackYLabel, stackY, stackYValue
    local cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue =
        Widgets.CreatePositionSliders(editor, "Cooldown text position")
    cooldownPositionLabel:SetPoint("TOPLEFT", stackPositionLabel, "TOPLEFT", 175, 0)
    frame.SoloCooldownPositionLabel, frame.SoloCooldownXLabel = cooldownPositionLabel, cooldownXLabel
    frame.SoloCooldownX, frame.SoloCooldownXValue, frame.SoloCooldownYLabel, frame.SoloCooldownY, frame.SoloCooldownYValue =
        cooldownX, cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue
    WirePositionSliders("soloStackPosition", stackX, stackXValue, stackY, stackYValue, "Stack text")
    WirePositionSliders("soloCooldownPosition", cooldownX, cooldownXValue, cooldownY, cooldownYValue, "Cooldown text")

    local hotkeyLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hotkeyLabel:SetPoint("TOPLEFT", stackYLabel, "BOTTOMLEFT", 0, -24)
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
    local hotkeySizeValue
    hotkeySize:SetScript("OnValueChanged", function(_, value)
        GUI:OnSoloTextSizeChanged("soloHotkeyFontSize", value, hotkeySizeValue, "Hotkey text")
    end)
    hotkeySizeValue = Widgets.AttachSliderInput(editor, hotkeySize, { suffix = " px", width = 46 })
    frame.SoloHotkeySizeValue = hotkeySizeValue
    local hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue, hotkeyYLabel, hotkeyY, hotkeyYValue =
        Widgets.CreatePositionSliders(editor, "Hotkey position")
    hotkeyPositionLabel:SetPoint("TOPLEFT", hotkey, "BOTTOMLEFT", -4, -18)
    frame.SoloHotkeyPositionLabel, frame.SoloHotkeyXLabel = hotkeyPositionLabel, hotkeyXLabel
    frame.SoloHotkeyX, frame.SoloHotkeyXValue = hotkeyX, hotkeyXValue
    frame.SoloHotkeyYLabel, frame.SoloHotkeyY, frame.SoloHotkeyYValue = hotkeyYLabel, hotkeyY, hotkeyYValue
    WirePositionSliders("soloHotkeyPosition", hotkeyX, hotkeyXValue, hotkeyY, hotkeyYValue, "Hotkey text")

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "display")
    controls.title, controls.line, controls.toggle = title, line, toggle
    controls.panel, controls.solo, controls.soloLabel = panel, solo, soloLabel
    controls.onTop, controls.onTopLabel = onTop, onTopLabel
    controls.size, controls.sizeLabel, controls.sizeValue = size, sizeLabel, sizeValue
    controls.crop, controls.cropLabel = crop, cropLabel
    controls.cropAmount, controls.cropValue = cropAmount, cropValue
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
    controls.stackPositionLabel, controls.stackXLabel, controls.stackX, controls.stackXValue =
        stackPositionLabel, stackXLabel, stackX, stackXValue
    controls.stackYLabel, controls.stackY, controls.stackYValue = stackYLabel, stackY, stackYValue
    controls.cooldownPositionLabel, controls.cooldownXLabel, controls.cooldownX =
        cooldownPositionLabel, cooldownXLabel, cooldownX
    controls.cooldownXValue, controls.cooldownYLabel, controls.cooldownY, controls.cooldownYValue =
        cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue
    controls.hotkeyLabel, controls.hotkey, controls.hotkeySizeLabel = hotkeyLabel, hotkey, hotkeySizeLabel
    controls.hotkeySize, controls.hotkeySizeValue = hotkeySize, hotkeySizeValue
    controls.hotkeyPositionLabel, controls.hotkeyXLabel, controls.hotkeyX, controls.hotkeyXValue =
        hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue
    controls.hotkeyYLabel, controls.hotkeyY, controls.hotkeyYValue = hotkeyYLabel, hotkeyY, hotkeyYValue
    controls.descriptor = {
        key = "display", title = title, toggle = toggle, bottom = hotkeyYLabel,
        gap = -17, collapseHeight = 560,
        elements = {
            panel, solo, soloLabel, onTop, onTopLabel, size, sizeLabel, sizeValue,
            crop, cropLabel, cropAmount, cropValue,
            bar.iconLabel, bar.icon, bar.iconValue, bar.widthLabel, bar.width, bar.widthValue,
            bar.heightLabel, bar.height, bar.heightValue, bar.textLabel, bar.text, bar.textValue,
            bar.match, bar.matchLabel, showSwipe, showSwipeLabel, showNumbers, showNumbersLabel,
            keepColored, keepColoredLabel, classSwipe, classSwipeLabel, activeBorder, activeBorderLabel,
            alwaysShow, alwaysShowLabel, desaturate, desaturateLabel, showStacks, showStacksLabel,
            opacity, opacityLabel, opacityValue, stackSizeLabel, stackSize, stackSizeValue,
            cooldownSizeLabel, cooldownSize, cooldownSizeValue,
            stackPositionLabel, stackXLabel, stackX, stackXValue, stackYLabel, stackY, stackYValue,
            cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue,
            hotkeyLabel, hotkey, hotkeySizeLabel, hotkeySize, hotkeySizeValue,
            hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue,
            hotkeyYLabel, hotkeyY, hotkeyYValue,
        },
    }
    return controls
end
