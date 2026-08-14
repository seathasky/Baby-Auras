local _, addon = ...

local Solo = addon.Solo
local Utilities = addon.SoloUtilities
local GetEntryAppearance = Utilities.GetEntryAppearance
local GetTextColor = Utilities.GetTextColor
local GetClassColor = Utilities.GetClassColor
local EntryUsesAura = Utilities.EntryUsesAura
local Mirroring = {}
addon.SoloMirroring = Mirroring

function Solo:MirrorCount(item, value)
    local entry = addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    if not display then return end
    pcall(display.Count.SetText, display.Count, value)
end

function Solo:MirrorBarText(item, key, value)
    local entry = addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    local target = display and display[key]
    if target then pcall(target.SetText, target, value) end
end

local function FindStatusBar(frame, depth)
    if not frame or (depth or 0) > 4 then return nil end
    if frame.IsObjectType and frame:IsObjectType("StatusBar") then return frame end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if ok then
        for _, child in ipairs(children) do
            local found = FindStatusBar(child, (depth or 0) + 1)
            if found then return found end
        end
    end
end

Mirroring.FindStatusBar = FindStatusBar

function Solo:MirrorBarProgress(item)
    local entry = addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    if not display or not display.BarProgress then return end
    local source = display.SourceStatusBar or FindStatusBar(item.Bar)
    if not source then return end
    display.SourceStatusBar = source
    pcall(function()
        local minimum, maximum = source:GetMinMaxValues()
        display.BarProgress:SetMinMaxValues(minimum, maximum)
        display.BarProgress:SetValue(source:GetValue())
        local settings = GetEntryAppearance(entry)
        local r, g, b, a = GetTextColor(settings, "soloBarProgressColor", "barProgressColor")
        display.BarProgress:SetStatusBarColor(r, g, b, a)
    end)
end

function Solo:MirrorCooldown(item, action, ...)
    local entry = addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    local cooldown = display and display.Cooldown
    if not cooldown then return end
    if display.LiveCooldown then
        -- The live Blizzard widget already received this update. Only re-assert
        -- BabyAuras' styling; mirroring it back into itself would recurse.
        if display.applyingAppearance then return end
        self:UpdateActiveState(item, display)
        self:ApplyAppearance(display)
        return
    end
    if action == "set" then
        pcall(cooldown.SetCooldown, cooldown, ...)
        self:SyncCooldown(item, display)
    elseif action == "durationObject" then
        pcall(cooldown.SetCooldownFromDurationObject, cooldown, ...)
    elseif action == "duration" then
        pcall(cooldown.SetCooldownDuration, cooldown, ...)
    elseif action == "expiration" then
        pcall(cooldown.SetCooldownFromExpirationTime, cooldown, ...)
    elseif action == "clear" then
        cooldown:Clear()
    elseif action == "pause" then
        cooldown:Pause()
    elseif action == "resume" then
        cooldown:Resume()
    elseif action == "swipeColor" then
        display.sourceSwipeColor = { ... }
        self:UpdateActiveState(item, display)
        local settings = GetEntryAppearance(entry)
        if settings.soloClassSwipe == true then
            local color = GetClassColor()
            cooldown:SetSwipeColor(color.r, color.g, color.b, 0.82)
        else
            pcall(cooldown.SetSwipeColor, cooldown, ...)
        end
    elseif action == "drawSwipe" then
        display.sourceDrawSwipe = ...
        local settings = GetEntryAppearance(entry)
        if settings.soloShowSwipe == false then
            cooldown:SetDrawSwipe(false)
        else
            cooldown:SetDrawSwipe(true)
        end
    elseif action == "hideNumbers" then
        display.sourceHideNumbers = ...
        local settings = GetEntryAppearance(entry)
        if settings.soloShowNumbers == false then
            cooldown:SetHideCountdownNumbers(true)
        else
            cooldown:SetHideCountdownNumbers(false)
        end
    elseif action == "reverse" then
        pcall(cooldown.SetReverse, cooldown, ...)
    elseif action == "useAuraTime" then
        pcall(cooldown.SetUseAuraDisplayTime, cooldown, ...)
    end
