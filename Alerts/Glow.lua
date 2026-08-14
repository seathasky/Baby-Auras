local _, addon = ...

-- Baby Auras owns this small glow renderer.  Custom animated styles are only
local Glow = {
    active = setmetatable({}, { __mode = "k" }),
    styles = {
        { key = "blizzard", label = "Blizzard Proc" },
        { key = "pixel", label = "Pixel Glow" },
        { key = "extended", label = "Extended Glow" },
    },
}
addon.Glow = Glow

local WHITE = "Interface\\Buttons\\WHITE8X8"
local driver = CreateFrame("Frame")
driver:Hide()

local function SafeNumber(value, fallback)
    value = tonumber(value)
    return value and value == value and value or fallback
end

local function GetSize(target)
    return math.max(1, SafeNumber(target:GetWidth(), 42)), math.max(1, SafeNumber(target:GetHeight(), 42))
end

local function EnsureHost(target)
    local host = target.__babyAurasGlowHost
    if host then return host end
    host = CreateFrame("Frame", nil, target)
    host:SetAllPoints(target)
    host:SetFrameLevel(math.min(10000, (target:GetFrameLevel() or 1) + 20))
    host:EnableMouse(false)
    host:Hide()
    target.__babyAurasGlowHost = host
    return host
end

local function EnsurePixel(host, count)
    host.pixelSegments = host.pixelSegments or {}
    for index = #host.pixelSegments + 1, count do
        local texture = host:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetTexture(WHITE)
        texture:SetBlendMode("ADD")
        host.pixelSegments[index] = texture
    end
    return host.pixelSegments
end

local function EnsureExtended(host, count)
    host.extendedEdges = host.extendedEdges or {}
    for layer = #host.extendedEdges + 1, count do
        local edges = {}
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            -- Texture sublevels are limited to -8..7. Layers share sublevel 7;
            -- their visual separation comes from size/alpha, not draw order.
            local texture = host:CreateTexture(nil, "OVERLAY", nil, 7)
            texture:SetTexture(WHITE)
            texture:SetBlendMode("ADD")
            edges[side] = texture
        end
        host.extendedEdges[layer] = edges
    end
    return host.extendedEdges
end

local function HideTextures(host)
    for _, texture in ipairs(host.pixelSegments or {}) do texture:Hide() end
    for _, edges in ipairs(host.extendedEdges or {}) do
        for _, texture in pairs(edges) do texture:Hide() end
    end
end

local function PlacePixel(data)
    local target, host = data.target, data.host
    local targetWidth, targetHeight = GetSize(target)
    local padding = data.padding
    local width, height = targetWidth + padding * 2, targetHeight + padding * 2
    local perimeter = 2 * (width + height)
    local thickness = data.thickness
    local length = math.max(5, math.floor(math.min(width, height) / 5 + 0.5))
    local phase = (data.elapsed * data.speed) % perimeter
    for index, texture in ipairs(data.segments) do
        local distance = (phase + ((index - 1) * perimeter / data.count)) % perimeter
        texture:ClearAllPoints()
        if distance < width then
            texture:SetSize(length, thickness)
            texture:SetPoint("CENTER", host, "TOPLEFT", distance - padding, padding)
        elseif distance < width + height then
            texture:SetSize(thickness, length)
            texture:SetPoint("CENTER", host, "TOPRIGHT", padding, padding - (distance - width))
        elseif distance < (2 * width) + height then
            texture:SetSize(length, thickness)
            texture:SetPoint("CENTER", host, "BOTTOMRIGHT", padding - (distance - width - height), -padding)
        else
            texture:SetSize(thickness, length)
            texture:SetPoint("CENTER", host, "BOTTOMLEFT", -padding, distance - (2 * width) - height - padding)
        end
    end
end

