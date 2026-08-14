local _, addon = ...

local Tutorial = addon.Tutorial

-- Region coordinates are expressed in that region's effective scale. Tutorial
-- overlays live directly on UIParent, so normalize every rectangle first.
local function GetUIParentRect(region)
    if not region or not region.GetRect then return end
    local left, bottom, width, height = region:GetRect()
    if not left or not bottom or not width or not height then return end
    local parentScale = UIParent:GetEffectiveScale()
    local regionScale = region:GetEffectiveScale()
    local factor = regionScale / math.max(parentScale, 0.01)
    return left * factor, bottom * factor, width * factor, height * factor
end


function Tutorial:SetOverlayRect(frame, left, bottom, width, height)
    if not frame then return end
    if not left or not bottom or width <= 0.5 or height <= 0.5 then
        frame:Hide()
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    frame:SetSize(width, height)
    frame:Show()
end

function Tutorial:GetTargetRect()
    local step = self.steps[self.stepIndex]
    if not step or not step.target then return end
    local value = step.target()
    local targets = type(value) == "table" and not value.GetRect and value or { value }
    local left, bottom, right, top
    for _, target in ipairs(targets) do
        if target and target.GetRect and target:IsShown() then
            local x, y, width, height = GetUIParentRect(target)
            if x and y and width and height then
                left = math.min(left or x, x)
                bottom = math.min(bottom or y, y)
                right = math.max(right or (x + width), x + width)
                top = math.max(top or (y + height), y + height)
            end
        end
    end
    if not left then
        local fallback = step.editorScroll and addon.GUI.frame.EditorBackground or addon.GUI.frame
        if not fallback then return end
        local x, y, width, height = GetUIParentRect(fallback)
        if x and y and width and height then return x, y, x + width, y + height end
        return
    end
    if step.fullEditorWidth and addon.GUI.frame.Editor then
        local editorLeft, _, editorWidth = GetUIParentRect(addon.GUI.frame.Editor)
        if editorLeft and editorWidth then right = editorLeft + editorWidth end
    end
    return left, bottom, right, top, targets[1]
end

function Tutorial:RestoreSpotlightState()
    for _, state in ipairs(self.spotlightState or {}) do
        if state.object then
            if state.alpha ~= nil and state.object.SetAlpha then
                state.object:SetAlpha(state.alpha)
            end
            if state.enabled ~= nil and state.object.SetEnabled then
                state.object:SetEnabled(state.enabled)
            end
        end
    end
    self.spotlightState = nil
end

