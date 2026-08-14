local _, addon = ...

local GUI = addon.GUI

function GUI:StartSoloEditMode()
    if InCombatLockdown() then
        self:SetStatus("Edit Mode is unavailable during combat.")
        print("|cFFFFCC00Baby Auras:|r Edit Mode cannot open during combat.")
        return
    end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EditMode") end
    self:InstallBlizzardEditReturnHook()
    local manager = _G.EditModeManagerFrame
    if not manager or (manager.CanEnterEditMode and not manager:CanEnterEditMode()) then
        self:SetStatus("Blizzard Edit Mode is not available right now.")
        return
    end

    self.returnFromBlizzardEditMode = true
    addon.Solo.combinedEditMode = true
    if self.frame then self.frame:Hide() end
    addon.Solo:Suspend("editMode")
    ShowUIPanel(manager)
    if not manager:IsShown() then
        self.returnFromBlizzardEditMode = nil
        addon.Solo.combinedEditMode = nil
        addon.Solo:Resume("editMode")
        self.frame:Show()
        self:SetStatus("Blizzard Edit Mode did not open.")
        return
    end
    C_Timer.After(0, function()
        if manager:IsShown() and GUI.returnFromBlizzardEditMode then
            addon.Solo.combinedEditMode = true
            addon.Solo:SetEditMode(true, false)
        end
    end)
end

function GUI:PrepareBlizzardCDMPanel()
    local panel = _G.CooldownViewerSettings
    if not panel then return false end

    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetUserPlaced(true)
    panel.ignoreFramePositionManager = true
    if SetUIPanelAttribute then
        SetUIPanelAttribute(panel, "area", "center")
        SetUIPanelAttribute(panel, "centerFrameSkipAnchoring", true)
        SetUIPanelAttribute(panel, "allowOtherPanels", 1)
    end

    if not self.cdmDragHandle then
        local dragHandle = CreateFrame("Button", "BabyAurasCDMDragHandle", panel)
        dragHandle:SetPoint("TOPLEFT", 54, -2)
        dragHandle:SetPoint("TOPRIGHT", -54, -2)
        dragHandle:SetHeight(28)
        dragHandle:SetFrameLevel(panel:GetFrameLevel() + 20)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetScript("OnDragStart", function()
            if not InCombatLockdown() then panel:StartMoving() end
        end)
        dragHandle:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
        dragHandle:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drag to move Blizzard CDM")
            GameTooltip:Show()
        end)
        dragHandle:SetScript("OnLeave", GameTooltip_Hide)
        self.cdmDragHandle = dragHandle
    end

    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    return true
end

function GUI:OpenBlizzardCDM()
    if InCombatLockdown() then
        self.openBlizzardAfterCombat = true
        print("|cFF66FF66Baby Auras:|r Blizzard CDM Edit queued until combat ends.")
        return false
    end
    self.openBlizzardAfterCombat = nil
    if CooldownViewerSettings and CooldownViewerSettings.TogglePanel then
        self:PrepareBlizzardCDMPanel()
        self.returnFromBlizzardCDM = true
        if self.frame then self.frame:Hide() end
        addon.Solo:Suspend("cdmSettings")
        CooldownViewerSettings:TogglePanel()
        if not CooldownViewerSettings:IsShown() then
            self.returnFromBlizzardCDM = nil
            self.frame:Show()
            addon.Solo:Resume("cdmSettings")
            self:SetStatus("Blizzard Cooldown Manager did not open.")
            return false
        end
        C_Timer.After(0, function()
            if CooldownViewerSettings:IsShown() then
                CooldownViewerSettings:ClearAllPoints()
                CooldownViewerSettings:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end)
        return true
    end
    print("|cFFFF6666Baby Auras:|r Blizzard Cooldown Manager is not available.")
    return false
end

function GUI:InstallCDMReturnHook()
    if self.cdmReturnHooked or not CooldownViewerSettings then return end
    self.cdmReturnHooked = true
    CooldownViewerSettings:HookScript("OnHide", function()
        if not GUI.returnFromBlizzardCDM then return end
        GUI.returnFromBlizzardCDM = nil
        C_Timer.After(0, function()
            if InCombatLockdown() then
                GUI.openAfterCombat = true
                print("|cFF66FF66Baby Auras:|r Options will reopen when combat ends.")
                return
            end
            GUI:Create()
            GUI.frame:Show()
            addon:RefreshAll()
            addon.Runtime:ScheduleCDMRefresh()
        end)
    end)
end

function GUI:InstallBlizzardEditReturnHook()
    local manager = _G.EditModeManagerFrame
    if self.blizzardEditReturnHooked or not manager then return end
    self.blizzardEditReturnHooked = true
    manager:HookScript("OnHide", function()
        if not GUI.returnFromBlizzardEditMode then return end
        GUI.returnFromBlizzardEditMode = nil
        C_Timer.After(0.15, function()
            if InCombatLockdown() then
                GUI.openAfterCombat = true
                print("|cFF66FF66Baby Auras:|r Options will reopen when combat ends.")
                return
            end
            GUI:Create()
            GUI.frame:Show()
            addon:RefreshAll()
            if GUI.pendingEntry then
                local entry = GUI.pendingEntry
                GUI.pendingEntry = nil
                GUI:Select(entry)
            end
        end)
    end)
end
