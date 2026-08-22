local _, addon = ...

local Monitor = {
    states = {},
    lastDispatch = {},
    heldReadyGlows = {},
    suppressedUntil = 0,
}
addon.NativeCooldownTriggers = Monitor

local AlertType = Enum.CooldownViewerAlertEventType
local Category = Enum.CooldownViewerCategory
local READY_POLL_INTERVAL = 0.1
local READY_SAMPLES_REQUIRED = 2
local DISPATCH_DEBOUNCE = 1
local readyCurve = C_CurveUtil and C_CurveUtil.CreateCurve()
if readyCurve then
    readyCurve:AddPoint(0, 1)
    readyCurve:AddPoint(0.001, 0)
end

local managedCategories = {}
local function AddManagedCategory(category)
    if category ~= nil then managedCategories[category] = true end
end
AddManagedCategory(Category.Essential)
AddManagedCategory(Category.Utility)
AddManagedCategory(Category.SpecAgnosticEssential)
AddManagedCategory(Category.EquipSlotEssential)

local managedTriggers = {}
local function AddManagedTrigger(trigger)
    if trigger ~= nil then managedTriggers[trigger] = true end
end
AddManagedTrigger(AlertType.Available)
AddManagedTrigger(AlertType.OnCooldown)
AddManagedTrigger(AlertType.ChargeGained)

local function GetActiveManagedCooldownIDs()
    local active = {}
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet then
        return active
    end
    for category in pairs(managedCategories) do
        local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, false) or {}
        for _, cooldownID in ipairs(cooldownIDs) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
            if info and info.isKnown ~= false then active[cooldownID] = true end
        end
    end
    return active
end

local function IsAccessible(value)
    if addon:IsSecret(value) then return false end
    return not canaccessvalue or canaccessvalue(value)
end

local function GetTriggerSettings(entry, trigger)
    return entry and addon:GetTriggerSettings(entry.cooldownID, trigger, false) or nil
end

local function IsTriggerEnabled(entry, trigger)
    if not entry or trigger ~= addon:GetPrimaryTrigger(entry) then return false, nil end
    local settings = GetTriggerSettings(entry, trigger)
    return settings and settings.enabled == true, settings
end

local function ResolveNativeSpellID(entry)
    if not entry then return nil end
    local info = entry.info or {}
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, liveInfo = pcall(
            C_CooldownViewer.GetCooldownViewerCooldownInfo, entry.cooldownID
        )
        if ok and liveInfo then info = liveInfo end
    end
    local baseSpellID = info.spellID or entry.spellID
    if not IsAccessible(baseSpellID) or type(baseSpellID) ~= "number" then return nil end

    if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
        local ok, overrideSpellID = pcall(C_SpellBook.FindSpellOverrideByID, baseSpellID)
        if ok and IsAccessible(overrideSpellID)
            and type(overrideSpellID) == "number" and overrideSpellID > 0 then
            return overrideSpellID, baseSpellID
        end
    elseif C_Spell and C_Spell.GetOverrideSpell then
        local ok, overrideSpellID = pcall(C_Spell.GetOverrideSpell, baseSpellID)
        if ok and IsAccessible(overrideSpellID)
            and type(overrideSpellID) == "number" and overrideSpellID > 0 then
            return overrideSpellID, baseSpellID
        end
    end
    return baseSpellID, baseSpellID
end

local function ReadNativeState(entry)
    local spellID, baseSpellID = ResolveNativeSpellID(entry)
    if not spellID or not C_Spell then return nil end

    local chargeInfo
    if C_Spell.GetSpellCharges then
        local ok, result = pcall(C_Spell.GetSpellCharges, spellID)
        if ok then chargeInfo = result end
        if not chargeInfo and baseSpellID ~= spellID then
            ok, result = pcall(C_Spell.GetSpellCharges, baseSpellID)
            if ok then chargeInfo = result end
        end
    end

    local maxCharges = chargeInfo and chargeInfo.maxCharges
    local hasCharges = chargeInfo and IsAccessible(maxCharges)
        and type(maxCharges) == "number" and maxCharges > 1
    if hasCharges then
        local chargeIsActive = chargeInfo.isActive
        local chargeRecharging = IsAccessible(chargeIsActive) and chargeIsActive == true
        local currentCharges = chargeInfo.currentCharges
        if not IsAccessible(currentCharges) or type(currentCharges) ~= "number" then
            -- currentCharges can be protected in combat. Use cooldown flags
            -- to distinguish zero charges from a background recharge.
            if C_Spell.GetSpellCooldown then
                local cooldownOK, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
                if cooldownOK and cooldown then
                    local isActive, isOnGCD = cooldown.isActive, cooldown.isOnGCD
                    if IsAccessible(isActive) and IsAccessible(isOnGCD) then
                        return isActive == true and isOnGCD ~= true,
                            spellID, nil, maxCharges, chargeRecharging
                    end
                end
            end
            return nil, spellID, nil, maxCharges, chargeRecharging
        end
        return currentCharges == 0, spellID, currentCharges, maxCharges, chargeRecharging
    end

    if not C_Spell.GetSpellCooldown then return nil end
    local ok, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
    if (not ok or not cooldown) and baseSpellID ~= spellID then
        ok, cooldown = pcall(C_Spell.GetSpellCooldown, baseSpellID)
    end
    if not ok then return nil end
    if not cooldown then return false, spellID, nil, nil end
    local isActive, isOnGCD = cooldown.isActive, cooldown.isOnGCD
    -- isActive/isOnGCD can be secret in combat; comparing them unguarded
    -- throws and aborts the whole trigger scan.
    if not IsAccessible(isActive) or not IsAccessible(isOnGCD) then return nil end
    return isActive == true and isOnGCD ~= true, spellID, nil, nil
