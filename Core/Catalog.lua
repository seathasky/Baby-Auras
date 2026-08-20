local _, addon = ...

addon.Catalog = { entries = {}, byCooldownID = {} }
local Catalog = addon.Catalog

local categories, seenCategories = {}, {}
local function AddCategory(category)
    if category ~= nil and not seenCategories[category] then
        seenCategories[category] = true
        categories[#categories + 1] = category
    end
end

local Category = Enum.CooldownViewerCategory
AddCategory(Category.Essential)
AddCategory(Category.Utility)
AddCategory(Category.TrackedBuff)
AddCategory(Category.TrackedBar)
AddCategory(Category.GroupBuff)
AddCategory(Category.SpecAgnosticEssential)
AddCategory(Category.SpecAgnosticTracked)
AddCategory(Category.EquipSlotEssential)
AddCategory(Category.EquipSlotTracked)

local displayOverridesByCooldownID = {
    [198408] = { spellID = 1295924, name = "Prismatic Bolt", realIcon = 8026694 },
}

local function GetDisplaySpellID(info)
    return info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
end

function Catalog:Build()
    wipe(self.entries)
    wipe(self.byCooldownID)
    local seen = {}

    for _, category in ipairs(categories) do
        local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true) or {}
        for _, cooldownID in ipairs(cooldownIDs) do
            if not seen[cooldownID] then
                seen[cooldownID] = true
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
                if info then
                    local spellID = GetDisplaySpellID(info)
                    local name = spellID and C_Spell.GetSpellName(spellID)
                    local icon = spellID and C_Spell.GetSpellTexture(spellID)
                    local originalIcon = icon
                    local displayOverride = displayOverridesByCooldownID[cooldownID]
                    if displayOverride then
                        spellID = displayOverride.spellID or spellID
                        name = displayOverride.name or name
                    end
                    if spellID and name then
                        local validTriggers = {}
                        for _, trigger in ipairs(C_CooldownViewer.GetValidAlertTypes(cooldownID) or {}) do
                            validTriggers[trigger] = true
                        end
                        local entry = {
                            cooldownID = cooldownID,
                            spellID = spellID,
                            name = name,
                            icon = icon,
                            originalIcon = originalIcon,
                            realIcon = displayOverride and displayOverride.realIcon or nil,
                            category = info.category,
                            known = info.isKnown == true,
                            info = info,
                            validTriggers = validTriggers,
                        }
                        self.entries[#self.entries + 1] = entry
                        self.byCooldownID[cooldownID] = entry
                    end
                end
            end
        end
    end

    table.sort(self.entries, function(left, right)
        if left.known ~= right.known then return left.known end
        if left.name ~= right.name then return left.name < right.name end
        return left.cooldownID < right.cooldownID
    end)
end

function Catalog:GetCustomIcon(entry)
    if not entry then return nil end
    local settings = addon:GetEntrySettings(entry.cooldownID, false)
    local customSpellID = settings and tonumber(settings.customIconSpellID)
    return customSpellID and C_Spell.GetSpellTexture(customSpellID) or nil
end

function Catalog:GetDisplayIcon(entry)
    if not entry then return nil end
    local settings = addon:GetEntrySettings(entry.cooldownID, false)
    local customIcon = self:GetCustomIcon(entry)
    if customIcon then return customIcon end
    if entry.cooldownID == 198408 and entry.realIcon
        and (not settings or settings.showPrismaticBoltIcon ~= false) then
        return entry.realIcon
    end
    return entry.originalIcon or entry.icon
end

function Catalog:Get(cooldownID)
    return self.byCooldownID[cooldownID]
end

function Catalog:GetFiltered(search)
    search = strtrim(search or ""):lower()
    if search == "" then return self.entries end

    local result = {}
    for _, entry in ipairs(self.entries) do
        if entry.name:lower():find(search, 1, true)
            or tostring(entry.spellID):find(search, 1, true)
            or tostring(entry.cooldownID):find(search, 1, true) then
            result[#result + 1] = entry
        end
    end
    return result
end
