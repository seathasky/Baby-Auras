local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults
local SetButtonTextWhite = addon.GUIWidgets.SetButtonTextWhite

function GUI:UpdateTestAlertButton()
    if not self.frame or not self.frame.Test then return end
    self.frame.Test:SetText(self.previewMode and "Preview Mode: ON" or "Preview Mode: OFF")
    self.frame.Test:SetButtonState("NORMAL", false)
    if self.frame.Test.ActiveBackground then
        self.frame.Test.ActiveBackground:SetShown(self.previewMode == true)
    end
    SetButtonTextWhite(self.frame.Test)
end

function GUI:GetCurrentTestGlowSettings()
    local saved = self.selected and self.selectedTrigger
        and addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, false) or nil
    return {
        glowDuration = 0,
        glowStyle = self.selectedGlowStyle or Defaults.trigger.glowStyle,
        color = saved and saved.color or Defaults.trigger.color,
        glowCount = math.floor(self.frame.GlowCount:GetValue() + 0.5),
        glowSpeed = math.floor(self.frame.GlowSpeed:GetValue() + 0.5),
        glowThickness = math.floor(self.frame.GlowThickness:GetValue() + 0.5),
        glowPadding = math.floor(self.frame.GlowPadding:GetValue() + 0.5),
    }
end

function GUI:RefreshHeldTestGlow()
    if not self.selected then return end
    local item = addon.Runtime:GetLiveItem(self.selected.cooldownID)
    if not item then
        if self.testGlowTarget then self:ClearPreviewSelection() end
        return
    end
    if not self.frame.Glow:GetChecked() then
        if self.testGlowTarget then
            addon.Effects:HideGlowTarget(self.testGlowTarget)
            self.testGlowTarget = nil
        end
        return
    end
    local settings = self:GetCurrentTestGlowSettings()
    if self.testGlowTarget then
        addon.Effects:HideGlowTarget(self.testGlowTarget)
        self.testGlowTarget = addon.Effects:ShowGlow(item, settings)
        self:UpdateTestAlertButton()
    elseif addon.Effects:IsGlowActive(item) then
        -- A real triggered alert remains a real alert; update its renderer
        -- without changing the Preview Mode button state.
        addon.Effects:RefreshActiveGlow(item, settings)
    elseif self.previewMode then
        -- Preview Mode may be active without a glow target when Glow Alert was
        -- previously off. Starting/enabling it should add the held glow now.
        self.testGlowTarget = addon.Effects:ShowGlow(item, settings)
        self:UpdateTestAlertButton()
    end
end

function GUI:ClearPreviewSelection()
    if self.testGlowTarget then addon.Effects:HideGlowTarget(self.testGlowTarget) end
    self.testGlowTarget = nil
    if self.previewMotionItem then
        addon.Effects:StopZoom(self.previewMotionItem)
        addon.Effects:StopBounce(self.previewMotionItem)
    end
    self.previewMotionItem = nil
end

function GUI:RefreshPreviewSelection()
    if not self.previewMode or not self.selected then return end
    self:ClearPreviewSelection()
    addon.Solo:SetGUIPositionMode(true)
    addon.Solo:SetIconsLocked(false)
    local entrySettings = addon:GetEntrySettings(self.selected.cooldownID, false)
    if entrySettings and entrySettings.solo == true then
        addon.Solo:ToggleTextPreview(self.selected, true)
    end
    local item = addon.Runtime:GetLiveItem(self.selected.cooldownID)
    if self.frame.Glow:GetChecked() and item then
        self.testGlowTarget = addon.Effects:ShowGlow(item, self:GetCurrentTestGlowSettings())
    end
    if self.frame.Zoom:GetChecked() and item then addon.Effects:PlayZoom(item) end
    if self.frame.Bounce:GetChecked() and item then
        addon.Effects:PlayBounce(item, tonumber(self.frame.BounceDuration:GetText()))
    end
    if item and (self.frame.Zoom:GetChecked() or self.frame.Bounce:GetChecked()) then
        self.previewMotionItem = item
    end
    self:UpdateTestAlertButton()
end

function GUI:StopTestGlow(silent)
    local wasActive = self.previewMode == true or self.testGlowTarget ~= nil
    self:ClearPreviewSelection()
    self.previewMode = false
    if self.selected then addon.Solo:ToggleTextPreview(self.selected, false) end
    if wasActive then
        self.stoppingPreviewMode = true
        addon.Solo:SetIconsLocked(true)
        self.stoppingPreviewMode = nil
    end
    self:UpdateTestAlertButton()
    if not silent then self:SetStatus("Preview Mode turned off; Solo icons locked.") end
end

function GUI:TestEditor()
    if not self.selected then return end
    if self.previewMode then
        self:StopTestGlow(false)
        return
    end
    self.previewMode = true
    local item = addon.Runtime:GetLiveItem(self.selected.cooldownID)
    local soundDescription = "No sound selected"
    local textValue = self.frame.TextBox:GetText() or ""
    if self.frame.TTS:GetChecked() and textValue ~= "" then
        addon.Effects:Speak(
            textValue,
            tonumber(self.frame.SpeechRate:GetText()) or Defaults.trigger.speechRate,
            self.frame.TTSVolume:GetValue()
        )
        soundDescription = "TTS preview played"
    elseif self.frame.Audio:GetChecked() then
        addon.Audio:Play(self.selectedAudio, self.selectedAudioChannel)
        soundDescription = self.selectedAudio and "Audio preview played" or "Choose an audio cue first"
    end
    addon.Solo:SetGUIPositionMode(true)
    addon.Solo:SetIconsLocked(false)
    local entrySettings = addon:GetEntrySettings(self.selected.cooldownID, false)
    if entrySettings and entrySettings.solo == true then
        addon.Solo:ToggleTextPreview(self.selected, true)
    end
    if self.frame.Glow:GetChecked() and item then
        self.testGlowTarget = addon.Effects:ShowGlow(item, self:GetCurrentTestGlowSettings())
    end
    if self.frame.Zoom:GetChecked() and item then addon.Effects:PlayZoom(item) end
    if self.frame.Bounce:GetChecked() and item then
        addon.Effects:PlayBounce(item, tonumber(self.frame.BounceDuration:GetText()))
    end
    if item and (self.frame.Zoom:GetChecked() or self.frame.Bounce:GetChecked()) then
        self.previewMotionItem = item
    end
    self:UpdateTestAlertButton()
    self:SetStatus(soundDescription .. "; Preview Mode ON - enabled visual effects are shown for inspection.")
end

