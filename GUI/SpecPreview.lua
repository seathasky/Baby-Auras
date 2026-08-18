local _, addon = ...

local GUI = addon.GUI
local Solo = addon.Solo
local Utilities = addon.SoloUtilities

GUI.otherSpecPreviewIDs = GUI.otherSpecPreviewIDs or {}

local function HasSoloForSpec(settings, specID)
    if type(settings) ~= "table" or settings.solo ~= true then return false end
    local specKey = tostring(specID)
    if type(settings.soloSpecs) == "table" then
        return settings.soloSpecs[specKey] == true
    end
    return settings.soloSpecID ~= nil and tostring(settings.soloSpecID) == specKey
end

local function BuildPreviewEntry(cooldownID)
    cooldownID = tonumber(cooldownID)
    if not cooldownID then return nil end
    local existing = addon.Catalog:Get(cooldownID)
    if existing then return existing end
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then return nil end

    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if not info then return nil end
    local spellID = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
    if not spellID then return nil end
    local name = C_Spell.GetSpellName(spellID)
    local icon = C_Spell.GetSpellTexture(spellID)
    if not name then return nil end

    local validTriggers = {}
    if C_CooldownViewer.GetValidAlertTypes then
        for _, trigger in ipairs(C_CooldownViewer.GetValidAlertTypes(cooldownID) or {}) do
            validTriggers[trigger] = true
        end
    end
    return {
        cooldownID = cooldownID,
        spellID = spellID,
        name = name,
        icon = icon,
        originalIcon = icon,
        category = info.category,
        known = false,
        info = info,
        validTriggers = validTriggers,
        specPreviewEntry = true,
    }
end

function Solo:IsSpecPreviewEnabled(entry)
    if not entry or not GUI.otherSpecPreviewIDs then return false end
    if not GUI.frame or not GUI.frame:IsShown() then return false end
    local settings = addon:GetEntrySettings(entry.cooldownID, false)
    if not settings then return false end
    local currentSpecID = addon:GetCurrentSpecID()
    for specID in pairs(GUI.otherSpecPreviewIDs) do
        if specID ~= currentSpecID and HasSoloForSpec(settings, specID) then
            return true
        end
    end
    return false
end

function Solo:IsVisibleForPositioning(entry)
    return Utilities.IsSoloEnabled(entry) or self:IsSpecPreviewEnabled(entry)
end

function Solo:RefreshSpecPreviewDisplays()
    local wanted = {}
    local currentSpecID = addon:GetCurrentSpecID()
    local profile = addon:GetProfile()
    for specID in pairs(GUI.otherSpecPreviewIDs or {}) do
        if specID ~= currentSpecID then
            for cooldownKey, settings in pairs(profile.entries or {}) do
                if HasSoloForSpec(settings, specID) then
                    local cooldownID = tonumber(cooldownKey)
                    if cooldownID then
                        local currentEntry = addon.Catalog:Get(cooldownID)
                        if not (currentEntry and Utilities.IsSoloEnabled(currentEntry)) then
                            local entry = BuildPreviewEntry(cooldownID)
                            if entry then
                                wanted[cooldownID] = true
                                local display = self:EnsureDisplay(entry, nil)
                                display.specPreviewOnly = true
                                display.specPreviewSpecID = specID
                                display.active = false
                                display.activeState = false
                                self:RefreshDisplay(display)
                            end
                        end
                    end
                end
            end
        end
    end

    for cooldownID, display in pairs(self.displays) do
        if display.specPreviewOnly and not wanted[cooldownID] then
            display.specPreviewOnly = nil
            display.specPreviewSpecID = nil
            if not Utilities.IsSoloEnabled(display.entry) then
                display:Hide()
            else
                self:RefreshDisplay(display)
            end
        end
    end
end

function GUI:ResetSpecIconPreviews()
    wipe(self.otherSpecPreviewIDs)
    if self.frame and self.frame.SpecIconsPopup then
        self.frame.SpecIconsPopup:Hide()
        for _, row in ipairs(self.frame.SpecIconRows or {}) do
            row.Check:SetChecked(false)
        end
    end
    if Solo and Solo.RefreshSpecPreviewDisplays then Solo:RefreshSpecPreviewDisplays() end
end

function GUI:RefreshSpecIconPanel()
    if not self.frame or not self.frame.SpecIconsPopup then return end
    local currentSpecID = addon:GetCurrentSpecID()
    local rows = self.frame.SpecIconRows or {}
    local count = 0
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    for index = 1, numSpecs do
        local specID, specName, _, specIcon = GetSpecializationInfo(index)
        if specID and specID ~= currentSpecID then
            count = count + 1
            local row = rows[count]
            if row then
                row.specID = specID
                row.Name:SetText(specName or ("Spec " .. index))
                row.Icon:SetTexture(specIcon)
                row.Check:SetChecked(self.otherSpecPreviewIDs[specID] == true)
                row:Show()
            end
        end
    end
    for index = count + 1, #rows do rows[index]:Hide() end
    self.frame.SpecIconsPopup:SetHeight(34 + (count * 28) + 8)
end

function GUI:CreateSpecIconPanel(frame)
    local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tab:SetSize(96, 22)
    tab:SetPoint("RIGHT", frame, "BOTTOMLEFT", 359, 17)
    tab:SetText("Spec Icons")
    tab:GetFontString():SetTextColor(1, 1, 1)
    tab:SetFrameLevel(frame:GetFrameLevel() + 8)
    frame.SpecIconsTab = tab

    local popup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    popup:SetWidth(176)
    popup:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -2)
    popup:SetFrameLevel(frame:GetFrameLevel() + 9)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.025, 0.025, 0.04, 0.98)
    popup:SetBackdropBorderColor(0.34, 0.58, 0.86, 0.95)
    popup:EnableMouse(true)
    popup:Hide()
    frame.SpecIconsPopup = popup

    local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Show Solo icons from:")
    title:SetTextColor(0.72, 0.82, 1)

    frame.SpecIconRows = {}
    for index = 1, 4 do
        local row = CreateFrame("Frame", nil, popup)
        row:SetSize(154, 24)
        row:SetPoint("TOPLEFT", 10, -28 - ((index - 1) * 28))
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        check:SetPoint("LEFT", 0, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", check, "RIGHT", 2, 0)
        local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        name:SetJustifyH("LEFT")
        row.Check, row.Icon, row.Name = check, icon, name
        check:SetScript("OnClick", function(self)
            local specID = row.specID
            if not specID then return end
            if self:GetChecked() then
                GUI.otherSpecPreviewIDs[specID] = true
            else
                GUI.otherSpecPreviewIDs[specID] = nil
            end
            Solo:RefreshSpecPreviewDisplays()
        end)
        row:Hide()
        frame.SpecIconRows[index] = row
    end

    tab:SetScript("OnClick", function()
        popup:SetShown(not popup:IsShown())
        if popup:IsShown() then GUI:RefreshSpecIconPanel() end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Spec Icons")
        GameTooltip:AddLine("Temporarily show Solo icons saved to your other specializations so you can align layouts.", 0.75, 0.85, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)

    self:RefreshSpecIconPanel()
end
