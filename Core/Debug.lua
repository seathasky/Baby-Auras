local _, addon = ...

addon.Debug = addon.Debug or {}
local Debug = addon.Debug

local PREFIX = "|cFF66FF66Baby Auras Debug:|r "

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
    else
        print(PREFIX .. message)
    end
end

local function SafeValue(value)
    if addon:IsSecret(value) then return "<secret>" end
    if value == nil then return "nil" end
    local valueType = type(value)
    if valueType == "boolean" then return value and "true" or "false" end
    if valueType == "number" or valueType == "string" then return tostring(value) end
    return "<" .. valueType .. ">"
end

local function SafeMethod(object, methodName)
    if not object or type(object[methodName]) ~= "function" then return nil, false end
    local ok, value = pcall(object[methodName], object)
    if not ok then return nil, false end
    return value, true
end

local function SafeText(fontString)
    if not fontString or type(fontString.GetText) ~= "function" then return nil end
    local ok, value = pcall(fontString.GetText, fontString)
    return ok and value or nil
end

local function GetSourceIcon(item)
    local texture
    if item and type(item.GetIconTexture) == "function" then
        local ok, result = pcall(item.GetIconTexture, item)
        if ok then texture = result end
    end
    texture = texture or (item and item.Icon and item.Icon.Icon) or (item and item.Icon)
    return texture
end

local function GetSourceCooldown(item)
    if not item then return nil end
    if type(item.GetCooldownFrame) == "function" then
        local ok, result = pcall(item.GetCooldownFrame, item)
        if ok and result then return result end
    end
    return item.Cooldown
end

local function GetChargeText(item)
    if not item then return nil end
    local chargeCount = item.ChargeCount
    if type(item.GetChargeCountFrame) == "function" then
        local ok, result = pcall(item.GetChargeCountFrame, item)
        if ok and result then chargeCount = result end
    end
    return chargeCount and SafeText(chargeCount.Current) or nil
end

local function GetApplicationText(item)
    if not item then return nil end
    return SafeText(item.Applications and item.Applications.Applications)
        or SafeText(item.Icon and item.Icon.Applications)
end

local function GetTextureValue(texture)
    if not texture or type(texture.GetTexture) ~= "function" then return nil end
    local ok, value = pcall(texture.GetTexture, texture)
    return ok and value or nil
end

local function GetCooldownTimes(cooldown)
    if not cooldown or type(cooldown.GetCooldownTimes) ~= "function" then return nil, nil end
    local ok, startMS, durationMS = pcall(cooldown.GetCooldownTimes, cooldown)
    if not ok then return nil, nil end
    return startMS, durationMS
end

local function GetViewerName(item)
    local viewer = addon.Solo and addon.Solo:GetViewer(item)
    if viewer == _G.EssentialCooldownViewer then return "Essential" end
    if viewer == _G.UtilityCooldownViewer then return "Utility" end
    if viewer == _G.BuffIconCooldownViewer then return "TrackedBuff" end
    if viewer == _G.BuffBarCooldownViewer then return "TrackedBar" end
    return viewer and (viewer.GetName and viewer:GetName()) or "Unknown"
end

local function MatchesFilter(record, filter)
    if not filter or filter == "" then
        return record.display and record.display:IsShown()
    end

    local needle = filter:lower()
    local numeric = tonumber(filter)
    if numeric then
        if record.entry.cooldownID == numeric or record.entry.spellID == numeric then return true end
        local resolvedSpellID = SafeMethod(record.item, "GetSpellID")
        local baseSpellID = SafeMethod(record.item, "GetBaseSpellID")
        local auraSpellID = SafeMethod(record.item, "GetAuraSpellID")
        local linkedSpellID = SafeMethod(record.item, "GetLinkedSpell")
        if resolvedSpellID == numeric or baseSpellID == numeric
            or auraSpellID == numeric or linkedSpellID == numeric then
            return true
        end
    end
    return record.entry.name and record.entry.name:lower():find(needle, 1, true) ~= nil
end

