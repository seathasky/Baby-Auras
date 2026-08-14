local _, addon = ...

addon.Minimap = {}
local MinimapLauncher = addon.Minimap

-- Keep minimap and addon-compartment icons on a square power-of-two texture
-- so WoW does not stretch the rectangular header asset into these icon slots.
local iconPath = "Interface\\AddOns\\BabyAuras\\Media\\Images\\BALogoTIconCentered.png"

function MinimapLauncher:SetHidden(hidden)
    BabyAurasDB.minimap.hide = hidden == true
    if not self.icon then return end
    if hidden then
        self.icon:Hide("Baby Auras")
    else
        self.icon:Show("Baby Auras")
    end
end

function MinimapLauncher:Initialize()
    if self.initialized then return end
    self.initialized = true

    local broker = LibStub("LibDataBroker-1.1"):NewDataObject("Baby Auras", {
        type = "launcher",
        text = "Baby Auras",
        icon = iconPath,
        OnClick = function(_, button)
            if button == "LeftButton" then addon.GUI:Toggle() end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText("Baby Auras")
            tooltip:AddLine("Left-click to open", 1, 1, 1)
            tooltip:AddLine("Drag to move the minimap icon", 0.7, 0.7, 0.7)
        end,
    })

    local icon = LibStub("LibDBIcon-1.0")
    icon:Register("Baby Auras", broker, BabyAurasDB.minimap, iconPath)
    if BabyAurasDB.minimap.showInCompartment then
        icon:AddButtonToCompartment("Baby Auras", iconPath)
    end

    self.broker = broker
    self.icon = icon
    self:SetHidden(BabyAurasDB.minimap.hide)
end
