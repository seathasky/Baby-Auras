local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults
local GetSavedColor = addon.GUIWidgets.GetSavedColor
local SetColorButtonColor = addon.GUIWidgets.SetColorButtonColor
local SetButtonTextWhite = addon.GUIWidgets.SetButtonTextWhite

local TriggerButtonNames = {
    [Enum.CooldownViewerAlertEventType.Available] = "Ready",
    [Enum.CooldownViewerAlertEventType.OnCooldown] = "Started",
    [Enum.CooldownViewerAlertEventType.ChargeGained] = "Charge Gained",
    [Enum.CooldownViewerAlertEventType.OnAuraApplied] = "Aura Gained",
    [Enum.CooldownViewerAlertEventType.OnAuraRemoved] = "Aura Lost",
    [Enum.CooldownViewerAlertEventType.PandemicTime] = "Pandemic",
}

local function FitSelectedName(frame, text)
    local label = frame.SelectedName
    local font = frame.SelectedNameFont
    if not label or not font or not font.path then
        if label then label:SetText(text) end
        return
    end

    local availableWidth = label:GetWidth()
    local fontSize = font.size or 16
    label:SetFont(font.path, fontSize, font.flags)
    label:SetText(text)

    local textWidth
    if label.GetUnboundedStringWidth then
        textWidth = label:GetUnboundedStringWidth()
    else
        label:SetWidth(1000)
        textWidth = label:GetStringWidth()
        label:SetWidth(availableWidth)
    end
    if textWidth and textWidth > availableWidth then
        fontSize = math.max(8, math.floor(fontSize * availableWidth / textWidth))
        label:SetFont(font.path, fontSize, font.flags)
    end
end

function GUI:GetClassStatusText()
    local className, classFile = UnitClass("player")
    local specializationIndex = GetSpecialization and GetSpecialization()
    local specializationName = specializationIndex and select(2, GetSpecializationInfo(specializationIndex))
    local color = classFile and RAID_CLASS_COLORS[classFile]
    local classText = className or "Unknown"
    local specializationText = specializationName or "No Spec"
    if color then
        local hex = ("%02x%02x%02x"):format(
            math.floor(color.r * 255 + 0.5),
            math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5)
        )
        return "|cff" .. hex .. specializationText .. "  " .. classText .. "|r"
    end
    return specializationText .. "  " .. classText
end

function GUI:UpdateClassStatusIcon(texture)
    if not texture then return end
    local _, classFile = UnitClass("player")
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        texture:Show()
    else
        texture:Hide()
    end
end

