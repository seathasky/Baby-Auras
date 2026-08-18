local _, addon = ...

local Solo = addon.Solo
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("ADDON_LOADED")
combatWatcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
combatWatcher:RegisterEvent("SPELL_UPDATE_CHARGES")
combatWatcher:RegisterUnitEvent("UNIT_AURA", "player", "target")
combatWatcher:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        Solo:InstallEditorHooks()
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "UNIT_AURA" then
        -- Blizzard can create/reset the native Cooldown countdown FontString a
        -- frame or two after the event that started the cooldown/aura. A single
        -- zero-delay refresh can therefore run too early, leaving BabyAuras'
        -- cooldown text preference unapplied until /reload. Reapply presentation
        -- only at a few settled points; no cooldown/aura values are copied here.
        Solo.cooldownRefreshGeneration = (Solo.cooldownRefreshGeneration or 0) + 1
        local generation = Solo.cooldownRefreshGeneration
        for _, delay in ipairs({ 0, 0.05, 0.20 }) do
            C_Timer.After(delay, function()
                if Solo.cooldownRefreshGeneration == generation then
                    Solo:RefreshCooldowns()
                end
            end)
        end
    elseif Solo.editMode then
        Solo:SetEditMode(false, false)
    end
end)