end

function Solo:UpdateActiveState(item, display)
    display = display or (addon.Runtime.itemEntries[item]
        and self.displays[addon.Runtime.itemEntries[item].cooldownID])
    if not item or not display then return end
    local color = item.cooldownSwipeColor
    if color and type(color) ~= "number" and type(color.GetRGBA) == "function" then
        local ok, red = pcall(color.GetRGBA, color)
        if ok and type(red) == "number" and not addon:IsSecret(red) then
            display.activeState = red ~= 0
        end
    end
end

function Solo:SyncSpellCooldown(display)
    local entry = display and display.entry
    if not entry or not C_Spell then return end
    local info = entry.info or {}
    -- Aura duration is owned by Blizzard's live cooldown widget and arrives via
    -- SetCooldownFromDurationObject. Spell APIs describe the underlying spell CD.
    if EntryUsesAura(entry) then return end
    local spellID = info.overrideSpellID or entry.spellID
    local durationObject
    if info.charges and C_Spell.GetSpellChargeDuration then
        durationObject = C_Spell.GetSpellChargeDuration(spellID)
    end
    if not durationObject and C_Spell.GetSpellCooldownDuration then
        durationObject = C_Spell.GetSpellCooldownDuration(spellID, true)
    end
    if durationObject and display.Cooldown.SetCooldownFromDurationObject then
        pcall(display.Cooldown.SetCooldownFromDurationObject, display.Cooldown, durationObject, true)
    end
end

function Solo:SyncAuraCooldown(item, display)
    if display and display.LiveCooldown then return true end
    if not item or not display or not C_UnitAuras or not C_UnitAuras.GetAuraDuration then return false end
    if type(item.GetAuraDataUnit) ~= "function" or type(item.GetAuraSpellInstanceID) ~= "function" then
        return false
    end
    local unitOK, unit = pcall(item.GetAuraDataUnit, item)
    local instanceOK, auraInstanceID = pcall(item.GetAuraSpellInstanceID, item)
    if not unitOK or not instanceOK or not unit or not auraInstanceID then return false end

    -- Keep the aura instance opaque. In 12.1 it may be secret: it is passed
    -- directly to Blizzard's duration-object API and is never compared, indexed,
    -- or used as a Lua table key.
    local durationOK, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
    if not durationOK or not durationObject then return false end
    local applied = pcall(
        display.Cooldown.SetCooldownFromDurationObject,
        display.Cooldown, durationObject, true
    )
    if applied then display.Cooldown:SetUseAuraDisplayTime(true) end
    return applied
end

function Solo:SyncCooldown(item, display)
    local entry = display and display.entry
    if not entry then return end
    local info = entry.info or {}
    if EntryUsesAura(entry) and self:SyncAuraCooldown(item, display) then return end
    self:SyncSpellCooldown(display)
end

function Solo:MirrorDesaturation(item, value)
    local entry = addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    if not display then return end
    display.sourceDesaturated = value
    self:ApplyAppearance(display)
end

function Solo:DetachLiveCooldown(display)
    local live = display and display.LiveCooldown
    if not live then return end
    local state = self.liveCooldownStates[live]
    local parent = state and state.parent or state and state.item
    display.applyingAppearance = true
    local ok, attachError = pcall(function()
        live:ClearAllPoints()
        live:SetParent(parent or UIParent)
        if state and state.points and #state.points > 0 then
            for _, point in ipairs(state.points) do live:SetPoint(unpack(point)) end
        elseif state and state.item then
            live:SetAllPoints(state.item)
        end
        if state then
            live:SetFrameLevel(state.frameLevel or 1)
            live:SetAlpha(state.alpha or 1)
            live:SetShown(state.shown ~= false)
            local originalFont = state.countdownFont
                or (state.countdownText and state.countdownText.fontName)
            if originalFont and type(live.SetCountdownFont) == "function" then
                live:SetCountdownFont(originalFont)
            end
            if state.countdownText and state.countdownText.region then
                local text = state.countdownText.region
                if state.countdownText.font and state.countdownText.font[1] then
                    text:SetFont(unpack(state.countdownText.font))
                end
                if state.countdownText.color then
                    text:SetTextColor(unpack(state.countdownText.color))
                end
                text:ClearAllPoints()
                for _, point in ipairs(state.countdownText.points or {}) do text:SetPoint(unpack(point)) end
            end
            if state.drawSwipe ~= nil then live:SetDrawSwipe(state.drawSwipe) end
            if state.hideNumbers ~= nil then live:SetHideCountdownNumbers(state.hideNumbers) end
            if state.reverse ~= nil then live:SetReverse(state.reverse) end
            if state.useAuraTime ~= nil then live:SetUseAuraDisplayTime(state.useAuraTime) end
        end
    end)
    display.applyingAppearance = nil
    if ok then
        display.LiveCooldown = nil
        display.Cooldown:Show()
        self.liveCooldownStates[live] = nil
    end
