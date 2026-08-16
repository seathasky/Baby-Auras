local _, addon = ...

local Solo = addon.Solo
local Utilities = addon.SoloUtilities
local GetEntryAppearance = Utilities.GetEntryAppearance
local GetTextColor = Utilities.GetTextColor
local GetClassColor = Utilities.GetClassColor
local EntryUsesAura = Utilities.EntryUsesAura
local Mirroring = {}
addon.SoloMirroring = Mirroring

function Solo:QueueItemSync(item)
    if not item then return end
    self.pendingItemSyncs = self.pendingItemSyncs or setmetatable({}, { __mode = "k" })
    if self.pendingItemSyncs[item] then return end
    self.pendingItemSyncs[item] = true
    C_Timer.After(0, function()
        Solo.pendingItemSyncs[item] = nil
        if addon.Runtime and addon.Runtime.itemEntries[item] then
            Solo:SyncFromItem(item)
        end
    end)
end

function Solo:MirrorCount(item, value)
    local entry = addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    if not display then return end
    pcall(display.Count.SetText, display.Count, value)
end

local function IsAccessible(value)
    if addon:IsSecret(value) then return false end
    return not canaccessvalue or canaccessvalue(value)
end

local function ResolveCooldownSpellID(entry)
    if not entry then return nil end
    -- Fetch the info live: override fields can change after talents, casts, and viewer refreshes.
    local info = entry.info or {}
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, liveInfo = pcall(
            C_CooldownViewer.GetCooldownViewerCooldownInfo, entry.cooldownID
        )
        if ok and liveInfo then info = liveInfo end
    end
    -- Tooltip overrides may identify an aura applied by the ability rather than
    -- the spell that owns its cooldown. Cooldown/charge state must use the
    -- actual override/base spell pair.
    local spellID = info.overrideSpellID or info.spellID or entry.spellID
    if not IsAccessible(spellID) or type(spellID) ~= "number" then return nil end
    return spellID
end

local function IsCooldownCategory(entry)
    local category = entry and entry.category
    local categories = Enum and Enum.CooldownViewerCategory
    if not categories then return false end
    return category == categories.Essential
        or category == categories.Utility
        or category == categories.SpecAgnosticEssential
        or category == categories.EquipSlotEssential
end

local function ResolveUnderlyingSpellID(entry)
    if not entry then return nil end
    local info = entry.info or {}
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, liveInfo = pcall(
            C_CooldownViewer.GetCooldownViewerCooldownInfo, entry.cooldownID
        )
        if ok and liveInfo then info = liveInfo end
    end

    -- Tooltip and linked spell IDs commonly identify the aura applied by an
    -- ability (Touch of the Magi is one example), not the spell that owns its
    -- cooldown. Blizzard uses the override/base pair for charge state too.
    local spellID = info.overrideSpellID or info.spellID
    if not IsAccessible(spellID) or type(spellID) ~= "number" then return nil end
    return spellID
end