end

local function IsSpellReady(spellID)
    if not spellID or not C_Spell or not C_Spell.IsSpellUsable then return false end
    if C_Spell.GetOverrideSpell then
        local ok, overrideSpellID = pcall(C_Spell.GetOverrideSpell, spellID)
        if ok and IsAccessible(overrideSpellID)
            and type(overrideSpellID) == "number" and overrideSpellID > 0 then
            spellID = overrideSpellID
        end
    end
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
    return ok and usable == true
end

local function GetSpellReadyAlpha(spellID)
    if not spellID or not readyCurve or not C_Spell
        or not C_Spell.GetSpellCooldownDuration then
        return false
    end
    local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if not ok or not duration or not duration.EvaluateRemainingDuration then return false end
    local alphaOK, alpha = pcall(duration.EvaluateRemainingDuration, duration, readyCurve)
    if not alphaOK then return false end

    if C_Spell.GetSpellCooldown then
        local cooldownOK, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
        if cooldownOK and cooldown and IsAccessible(cooldown.isOnGCD) and cooldown.isOnGCD == true then
            alpha = 1
        end
    end
    if not IsSpellReady(spellID) then alpha = 0 end
    return true, alpha
end

function Monitor:IsManagedTrigger(entry, trigger)
    return entry ~= nil and managedCategories[entry.category] == true
        and managedTriggers[trigger] == true
end

function Monitor:GetLiveItem(entry)
    return entry and addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID) or nil
end

function Monitor:ClearHeldReady(item, entry)
    entry = entry or (item and addon.Runtime.itemEntries[item])
    local cooldownID = entry and entry.cooldownID
    local heldItem = cooldownID and self.heldReadyGlows[cooldownID]
    if not heldItem then return end
    addon.Effects:HideGlow(heldItem)
    self.heldReadyGlows[cooldownID] = nil
end

function Monitor:Fire(entry, trigger, settings)
    local item = self:GetLiveItem(entry)
    if not item or not settings or settings.enabled ~= true then return end
    -- Several Blizzard cooldown events can describe the same state edge in the
    -- same frame. Effects (especially TTS) must run once for that logical edge.
    local key = tostring(entry.cooldownID) .. ":" .. tostring(trigger)
    local now = GetTime()
    local previous = self.lastDispatch[key]
    if previous and now - previous < DISPATCH_DEBOUNCE then return end
    self.lastDispatch[key] = now
    addon.Effects:Fire(item, entry, trigger, settings)
end

function Monitor:HandleNativeChargeGained(entry)
    if not entry or not managedCategories[entry.category] then return false end
    local enabled, settings = IsTriggerEnabled(entry, AlertType.ChargeGained)
    if enabled then self:Fire(entry, AlertType.ChargeGained, settings) end
    return true
end

function Monitor:HandleNativeStarted(entry)
    if not entry or not managedCategories[entry.category] then return false end
    local enabled, settings = IsTriggerEnabled(entry, AlertType.OnCooldown)
    if enabled then self:Fire(entry, AlertType.OnCooldown, settings) end
    return true
end

local function SpellIDsMatch(entry, castSpellID)
    if not entry or not IsAccessible(castSpellID) or type(castSpellID) ~= "number" then
        return false
    end
    local spellID, baseSpellID = ResolveNativeSpellID(entry)
    if castSpellID == spellID or castSpellID == baseSpellID then return true end
    if not C_Spell or not C_Spell.GetBaseSpell then return false end
    local ok, castBase = pcall(C_Spell.GetBaseSpell, castSpellID)
    if not ok or type(castBase) ~= "number" then castBase = castSpellID end
    if castBase == spellID or castBase == baseSpellID then return true end
    if spellID then
        ok, spellID = pcall(C_Spell.GetBaseSpell, spellID)
        if ok and type(spellID) == "number" and castBase == spellID then return true end
    end
    return false