end

function Solo:AttachLiveCooldown(item, display, sourceCooldown)
    if not item or not display or not sourceCooldown or not EntryUsesAura(display.entry) then return false end
    if display.LiveCooldown == sourceCooldown then return true end
    if display.LiveCooldown then self:DetachLiveCooldown(display) end

    local oldState = self.liveCooldownStates[sourceCooldown]
    if oldState and oldState.display and oldState.display ~= display then
        self:DetachLiveCooldown(oldState.display)
    end
    local state = {
        parent = sourceCooldown:GetParent(), item = item, display = display, points = {},
        frameLevel = sourceCooldown:GetFrameLevel(), alpha = sourceCooldown:GetAlpha(),
        shown = sourceCooldown:IsShown(),
    }
    local function Read(method, key)
        if type(sourceCooldown[method]) ~= "function" then return end
        local ok, value = pcall(sourceCooldown[method], sourceCooldown)
        if ok and type(value) == "boolean" then state[key] = value end
    end
    Read("GetDrawSwipe", "drawSwipe")
    Read("GetHideCountdownNumbers", "hideNumbers")
    Read("GetReverse", "reverse")
    Read("GetUseAuraDisplayTime", "useAuraTime")
    pcall(function()
        for index = 1, sourceCooldown:GetNumPoints() do
            state.points[index] = { sourceCooldown:GetPoint(index) }
        end
    end)
    local ok = pcall(function()
        sourceCooldown:ClearAllPoints()
        sourceCooldown:SetParent(display)
        sourceCooldown:SetAlpha(1)
        sourceCooldown:Show()
        if display.isBar then
            sourceCooldown:SetPoint("TOPLEFT", display.Icon, "TOPLEFT")
            sourceCooldown:SetPoint("BOTTOMRIGHT", display.Icon, "BOTTOMRIGHT")
        else
            sourceCooldown:SetAllPoints(display)
        end
    end)
    if not ok then
        display.liveCooldownAttachFailed = true
        if not display.liveCooldownWarningShown then
            display.liveCooldownWarningShown = true
            print("|cFFFF6666Baby Auras:|r Live aura timer could not attach for "
                .. tostring(display.entry.name) .. ": " .. tostring(attachError))
        end
        return false
    end

    self.liveCooldownStates[sourceCooldown] = state
    display.liveCooldownAttachFailed = nil
    display.LiveCooldown = sourceCooldown
    display.Cooldown:Hide()
    self:ApplyAppearance(display)
    return true
end