function Tutorial:ApplySpotlightState(left, bottom, right, top)
    self:RestoreSpotlightState()
    if not left or not addon.GUI.frame then return end

    local states, seen = {}, {}
    local function Brighten(object)
        if not object or seen[object] or not object.GetRect or not object:IsShown() then return end
        seen[object] = true
        local x, y, width, height = GetUIParentRect(object)
        if not x or x + width < left or x > right or y + height < bottom or y > top then return end

        local state = { object = object }
        if object.GetAlpha and object.SetAlpha then
            local alpha = object:GetAlpha()
            if alpha < 1 then
                state.alpha = alpha
                object:SetAlpha(1)
            end
        end
        if object.IsEnabled and object.SetEnabled then
            local enabled = object:IsEnabled()
            if enabled == false then
                state.enabled = false
                object:SetEnabled(true)
            end
        end
        if state.alpha ~= nil or state.enabled ~= nil then states[#states + 1] = state end
    end

    local function Visit(frame)
        Brighten(frame)
        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do Brighten(region) end
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do Visit(child) end
        end
    end

    Visit(addon.GUI.frame)
    self.spotlightState = states
end

function Tutorial:ScrollTargetIntoView(target)
    local gui = addon.GUI.frame
    if not target or not gui or not gui.EditorScroll or not gui.Editor then return end
    local _, editorBottom, _, editorHeight = gui.Editor:GetRect()
    local _, targetBottom, _, targetHeight = target:GetRect()
    if not editorBottom or not targetBottom or not editorHeight or not targetHeight then return end
    local editorTop, targetTop = editorBottom + editorHeight, targetBottom + targetHeight
    local offset = editorTop - targetTop
    gui.EditorScroll:SetVerticalScroll(Clamp(offset - 12, 0, gui.EditorScroll:GetVerticalScrollRange()))
end

function Tutorial:CenterTargetsInEditor()
    local gui = addon.GUI.frame
    if not gui or not gui.EditorScroll or not gui.Editor then return end
    local _, targetBottom, _, targetTop = self:GetTargetRect()
    local _, viewBottom, _, viewHeight = GetUIParentRect(gui.EditorScroll)
    if not targetBottom or not targetTop or not viewBottom or not viewHeight then return end
    local viewTop = viewBottom + viewHeight
    local usableBottom, usableTop = viewBottom + 14, viewTop - 14
    local targetHeight = targetTop - targetBottom
    local screenDelta
    if targetHeight <= usableTop - usableBottom then
        screenDelta = ((usableBottom + usableTop) / 2) - ((targetBottom + targetTop) / 2)
    else
        screenDelta = usableTop - targetTop
    end
    local parentScale = UIParent:GetEffectiveScale()
    local editorScale = gui.Editor:GetEffectiveScale()
    local factor = editorScale / math.max(parentScale, 0.01)
    local scroll = gui.EditorScroll:GetVerticalScroll() + (screenDelta / math.max(factor, 0.01))
    gui.EditorScroll:SetVerticalScroll(Clamp(scroll, 0, gui.EditorScroll:GetVerticalScrollRange()))
end

function Tutorial:PositionPreviewArrow()
    if not self.previewArrowActive or not self.dialog or not self.cdmArrow then return end
    local arrow = self.cdmArrow
    arrow:ClearAllPoints()
    arrow:SetSize(190, 67)
    self.arrowAnchor = {
        point = "TOPLEFT", relativeTo = self.dialog, relativePoint = "BOTTOMLEFT", x = -28, y = -10,
    }
    arrow:SetPoint("TOPLEFT", self.dialog, "BOTTOMLEFT", -28, -10)
    arrow:Show()
end

function Tutorial:LayoutOverlay()
    if not self.active then return end
    local gui = addon.GUI.frame
    if not gui then return end
    local frameLeft, frameBottom, frameWidth, frameHeight = GetUIParentRect(gui)
    local left, bottom, right, top = self:GetTargetRect()
    if not frameLeft or not left then return end

    local frameRight, frameTop = frameLeft + frameWidth, frameBottom + frameHeight
    local screenLeft, screenBottom, screenWidth, screenHeight = GetUIParentRect(UIParent)
    if screenLeft then
        local screenRight, screenTop = screenLeft + screenWidth, screenBottom + screenHeight
        local clippedLeft = Clamp(frameLeft, screenLeft, screenRight)
        local clippedRight = Clamp(frameRight, screenLeft, screenRight)
        local clippedBottom = Clamp(frameBottom, screenBottom, screenTop)
        local clippedTop = Clamp(frameTop, screenBottom, screenTop)
        self:SetOverlayRect(self.outsideDimmers[1], screenLeft, clippedTop, screenWidth, screenTop - clippedTop)
        self:SetOverlayRect(self.outsideDimmers[2], screenLeft, screenBottom, screenWidth, clippedBottom - screenBottom)
        self:SetOverlayRect(self.outsideDimmers[3], screenLeft, clippedBottom, clippedLeft - screenLeft, clippedTop - clippedBottom)
        self:SetOverlayRect(self.outsideDimmers[4], clippedRight, clippedBottom, screenRight - clippedRight, clippedTop - clippedBottom)
    end

    local padding = 6
    left = Clamp(left - padding, frameLeft, frameRight)
    right = Clamp(right + padding, frameLeft, frameRight)
    bottom = Clamp(bottom - padding, frameBottom, frameTop)
    top = Clamp(top + padding, frameBottom, frameTop)

    self:SetOverlayRect(self.dimmers[1], frameLeft, top, frameWidth, frameTop - top)
    self:SetOverlayRect(self.dimmers[2], frameLeft, frameBottom, frameWidth, bottom - frameBottom)
    self:SetOverlayRect(self.dimmers[3], frameLeft, bottom, left - frameLeft, top - bottom)
    self:SetOverlayRect(self.dimmers[4], right, bottom, frameRight - right, top - bottom)
    self:SetOverlayRect(self.highlight, left, bottom, right - left, top - bottom)

    local dialog = self.dialog
    dialog:ClearAllPoints()
    local dialogHeight = dialog:GetHeight()
    if bottom - frameBottom >= dialogHeight + 16 then
        dialog:SetPoint("TOP", self.highlight, "BOTTOM", 0, -10)
    elseif frameTop - top >= dialogHeight + 16 then
        dialog:SetPoint("BOTTOM", self.highlight, "TOP", 0, 10)
    elseif (left + right) / 2 > (frameLeft + frameRight) / 2 then
        dialog:SetPoint("RIGHT", self.highlight, "LEFT", -10, 0)
    else
        dialog:SetPoint("LEFT", self.highlight, "RIGHT", 10, 0)
    end
    self:PositionPreviewArrow()
end


