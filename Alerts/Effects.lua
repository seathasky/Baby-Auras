local _, addon = ...

addon.Effects = {
    voice = nil,
    glowGeneration = setmetatable({}, { __mode = "k" }),
    activeGlowTargets = setmetatable({}, { __mode = "k" }),
    glowTargetItems = setmetatable({}, { __mode = "k" }),
    forcedGlowDisplays = setmetatable({}, { __mode = "k" }),
    zoomAnimations = setmetatable({}, { __mode = "k" }),
    activeZoomTargets = setmetatable({}, { __mode = "k" }),
    activeZoomCompanions = setmetatable({}, { __mode = "k" }),
    forcedZoomDisplays = setmetatable({}, { __mode = "k" }),
    bounceAnimations = setmetatable({}, { __mode = "k" }),
    activeBounceTargets = setmetatable({}, { __mode = "k" }),
    activeBounceCompanions = setmetatable({}, { __mode = "k" }),
    forcedBounceDisplays = setmetatable({}, { __mode = "k" }),
    bounceGeneration = setmetatable({}, { __mode = "k" }),
}
local Effects = addon.Effects
local Defaults = addon.Defaults

function Effects:GetGlowTarget(item, style)
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and addon.Solo and addon.Solo.displays[entry.cooldownID]
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    if display and settings and addon.SoloUtilities.IsSoloEnabled(entry) then
        if style == "blizzard" and display.isBar and display.ProcGlowTarget then
            return display.ProcGlowTarget, true
        end
        return display, true
    end
    return item, false
end

function Effects:CacheVoice()
    local voices = C_VoiceChat.GetTtsVoices()
    self.voice = voices and voices[1] or nil
end

function Effects:Speak(text, rate, volume)
    if BabyAurasDB and BabyAurasDB.muteAllAudio == true then return false end
    if not text or text == "" then return false end
    if C_VoiceChat and C_VoiceChat.SpeakText then
        if not self.voice then self:CacheVoice() end
        if self.voice then
            rate = Clamp(tonumber(rate) or Defaults.trigger.speechRate, -10, 10)
            volume = Clamp(tonumber(volume) or Defaults.trigger.ttsVolume, 0, 100)
            return pcall(C_VoiceChat.SpeakText, self.voice.voiceID, text, rate, volume, true)
        end
    end

    -- Compatibility fallbacks for clients without the rate-aware API.
    local legacySpeak = rawget(_G, "TextToSpeechFrame_PlayCooldownAlertMessage")
    if legacySpeak then
        return pcall(legacySpeak, nil, text, true)
    elseif C_CombatAudioAlert and C_CombatAudioAlert.SpeakText then
        return pcall(
            C_CombatAudioAlert.SpeakText,
            text, Enum.CombatAudioAlertCategory.General, true
        )
    end
    return false
end

function Effects:RestoreForcedZoomDisplay(item, display)
    if not display then return end
    local glowTarget = self.activeGlowTargets[item]
    local bounceTarget = self.activeBounceTargets[item]
    local bounceCompanion = self.activeBounceCompanions[item]
    if glowTarget then
        self.forcedGlowDisplays[glowTarget] = display
    elseif bounceTarget == display or bounceCompanion == display or bounceTarget == display.NativeItem then
        self.forcedBounceDisplays[item] = display
    elseif addon.Solo then
        addon.Solo:RefreshDisplay(display)
    end
end

function Effects:CreateZoomAnimation(target)
    local zoom = target:CreateAnimationGroup()
    local grow = zoom:CreateAnimation("Scale")
    grow:SetOrder(1)
    grow:SetDuration(0.16)
    grow:SetSmoothing("OUT")
    grow:SetOrigin("CENTER", 0, 0)
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(1.10, 1.10)
    local ease = zoom:CreateAnimation("Scale")
    ease:SetOrder(2)
    ease:SetDuration(0.18)
    ease:SetSmoothing("IN_OUT")
    ease:SetOrigin("CENTER", 0, 0)
    ease:SetScaleFrom(1.10, 1.10)
    ease:SetScaleTo(1.025, 1.025)
    local settle = zoom:CreateAnimation("Scale")
    settle:SetOrder(3)
    settle:SetDuration(0.16)
    settle:SetSmoothing("OUT")
    settle:SetOrigin("CENTER", 0, 0)
    settle:SetScaleFrom(1.025, 1.025)
    settle:SetScaleTo(1, 1)
    local function FinishZoom()
        local item = zoom.ActiveItem
        if item then Effects:StopZoom(item) end
    end
    zoom:SetScript("OnFinished", FinishZoom)
    self.zoomAnimations[target] = zoom
    return zoom
end