function Solo:RestoreUnderlyingCooldown(item, display)
    local entry = display and display.entry
    if not item or not display or not IsCooldownCategory(entry) or not C_Spell then
        return false
    end
    -- Never replace a live aura/totem duration. The repair is for the transition
    -- after that visual source has gone away while the cast spell is still on CD.
    if item.auraInstanceID ~= nil or item.wasSetFromAura == true then return false end
    if display.restoringUnderlyingCooldown then return false end

    local spellID = ResolveUnderlyingSpellID(entry)
    if not spellID then return false end

    local durationObject
    local restoredDesaturation
    local hasCharges = false
    if C_Spell.GetSpellCharges and C_Spell.GetSpellChargeDuration then
        local ok, charges = pcall(C_Spell.GetSpellCharges, spellID)
        local maxCharges = ok and charges and charges.maxCharges
        hasCharges = IsAccessible(maxCharges) and type(maxCharges) == "number" and maxCharges > 1
        if hasCharges then
            local currentCharges = charges.currentCharges
            if IsAccessible(currentCharges) and type(currentCharges) == "number" then
                restoredDesaturation = currentCharges == 0
            end
            local chargeIsActive = charges.isActive
            if IsAccessible(chargeIsActive) and chargeIsActive == true then
                ok, durationObject = pcall(C_Spell.GetSpellChargeDuration, spellID)
                if not ok then durationObject = nil end
            end
        end
    end
    if not hasCharges and C_Spell.GetSpellCooldown
        and C_Spell.GetSpellCooldownDuration then
        local ok, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
        local isActive = ok and cooldown and cooldown.isActive
        local isOnGCD = ok and cooldown and cooldown.isOnGCD
        -- isActive/isOnGCD can be secret in combat; comparing them directly
        -- without this gate throws and aborts the whole sync pass.
        if ok and cooldown and IsAccessible(isActive) and IsAccessible(isOnGCD) then
            restoredDesaturation = isActive == true and isOnGCD ~= true
            if restoredDesaturation then
                ok, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID)
                if not ok then durationObject = nil end
            end
        end
    end

    -- A readable ready/charges state with nothing to restore still needs to
    -- clear stale desaturation left over from the aura-visual period: native
    -- SetDesaturated updates aren't reliably re-fired for hasAura spells like
    -- Touch of the Magi once combat starts.
    if not durationObject then
        if type(restoredDesaturation) == "boolean" then
            display.sourceDesaturated = restoredDesaturation
            self:ApplyAppearance(display)
        end
        return false
    end

    local cooldown = display.LiveCooldown or display.Cooldown
    if not cooldown or type(cooldown.SetCooldownFromDurationObject) ~= "function" then
        return false
    end
    display.restoringUnderlyingCooldown = true
    if type(cooldown.SetUseAuraDisplayTime) == "function" then
        pcall(cooldown.SetUseAuraDisplayTime, cooldown, false)
    end
    if type(cooldown.SetReverse) == "function" then
        pcall(cooldown.SetReverse, cooldown, false)
    end
    local applied = pcall(cooldown.SetCooldownFromDurationObject, cooldown, durationObject)
    if applied and type(restoredDesaturation) == "boolean" then
        display.sourceDesaturated = restoredDesaturation
    end
    display.restoringUnderlyingCooldown = nil
    return applied
end

local function GetLiveChargeInfo(entry)
    if not C_Spell or not C_Spell.GetSpellCharges then return nil end
    local spellID = ResolveCooldownSpellID(entry)
    if not spellID then return nil end

    local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
    if not ok or not chargeInfo then return nil end
    return chargeInfo, spellID
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
        if action == "clear" or action == "durationObject"
            or action == "duration" or action == "expiration" then
            self:RestoreUnderlyingCooldown(item, display)
        end
        self:UpdateActiveState(item, display)
        self:ApplyAppearance(display)
        return
    end
    local mirroredTiming = false
    if action == "set" then
        mirroredTiming = pcall(cooldown.SetCooldown, cooldown, ...)
    elseif action == "durationObject" then
        mirroredTiming = pcall(cooldown.SetCooldownFromDurationObject, cooldown, ...)
    elseif action == "duration" then
        mirroredTiming = pcall(cooldown.SetCooldownDuration, cooldown, ...)
    elseif action == "expiration" then
        mirroredTiming = pcall(cooldown.SetCooldownFromExpirationTime, cooldown, ...)
    elseif action == "clear" then
        cooldown:Clear()
        display.nativeAuraCooldownMirrored = nil
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

    if mirroredTiming then
        -- The native frame is now the authoritative timer source. Its Cooldown
        -- widget advances on its own, so deferred appearance/icon refreshes must
        -- not replace this exact CMC-style copy with a reconstructed timer.
        display.nativeAuraCooldownMirrored = true
    end

    -- Aura-capable cooldown items can be cleared or handed a zero-duration aura
    -- after the aura ends even while their underlying cast spell is still on CD.
    -- Re-arm only that real cooldown; otherwise keep the exact native update.
    if action == "durationObject" or action == "duration"
        or action == "expiration" or action == "clear" then
        self:RestoreUnderlyingCooldown(item, display)
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
    local spellID = ResolveCooldownSpellID(entry)
    if not spellID then return end
    local durationObject
    local chargeInfo = GetLiveChargeInfo(entry)
    local currentCharges
    local hasCharges = false
    local onActualCooldown
    if chargeInfo and C_Spell.GetSpellChargeDuration then
        local maxCharges = chargeInfo.maxCharges
        hasCharges = IsAccessible(maxCharges)
            and type(maxCharges) == "number" and maxCharges > 1
        if hasCharges then
            currentCharges = chargeInfo.currentCharges
            if IsAccessible(currentCharges) and type(currentCharges) == "number" then
                onActualCooldown = currentCharges == 0
            end
            -- isActive can be a secret value (e.g. Mythic+ combat restrictions).
            -- The duration object itself is opaque and safe to apply either
            -- way, so don't gate the fetch on being able to read that flag.
            local ok, result = pcall(C_Spell.GetSpellChargeDuration, spellID)
            if ok then durationObject = result end
        end
    end
    if hasCharges and IsAccessible(currentCharges) and type(currentCharges) == "number" then
        pcall(display.Count.SetText, display.Count, currentCharges)
    else
        pcall(display.Count.SetText, display.Count, "")
    end
    if not hasCharges and C_Spell.GetSpellCooldown then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and cooldownInfo then
            local isActive, isOnGCD = cooldownInfo.isActive, cooldownInfo.isOnGCD
            if IsAccessible(isActive) and IsAccessible(isOnGCD) then
                onActualCooldown = isActive == true and isOnGCD ~= true
            end
        else
            onActualCooldown = false
        end
    end
    if not hasCharges and onActualCooldown ~= false and C_Spell.GetSpellCooldownDuration then
        -- Fetch even when isActive/isOnGCD were unreadable (secret): the
        -- duration object is opaque and SetCooldownFromDurationObject doesn't
        -- need those booleans to apply it.
        local ok, result = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        if ok then durationObject = result end
    end
    if type(onActualCooldown) == "boolean" then
        display.sourceDesaturated = onActualCooldown
    end
    if durationObject and display.Cooldown.SetCooldownFromDurationObject then
        if type(display.Cooldown.SetUseAuraDisplayTime) == "function" then
            pcall(display.Cooldown.SetUseAuraDisplayTime, display.Cooldown, false)
        end
        if type(display.Cooldown.SetReverse) == "function" then
            pcall(display.Cooldown.SetReverse, display.Cooldown, false)
        end
        pcall(display.Cooldown.SetCooldownFromDurationObject, display.Cooldown, durationObject)
    elseif onActualCooldown == false and type(display.Cooldown.Clear) == "function" then
        pcall(display.Cooldown.Clear, display.Cooldown)
    end
