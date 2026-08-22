local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults

function GUI:OnTTSVolumeChanged(value)
    if not self.frame or not self.frame.TTSVolume then return end
    local volume = Clamp(math.floor((tonumber(value) or Defaults.trigger.ttsVolume) + 0.5), 0, 100)
    self.frame.TTSVolumeValue:SetText(volume .. "%")
    if not self.refreshing then self:ScheduleAutoSave() end
end

function GUI:SetAudioChannel(channel)
    self.selectedAudioChannel = channel or "Master"
    self.frame.AudioChannel:GenerateMenu()
    self:CommitEditor()
end

function GUI:UpdateSoundControls()
    if not self.frame then return end
    local triggerEnabled = self.frame.Enabled:GetChecked() == true and self.selectedTrigger ~= nil
    local ttsEnabled = triggerEnabled and self.frame.TTS:GetChecked() == true
    local audioEnabled = triggerEnabled and self.frame.Audio:GetChecked() == true
    self.frame.TextBox:SetEnabled(ttsEnabled)
    self.frame.SpeechRate:SetEnabled(ttsEnabled)
    self.frame.TTSVolume:SetEnabled(ttsEnabled)
    self.frame.TTSVolumeValue:SetEnabled(ttsEnabled)
    self.frame.TTSLabel:SetTextColor(ttsEnabled and 1 or 0.45, ttsEnabled and 0.82 or 0.45, 0, 1)
    self.frame.SpeechRateLabel:SetTextColor(ttsEnabled and 1 or 0.45, ttsEnabled and 0.82 or 0.45, 0, 1)
    self.frame.TTSVolume:SetAlpha(ttsEnabled and 1 or 0.32)
    self.frame.TTSVolumeValue:SetAlpha(ttsEnabled and 1 or 0.32)
    self.frame.AudioDropdown:SetEnabled(audioEnabled)
    self.frame.AudioChannel:SetEnabled(audioEnabled)
    self.frame.AudioPreview:SetEnabled(audioEnabled and self.selectedAudio ~= nil)
    self.frame.AudioPreview:SetAlpha(audioEnabled and self.selectedAudio and 1 or 0.32)
    self.frame.AudioLabel:SetTextColor(audioEnabled and 1 or 0.45, audioEnabled and 0.82 or 0.45, 0, 1)
end

function GUI:OnTTSClicked()
    if self.refreshing then return end
    self:UpdateSoundControls()
    self:CommitEditor()
end

function GUI:OnAudioClicked()
    if self.refreshing then return end
    self:UpdateSoundControls()
    self:CommitEditor()
end

function GUI:SetAudioSound(soundEnum)
    self.selectedAudio = soundEnum
    if self.selected and self.selectedTrigger then
        local settings = addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, true)
        settings.audioSound = soundEnum
        settings.audioChannel = self.selectedAudioChannel or Defaults.trigger.audioChannel
    end
    if self.frame and self.frame.AudioDropdown then
        self.frame.AudioDropdown:GenerateMenu()
        self:UpdateSoundControls()
    end
    self:SetStatus(soundEnum and "Audio selection saved automatically." or "Audio selection cleared.")
end

function GUI:PreviewAudio()
    if not self.selectedAudio then
        self:SetStatus("Choose an audio cue first.")
        return
    end
    addon.Audio:Play(self.selectedAudio, self.selectedAudioChannel)
    self:SetStatus("Audio preview played.")
end

