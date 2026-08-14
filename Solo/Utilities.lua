local _, addon = ...

addon.SoloUtilities = addon.SoloUtilities or {}
local Utilities = addon.SoloUtilities
local Defaults = addon.Defaults
local PixelPerfect = LibStub and LibStub("LibPixelPerfect-1.0", true)
local SOLO_ICON_BASE_SIZE = 42

function Utilities.GetEntryAppearance(entry)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    return settings or {}
end

function Utilities.GetBarDimensions(entry, item)
    local settings = Utilities.GetEntryAppearance(entry)
    local sourceHeight = item and item:GetHeight() or Defaults.soloBarAppearance.iconSize
    local sourceWidth = item and item:GetWidth() or Defaults.soloBarAppearance.width
    local iconSize = Clamp(tonumber(settings.soloBarIconSize) or math.max(24, sourceHeight), 16, 96)
    local barWidth = Clamp(tonumber(settings.soloBarWidth)
        or math.max(80, sourceWidth - sourceHeight - 2), 80, 400)
    local barHeight = Clamp(tonumber(settings.soloBarHeight)
        or math.max(4, sourceHeight - 10), 4, 80)
    if settings.soloBarMatchIconHeight ~= false then iconSize = barHeight end
    return iconSize, barWidth, barHeight
end

function Utilities.GetSoloBaseDimensions(entry, item, isBar)
    if isBar then
        local iconSize, barWidth, barHeight = Utilities.GetBarDimensions(entry, item)
        return iconSize + barWidth, math.max(iconSize, barHeight)
    end
    return SOLO_ICON_BASE_SIZE, SOLO_ICON_BASE_SIZE
end

function Utilities.GetTextColor(settings, settingKey, defaultKey)
    local color = settings[settingKey]
    if type(color) ~= "table" then color = Defaults.soloAppearance[defaultKey] end
    return Clamp(tonumber(color and color[1]) or 1, 0, 1),
        Clamp(tonumber(color and color[2]) or 1, 0, 1),
        Clamp(tonumber(color and color[3]) or 1, 0, 1),
        Clamp(tonumber(color and color[4]) or 1, 0, 1)
end

function Utilities.GetClassColor()
    local classFile = select(2, UnitClass("player"))
    return classFile and RAID_CLASS_COLORS[classFile] or NORMAL_FONT_COLOR
end

function Utilities.EntryUsesAura(entry)
    if not entry then return false end
    if entry.info and entry.info.hasAura then return true end
    local triggers = entry.validTriggers
    return triggers and (
        triggers[Enum.CooldownViewerAlertEventType.OnAuraApplied]
        or triggers[Enum.CooldownViewerAlertEventType.OnAuraRemoved]
    ) or false
end

function Utilities.GetPhysicalPixelSize(frame, pixels)
    if PixelPerfect then
        PixelPerfect.SetParentFrame(frame)
        local size = PixelPerfect.PScale(pixels)
        PixelPerfect.SetParentFrame(UIParent)
        return size
    end
    return PixelUtil.GetNearestPixelSize(pixels, frame:GetEffectiveScale())
end

function Utilities.IsSoloEnabled(entry)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    return settings and settings.solo == true
end

function Utilities.GetScreenCenter(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return nil, nil end
    local scale = frame:GetEffectiveScale()
    return x * scale, y * scale
end

function Utilities.ScreenToUIParent(x, y)
    local scale = UIParent:GetEffectiveScale()
    return x and (x / scale) or nil, y and (y / scale) or nil
end

