local _, addon = ...

local Solo = addon.Solo
local Defaults = addon.Defaults
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

function Solo:GetViewer(item)
    if not item or type(item.GetViewerFrame) ~= "function" then return false end
    local ok, viewer = pcall(item.GetViewerFrame, item)
    return ok and viewer or nil
end

function Solo:IsSupportedItem(item)
    local viewer = self:GetViewer(item)
    return viewer == _G.EssentialCooldownViewer
        or viewer == _G.UtilityCooldownViewer
        or viewer == _G.BuffIconCooldownViewer
        or viewer == _G.BuffBarCooldownViewer
end

function Solo:IsTrackedBarItem(item)
    return self:GetViewer(item) == _G.BuffBarCooldownViewer
end

function Solo:IsEligible(entry)
    if not entry then return false end
    local item = addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID)
    return item and self:IsSupportedItem(item) or false
end

function Solo:GetTexture(entry)
    return addon.Catalog:GetDisplayIcon(entry)
end

function Solo:SetSourceHidden(item, hidden)
    if item and item.SetAlpha then item:SetAlpha(hidden and 0 or 1) end
end

function Solo:EnsureDisplay(entry, item)
    local display = self.displays[entry.cooldownID]
    local itemIsBar = item and self:IsTrackedBarItem(item) or false
    if display and item and display.isBar ~= itemIsBar then
        if display.isDragging then
            display:StopMovingOrSizing()
            display.isDragging = nil
            self:SaveDisplayPosition(display)
        end
        self:ClearSnap(display)
        if display.LiveCooldown then self:DetachLiveCooldown(display) end
        if addon.Glow then addon.Glow:Stop(display) end
        display:Hide()
        if display.EditOutline then display.EditOutline:Hide() end
        display:SetScript("OnDragStart", nil)
        display:SetScript("OnDragStop", nil)
        display:SetScript("OnUpdate", nil)
        display:SetScript("OnClick", nil)
        display:SetScript("OnEnter", nil)
        display:SetScript("OnLeave", nil)
        self.displays[entry.cooldownID] = nil
        display = self:CreateDisplay(entry, item)
    elseif not display then
        display = self:CreateDisplay(entry, item)
    end
    display.entry = entry
    self:ApplyDisplayScale(display)
    if item then
        self.sources[entry.cooldownID] = item
        self:InstallMirrors(item, display)
    end
    self:RefreshDisplay(display)
    return display
end

function Solo:SyncFromItem(item)
    local entry = addon.Runtime.itemEntries[item]
    if not entry or not IsSoloEnabled(entry) or not self:IsSupportedItem(item) then return end
    local display = self:EnsureDisplay(entry, item)
    if type(item.IsActive) == "function" then
        local ok, active = pcall(item.IsActive, item)
        if ok and not addon:IsSecret(active) then display.active = active == true end
    end
    self:UpdateActiveState(item, display)
    self:SyncCooldown(item, display)
    self:RefreshDisplay(display)
end

function Solo:OnTrigger(item, trigger)
    local entry = addon.Runtime.itemEntries[item]
    if not entry or not IsSoloEnabled(entry) then return end
    local display = self:EnsureDisplay(entry, item)
    if trigger == Enum.CooldownViewerAlertEventType.OnAuraApplied then
        display.active = true
        display.activeState = true
    elseif trigger == Enum.CooldownViewerAlertEventType.OnAuraRemoved then
        display.active = false
        display.activeState = false
    end
    self:SyncCooldown(item, display)
    self:RefreshDisplay(display)
end

function Solo:RefreshItem(item)
    local entry = addon.Runtime.itemEntries[item]
    local oldCooldownID = self.itemCooldownIDs[item]
    if oldCooldownID and (not entry or oldCooldownID ~= entry.cooldownID) then
        local oldDisplay = self.displays[oldCooldownID]
        if self.sources[oldCooldownID] == item then
            if oldDisplay and oldDisplay.LiveCooldown then self:DetachLiveCooldown(oldDisplay) end
            self.sources[oldCooldownID] = nil
            if oldDisplay then
                oldDisplay.active = false
                oldDisplay.activeState = false
                oldDisplay:Hide()
            end
        end
        self:SetSourceHidden(item, false)
    end
    self.itemCooldownIDs[item] = entry and entry.cooldownID or nil

    if not entry or not self:IsSupportedItem(item) then return end
    if IsSoloEnabled(entry) then
        local previousSource = self.sources[entry.cooldownID]
        if previousSource and previousSource ~= item then
            local display = self.displays[entry.cooldownID]
            if display and display.LiveCooldown then self:DetachLiveCooldown(display) end
            self:SetSourceHidden(previousSource, false)
        end
        self.sources[entry.cooldownID] = item
        self:SetSourceHidden(item, not self.suspended)
        self:SyncFromItem(item)
    else
        self:SetSourceHidden(item, false)
    end
end

function Solo:ReleaseItem(item)
    local cooldownID = self.itemCooldownIDs[item]
    local display = cooldownID and self.displays[cooldownID]
    if cooldownID and self.sources[cooldownID] == item then
        if display and display.LiveCooldown then self:DetachLiveCooldown(display) end
        self.sources[cooldownID] = nil
        if display then
            if addon.Glow then addon.Glow:Stop(display) end
            display.active = false
            display.activeState = false
            display:Hide()
        end
    end
    self.itemCooldownIDs[item] = nil
    self:SetSourceHidden(item, false)
end

function Solo:ReconcileDisplays()
    for cooldownID, display in pairs(self.displays) do
        local item = self.sources[cooldownID]
        local entry = item and addon.Runtime.itemEntries[item]
        if not entry or entry.cooldownID ~= cooldownID then
            if display.LiveCooldown then self:DetachLiveCooldown(display) end
            if addon.Glow then addon.Glow:Stop(display) end
            self.sources[cooldownID] = nil
            display.active = false
            display.activeState = false
            display:Hide()
        else
            display.entry = entry
            self:RefreshDisplay(display)
        end
    end
end

-- Kept as a no-op compatibility entry point for Runtime.
function Solo:CompactViewer() end

function Solo:SetEnabled(entry, enabled)
    if InCombatLockdown() then return false, "Solo icons cannot be changed during combat." end
    if enabled and not self:IsEligible(entry) then
        return false, "Solo is available only for live Blizzard Cooldown Manager elements."
    end

    local settings = addon:GetEntrySettings(entry.cooldownID, true)
    local item = addon.Runtime:GetLiveItem(entry.cooldownID)
    settings.solo = enabled == true
    if enabled then
        if settings.soloBlackBorder == nil then
            settings.soloBlackBorder = item and self:IsTrackedBarItem(item)
                and false or Defaults.soloAppearance.blackBorder
        end
        if settings.soloBorderPixels == nil then
            settings.soloBorderPixels = Defaults.soloAppearance.borderPixels
        end
    end
    if enabled then
        if not settings.soloPosition then
            settings.soloPosition = self:GetDefaultPosition(entry, item)
        end
        self:GetPosition(entry, true)
        self:EnsureDisplay(entry, item)
        if item then
            self:SetSourceHidden(item, not self.suspended)
            self:SyncFromItem(item)
        end
    else
        self:RemoveFromLinkGroup(entry)
        local display = self.displays[entry.cooldownID]
        if display then
            self:DetachLiveCooldown(display)
            if addon.Glow then addon.Glow:Stop(display) end
            display:Hide()
        end
        self:SetSourceHidden(item or self.sources[entry.cooldownID], false)
    end
    return true
end
