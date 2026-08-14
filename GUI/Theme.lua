local _, addon = ...

local Theme = {}
addon.Theme = Theme

Theme.LPP = LibStub and LibStub("LibPixelPerfect-1.0", true)
Theme.LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

if Theme.LSM then
    Theme.LSM:Register("font", "Baby Auras - Baby", [[Interface\AddOns\BabyAuras\Media\CustomFonts\Baby.ttf]])
    Theme.LSM:Register("font", "Baby Auras - Uwu", [[Interface\AddOns\BabyAuras\Media\CustomFonts\uwu.ttf]])

    -- Prime WoW's font cache so bundled fonts render on the first selection.
    local babyFont = CreateFont("BabyAurasPreloadBabyFont")
    babyFont:SetFont([[Interface\AddOns\BabyAuras\Media\CustomFonts\Baby.ttf]], 12, "")
    local uwuFont = CreateFont("BabyAurasPreloadUwuFont")
    uwuFont:SetFont([[Interface\AddOns\BabyAuras\Media\CustomFonts\uwu.ttf]], 12, "")
end

function Theme:OnSharedMediaRegistered(_, mediaType)
    if mediaType ~= "font" or self.fontRefreshPending then return end
    self.fontRefreshPending = true
    -- Several addons register their media in one batch. Refresh once after the
    -- current registration burst rather than rebuilding every active display
    -- and the dropdown once per font.
    C_Timer.After(0, function()
        Theme.fontRefreshPending = nil
        if addon.Runtime then addon.Runtime:RefreshAppearances() end
        if addon.GUI then addon.GUI:RefreshFontMedia() end
    end)
end

if Theme.LSM then
    Theme.LSM.RegisterCallback(Theme, "LibSharedMedia_Registered", "OnSharedMediaRegistered")
end

Theme.font = STANDARD_TEXT_FONT
Theme.originalFontSizes = setmetatable({}, { __mode = "k" })
Theme.colors = {
    canvas = { 0.018, 0.035, 0.060, 0.98 },
    surface = { 0.030, 0.070, 0.110, 0.96 },
    raised = { 0.055, 0.125, 0.185, 0.98 },
    hover = { 0.085, 0.205, 0.300, 1 },
    border = { 0.280, 0.650, 0.900, 0.82 },
    accent = { 0.520, 0.820, 1.000, 1 },
    text = { 0.900, 0.965, 1.000, 1 },
    muted = { 0.560, 0.690, 0.780, 1 },
}

local function Color(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

function Theme:Pixel(frame, pixels)
    if not self.LPP or not frame then return pixels or 0 end
    self.LPP.SetParentFrame(frame)
    local value = self.LPP.PScale(pixels or 0)
    self.LPP.SetParentFrame(UIParent)
    return value
end

function Theme:Size(frame, width, height)
    if not frame then return end
    frame:SetSize(self:Pixel(frame, width), self:Pixel(frame, height))
end

function Theme:Width(frame, width)
    if frame then frame:SetWidth(self:Pixel(frame, width)) end
end

function Theme:Height(frame, height)
    if frame then frame:SetHeight(self:Pixel(frame, height)) end
end

function Theme:Point(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return end
    frame:SetPoint(point, relativeTo, relativePoint, self:Pixel(frame, x or 0), self:Pixel(frame, y or 0))
end

function Theme:SnapFrame(frame)
    if not frame or frame:IsForbidden() then return end
    local width, height = frame:GetSize()
    if width and height and width > 0 and height > 0 then
        frame:SetSize(self:Pixel(frame, width), self:Pixel(frame, height))
    end
end

function Theme:SnapTree(frame)
    if not frame then return end
    self:SnapFrame(frame)
    for index = 1, select("#", frame:GetChildren()) do
        self:SnapTree(select(index, frame:GetChildren()))
    end
end

function Theme:ApplyFont(fontString, forcedSize)
    if not fontString or not fontString.SetFont then return end
    if forcedSize then
        local _, _, flags = fontString:GetFont()
        pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT, forcedSize, flags or "")
    end
end

function Theme:ApplyFontTree(frame)
    if not frame then return end
    for index = 1, frame:GetNumRegions() do
        local region = select(index, frame:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            self:ApplyFont(region)
        end
    end
    for index = 1, select("#", frame:GetChildren()) do
        self:ApplyFontTree(select(index, frame:GetChildren()))
    end
end

local function AddEdges(control, color)
    if control.BabyAuraEdges then return end
    control.BabyAuraEdges = {}
    local top = control:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); Theme:Height(top, 1); Color(top, color)
    local bottom = control:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); Theme:Height(bottom, 1); Color(bottom, color)
    local left = control:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); Theme:Width(left, 1); Color(left, color)
    local right = control:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); Theme:Width(right, 1); Color(right, color)
    control.BabyAuraEdges = { top, bottom, left, right }
end

function Theme:SkinButton(button, strong)
    self:SnapFrame(button)
end

function Theme:SkinInput(input)
    self:SnapFrame(input)
end

function Theme:ApplyPanel(frame, surface)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
end
