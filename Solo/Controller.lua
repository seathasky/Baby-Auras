local _, addon = ...

local Solo = addon.Solo
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("ADDON_LOADED")
combatWatcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
combatWatcher:RegisterEvent("SPELL_UPDATE_CHARGES")
combatWatcher:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        Solo:InstallEditorHooks()
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        if not Solo.cooldownRefreshQueued then
            Solo.cooldownRefreshQueued = true
            C_Timer.After(0, function()
                Solo.cooldownRefreshQueued = nil
                Solo:RefreshCooldowns()
            end)
        end
    elseif Solo.editMode then
        Solo:SetEditMode(false, false)
    end
end)