end

function Monitor:HandlePlayerSpellcast(castSpellID)
    if GetTime() < self.suppressedUntil then return end
    local activeCooldownIDs = GetActiveManagedCooldownIDs()
    local seen = {}
    for _, entry in pairs(addon.Runtime.itemEntries) do
        local cooldownID = entry and entry.cooldownID
        if cooldownID and not seen[cooldownID] and activeCooldownIDs[cooldownID]
            and managedCategories[entry.category] and SpellIDsMatch(entry, castSpellID) then
            seen[cooldownID] = true
            local enabled, settings = IsTriggerEnabled(entry, AlertType.OnCooldown)
            if enabled then
                local matchedEntry, matchedSettings = entry, settings
                -- Let SPELL_UPDATE_COOLDOWN/CHARGES settle, then require a real
                -- cooldown or recharge. The Fire dedupe merges this with sampled
                -- and native Started signals from the same cast.
                local function ConfirmStarted()
                    local onCooldown, _, _, maxCharges, chargeRecharging = ReadNativeState(matchedEntry)
                    local isChargeSpell = type(maxCharges) == "number" and maxCharges > 1
                    local started = isChargeSpell and chargeRecharging == true
                        or not isChargeSpell and onCooldown == true
                    if started then
                        Monitor:Fire(matchedEntry, AlertType.OnCooldown, matchedSettings)
                    end
                end
                C_Timer.After(0, ConfirmStarted)
                C_Timer.After(0.05, ConfirmStarted)
            end
        end
    end
end

function Monitor:UpdateHeldReady(entry, ready, settings, spellID)
    local item = self:GetLiveItem(entry)
    if not item then
        self:ClearHeldReady(nil, entry)
        return
    end
    local duration = settings and tonumber(settings.glowDuration)
    if duration == nil then duration = addon.Defaults.trigger.glowDuration end
    local shouldHold = ready and settings and settings.enabled == true
        and settings.glow == true and duration == 0
    if shouldHold then
        local heldItem = self.heldReadyGlows[entry.cooldownID]
        if heldItem and heldItem ~= item then addon.Effects:HideGlow(heldItem) end
        if not addon.Effects:IsGlowActive(item) then addon.Effects:ShowGlow(item, settings) end
        self.heldReadyGlows[entry.cooldownID] = item
        local alphaOK, readyAlpha = GetSpellReadyAlpha(spellID)
        if alphaOK then addon.Effects:SetGlowAlpha(item, readyAlpha) end
    else
        self:ClearHeldReady(item, entry)
    end
end

