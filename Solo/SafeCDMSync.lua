local _, addon = ...

local Solo = addon.Solo
local Utilities = addon.SoloUtilities
local EntryUsesAura = Utilities.EntryUsesAura

local function Accessible(value)
    if addon:IsSecret(value) then return false end
    return not canaccessvalue or canaccessvalue(value)
end

local function CooldownCategory(entry)
    local category = entry and entry.category
    local C = Enum and Enum.CooldownViewerCategory
    return C and (category == C.Essential or category == C.Utility
        or category == C.SpecAgnosticEssential or category == C.EquipSlotEssential)
end

local function LiveInfo(entry)
    if not entry then return nil end
    local info = entry.info
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, value = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, entry.cooldownID)
        if ok and value then info = value end
    end
    return info or {}
end

-- Blizzard settings items have UsesDynamicAppearance() == false. This is the
-- exact spell precedence used by their settings screen.
local function StaticDisplaySpellID(entry)
    local info = LiveInfo(entry)
    local id = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID or entry.spellID
    return Accessible(id) and type(id) == "number" and id or nil
end

-- For actual spell cooldown/charge state Blizzard intentionally uses the
-- override/base pair, not an aura tooltip override.
local function CooldownSpellID(entry)
    local info = LiveInfo(entry)
    local id = info.overrideSpellID or info.spellID or entry.spellID
    if not Accessible(id) or type(id) ~= "number" then return nil end
    return id
end

local function ReadLiveTexture(item)
    if not item then return nil end
    local textureRegion
    if type(item.GetIconTexture) == "function" then
        local ok, value = pcall(item.GetIconTexture, item)
        if ok then textureRegion = value end
    end
    textureRegion = textureRegion or (item.Icon and item.Icon.Icon) or item.Icon
    if textureRegion and type(textureRegion.GetTexture) == "function" then
        local ok, texture = pcall(textureRegion.GetTexture, textureRegion)
        if ok and Accessible(texture) then return texture end
    end
    if type(item.GetSpellTexture) == "function" then
        local ok, texture = pcall(item.GetSpellTexture, item)
        if ok and Accessible(texture) then return texture end
    end
end

local function SetCountFromNative(item, display, entry)
    if not display or not display.Count then return end
    local source
    if CooldownCategory(entry) then
        local chargeFrame = item and item.ChargeCount
        if item and type(item.GetChargeCountFrame) == "function" then
            local ok, value = pcall(item.GetChargeCountFrame, item)
            if ok and value then chargeFrame = value end
        end
        source = chargeFrame and chargeFrame.Current
    elseif EntryUsesAura(entry) then
        source = item and ((item.Applications and item.Applications.Applications)
            or (item.Icon and item.Icon.Applications))
    end
    if source and type(source.GetText) == "function" then
        local ok, text = pcall(source.GetText, source)
        if ok and Accessible(text) then
            pcall(display.Count.SetText, display.Count, text or "")
            return
        end
    end
    -- Safe API fallback for ordinary charge spells.
    local spellID = CooldownSpellID(entry)
    if spellID and C_Spell and C_Spell.GetSpellCharges then
        local ok, charges = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and charges then
            local maxCharges, current = charges.maxCharges, charges.currentCharges
            if Accessible(maxCharges) and Accessible(current)
                and type(maxCharges) == "number" and maxCharges > 1 then
                pcall(display.Count.SetText, display.Count, current)
                return
            end
        end
    end
    pcall(display.Count.SetText, display.Count, "")
end

local function ApplyDurationObject(display, durationObject, reverse)
    if not display or not display.Cooldown or not durationObject then return false end
    local cd = display.Cooldown
    if type(cd.SetCooldownFromDurationObject) ~= "function" then return false end
    pcall(cd.SetUseAuraDisplayTime, cd, reverse == true)
    pcall(cd.SetReverse, cd, reverse == true)
    local ok = pcall(cd.SetCooldownFromDurationObject, cd, durationObject)
    if ok then
        pcall(cd.SetDrawSwipe, cd, true)
        display.sourceDrawSwipe = true
    end
    return ok