local function PlaceExtended(data)
    local pulse = (math.sin(data.elapsed * data.speed) + 1) * 0.5
    for layer, edges in ipairs(data.edges) do
        local visible = layer <= data.count
        local expansion = data.padding + layer * data.thickness + pulse * data.thickness
        local thickness = data.thickness
        local alpha = math.max(0.12, 0.72 - layer * 0.075) * (0.55 + pulse * 0.45)
        for _, texture in pairs(edges) do texture:SetShown(visible) end
        if visible then
        for _, texture in pairs(edges) do texture:SetAlpha(alpha) end
        edges.top:ClearAllPoints(); edges.top:SetPoint("BOTTOMLEFT", data.host, "TOPLEFT", -expansion, expansion); edges.top:SetPoint("BOTTOMRIGHT", data.host, "TOPRIGHT", expansion, expansion); edges.top:SetHeight(thickness)
        edges.bottom:ClearAllPoints(); edges.bottom:SetPoint("TOPLEFT", data.host, "BOTTOMLEFT", -expansion, -expansion); edges.bottom:SetPoint("TOPRIGHT", data.host, "BOTTOMRIGHT", expansion, -expansion); edges.bottom:SetHeight(thickness)
        edges.left:ClearAllPoints(); edges.left:SetPoint("TOPRIGHT", data.host, "TOPLEFT", -expansion, expansion); edges.left:SetPoint("BOTTOMRIGHT", data.host, "BOTTOMLEFT", -expansion, -expansion); edges.left:SetWidth(thickness)
        edges.right:ClearAllPoints(); edges.right:SetPoint("TOPLEFT", data.host, "TOPRIGHT", expansion, expansion); edges.right:SetPoint("BOTTOMLEFT", data.host, "BOTTOMRIGHT", expansion, -expansion); edges.right:SetWidth(thickness)
        end
    end
end

driver:SetScript("OnUpdate", function(_, elapsed)
    local anyActive = false
    for host, data in pairs(Glow.active) do
        anyActive = true
        if host:IsShown() and data.target:IsShown() then
            data.elapsed = data.elapsed + elapsed
            if data.style == "pixel" then PlacePixel(data) else PlaceExtended(data) end
        end
    end
    if not anyActive then driver:Hide() end
end)

function Glow:GetLabel(key)
    for _, style in ipairs(self.styles) do
        if style.key == key then return style.label end
    end
    return self.styles[1].label
end

function Glow:Stop(target)
    if not target then return end
    local host = target.__babyAurasGlowHost
    if not host then return end
    self.active[host] = nil
    HideTextures(host)
    host:Hide()
end

function Glow:SetAlpha(target, alpha)
    local host = target and target.__babyAurasGlowHost
    if host then host:SetAlpha(alpha) end
end

function Glow:Start(target, style, color, options)
    if not target then return false end
    self:Stop(target)
    style = style or "blizzard"
    if style == "blizzard" then return false end
    local host = EnsureHost(target)
    options = options or {}
    local r, g, b = 1, 0.82, 0
    if type(color) == "table" then r, g, b = color[1] or r, color[2] or g, color[3] or b end
    local resolvedStyle = style == "extended" and "extended" or "pixel"
    local defaultCount = resolvedStyle == "extended" and 3 or 8
    local data = {
        target = target, host = host, style = resolvedStyle, elapsed = 0,
        count = Clamp(math.floor(SafeNumber(options.glowCount, defaultCount) + 0.5), resolvedStyle == "extended" and 1 or 2, resolvedStyle == "extended" and 8 or 64),
        speed = Clamp(SafeNumber(options.glowSpeed, 4), 1, 10) * (resolvedStyle == "extended" and 1 or 12),
        thickness = Clamp(math.floor(SafeNumber(options.glowThickness, 2) + 0.5), 1, 8),
        padding = Clamp(math.floor(SafeNumber(options.glowPadding, 0) + 0.5), 0, 20),
    }
    if data.style == "pixel" then
        data.segments = EnsurePixel(host, data.count)
        for index, texture in ipairs(data.segments) do texture:SetVertexColor(r, g, b, 1); texture:SetShown(index <= data.count) end
        PlacePixel(data)
    else
        data.edges = EnsureExtended(host, data.count)
        for _, edges in ipairs(data.edges) do
            for _, texture in pairs(edges) do texture:SetVertexColor(r, g, b, 1); texture:Show() end
        end
        PlaceExtended(data)
    end
    host:Show()
    self.active[host] = data
    driver:Show()
    return true
end