function Effects:StopZoom(item)
    if not item then return end
    local target = self.activeZoomTargets[item]
    local companion = self.activeZoomCompanions[item]
    if not target and not companion then return end
    self.activeZoomTargets[item] = nil
    self.activeZoomCompanions[item] = nil
    for _, motionTarget in ipairs({ target, companion }) do
        if motionTarget then
            local animation = self.zoomAnimations[motionTarget]
            if animation then
                animation.ActiveItem = nil
                if animation:IsPlaying() then animation:Stop() end
            end
        end
    end
    local forcedDisplay = self.forcedZoomDisplays[item]
    self.forcedZoomDisplays[item] = nil
    self:RestoreForcedZoomDisplay(item, forcedDisplay)
end

function Effects:StopBounce(item)
    if not item then return end
    local target = self.activeBounceTargets[item]
    local companion = self.activeBounceCompanions[item]
    self.bounceGeneration[item] = (self.bounceGeneration[item] or 0) + 1
    if not target and not companion then return end
    self.activeBounceTargets[item] = nil
    self.activeBounceCompanions[item] = nil
    for _, motionTarget in ipairs({ target, companion }) do
        if motionTarget then
            local animation = self.bounceAnimations[motionTarget]
            if animation then
                animation.ActiveItem = nil
                if animation:IsPlaying() then animation:Stop() end
            end
        end
    end
    local forcedDisplay = self.forcedBounceDisplays[item]
    self.forcedBounceDisplays[item] = nil
    local glowTarget = self.activeGlowTargets[item]
    local zoomTarget = self.activeZoomTargets[item]
    local zoomCompanion = self.activeZoomCompanions[item]
    if forcedDisplay and glowTarget then
        self.forcedGlowDisplays[glowTarget] = forcedDisplay
    elseif forcedDisplay and (zoomTarget == forcedDisplay or zoomCompanion == forcedDisplay or zoomTarget == forcedDisplay.NativeItem) then
        self.forcedZoomDisplays[item] = forcedDisplay
    elseif forcedDisplay and addon.Solo then
        addon.Solo:RefreshDisplay(forcedDisplay)
    end
end

function Effects:GetIconMotionTarget(item)
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and addon.Solo and addon.Solo.displays[entry.cooldownID]
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)

    if display and settings and addon.SoloUtilities.IsSoloEnabled(entry) then
        if display.isBar then return nil end

        -- Native-hosted Solo icons are visually rendered by Blizzard's CDM item.
        -- Animating the BabyAuras shell only moves its border/overlays, which is
        -- why Bounce and Zoom appeared to affect only the border. Animate the
        -- hosted visual itself so icon + cooldown + text move together.
        if display.NativeItem then
            return display.NativeItem, true, display
        end
        return display, true, display
    end

    if addon.Solo and addon.Solo:IsTrackedBarItem(item) then return nil end
    return item, false, nil
end

function Effects:CreateBounceAnimation(target)
    local bounce = target:CreateAnimationGroup()
    bounce:SetLooping("REPEAT")
    local up = bounce:CreateAnimation("Translation")
    up:SetOrder(1)
    up:SetDuration(0.18)
    up:SetSmoothing("OUT")
    up:SetOffset(0, 12)
    local down = bounce:CreateAnimation("Translation")
    down:SetOrder(2)
    down:SetDuration(0.18)
    down:SetSmoothing("IN")
    down:SetOffset(0, -12)
    self.bounceAnimations[target] = bounce
    return bounce
end

function Effects:PlayZoom(item)
    if not item then return false end
    self:StopZoom(item)
    local target, isSolo, soloDisplay = self:GetIconMotionTarget(item)
    if not target then return false end
    local animation = self.zoomAnimations[target] or self:CreateZoomAnimation(target)
    if animation.ActiveItem and animation.ActiveItem ~= item then self:StopZoom(animation.ActiveItem) end
    if isSolo and soloDisplay and addon.Solo and not addon.Solo.suspended then
        local needsForce = not soloDisplay:IsShown()
        if target == soloDisplay.NativeItem then
            local ok, alpha = pcall(target.GetAlpha, target)
            needsForce = needsForce or (ok and alpha == 0)
        end
        if needsForce then
            soloDisplay:Show()
            if target == soloDisplay.NativeItem then pcall(target.SetAlpha, target, 1) end
            self.forcedZoomDisplays[item] = soloDisplay
        end
    end
    animation.ActiveItem = item
    self.activeZoomTargets[item] = target

    -- The native CDM item and the BabyAuras shell are separate frames. Animate
    -- both with identical transforms so the Blizzard-rendered icon/timer and the
    -- BabyAuras border/glow remain visually locked together.
    local companion = (soloDisplay and target == soloDisplay.NativeItem) and soloDisplay or nil
    if companion then
        local companionAnimation = self.zoomAnimations[companion] or self:CreateZoomAnimation(companion)
        if companionAnimation.ActiveItem and companionAnimation.ActiveItem ~= item then
            self:StopZoom(companionAnimation.ActiveItem)
        end
        companionAnimation.ActiveItem = item
        self.activeZoomCompanions[item] = companion
        companionAnimation:Play()
    end

    animation:Play()
    return true
end

