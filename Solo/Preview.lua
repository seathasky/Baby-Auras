local _, addon = ...

local Solo = addon.Solo
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

function Solo:ToggleTextPreview(entry, enabled)
    if not entry or (enabled ~= false and not self:IsPositioningMode()) then return false end
    if enabled == nil then
        self.textPreviewEnabled = not self.textPreviewEnabled
    else
        self.textPreviewEnabled = enabled == true
    end
    self:EnsureDisplay(entry, addon.Runtime:GetLiveItem(entry.cooldownID))
    for _, display in pairs(self.displays) do self:RefreshDisplay(display) end
    return self.textPreviewEnabled == true
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
