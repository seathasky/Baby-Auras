local _, addon = ...

local Solo = addon.Solo
local combatWatcher = CreateFrame("Frame")
local COOLDOWN_REFRESH_DELAYS = { 0, 0.05, 0.20 }
local cooldownRefreshTimers = {}

local function CancelCooldownRefreshTimers()
    for index = 1, 3 do
        local timer = cooldownRefreshTimers[index]
        if timer then timer:Cancel() end
        cooldownRefreshTimers[index] = nil
    end
end

local function ScheduleCooldownRefreshes()
    -- A newer cooldown/aura event makes every older settled refresh obsolete.
    -- Cancel those timers instead of letting their callbacks wake up only to
    -- perform no useful refresh work.
    CancelCooldownRefreshTimers()
    for index, delay in ipairs(COOLDOWN_REFRESH_DELAYS) do
        local timerIndex = index
        cooldownRefreshTimers[timerIndex] = C_Timer.NewTimer(delay, function()
            cooldownRefreshTimers[timerIndex] = nil
            Solo:RefreshCooldowns()
        end)
    end
end

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
        ScheduleCooldownRefreshes()
    elseif Solo.editMode then
        Solo:SetEditMode(false, false)
    end
end)
