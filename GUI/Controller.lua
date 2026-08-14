local _, addon = ...

local GUI = addon.GUI

function GUI:Toggle()
    if (not self.frame or not self.frame:IsShown()) and InCombatLockdown() then
        self.openAfterCombat = true
        print("|cFF66FF66Baby Auras:|r Options will open when combat ends.")
        return
    end
    self.openAfterCombat = nil
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
    if self.frame:IsShown() then addon:RefreshAll() end
end

local combatQueue = CreateFrame("Frame")
combatQueue:RegisterEvent("ADDON_LOADED")
combatQueue:RegisterEvent("PLAYER_REGEN_DISABLED")
combatQueue:RegisterEvent("PLAYER_REGEN_ENABLED")
combatQueue:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_CooldownViewer" or addonName == "Blizzard_EditMode" or addonName == "BabyAuras" then
            GUI:InstallCDMReturnHook()
            GUI:InstallBlizzardEditReturnHook()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if GUI.frame and GUI.frame:IsShown() then
            GUI.frame:Hide()
            GUI.openAfterCombat = true
            print("|cFF66FF66Baby Auras:|r Options closed for combat and will reopen afterward.")
        end
    elseif GUI.openBlizzardAfterCombat then
        C_Timer.After(0, function() GUI:OpenBlizzardCDM() end)
    elseif GUI.openAfterCombat then
        GUI.openAfterCombat = nil
        C_Timer.After(0, function()
            GUI:Create()
            GUI.frame:Show()
            addon:RefreshAll()
        end)
    end
end)