local function CollectRecords(filter)
    local records = {}
    local seen = setmetatable({}, { __mode = "k" })
    for item, entry in pairs(addon.Runtime and addon.Runtime.itemEntries or {}) do
        if item and entry and not seen[item] then
            seen[item] = true
            local display = addon.Solo and addon.Solo.displays and addon.Solo.displays[entry.cooldownID]
            local record = { item = item, entry = entry, display = display }
            if MatchesFilter(record, filter) then records[#records + 1] = record end
        end
    end
    table.sort(records, function(left, right)
        if left.entry.cooldownID ~= right.entry.cooldownID then
            return left.entry.cooldownID < right.entry.cooldownID
        end
        return GetViewerName(left.item) < GetViewerName(right.item)
    end)
    return records
end

local function PrintCooldown(label, cooldown)
    if not cooldown then
        Print(label .. " cooldown=<none>")
        return
    end
    local startMS, durationMS = GetCooldownTimes(cooldown)
    local reverse = SafeMethod(cooldown, "GetReverse")
    local drawSwipe = SafeMethod(cooldown, "GetDrawSwipe")
    local hideNumbers = SafeMethod(cooldown, "GetHideCountdownNumbers")
    local useAuraTime = SafeMethod(cooldown, "GetUseAuraDisplayTime")
    Print(string.format(
        "%s cooldown startMS=%s durationMS=%s reverse=%s drawSwipe=%s hideNumbers=%s auraTime=%s",
        label, SafeValue(startMS), SafeValue(durationMS), SafeValue(reverse), SafeValue(drawSwipe),
        SafeValue(hideNumbers), SafeValue(useAuraTime)))
end

function Debug:Dump(filter)
    filter = strtrim(filter or "")
    local records = CollectRecords(filter)
    if #records == 0 then
        if filter == "" then
            Print("no shown Solo entries found. Use |cFFFFFFFF/ba debug <spellID, cooldownID, or name>|r to inspect a specific live CDM item.")
        else
            Print("no live CDM item matched |cFFFFFFFF" .. filter .. "|r.")
        end
        return
    end

    Print("diagnostic snapshot only; no addon state was changed. Matches: " .. #records)
    for index, record in ipairs(records) do
        local item, entry, display = record.item, record.entry, record.display
        local resolvedSpellID = SafeMethod(item, "GetSpellID")
        local baseSpellID = SafeMethod(item, "GetBaseSpellID")
        local auraSpellID = SafeMethod(item, "GetAuraSpellID")
        local linkedSpellID = SafeMethod(item, "GetLinkedSpell")
        local active = SafeMethod(item, "IsActive")
        local sourceTexture = GetTextureValue(GetSourceIcon(item))
        local baTexture = display and GetTextureValue(display.Icon) or nil
        local baCount = display and SafeText(display.Count) or nil
        local customSettings = addon:GetEntrySettings(entry.cooldownID, false)
        local customIconSpellID = customSettings and customSettings.customIconSpellID or nil

        Print(string.format("[%d] %s | viewer=%s", index, entry.name or "Unknown", GetViewerName(item)))
        Print(string.format(
            "IDs cooldown=%s catalogSpell=%s base=%s resolved=%s aura=%s linked=%s active=%s",
            SafeValue(entry.cooldownID), SafeValue(entry.spellID), SafeValue(baseSpellID),
            SafeValue(resolvedSpellID), SafeValue(auraSpellID), SafeValue(linkedSpellID), SafeValue(active)))
        Print(string.format(
            "Icons Blizzard=%s BabyAuras=%s catalog=%s customSpell=%s",
            SafeValue(sourceTexture), SafeValue(baTexture), SafeValue(addon.Catalog:GetDisplayIcon(entry)),
            SafeValue(customIconSpellID)))
        Print(string.format(
            "Text BlizzardCharge=%s BlizzardApplications=%s BabyAurasCount=%s",
            SafeValue(GetChargeText(item)), SafeValue(GetApplicationText(item)), SafeValue(baCount)))
        PrintCooldown("Blizzard", GetSourceCooldown(item))
        PrintCooldown("BabyAuras", display and (display.LiveCooldown or display.Cooldown) or nil)
        Print("---")
    end
end
