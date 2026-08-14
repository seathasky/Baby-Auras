local _, addon = ...

addon.Navigation = { headers = {}, icons = {} }
local Navigation = addon.Navigation

local function CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetHeight(28)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
    })
    header:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    header:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
    local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", 10, 0)
    text:SetTextColor(0.48, 0.78, 1)
    header.Text = text
    header:Hide()
    return header
end

local function CreateIcon(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(40, 40)
    button:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
    button:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.Icon = icon

    local selectionOutline = CreateFrame("Frame", nil, button, "BackdropTemplate")
    selectionOutline:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    selectionOutline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    selectionOutline:SetFrameLevel(button:GetFrameLevel() + 5)
    selectionOutline:EnableMouse(false)
    selectionOutline:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 3,
    })
    selectionOutline:SetBackdropBorderColor(0.10, 1, 0.25, 1)
    selectionOutline:Hide()
    button.SelectionOutline = selectionOutline

    local solo = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    solo:SetPoint("TOPRIGHT", 1, 2)
    solo:SetText("S")
    solo:SetTextColor(0.2, 0.85, 1)
    button.Solo = solo
    button:SetScript("OnClick", function(self)
        if self.data and Navigation.onSelect then Navigation.onSelect(self.data.entry) end
    end)
    button:SetScript("OnEnter", function(self)
        if not self.data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.data.entry.name)
        GameTooltip:AddDoubleLine("Spell ID", self.data.entry.spellID, 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddLine("Can be moved as a Solo element", 0.2, 0.85, 1)
        GameTooltip:AddLine("Click to configure", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
    return button
end

function Navigation:Create(parent, onSelect, onOpenBlizzard)
    if self.panel then return self.panel end
    self.onSelect = onSelect
    self.onOpenBlizzard = onOpenBlizzard

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 18, -64)
    panel:SetPoint("BOTTOMLEFT", 18, 24)
    panel:SetWidth(332)
    self.panel = panel

    local blizzard = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    blizzard:SetPoint("TOPLEFT", 0, 0)
    blizzard:SetSize(310, 34)
    blizzard:SetText("Choose Spells to Track")
    blizzard:GetFontString():SetTextColor(1, 1, 1)
    blizzard:SetScript("OnClick", function()
        if Navigation.onOpenBlizzard then Navigation.onOpenBlizzard() end
    end)
    self.blizzardButton = blizzard

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", blizzard, "BOTTOMLEFT", 4, -4)
    hint:SetWidth(306)
    hint:SetJustifyH("LEFT")
    hint:SetText("Opens Blizzard Cooldown Manager. Baby Auras lists your chosen elements below.")
    self.hint = hint

    local scroll = CreateFrame("ScrollFrame", "BabyAurasCDMDashboardScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -70)
    scroll:SetPoint("BOTTOMRIGHT", -24, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(300)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.content = content
    return panel
end

function Navigation:AcquireHeader(index)
    self.headers[index] = self.headers[index] or CreateHeader(self.content)
    return self.headers[index]
end

function Navigation:AcquireIcon(index)
    self.icons[index] = self.icons[index] or CreateIcon(self.content)
    return self.icons[index]
end

function Navigation:Refresh(selectedCooldownID)
    if not self.panel then return end
    for _, header in ipairs(self.headers) do header:Hide() end
    for _, icon in ipairs(self.icons) do icon:Hide() end

    local y = 0
    local headerIndex = 0
    local iconIndex = 0
    local columns = 6
    local iconStep = 47
    for _, section in ipairs(addon.Runtime:GetCDMSections()) do
        headerIndex = headerIndex + 1
        local header = self:AcquireHeader(headerIndex)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -y)
        header:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
        header.Text:SetText(section.name .. " (" .. #section.entries .. ")")
        header:Show()
        y = y + 34

        if #section.entries > 0 then
            for entryIndex, data in ipairs(section.entries) do
                iconIndex = iconIndex + 1
                local button = self:AcquireIcon(iconIndex)
                local column = (entryIndex - 1) % columns
                local row = math.floor((entryIndex - 1) / columns)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", 4 + (column * iconStep), -(y + (row * iconStep)))
                button.data = data
                button.sectionKey = section.key
                button.Icon:SetTexture(addon.Catalog:GetDisplayIcon(data.entry))
                button:SetAlpha(1)
                local settings = addon:GetEntrySettings(data.entry.cooldownID, false)
                button.Solo:SetShown(settings and settings.solo == true)
                if data.entry.cooldownID == selectedCooldownID then
                    button.SelectionOutline:Show()
                else
                    button.SelectionOutline:Hide()
                end
                button:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
                button:Show()
            end
            y = y + (math.ceil(#section.entries / columns) * iconStep)
        end
        y = y + 8
    end
    self.content:SetHeight(math.max(1, y))
end
