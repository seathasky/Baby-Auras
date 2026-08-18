local _, addon = ...

-- Read-only Cooldown Manager presentation bridge.
-- IMPORTANT: never instantiate CooldownViewer item templates or call SetCooldownID
-- from addon code. Blizzard's OnCooldownIDSet mutates the shared cooldownInfo table
-- (linkedSpellID, aura state, etc.), which can taint secret combat state.
addon.CDMState = { settingsCache = {} }
local CDMState = addon.CDMState

local function SafeSpellName(spellID)
    if not spellID or not C_Spell then return nil end
    local ok, value = pcall(C_Spell.GetSpellName, spellID)
    return ok and value or nil
end

local function SafeStaticTexture(spellID)
    if not spellID or not C_Spell then return nil end
    local ok, icon, originalIcon = pcall(C_Spell.GetSpellTexture, spellID)
    if not ok then return nil end
    -- Blizzard settings items have UsesDynamicAppearance()==false and therefore
    -- use the original/static spell texture.
    return originalIcon or icon
end

function CDMState:Invalidate()
    wipe(self.settingsCache)
end

function CDMState:GetProviderInfo(cooldownID)
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
        if ok then return info end
    end
end

function CDMState:GetSettingsState(cooldownID)
    if type(cooldownID) ~= "number" then return nil end
    local cached = self.settingsCache[cooldownID]
    if cached then return cached end

    local info = self:GetProviderInfo(cooldownID)
    if not info then return nil end

    -- Exact GetSpellID precedence for a Blizzard settings item when
    -- UsesDynamicAppearance()==false: tooltip override -> override -> base.
    local spellID = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
    local state = {
        cooldownID = cooldownID,
        info = info,
        category = info.category,
        spellID = spellID,
        baseSpellID = info.spellID,
        name = SafeSpellName(spellID),
        texture = SafeStaticTexture(spellID),
    }
    self.settingsCache[cooldownID] = state
    return state
end

function CDMState:GetLiveItem(cooldownID)
    return addon.Runtime and addon.Runtime:GetLiveItem(cooldownID) or nil
end

function CDMState:GetLiveTexture(cooldownID, item)
    item = item or self:GetLiveItem(cooldownID)
    if not item then return nil end

    -- Read the Texture region Blizzard already populated. This is observation
    -- only: no Blizzard frame/table state is modified.
    local textureRegion = item.Icon and item.Icon.Icon or item.Icon
    if type(item.GetIconTexture) == "function" then
        local ok, region = pcall(item.GetIconTexture, item)
        if ok and region then textureRegion = region end
    end
    if textureRegion and type(textureRegion.GetTexture) == "function" then
        local ok, texture = pcall(textureRegion.GetTexture, textureRegion)
        if ok and texture ~= nil then return texture end
    end
    return nil
end

function CDMState:GetDisplayTexture(entry, preferLive)
    if not entry then return nil end
    local settings = addon:GetEntrySettings(entry.cooldownID, false)
    local customSpellID = settings and tonumber(settings.customIconSpellID)
    if customSpellID and C_Spell then
        local ok, texture = pcall(C_Spell.GetSpellTexture, customSpellID)
        if ok and texture then return texture end
    end

    if entry.cooldownID == 198408 and settings and settings.showPrismaticBoltIcon == true then
        return 8026694
    end

    if preferLive then
        local texture = self:GetLiveTexture(entry.cooldownID)
        if texture ~= nil then return texture end
    end

    local state = self:GetSettingsState(entry.cooldownID)
    return state and state.texture or entry.originalIcon or entry.icon
end