function GUI:RefreshEditor(message)
    if not self.frame then return end
    local frame = self.frame
    local entry = self.selected
    self.refreshing = true
    frame.EditorScroll:SetShown(entry ~= nil)
    frame.Editor:SetShown(entry ~= nil)
    frame.SelectedHeader:SetShown(entry ~= nil)
    frame.Empty:SetShown(entry == nil)
    if not entry then
        frame.Empty:SetText("Choose a live Cooldown Manager icon on the left.")
        self.refreshing = false
        return
    end

    self:ResetEditorSectionVisibility()

    frame.SelectedIcon:SetTexture(addon.Catalog:GetDisplayIcon(entry))
    local triggerName = self.selectedTrigger and addon.TriggerNames[self.selectedTrigger]
    FitSelectedName(frame, entry.name .. (triggerName and " (" .. triggerName .. ")" or ""))
    local entrySettings = addon:GetEntrySettings(entry.cooldownID, false)
    local timerStatus = ""
    local auraTriggers = entry.validTriggers and (
        entry.validTriggers[Enum.CooldownViewerAlertEventType.OnAuraApplied]
        or entry.validTriggers[Enum.CooldownViewerAlertEventType.OnAuraRemoved]
    )
    if auraTriggers and entrySettings and entrySettings.solo == true then
        local display = addon.Solo.displays[entry.cooldownID]
        if display and display.LiveCooldown then
            timerStatus = "|cFF44FF77TIMER: LIVE|r"
        elseif display and display.liveCooldownAttachFailed then
            timerStatus = "|cFFFF5555TIMER: BLOCKED|r"
        else
            timerStatus = "|cFFFFCC44TIMER: PENDING|r"
        end
    end
    frame.SelectedID:SetText("spellID " .. entry.spellID .. "  -  cooldownID " .. entry.cooldownID)
    frame.SelectedTimer:SetText(timerStatus)
    frame.SelectedTimer:SetShown(timerStatus ~= "")
    frame.IconSpellID:SetText(entrySettings and entrySettings.customIconSpellID or "")
    local isPrismaticBolt = entry.cooldownID == 198408
    frame.IconLabel:SetText(isPrismaticBolt
        and "Custom icon spell ID (overrides choice below)"
        or "Custom icon spell ID (blank = Blizzard icon)")
    frame.PrismaticIcon:SetShown(isPrismaticBolt)
    frame.PrismaticIconLabel:SetShown(isPrismaticBolt)
    frame.PrismaticIcon:SetChecked(isPrismaticBolt and (not entrySettings or entrySettings.showPrismaticBoltIcon ~= false))
    frame.Message:ClearAllPoints()
    frame.Message:SetPoint("TOPLEFT", frame.IconSpellID, "BOTTOMLEFT", -4, isPrismaticBolt and -40 or -16)
    local soloEligible = addon.Solo:IsEligible(entry)
    frame.SoloPanel:SetShown(soloEligible)
    frame.Solo:SetShown(soloEligible)
    frame.SoloLabel:SetShown(soloEligible)
    for _, element in ipairs(frame.SoloEligibilityElements or {}) do element:SetShown(soloEligible) end
    frame.Solo:SetChecked(entrySettings and entrySettings.solo == true)
    frame.SoloOnTop:SetChecked(entrySettings and entrySettings.soloOnTop == true)
    frame.SoloSize:SetShown(soloEligible)
    frame.SoloSizeLabel:SetShown(soloEligible)
    frame.SoloSizeValue:SetShown(soloEligible)
    frame.SoloSize:SetValue(entrySettings and entrySettings.soloScale or Defaults.soloScale)
    local liveItem = addon.Runtime:GetLiveItem(entry.cooldownID)
    local isTrackedBar = liveItem and addon.Solo:IsTrackedBarItem(liveItem) or false
    frame.ActiveTrackedBar = isTrackedBar
    frame.SoloSizeLabel:SetText(isTrackedBar and "Global size" or "Icon size")
    local showCrop = soloEligible and not isTrackedBar
    frame.SoloCrop:SetShown(showCrop)
    frame.SoloCropLabel:SetShown(showCrop)
    frame.SoloCropAmount:SetShown(showCrop)
    frame.SoloCropValue:SetShown(showCrop)
    frame.SoloCrop:SetChecked(entrySettings and entrySettings.soloCropEnabled == true)
    frame.SoloCropAmount:SetValue(entrySettings and entrySettings.soloCropPercent
        or Defaults.soloAppearance.cropPercent)
    for _, element in ipairs(frame.SoloBarElements or {}) do element:SetShown(isTrackedBar) end
    frame.SoloShowSwipe:ClearAllPoints()
    if isTrackedBar then
        frame.SoloShowSwipe:SetPoint("TOPLEFT", frame.SoloSize, "BOTTOMLEFT", -4, -147)
    else
        frame.SoloShowSwipe:SetPoint("TOPLEFT", frame.SoloCrop, "BOTTOMLEFT", 0, -3)
    end
    if isTrackedBar then
        local sourceHeight = liveItem:GetHeight()
        local sourceWidth = liveItem:GetWidth()
        frame.SoloBarIconSize:SetValue(entrySettings and entrySettings.soloBarIconSize or math.max(24, sourceHeight))
        frame.SoloBarWidth:SetValue(entrySettings and entrySettings.soloBarWidth
            or math.max(80, sourceWidth - sourceHeight - 2))
        frame.SoloBarHeight:SetValue(entrySettings and entrySettings.soloBarHeight
            or math.max(4, sourceHeight - 10))
        frame.SoloBarTextSize:SetValue(entrySettings and entrySettings.soloBarTextSize
            or Defaults.soloBarAppearance.textSize)
        frame.SoloBarMatchIcon:SetChecked(not entrySettings or entrySettings.soloBarMatchIconHeight ~= false)
    end
    frame.SoloOpacity:SetValue(entrySettings and entrySettings.soloOpacity or Defaults.soloAppearance.opacity)
    frame.SoloStackSize:SetValue(entrySettings and entrySettings.soloStackFontSize or Defaults.soloAppearance.stackFontSize)
    frame.SoloCooldownSize:SetValue(entrySettings and entrySettings.soloCooldownFontSize or Defaults.soloAppearance.cooldownFontSize)
    frame.SoloHotkeySize:SetValue(entrySettings and entrySettings.soloHotkeyFontSize or Defaults.soloAppearance.hotkeyFontSize)
    frame.SoloHotkey:SetText(entrySettings and entrySettings.soloHotkey or Defaults.soloAppearance.hotkey)
    local stackX, stackY = addon.Solo:GetTextPosition(entry, "soloStackPosition")
    frame.SoloStackX:SetText(tostring(math.floor(stackX + 0.5)))
    frame.SoloStackY:SetText(tostring(math.floor(stackY + 0.5)))
    local cooldownX, cooldownY = addon.Solo:GetTextPosition(entry, "soloCooldownPosition")
    frame.SoloCooldownX:SetText(tostring(math.floor(cooldownX + 0.5)))
    frame.SoloCooldownY:SetText(tostring(math.floor(cooldownY + 0.5)))
    local hotkeyX, hotkeyY = addon.Solo:GetTextPosition(entry, "soloHotkeyPosition")
    frame.SoloHotkeyX:SetText(tostring(math.floor(hotkeyX + 0.5)))
    frame.SoloHotkeyY:SetText(tostring(math.floor(hotkeyY + 0.5)))
    frame.SoloShowSwipe:SetChecked(not entrySettings or entrySettings.soloShowSwipe ~= false)
    frame.SoloShowNumbers:SetChecked(not entrySettings or entrySettings.soloShowNumbers ~= false)
    frame.SoloShowStacks:SetChecked(not entrySettings or entrySettings.soloShowStacks ~= false)
    frame.SoloClassSwipe:SetChecked(entrySettings and entrySettings.soloClassSwipe == true)
    frame.SoloKeepColored:SetChecked(entrySettings and entrySettings.soloKeepColored == true)
    frame.SoloActiveBorder:SetChecked(entrySettings and entrySettings.soloActiveBorder == true)
    frame.SoloAlwaysShow:SetChecked(entrySettings and entrySettings.soloAlwaysShow == true)
    frame.SoloDesaturateInactive:SetChecked(entrySettings and entrySettings.soloDesaturateInactive == true)
    local blackBorderChecked
    if entrySettings and entrySettings.soloBlackBorder ~= nil then
        blackBorderChecked = entrySettings.soloBlackBorder == true
    else
        blackBorderChecked = not isTrackedBar
    end
    frame.SoloBlackBorder:SetChecked(blackBorderChecked)
    frame.SoloBorderSize:SetValue(entrySettings and entrySettings.soloBorderPixels or Defaults.soloAppearance.borderPixels)
    for _, element in ipairs(frame.SoloBarThemeElements or {}) do element:SetShown(isTrackedBar) end
    frame.SoloFontLabel:ClearAllPoints()
    frame.SoloFontLabel:SetPoint("TOPLEFT",
        isTrackedBar and frame.SoloBarFillColor or frame.SoloBlackBorder,
        "BOTTOMLEFT", 4, isTrackedBar and -10 or -10)
    SetColorButtonColor(frame.SoloBarFillColor,
        GetSavedColor(entrySettings, "soloBarFillColor", "barFillColor"))
    SetColorButtonColor(frame.SoloBarProgressColor,
        GetSavedColor(entrySettings, "soloBarProgressColor", "barProgressColor"))
    frame.SoloBarTextColor:SetShown(isTrackedBar)
    frame.ResetSoloTextColors:ClearAllPoints()
    frame.ResetSoloTextColors:SetPoint("TOPLEFT",
        isTrackedBar and frame.SoloBarTextColor or frame.SoloStackColor,
        "BOTTOMLEFT", 0, -7)
    SetColorButtonColor(frame.SoloBarTextColor,
        GetSavedColor(entrySettings, "soloBarTextColor", "barTextColor"))
    frame.SoloFont:GenerateMenu()
    SetColorButtonColor(frame.SoloStackColor, GetSavedColor(entrySettings, "soloStackColor", "stackColor"))
    SetColorButtonColor(frame.SoloCooldownColor, GetSavedColor(entrySettings, "soloCooldownColor", "cooldownColor"))
    SetColorButtonColor(frame.SoloHotkeyColor, GetSavedColor(entrySettings, "soloHotkeyColor", "hotkeyColor"))

    if not self.selectedTrigger then
        frame.Trigger:SetText("No supported triggers")
        frame.Trigger:Show()
        frame.TriggerHint:Show()
        for _, button in ipairs(frame.EventTriggerButtons) do button:Hide() end
        frame.Enabled:SetChecked(false)
        frame.Glow:SetChecked(false)
        frame.TTS:SetChecked(false)
        frame.Audio:SetChecked(false)
        frame.TextBox:SetText("")
        frame.SpeechRate:SetText("0")
        self:UpdateTriggerGate()
        self.refreshing = false
        return
    end

    local settings = addon:GetTriggerSettings(entry.cooldownID, self.selectedTrigger, false)
    local availableTriggers = self:GetAvailableTriggers(entry)
    frame.Trigger:Hide()
    frame.TriggerHint:Hide()
    local buttonCount = #availableTriggers
    local gap = 6
    local rowWidth = 335
    local buttonWidth = (rowWidth - (gap * math.max(0, buttonCount - 1))) / math.max(1, buttonCount)
    for index, button in ipairs(frame.EventTriggerButtons) do
        local trigger = availableTriggers[index]
        button:SetShown(trigger ~= nil)
        if trigger then
            button.trigger = trigger
            button:ClearAllPoints()
            if index == 1 then
                button:SetPoint("TOPLEFT", frame.Trigger)
            else
                button:SetPoint("LEFT", frame.EventTriggerButtons[index - 1], "RIGHT", gap, 0)
            end
            button:SetSize(buttonWidth, 26)
            button:SetText(TriggerButtonNames[trigger] or addon.TriggerNames[trigger] or tostring(trigger))
            button:GetFontString():SetFontObject(buttonCount >= 3 and GameFontNormalSmall or GameFontNormal)
            local selected = trigger == self.selectedTrigger
            button:SetAlpha(selected and 1 or 0.72)
            button:GetFontString():SetTextColor(1, 1, 1)
        end
    end
    frame.Enabled:SetChecked(settings and settings.enabled or false)
    frame.Zoom:SetChecked(settings and settings.zoom == true or false)
    frame.Bounce:SetChecked(settings and settings.bounce == true or false)
    frame.Glow:SetChecked(settings and settings.glow or false)
    self.selectedGlowStyle = settings and settings.glowStyle or Defaults.trigger.glowStyle
    local cropEnabled = not isTrackedBar and entrySettings and entrySettings.soloCropEnabled == true
    if (isTrackedBar or cropEnabled) and self.selectedGlowStyle == "blizzard" then
        if cropEnabled and settings then settings.soloCropPreviousGlowStyle = "blizzard" end
        self.selectedGlowStyle = "pixel"
        if settings then settings.glowStyle = "pixel" end
    end
    frame.GlowStyle:GenerateMenu()
    SetColorButtonColor(frame.GlowColor, settings and settings.color or Defaults.trigger.color)
    self:RefreshGlowTuningControls(settings)
    frame.Duration:SetText(tostring(settings and settings.glowDuration or Defaults.trigger.glowDuration))
    frame.BounceDuration:SetText(tostring(settings and settings.bounceDuration or Defaults.trigger.bounceDuration))
    frame.TextBox:SetText(settings and settings.text or (entry.name .. " " .. (addon.TriggerNames[self.selectedTrigger] or "")))
    frame.SpeechRate:SetText(tostring(settings and settings.speechRate or Defaults.trigger.speechRate))
    frame.TTSVolume:SetValue(settings and settings.ttsVolume or Defaults.trigger.ttsVolume)
    local ttsEnabled = settings and settings.ttsEnabled == true or Defaults.trigger.ttsEnabled
    local audioEnabled = settings and settings.audioEnabled == true or false
    frame.TTS:SetChecked(ttsEnabled)
    frame.Audio:SetChecked(audioEnabled)
    self.selectedAudio = settings and settings.audioSound or nil
    self.selectedAudioChannel = settings and settings.audioChannel or Defaults.trigger.audioChannel
    frame.AudioDropdown:GenerateMenu()
    frame.AudioChannel:GenerateMenu()
    self:UpdateTriggerGate()
    frame.Message:SetText(message or "Live Blizzard Cooldown Manager frame detected.")
    self.refreshing = false
    self:ApplyEditorSectionLayout()
end

function GUI:Refresh()
    if not self.frame or not self.frame.BabyAurasReady then return end
    self.frame.ClassStatus:SetText(self:GetClassStatusText())
    if self.frame.ClassStatusGroup then
        self.frame.ClassStatusGroup:SetWidth(21 + 7 + self.frame.ClassStatus:GetStringWidth())
        self.frame.ClassStatus:SetWidth(self.frame.ClassStatus:GetStringWidth() + 2)
    end
    self:UpdateClassStatusIcon(self.frame.ClassStatusIcon)
    if self.selected then self.selected = addon.Catalog:Get(self.selected.cooldownID) end
    addon.Navigation:Refresh(self.selected and self.selected.cooldownID)
    addon.Solo:RefreshEditSelection()
    self:RefreshEditor()
    local function WhitenVisibleButtons(parent)
        for _, child in ipairs({ parent:GetChildren() }) do
            if child.GetObjectType and child:GetObjectType() == "Button" then
                SetButtonTextWhite(child)
            end
            if child.GetChildren then WhitenVisibleButtons(child) end
        end
    end
    WhitenVisibleButtons(self.frame)
end