function Effects:PlayBounce(item, duration)
    if not item then return false end
    self:StopBounce(item)
    local target, isSolo, soloDisplay = self:GetIconMotionTarget(item)
    if not target then return false end
    local animation = self.bounceAnimations[target] or self:CreateBounceAnimation(target)
    if animation.ActiveItem and animation.ActiveItem ~= item then self:StopBounce(animation.ActiveItem) end
    if isSolo and soloDisplay and addon.Solo and not addon.Solo.suspended then
        local needsForce = not soloDisplay:IsShown()
        if target == soloDisplay.NativeItem then
            local ok, alpha = pcall(target.GetAlpha, target)
            needsForce = needsForce or (ok and alpha == 0)
        end
        if needsForce then
            soloDisplay:Show()
            if target == soloDisplay.NativeItem then pcall(target.SetAlpha, target, 1) end
            self.forcedBounceDisplays[item] = soloDisplay
        end
    end
    animation.ActiveItem = item
    self.activeBounceTargets[item] = target

    -- Keep the BabyAuras shell/border synchronized with the separately hosted
    -- Blizzard CDM visual for the entire bounce.
    local companion = (soloDisplay and target == soloDisplay.NativeItem) and soloDisplay or nil
    if companion then
        local companionAnimation = self.bounceAnimations[companion] or self:CreateBounceAnimation(companion)
        if companionAnimation.ActiveItem and companionAnimation.ActiveItem ~= item then
            self:StopBounce(companionAnimation.ActiveItem)
        end
        companionAnimation.ActiveItem = item
        self.activeBounceCompanions[item] = companion
        companionAnimation:Play()
    end

    local generation = (self.bounceGeneration[item] or 0) + 1
    self.bounceGeneration[item] = generation
    animation:Play()
    duration = tonumber(duration)
    if duration == nil then duration = Defaults.trigger.bounceDuration end
    if duration > 0 then
        C_Timer.After(duration, function()
            if Effects.bounceGeneration[item] == generation then Effects:StopBounce(item) end
        end)
    end
    return true
end

function Effects:ShowGlow(item, settings)
    if not item then return end
    local style = settings.glowStyle or Defaults.trigger.glowStyle
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and addon.Solo and addon.Solo.displays[entry.cooldownID]
    if display and display.isBar and style == "blizzard" then style = "pixel" end
    local entrySettings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    if display and not display.isBar and entrySettings and entrySettings.soloCropEnabled == true
        and style == "blizzard" then
        style = "pixel"
    end
    local target, isSolo = self:GetGlowTarget(item, style)
    if not target then return end
    -- Aura Lost fires after the tracked Solo display becomes inactive. Keep the
    -- icon visible for the alert itself, then restore its normal visibility when
    -- that glow ends. Sounds/TTS do not need this, but visual alerts do.
    if isSolo and display and not display:IsShown()
        and addon.Solo and not addon.Solo.suspended then
        display:Show()
        self.forcedGlowDisplays[target] = display
    end
    if isSolo and display and self.forcedBounceDisplays[item] == display then
        self.forcedGlowDisplays[target] = display
    end
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
    local forcedDisplay = self.forcedGlowDisplays[target]
    self.forcedGlowDisplays[target] = nil
    local item = self.glowTargetItems[target]
    if item and self.activeGlowTargets[item] == target then self.activeGlowTargets[item] = nil end
    self.glowTargetItems[target] = nil
    self.glowGeneration[target] = (self.glowGeneration[target] or 0) + 1
    if addon.Glow then addon.Glow:Stop(target) end
    if ActionButtonSpellAlertManager then ActionButtonSpellAlertManager:HideAlert(target) end
    if forcedDisplay and item and self.activeBounceTargets[item] == forcedDisplay then
        self.forcedBounceDisplays[item] = forcedDisplay
    elseif forcedDisplay and item and self.activeZoomTargets[item] == forcedDisplay then
        self.forcedZoomDisplays[item] = forcedDisplay
    elseif forcedDisplay and addon.Solo then
        addon.Solo:RefreshDisplay(forcedDisplay)
    end
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
    self:StopZoom(item)
    self:StopBounce(item)
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
    -- A new trigger supersedes any held glow or in-progress motion from the
    -- previous state, even when this trigger is configured as sound/TTS-only.
    self:HideGlow(item)
    local ttsEnabled = settings.ttsEnabled == true
    if ttsEnabled and settings.text and settings.text ~= "" then
        self:Speak(settings.text, settings.speechRate, settings.ttsVolume)
    end
    if settings.audioEnabled and settings.audioSound then
        addon.Audio:Play(settings.audioSound, settings.audioChannel)
    end
    -- Build/attach the glow before starting motion. Animation transforms do not
    -- reliably propagate to regions attached after a parent animation has begun
    -- in combat; Preview Mode already uses this order and keeps both together.
    if settings.glow then
        self:ShowGlow(item, settings)
    end
    if settings.zoom == true then
        self:PlayZoom(item)
    end
    if settings.bounce == true then
        self:PlayBounce(item, settings.bounceDuration)
    end
end
