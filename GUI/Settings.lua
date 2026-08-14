local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults

function GUI:SetFadeEnabled(enabled)
    BabyAurasDB.fadeWhenUnfocused = enabled == true
    if self.frame and self.frame.FadeWhenUnfocused then
        self.frame.FadeWhenUnfocused:SetChecked(BabyAurasDB.fadeWhenUnfocused)
    end
    if self.frame and not BabyAurasDB.fadeWhenUnfocused then
        self.frame:SetAlpha(1)
    end
end

function GUI:SetFadeOpacity(value)
    local opacity = Clamp(math.floor((tonumber(value) or Defaults.database.fadeOpacity) + 0.5), 10, 90)
    BabyAurasDB.fadeOpacity = opacity
    if self.frame and self.frame.FadeOpacityValue then
        self.frame.FadeOpacityValue:SetText(opacity .. "%")
    end
end

function GUI:SetGUIScale(value, applyScale)
    local scale = Clamp(math.floor(((tonumber(value) or Defaults.database.guiScale) + 2.5) / 5) * 5, 70, 130)
    BabyAurasDB.guiScale = scale
    if applyScale ~= false and self.frame then self.frame:SetScale(scale / 100) end
    if self.frame and self.frame.GUIScaleValue then
        self.frame.GUIScaleValue:SetText(scale .. "%")
    end
    return scale
end

function GUI:SetMinimapHidden(hidden)
    addon.Minimap:SetHidden(hidden == true)
    if self.frame and self.frame.HideMinimap then
        self.frame.HideMinimap:SetChecked(BabyAurasDB.minimap.hide)
    end
end

function GUI:ConfirmResetAllSettings()
    StaticPopupDialogs.BABY_AURAS_RESET_ALL_SETTINGS = {
        text = "|cFFFF2020ARE YOU SURE?|r\n\n|cFFFF4040This resets ALL Baby Auras settings.|r\n\nEvery class profile, trigger, Solo layout, color, sound, GUI preference, and saved position will be erased. This cannot be undone.",
        button1 = "RESET EVERYTHING",
        button2 = CANCEL,
        OnAccept = function()
            BabyAurasDB = addon.Defaults:InitializeDatabase({})
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("BABY_AURAS_RESET_ALL_SETTINGS")
end