end

function Solo:SyncAuraCooldown(item, display)
    if display and display.LiveCooldown then return true end
    if not item or not display or not display.Cooldown then return false end
    if display.nativeAuraCooldownMirrored then return true end

    local cooldown = display.Cooldown
    if type(cooldown.SetUseAuraDisplayTime) == "function" then
        pcall(cooldown.SetUseAuraDisplayTime, cooldown, true)
    end
    if type(cooldown.SetReverse) == "function" then
        -- CMC's live-aura cooldown frames use reverse mode. Spell cooldowns
        -- switch this back off in SyncSpellCooldown/RestoreUnderlyingCooldown.
        pcall(cooldown.SetReverse, cooldown, true)
    end

    -- Match CMC's TrackerItemVisuals/ApplyCustomActiveOverlay path: feed a real
    -- CooldownFrameTemplate with start + duration through SetCooldown. The
    -- previous SetCooldownFromExpirationTime mirror did not make Retail create
    -- countdown text for replacement buffs such as Prismatic Bolt.
    if type(item.GetCooldownValues) == "function"
        and type(cooldown.SetCooldown) == "function" then
        local valuesOK, expirationTime, duration, modRate = pcall(item.GetCooldownValues, item)
        if valuesOK then
            -- Aura times can be secret in combat. Keep both the subtraction and
            -- Cooldown call inside pcall; if Retail denies arithmetic here, the
            -- native duration-object path below remains the protected fallback.
            local applied = pcall(function()
                local startTime = expirationTime - duration
                cooldown:SetCooldown(startTime, duration, modRate)
                cooldown:SetDrawSwipe(true)
            end)
            if applied then return true end
        end
    end

    if not C_UnitAuras or not C_UnitAuras.GetAuraDuration then return false end
    if type(item.GetAuraDataUnit) ~= "function" or type(item.GetAuraSpellInstanceID) ~= "function" then
        return false
    end
    local unitOK, unit = pcall(item.GetAuraDataUnit, item)
    local instanceOK, auraInstanceID = pcall(item.GetAuraSpellInstanceID, item)
    if not unitOK or not instanceOK or not unit then return false end

    -- Keep the aura instance opaque. In 12.1 it may be secret: it is passed
    -- directly to Blizzard's duration-object API and is never compared, indexed,
    -- or used as a Lua table key.
    local durationOK, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
    if not durationOK or not durationObject then return false end
    local applied = pcall(
        cooldown.SetCooldownFromDurationObject,
        cooldown, durationObject, true
    )
    return applied
end

