local _, addon = ...

addon.Effects = {
    voice = nil,
    glowGeneration = setmetatable({}, { __mode = "k" }),
    activeGlowTargets = setmetatable({}, { __mode = "k" }),
    glowTargetItems = setmetatable({}, { __mode = "k" }),
}
local Effects = addon.Effects
local Defaults = addon.Defaults

function Effects:GetGlowTarget(item, style)
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and addon.Solo and addon.Solo.displays[entry.cooldownID]
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    if display and settings and settings.solo == true then
        if style == "blizzard" and display.isBar and display.ProcGlowTarget then
            return display.ProcGlowTarget, true
        end
        return display.isBar and display or display.IconClip, true
    end
    return item, false
end

function Effects:CacheVoice()
    local voices = C_VoiceChat.GetTtsVoices()
    self.voice = voices and voices[1] or nil
end

function Effects:Speak(text, rate, volume)
    if not text or text == "" then return false end
    if TextToSpeechFrame_PlayCooldownAlertMessage then
        return pcall(TextToSpeechFrame_PlayCooldownAlertMessage, nil, text, true)
    elseif C_CombatAudioAlert and C_CombatAudioAlert.SpeakText then
        return pcall(
            C_CombatAudioAlert.SpeakText,
            text, Enum.CombatAudioAlertCategory.General, true
        )
    end

    -- Compatibility fallback for clients without the cooldown-alert APIs.
    if not self.voice then self:CacheVoice() end
    if not self.voice or not C_VoiceChat.SpeakText then return false end
    rate = Clamp(tonumber(rate) or Defaults.trigger.speechRate, -10, 10)
    volume = Clamp(tonumber(volume) or Defaults.trigger.ttsVolume, 0, 100)
    return pcall(C_VoiceChat.SpeakText, self.voice.voiceID, text, rate, volume, true)
end

function Effects:ShowGlow(item, settings)
    if not item then return end
    local style = settings.glowStyle or Defaults.trigger.glowStyle
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and addon.Solo and addon.Solo.displays[entry.cooldownID]
    if display and not display.isBar and style == "blizzard" then
        local entrySettings = addon:GetEntrySettings(entry.cooldownID, false)
        if entrySettings and entrySettings.soloCropEnabled == true then style = "pixel" end
    end
    local target, isSolo = self:GetGlowTarget(item, style)
    if not target then return end
    -- Clear the alternate tracked-bar target so changing styles cannot leave
    -- the previous full-bar or icon-only alert behind.
    if display and display.ProcGlowTarget then
        self:HideGlowTarget(target == display and display.ProcGlowTarget or display)
    end
    local generation = (self.glowGeneration[target] or 0) + 1
    self.glowGeneration[target] = generation
    local customStarted = isSolo and addon.Glow and addon.Glow:Start(target, style, settings.color, settings)
    if not customStarted and ActionButtonSpellAlertManager then
        ActionButtonSpellAlertManager:ShowAlert(target)
    end
    self.activeGlowTargets[item] = target
    self.glowTargetItems[target] = item

    local duration = tonumber(settings.glowDuration) or 0
    if duration > 0 then
        C_Timer.After(duration, function()
            if self.glowGeneration[target] == generation then self:HideGlowTarget(target) end
        end)
    end
    return target
end

function Effects:HideGlowTarget(target)
    if not target then return end
    local item = self.glowTargetItems[target]
    if item and self.activeGlowTargets[item] == target then self.activeGlowTargets[item] = nil end
    self.glowTargetItems[target] = nil
    self.glowGeneration[target] = (self.glowGeneration[target] or 0) + 1
    if addon.Glow then addon.Glow:Stop(target) end
    if ActionButtonSpellAlertManager then ActionButtonSpellAlertManager:HideAlert(target) end
end

function Effects:RefreshActiveGlow(item, settings)
    local target = item and self.activeGlowTargets[item]
    if not target then return nil end
    self:HideGlowTarget(target)
    return self:ShowGlow(item, settings)
end

function Effects:IsGlowActive(item)
    return item ~= nil and self.activeGlowTargets[item] ~= nil
end

function Effects:SetGlowAlpha(item, alpha)
    if not item then return end
    local target = self.activeGlowTargets[item]
    if not target then return end
    if addon.Glow then addon.Glow:SetAlpha(target, alpha) end
    if target.SpellActivationAlert then
        target.SpellActivationAlert:SetAlpha(alpha)
    end
end

function Effects:HideGlow(item)
    if not item then return end
    -- The Blizzard item may have been recycled or detached since this glow was
    -- started. Clear the exact cached Solo target before trying live resolution.
    local activeTarget = self.activeGlowTargets[item]
    if activeTarget then
        self:HideGlowTarget(activeTarget)
        return
    end
    self:HideGlowTarget(item)
    local target = self:GetGlowTarget(item)
    if target ~= item then self:HideGlowTarget(target) end
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and addon.Solo and addon.Solo.displays[entry.cooldownID]
    if display and display.ProcGlowTarget then self:HideGlowTarget(display.ProcGlowTarget) end
end

function Effects:Fire(item, entry, trigger, settings)
    local ttsEnabled = settings.ttsEnabled == true
    if ttsEnabled and settings.text and settings.text ~= "" then
        self:Speak(settings.text, settings.speechRate, settings.ttsVolume)
    end
    if settings.audioEnabled and settings.audioSound then
        addon.Audio:Play(settings.audioSound, settings.audioChannel)
    end
    if settings.glow then
        self:ShowGlow(item, settings)
    end
end
