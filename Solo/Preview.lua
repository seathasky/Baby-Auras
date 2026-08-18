local _, addon = ...

local Solo = addon.Solo
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

function Solo:SetTextPreviewEnabled(enabled)
    if enabled == true and not self:IsPositioningMode() then return false end
    self.textPreviewEnabled = enabled == true
    for _, display in pairs(self.displays) do self:RefreshDisplay(display) end
    return self.textPreviewEnabled == true
end

function Solo:ToggleTextPreview(entry, enabled)
    if not entry or (enabled ~= false and not self:IsPositioningMode()) then return false end
    self:EnsureDisplay(entry, addon.Runtime:GetLiveItem(entry.cooldownID))
    if enabled == nil then
        return self:SetTextPreviewEnabled(not self.textPreviewEnabled)
    end
    return self:SetTextPreviewEnabled(enabled == true)
end

function Solo:IsTextPreviewEnabled()
    return self:IsPositioningMode() and self.textPreviewEnabled == true
end

function Solo:RefreshCooldowns()
    for cooldownID, display in pairs(self.displays) do
        if IsSoloEnabled(display.entry) then
            self:SyncCooldown(self.sources[cooldownID], display)
            self:ApplyAppearance(display)
        end
    end
end