function Solo:SyncCooldown(item, display)
    local entry = display and display.entry
    if not entry then return end
    if self:RestoreUnderlyingCooldown(item, display) then return end
    if EntryUsesAura(entry) and self:SyncAuraCooldown(item, display) then return end
    if not EntryUsesAura(entry) or IsCooldownCategory(entry) then
        self:SyncSpellCooldown(display)
    end
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
    local ok, attachError = pcall(function()
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
        local function RefreshCount(_, value)
            -- Stack text can itself be protected. Pass it directly to the
            -- FontString; SetText(nil) already provides the empty-state behavior.
            Solo:MirrorCount(item, value)
        end
        if not self.mirrorHooks[countSource] then
            self.mirrorHooks[countSource] = true
            hooksecurefunc(countSource, "SetText", function()
                -- Do not inspect a possibly-secret count while Blizzard's native
                -- refresh is still on the stack. Reading it next frame avoids
                -- tainting the remainder of that refresh.
                C_Timer.After(0, function()
                    pcall(function() RefreshCount(countSource, countSource:GetText()) end)
                end)
            end)
        end
        pcall(function() RefreshCount(countSource, countSource:GetText()) end)
    end

    -- Aura categories own Applications text. Cooldown categories must never
    -- inherit it: Blizzard pools these widgets, so a stale aura stack such as
    -- "2" can otherwise leak onto a non-charge spell (Ice Cold/Alter Time).
    if EntryUsesAura(display.entry) then
        InstallCountSource(item.Applications and item.Applications.Applications)
        InstallCountSource(item.Icon and item.Icon.Applications)
    else
        display.Count:SetText("")
    end

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
                -- Follow CMC's native cooldown hook pattern: consume the exact
                -- update Blizzard just applied instead of rediscovering it from
                -- a spell ID on the following frame. This is essential for
                -- replacement auras such as Prismatic Bolt, whose timer is not
                -- a spell cooldown. Keep the deferred sync as a state/appearance
                -- backup after the native update has completed.
                if EntryUsesAura(display.entry) then
                    Solo:MirrorCooldown(item, action, ...)
                end
                Solo:QueueItemSync(item)
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
    -- Aura entries reuse Blizzard's own Cooldown widget directly (matches
    -- v1.0.1): its native swipe/countdown stays authoritative instead of being
    -- re-derived, which is what made TrackedBuff/TrackedBar reliable.
    if not self:AttachLiveCooldown(item, display, sourceCooldown) then
        if display.LiveCooldown then self:DetachLiveCooldown(display) end
        display.Cooldown:Show()
    end

    local sourceIcon
    if type(item.GetIconTexture) == "function" then
        local ok, iconTexture = pcall(item.GetIconTexture, item)
        if ok then sourceIcon = iconTexture end
    end
    sourceIcon = sourceIcon or (item.Icon and item.Icon.Icon) or item.Icon
    if sourceIcon and type(sourceIcon.SetDesaturated) == "function" and not self.mirrorHooks[sourceIcon] then
        self.mirrorHooks[sourceIcon] = true
        hooksecurefunc(sourceIcon, "SetDesaturated", function() Solo:QueueItemSync(item) end)
    end
    if sourceIcon and type(sourceIcon.IsDesaturated) == "function" then
        local ok, value = pcall(sourceIcon.IsDesaturated, sourceIcon)
        if ok and not addon:IsSecret(value) and type(value) == "boolean" then
            self:MirrorDesaturation(item, value)
        end
    end

    self:UpdateActiveState(item, display)
    self:SyncCooldown(item, display)

    if display.isBar and item.Bar then
        local function InstallBarText(source, key)
            if not source then return end
            if not self.mirrorHooks[source] then
                self.mirrorHooks[source] = true
                hooksecurefunc(source, "SetText", function()
                    C_Timer.After(0, function()
                        pcall(function() Solo:MirrorBarText(item, key, source:GetText()) end)
                    end)
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
                    hooksecurefunc(sourceStatusBar, "SetValue", function() Solo:QueueItemSync(item) end)
                end
                if type(sourceStatusBar.SetMinMaxValues) == "function" then
                    hooksecurefunc(sourceStatusBar, "SetMinMaxValues", function() Solo:QueueItemSync(item) end)
                end
                if type(sourceStatusBar.SetStatusBarColor) == "function" then
                    hooksecurefunc(sourceStatusBar, "SetStatusBarColor", function() Solo:QueueItemSync(item) end)
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
