local _, addon = ...

local Tutorial = addon.Tutorial

local function SetBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
end

function Tutorial:Create()
    if self.dialog then return end

    self.outsideDimmers = {}
    for index = 1, 4 do
        local dimmer = CreateFrame("Button", nil, UIParent)
        dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
        dimmer:SetFrameLevel(98)
        dimmer:EnableMouse(true)
        local texture = dimmer:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        texture:SetColorTexture(0, 0, 0, 0.90)
        dimmer:Hide()
        self.outsideDimmers[index] = dimmer
    end

    self.dimmers = {}
    for index = 1, 4 do
        local dimmer = CreateFrame("Button", nil, UIParent)
        dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
        dimmer:SetFrameLevel(100)
        dimmer:EnableMouse(true)
        local texture = dimmer:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        texture:SetColorTexture(0.015, 0.02, 0.03, 0.78)
        dimmer:Hide()
        self.dimmers[index] = dimmer
    end

    local highlight = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    highlight:SetFrameStrata("FULLSCREEN_DIALOG")
    highlight:SetFrameLevel(102)
    highlight:EnableMouse(true)
    SetBackdrop(highlight)
    highlight:SetBackdropColor(0, 0, 0, 0)
    highlight:SetBackdropBorderColor(0.25, 0.85, 1, 1)
    highlight:SetScript("OnClick", function()
        local step = Tutorial.steps[Tutorial.stepIndex]
        if step and step.cursor then Tutorial:Next() end
    end)
    highlight:Hide()
    self.highlight = highlight

    local cursor = highlight:CreateTexture(nil, "OVERLAY")
    cursor:SetSize(32, 32)
    cursor:SetPoint("CENTER", highlight, "CENTER", 9, -9)
    cursor:SetTexture("Interface\\CURSOR\\Point")
    cursor:Hide()
    self.cursor = cursor

    local targetGlow = highlight:CreateTexture(nil, "OVERLAY", nil, 2)
    targetGlow:SetPoint("CENTER")
    targetGlow:SetSize(70, 70)
    targetGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    targetGlow:SetBlendMode("ADD")
    targetGlow:SetVertexColor(0.15, 0.75, 1, 1)
    targetGlow:Hide()
    self.targetGlow = targetGlow

    local cdmArrow = CreateFrame("Frame", nil, UIParent)
    cdmArrow:SetSize(240, 85)
    cdmArrow:SetFrameStrata("TOOLTIP")
    cdmArrow:SetFrameLevel(10000)
    cdmArrow:EnableMouse(false)
    local cdmArrowTexture = cdmArrow:CreateTexture(nil, "OVERLAY")
    cdmArrowTexture:SetAllPoints()
    cdmArrowTexture:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\redarrowleft.png")
    cdmArrow:Hide()
    self.cdmArrow = cdmArrow

    local cdmBlocker = CreateFrame("Button", nil, UIParent)
    cdmBlocker:SetFrameStrata("FULLSCREEN_DIALOG")
    cdmBlocker:SetFrameLevel(200)
    cdmBlocker:EnableMouse(true)
    cdmBlocker:Hide()
    self.cdmBlocker = cdmBlocker

    local editModePreview = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    editModePreview:SetSize(382, 335)
    editModePreview:SetFrameStrata("TOOLTIP")
    editModePreview:SetFrameLevel(190)
    editModePreview:SetClampedToScreen(true)
    editModePreview:EnableMouse(false)
    SetBackdrop(editModePreview)
    editModePreview:SetBackdropColor(0.01, 0.015, 0.025, 1)
    editModePreview:SetBackdropBorderColor(0.25, 0.8, 1, 1)
    local editModeImage = editModePreview:CreateTexture(nil, "ARTWORK")
    editModeImage:SetPoint("TOPLEFT", 5, -5)
    editModeImage:SetPoint("BOTTOMRIGHT", -5, 5)
    editModeImage:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\tutorial-edit-mode.png")
    editModePreview:Hide()
    self.editModePreview = editModePreview

    local confetti = CreateFrame("Frame", nil, UIParent)
    confetti:SetAllPoints(UIParent)
    confetti:SetFrameStrata("FULLSCREEN_DIALOG")
    confetti:SetFrameLevel(180)
    confetti:EnableMouse(false)
    confetti.particles = {}
    confetti:SetScript("OnUpdate", function(_, elapsed)
        Tutorial:UpdateConfetti(elapsed)
    end)
    confetti:Hide()
    self.confetti = confetti

    local dialog = CreateFrame("Frame", "BabyAurasTutorialDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(350, 205)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(200)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    SetBackdrop(dialog)
    dialog:SetBackdropColor(0.025, 0.035, 0.055, 0.99)
    dialog:SetBackdropBorderColor(0.35, 0.75, 1, 1)

    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetWidth(250)
    title:SetJustifyH("LEFT")
    title:SetTextColor(0.42, 0.82, 1)
    dialog.Title = title

    local progress = dialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    progress:SetPoint("TOPRIGHT", -18, -18)
    dialog.Progress = progress

    local body = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -13)
    body:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -18, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    dialog.Body = body

    local back = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    back:SetSize(78, 25)
    back:SetPoint("BOTTOMLEFT", 16, 14)
    back:SetText("Back")
    back:GetFontString():SetTextColor(1, 1, 1)
    back:SetScript("OnClick", function() Tutorial:Previous() end)
    dialog.Back = back

    local exit = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    exit:SetSize(94, 25)
    exit:SetPoint("BOTTOM", 0, 14)
    exit:SetText("Exit Tutorial")
    exit:GetFontString():SetTextColor(1, 1, 1)
    exit:SetScript("OnClick", function() Tutorial:Stop(false) end)
    dialog.Exit = exit

    local nextButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    nextButton:SetSize(78, 25)
    nextButton:SetPoint("BOTTOMRIGHT", -16, 14)
    nextButton:SetText("Next")
    nextButton:GetFontString():SetTextColor(1, 1, 1)
    nextButton:SetScript("OnClick", function() Tutorial:Next() end)
    dialog.Next = nextButton

    dialog:SetScript("OnUpdate", function(_, elapsed) Tutorial:OnUpdate(elapsed) end)
    dialog:Hide()
    self.dialog = dialog

    addon.GUI.frame:HookScript("OnHide", function()
        if Tutorial.active then Tutorial:Stop(false) end
    end)
end


