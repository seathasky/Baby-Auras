local _, addon = ...

local GUI = addon.GUI
local ApplyBackdrop = addon.GUIWidgets.ApplyBackdrop
local SetButtonTextWhite = addon.GUIWidgets.SetButtonTextWhite

local ABOUT_LINKS = {
    curseforge = "https://www.curseforge.com/members/seathasky/projects",
    github = "https://github.com/seathasky",
    discord = "https://discord.gg/9w6ZdaksDX",
}

function GUI:ShowCopyLink(label, url)
    StaticPopupDialogs.BABY_AURAS_COPY_LINK = {
        text = "Copy the %s link with Ctrl+C:",
        button1 = CLOSE,
        hasEditBox = true,
        editBoxWidth = 360,
        OnShow = function(dialog, data)
            dialog.EditBox:SetText(data.url)
            dialog.EditBox:SetFocus()
            dialog.EditBox:HighlightText()
        end,
        EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
        EditBoxOnEnterPressed = function(editBox) editBox:HighlightText() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("BABY_AURAS_COPY_LINK", label, nil, { url = url })
end

function GUI:CreateAbout()
    if self.aboutFrame then return self.aboutFrame end
    local about = CreateFrame("Frame", "BabyAurasAboutFrame", UIParent, "BackdropTemplate")
    about:SetSize(650, 680)
    about:SetPoint("CENTER")
    about:SetFrameStrata("FULLSCREEN_DIALOG")
    about:SetMovable(true)
    about:SetClampedToScreen(true)
    about:EnableMouse(true)
    about:RegisterForDrag("LeftButton")
    about:SetScript("OnDragStart", about.StartMoving)
    about:SetScript("OnDragStop", about.StopMovingOrSizing)
    ApplyBackdrop(about)

    local close = CreateFrame("Button", nil, about, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    local portrait = about:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(360, 254)
    portrait:SetPoint("TOP", 0, -20)
    portrait:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\cat.png")
    local title = about:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOP", portrait, "BOTTOM", 0, -10)
    title:SetText("About Seathasky")
    title:SetTextColor(137 / 255, 147 / 255, 210 / 255)

    local bio = about:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    bio:SetPoint("TOPLEFT", 28, -326)
    bio:SetPoint("TOPRIGHT", -28, -326)
    bio:SetJustifyH("LEFT")
    bio:SetJustifyV("TOP")
    bio:SetSpacing(3)
    bio:SetText("Hi, I'm Seathasky!\n\nI'm a passionate WoW player for 20+ years and developer dedicated to creating addons that make our adventures in Azeroth just a little bit smoother.\n\nWhether it's streamlining a class rotation or cleaning up the UI, I love building tools that help the community.\n\nHave an addon request, suggestion, or bug report? Join my Discord and let me know. Please understand that I work alone, so I can't always get to everything right away, but I'll try my best!\n\nP.S. The cat in the picture is Emmi, me and my wife's child and the inspiration behind Baby Auras. She's extremely cuddly and communicates every request by screaming, basically a tiny raid leader with no indoor voice.")

    local function AddLink(text, key, x)
        local isDiscord = key == "discord"
        local button = CreateFrame("Button", nil, about, isDiscord and "BackdropTemplate" or "UIPanelButtonTemplate")
        button:SetSize(158, 28)
        button:SetPoint("BOTTOMLEFT", x, 22)
        if isDiscord then
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
            })
            button:SetBackdropColor(88 / 255, 101 / 255, 242 / 255, 1)
            button:SetBackdropBorderColor(0.55, 0.62, 1, 1)
            local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("CENTER")
            label:SetTextColor(1, 1, 1)
            button:SetFontString(label)
            button:SetScript("OnEnter", function(self)
                self:SetBackdropColor(108 / 255, 121 / 255, 1, 1)
            end)
            button:SetScript("OnLeave", function(self)
                self:SetBackdropColor(88 / 255, 101 / 255, 242 / 255, 1)
            end)
        end
        button:SetText(text)
        SetButtonTextWhite(button)
        button:SetScript("OnClick", function() GUI:ShowCopyLink(text, ABOUT_LINKS[key]) end)
    end
    AddLink("CurseForge Projects", "curseforge", 55)
    AddLink("GitHub Source", "github", 246)
    AddLink("Discord", "discord", 437)
    about:Hide()
    self.aboutFrame = about
    return about
end

function GUI:ToggleAbout()
    if InCombatLockdown() then return end
    local about = self:CreateAbout()
    about:SetShown(not about:IsShown())
end