end

local function GetAuraDurationForAuraData(unit, aura)
    if not aura then return nil end
    local instanceID = aura.auraInstanceID
    if not Accessible(instanceID) or type(instanceID) ~= "number" then return nil end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDuration then return nil end
    local ok, duration = pcall(C_UnitAuras.GetAuraDuration, unit, instanceID)
    return ok and duration or nil
end

local function FindSafeAuraDuration(entry, item)
    if not C_UnitAuras then return nil end
    local candidateIDs, seen = {}, {}
    local function Add(id)
        if Accessible(id) and type(id) == "number" and not seen[id] then
            seen[id] = true
            candidateIDs[#candidateIDs + 1] = id
        end
    end
    if item then
        if type(item.GetAuraSpellID) == "function" then
            local ok, id = pcall(item.GetAuraSpellID, item); if ok then Add(id) end
        end
        if type(item.GetSpellID) == "function" then
            local ok, id = pcall(item.GetSpellID, item); if ok then Add(id) end
        end
    end
    local info = LiveInfo(entry)
    Add(info.linkedSpellID)
    if type(info.linkedSpellIDs) == "table" then
        for _, id in ipairs(info.linkedSpellIDs) do Add(id) end
    end
    Add(info.overrideTooltipSpellID)
    Add(info.overrideSpellID)
    Add(info.spellID)
    Add(entry.spellID)

    -- Player auras have a taint-safe spell-ID lookup in the 12.1 API.
    if C_UnitAuras.GetPlayerAuraBySpellID then
        for _, id in ipairs(candidateIDs) do
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and aura then
                local duration = GetAuraDurationForAuraData("player", aura)
                if duration then return duration, aura end
            end
        end
    end

    -- Target lookup is name-based and only succeeds for non-secret auras. If
    -- Retail restricts the aura, we deliberately decline to manufacture a timer.
    if UnitExists("target") and C_UnitAuras.GetAuraDataBySpellName then
        for _, id in ipairs(candidateIDs) do
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            if name and Accessible(name) then
                for _, filter in ipairs({ "HARMFUL|PLAYER", "HELPFUL|PLAYER", "HARMFUL", "HELPFUL" }) do
                    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", name, filter)
                    if ok and aura then
                        local auraSpellID = aura.spellId
                        if (not Accessible(auraSpellID)) or auraSpellID == id then
                            local duration = GetAuraDurationForAuraData("target", aura)
                            if duration then return duration, aura end
                        end
                    end
                end
            end
        end
    end
end

function Solo:DetachLiveCooldown(display)
    -- 12.1 secret-value safety: never reparent or otherwise mutate Blizzard's
    -- CooldownViewer cooldown frame.
    if display then
        display.LiveCooldown = nil
        if display.Cooldown then display.Cooldown:Show() end
    end
end

function Solo:AttachLiveCooldown()
    return false
end

function Solo:MirrorCooldown()
    -- Disabled intentionally. Passing Blizzard's secret timing arguments from a
    -- secure hook into an addon-owned cooldown is forbidden in 12.1.
end

function Solo:SyncSpellCooldown(display)
    local entry = display and display.entry
    if not entry or not C_Spell then return false end
    local spellID = CooldownSpellID(entry)
    if not spellID then return false end

    local chargeDuration
    local hasCharges = false
    if C_Spell.GetSpellCharges and C_Spell.GetSpellChargeDuration then
        local ok, charges = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and charges then
            local maxCharges = charges.maxCharges
            if Accessible(maxCharges) and type(maxCharges) == "number" and maxCharges > 1 then
                hasCharges = true
                local durationOK, value = pcall(C_Spell.GetSpellChargeDuration, spellID)
                if durationOK then chargeDuration = value end
            end
        end
    end
    if hasCharges and chargeDuration then
        return ApplyDurationObject(display, chargeDuration, false)
    end

    if C_Spell.GetSpellCooldownDuration then
        local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        if ok and duration then return ApplyDurationObject(display, duration, false) end
    end
    if display.Cooldown and type(display.Cooldown.Clear) == "function" then
        pcall(display.Cooldown.Clear, display.Cooldown)
    end
    return false
end

function Solo:RestoreUnderlyingCooldown(_, display)
    return self:SyncSpellCooldown(display)
end

function Solo:SyncAuraCooldown(item, display)
    local duration = FindSafeAuraDuration(display and display.entry, item)
    if duration then return ApplyDurationObject(display, duration, true) end
    return false
end

function Solo:SyncCooldown(item, display)
    local entry = display and display.entry
    if not entry or not display.Cooldown then return end
    -- Actively cast Essential/Utility items may display an aura, but their
    -- underlying recharge/cooldown must still remain available when the aura is
    -- not safely readable.
    if EntryUsesAura(entry) and self:SyncAuraCooldown(item, display) then return end
    if CooldownCategory(entry) then
        self:SyncSpellCooldown(display)
    elseif type(display.Cooldown.Clear) == "function" then
        pcall(display.Cooldown.Clear, display.Cooldown)
    end
end

function Solo:MirrorBarProgress(item)
    local entry = addon.Runtime and addon.Runtime.itemEntries[item]
    local display = entry and self.displays[entry.cooldownID]
    if not display or not display.BarProgress or not item or not item.Bar then return end
    local source = display.SourceStatusBar or (addon.SoloMirroring and addon.SoloMirroring.FindStatusBar(item.Bar))
    if not source then return end
    display.SourceStatusBar = source
    local ok, minimum, maximum = pcall(source.GetMinMaxValues, source)
    if not ok or not Accessible(minimum) or not Accessible(maximum) then return end
    local valueOK, value = pcall(source.GetValue, source)
    if not valueOK or not Accessible(value) then return end
    pcall(display.BarProgress.SetMinMaxValues, display.BarProgress, minimum, maximum)
    pcall(display.BarProgress.SetValue, display.BarProgress, value)
end

function Solo:InstallMirrors(item, display)
    if not item or not display then return end
    -- Read-only snapshot of Blizzard presentation. No hooks are installed on
    -- Cooldown, FontString, StatusBar, aura, or item refresh methods here.
    local texture = ReadLiveTexture(item)
    if texture then display.runtimeTexture = texture end
    SetCountFromNative(item, display, display.entry)

    local sourceIcon
    if type(item.GetIconTexture) == "function" then
        local ok, value = pcall(item.GetIconTexture, item); if ok then sourceIcon = value end
    end
    sourceIcon = sourceIcon or (item.Icon and item.Icon.Icon) or item.Icon
    if sourceIcon and type(sourceIcon.IsDesaturated) == "function" then
        local ok, value = pcall(sourceIcon.IsDesaturated, sourceIcon)
        if ok and Accessible(value) and type(value) == "boolean" then
            display.sourceDesaturated = value
        end
    end

    if display.isBar and item.Bar then
        local function CopyText(source, target)
            if source and target and type(source.GetText) == "function" then
                local ok, text = pcall(source.GetText, source)
                if ok and Accessible(text) then pcall(target.SetText, target, text or "") end
            end
        end
        CopyText(item.Bar.Name, display.BarName)
        CopyText(item.Bar.Duration, display.BarDuration)
        self:MirrorBarProgress(item)
    end

    self:SyncCooldown(item, display)
end

-- Expose the static resolver so the GUI can use the same source as Blizzard's
-- settings screen without constructing/mutating a Blizzard settings item.
function Solo:GetCDMStaticSpellID(entry)
    return StaticDisplaySpellID(entry)
end