function Monitor:Evaluate(primeOnly)
    if not BabyAurasDB or not addon.Runtime then return end
    local seen = {}
    local activeCooldownIDs = GetActiveManagedCooldownIDs()
    local suppressed = GetTime() < self.suppressedUntil

    for item, entry in pairs(addon.Runtime.itemEntries) do
        local cooldownID = entry and entry.cooldownID
        if cooldownID and activeCooldownIDs[cooldownID]
            and managedCategories[entry.category] and not seen[cooldownID] then
            seen[cooldownID] = true
            local primaryTrigger = addon:GetPrimaryTrigger(entry)
            local primarySettings = managedTriggers[primaryTrigger]
                and GetTriggerSettings(entry, primaryTrigger) or nil
            local primaryEnabled = primarySettings and primarySettings.enabled == true
            local readyEnabled = primaryEnabled and primaryTrigger == AlertType.Available
            local startedEnabled = primaryEnabled and primaryTrigger == AlertType.OnCooldown
            local chargeEnabled = primaryEnabled and primaryTrigger == AlertType.ChargeGained
            local readySettings = readyEnabled and primarySettings or nil
            local startedSettings = startedEnabled and primarySettings or nil
            local chargeSettings = chargeEnabled and primarySettings or nil
            local monitored = readyEnabled or startedEnabled or chargeEnabled

            if monitored then
                local onCooldown, spellID, currentCharges, maxCharges, chargeRecharging = ReadNativeState(entry)
                if onCooldown ~= nil then
                    local state = self.states[cooldownID]
                    if not state then
                        state = {
                            onCooldown = onCooldown,
                            armed = onCooldown or nil,
                            readySamples = 0,
                            currentCharges = currentCharges,
                            maxCharges = maxCharges,
                            chargeRecharging = chargeRecharging,
                        }
                        self.states[cooldownID] = state
                    elseif primeOnly then
                        state.onCooldown = onCooldown
                        state.armed = onCooldown or nil
                        state.readySamples = 0
                        state.currentCharges = currentCharges
                        state.maxCharges = maxCharges
                        state.chargeRecharging = chargeRecharging
                    else
                        local isChargeSpell = type(maxCharges) == "number" and maxCharges > 1
                        local startedEdge
                        if isChargeSpell and type(chargeRecharging) == "boolean"
                            and type(state.chargeRecharging) == "boolean" then
                            startedEdge = state.chargeRecharging == false
                                and chargeRecharging == true
                        else
                            startedEdge = state.onCooldown == false and onCooldown == true
                        end
                        if startedEdge then addon.Effects:HideGlow(item) end
                        if startedEnabled and not suppressed and startedEdge then
                            self:Fire(entry, AlertType.OnCooldown, startedSettings)
                        end

                        if onCooldown then
                            if not state.onCooldown then
                                self:ClearHeldReady(item, entry)
                            end
                            state.armed = true
                            state.readySamples = 0
                        elseif state.armed then
                            if IsSpellReady(spellID) then
                                state.readySamples = (state.readySamples or 0) + 1
                            else
                                state.readySamples = 0
                            end
                            if state.readySamples >= READY_SAMPLES_REQUIRED then
                                -- End any held On Cooldown/Charge glow even if the
                                -- Ready trigger itself is disabled or sound-only.
                                addon.Effects:HideGlow(item)
                                if readyEnabled and not suppressed
                                    and activeCooldownIDs[cooldownID]
                                    and self:GetLiveItem(entry) ~= nil then
                                    self:Fire(entry, AlertType.Available, readySettings)
                                end
                                state.armed = nil
                                state.readySamples = 0
                            end
                        end

                        local chargeGained = type(currentCharges) == "number"
                            and type(state.currentCharges) == "number"
                            and currentCharges > state.currentCharges
                        if not chargeGained and type(maxCharges) == "number" and maxCharges > 1 then
                            chargeGained = state.onCooldown == true and onCooldown == false
                                or state.chargeRecharging == true and chargeRecharging == false
                        end
                        if chargeEnabled and not suppressed and chargeGained then
                            self:Fire(entry, AlertType.ChargeGained, chargeSettings)
                        end
                        state.onCooldown = onCooldown
                        state.currentCharges = currentCharges
                        state.maxCharges = maxCharges
                        state.chargeRecharging = chargeRecharging
                    end

                    local readyNow = not onCooldown and IsSpellReady(spellID)
                    self:UpdateHeldReady(entry, readyNow, readySettings, spellID)
                else
                    self:ClearHeldReady(item, entry)
                end
            else
                self.states[cooldownID] = nil
                self:ClearHeldReady(item, entry)
            end
        end
    end

    for cooldownID in pairs(self.states) do
        if not seen[cooldownID] then self.states[cooldownID] = nil end
    end
    for cooldownID, item in pairs(self.heldReadyGlows) do
        if not seen[cooldownID] then
            addon.Effects:HideGlow(item)
            self.heldReadyGlows[cooldownID] = nil
        end
    end
end

function Monitor:Prime(delay)
    wipe(self.states)
    self.suppressedUntil = GetTime() + (delay or 0)
    self:Evaluate(true)
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELL_UPDATE_USABLE",
    "SPELLS_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "COOLDOWN_VIEWER_DATA_LOADED",
    "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
    "COOLDOWN_VIEWER_TABLE_HOTFIXED",
    "LOADING_SCREEN_ENABLED",
    "LOADING_SCREEN_DISABLED",
    "PLAYER_ENTERING_WORLD",
}) do eventFrame:RegisterEvent(event) end
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if IsAccessible(spellID) then Monitor:HandlePlayerSpellcast(spellID) end
    elseif event == "LOADING_SCREEN_ENABLED" then
        Monitor.suppressedUntil = math.huge
    elseif event == "LOADING_SCREEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" then
        Monitor:Prime(2)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if not unit or unit == "player" then Monitor:Prime(2) end
    elseif event == "SPELLS_CHANGED"
        or event == "COOLDOWN_VIEWER_DATA_LOADED"
        or event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED"
        or event == "COOLDOWN_VIEWER_TABLE_HOTFIXED" then
        Monitor:Prime(0.5)
    else
        Monitor:Evaluate(false)
    end
end)

local tickerFrame = CreateFrame("Frame")
tickerFrame.elapsed = 0
tickerFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < READY_POLL_INTERVAL then return end
    self.elapsed = 0
    Monitor:Evaluate(false)
end)

if EventRegistry then
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        C_Timer.After(0, function() Monitor:Prime(0.5) end)
    end)
end