function Solo:InstallMirrors(item, display)
    local function InstallCountSource(countSource)
        if not countSource then return end
        if not self.mirrorHooks[countSource] then
            self.mirrorHooks[countSource] = true
            hooksecurefunc(countSource, "SetText", function(_, value)
                Solo:MirrorCount(item, value)
            end)
        end
        pcall(function() display.Count:SetText(countSource:GetText()) end)
    end
    InstallCountSource(item.Applications and item.Applications.Applications)
    InstallCountSource(item.ChargeCount and item.ChargeCount.Current)
    InstallCountSource(item.Icon and item.Icon.Applications)

    local sourceCooldown = item.Cooldown
    if type(item.GetCooldownFrame) == "function" then
        local ok, cooldownFrame = pcall(item.GetCooldownFrame, item)
        if ok and cooldownFrame then sourceCooldown = cooldownFrame end
    end
    if sourceCooldown and not self.mirrorHooks[sourceCooldown] then
        self.mirrorHooks[sourceCooldown] = true
        local function Mirror(method, action)
            if type(sourceCooldown[method]) ~= "function" then return end
            hooksecurefunc(sourceCooldown, method, function(_, ...)
                Solo:MirrorCooldown(item, action, ...)
            end)
        end
        Mirror("SetCooldown", "set")
        Mirror("SetCooldownFromDurationObject", "durationObject")
        Mirror("SetCooldownDuration", "duration")
        Mirror("SetCooldownFromExpirationTime", "expiration")
        Mirror("Clear", "clear")
        Mirror("Pause", "pause")
        Mirror("Resume", "resume")
        Mirror("SetSwipeColor", "swipeColor")
        Mirror("SetDrawSwipe", "drawSwipe")
        Mirror("SetHideCountdownNumbers", "hideNumbers")
        Mirror("SetReverse", "reverse")
        Mirror("SetUseAuraDisplayTime", "useAuraTime")
    end
    self:AttachLiveCooldown(item, display, sourceCooldown)

    local sourceIcon
    if type(item.GetIconTexture) == "function" then
        local ok, iconTexture = pcall(item.GetIconTexture, item)
        if ok then sourceIcon = iconTexture end
    end
    sourceIcon = sourceIcon or (item.Icon and item.Icon.Icon) or item.Icon
    if sourceIcon and type(sourceIcon.SetDesaturated) == "function" and not self.mirrorHooks[sourceIcon] then
        self.mirrorHooks[sourceIcon] = true
        hooksecurefunc(sourceIcon, "SetDesaturated", function(_, value)
            Solo:MirrorDesaturation(item, value)
        end)
    end
    if sourceIcon and type(sourceIcon.IsDesaturated) == "function" then
        local ok, value = pcall(sourceIcon.IsDesaturated, sourceIcon)
        if ok and type(value) == "boolean" then self:MirrorDesaturation(item, value) end
    end

    self:UpdateActiveState(item, display)
    self:SyncCooldown(item, display)

    if display.isBar and item.Bar then
        local function InstallBarText(source, key)
            if not source then return end
            if not self.mirrorHooks[source] then
                self.mirrorHooks[source] = true
                hooksecurefunc(source, "SetText", function(_, value)
                    Solo:MirrorBarText(item, key, value)
                end)
            end
            pcall(function() Solo:MirrorBarText(item, key, source:GetText()) end)
        end
        InstallBarText(item.Bar.Name, "BarName")
        InstallBarText(item.Bar.Duration, "BarDuration")
        local sourceStatusBar = addon.SoloMirroring.FindStatusBar(item.Bar)
        if sourceStatusBar then
            display.SourceStatusBar = sourceStatusBar
            if not self.mirrorHooks[sourceStatusBar] then
                self.mirrorHooks[sourceStatusBar] = true
                if type(sourceStatusBar.SetValue) == "function" then
                    hooksecurefunc(sourceStatusBar, "SetValue", function() Solo:MirrorBarProgress(item) end)
                end
                if type(sourceStatusBar.SetMinMaxValues) == "function" then
                    hooksecurefunc(sourceStatusBar, "SetMinMaxValues", function() Solo:MirrorBarProgress(item) end)
                end
                if type(sourceStatusBar.SetStatusBarColor) == "function" then
                    hooksecurefunc(sourceStatusBar, "SetStatusBarColor", function() Solo:MirrorBarProgress(item) end)
                end
            end
            Solo:MirrorBarProgress(item)
            display.barProgressElapsed = 0
            display:SetScript("OnUpdate", function(self, elapsed)
                self.barProgressElapsed = self.barProgressElapsed + elapsed
                if self.barProgressElapsed >= 0.05 then
                    self.barProgressElapsed = 0
                    Solo:MirrorBarProgress(item)
                end
            end)
        end
    end
end
