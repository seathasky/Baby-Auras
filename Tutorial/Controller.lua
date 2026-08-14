local _, addon = ...

local Tutorial = addon.Tutorial

function Tutorial:ShowStep(index)
    self:RestoreSpotlightState()
    self:StopCelebration()
    self:HideCooldownSettingsPreview()
    self:HideBabyAurasSettings()
    self.stepIndex = Clamp(index, 1, #self.steps)
    local step = self.steps[self.stepIndex]
    if step.sectionKey and addon.GUI then addon.GUI:ExpandEditorSection(step.sectionKey, true) end
    if step.prepare then step.prepare() end

    self.dialog.Title:SetText(step.title)
    self.dialog.Body:SetText(step.text)
    self.dialog.Progress:SetText(self.stepIndex .. " / " .. #self.steps)
    self.dialog.Back:SetEnabled(self.stepIndex > 1)
    self.dialog.Next:SetText(self.stepIndex == #self.steps and "Finish" or "Next")
    self.dialog.Back:GetFontString():SetTextColor(1, 1, 1)
    self.dialog.Exit:GetFontString():SetTextColor(1, 1, 1)
    self.dialog.Next:GetFontString():SetTextColor(1, 1, 1)
    self.cursor:SetShown(step.cursor == true)
    self.targetGlow:SetShown(step.iconEmphasis == true)
    self.editModePreview:SetShown(step.showEditModeImage == true)
    self.cursor:ClearAllPoints()
    if step.cursorPosition == "RIGHT" then
        self.cursor:SetPoint("RIGHT", self.highlight, "RIGHT", -8, 0)
    elseif step.cursorPosition == "OUTSIDE_RIGHT" then
        self.cursor:SetPoint("TOPLEFT", self.highlight, "BOTTOMRIGHT", -8, 8)
    else
        self.cursor:SetPoint("CENTER", self.highlight, "CENTER", 9, -9)
    end

    local _, _, _, _, firstTarget = self:GetTargetRect()
    if step.editorScroll and firstTarget then
        self:ScrollTargetIntoView(firstTarget)
        self:CenterTargetsInEditor()
        local expectedStep = self.stepIndex
        C_Timer.After(0, function()
            if Tutorial.active and Tutorial.stepIndex == expectedStep then
                Tutorial:CenterTargetsInEditor()
                Tutorial:LayoutOverlay()
            end
        end)
    end
    self.elapsed = 1
    self:LayoutOverlay()
    if step.showEditModeImage then
        self.editModePreview:ClearAllPoints()
        self.editModePreview:SetPoint("RIGHT", addon.GUI.frame, "LEFT", -16, 0)
    end
    if step.targetArrow then
        self.cdmArrow:ClearAllPoints()
        self.cdmArrow:SetSize(150, 53)
        if step.targetArrowPosition == "INSIDE_RIGHT" then
            self.arrowAnchor = { point = "RIGHT", relativeTo = self.highlight, relativePoint = "RIGHT", x = -8, y = 0 }
            self.cdmArrow:SetPoint("RIGHT", self.highlight, "RIGHT", -8, 0)
        elseif step.targetArrowPosition == "ABOVE_DIALOG" then
            self.arrowAnchor = { point = "BOTTOMLEFT", relativeTo = self.dialog, relativePoint = "TOPLEFT", x = 8, y = 8 }
            self.cdmArrow:SetPoint("BOTTOMLEFT", self.dialog, "TOPLEFT", 8, 8)
        else
            self.arrowAnchor = { point = "LEFT", relativeTo = self.highlight, relativePoint = "RIGHT", x = -3, y = 0 }
            self.cdmArrow:SetPoint("LEFT", self.highlight, "RIGHT", -3, 0)
        end
        self.cdmArrow:Show()
    end
    local left, bottom, right, top = self:GetTargetRect()
    self:ApplySpotlightState(left, bottom, right, top)
end

function Tutorial:Start()
    if InCombatLockdown() then
        addon.GUI:SetStatus("Tutorial is unavailable during combat.")
        return
    end
    addon.GUI:Create()
    self:Create()
    addon.GUI.frame:Show()
    addon.GUI.frame:SetAlpha(1)
    if addon.GUI.frame.SettingsPopup then addon.GUI.frame.SettingsPopup:Hide() end
    addon.GUI.temporaryExpandedSections = nil
    self.active = true
    self.dialog:Show()
    for _, dimmer in ipairs(self.outsideDimmers) do dimmer:Show() end
    for _, dimmer in ipairs(self.dimmers) do dimmer:Show() end
    self.highlight:Show()
    self:ShowStep(1)
end

function Tutorial:Stop(completed)
    self.active = false
    self:RestoreSpotlightState()
    self:StopCelebration()
    self:HideCooldownSettingsPreview()
    self:HideBabyAurasSettings()
    if self.dialog then self.dialog:Hide() end
    if self.highlight then self.highlight:Hide() end
    if self.editModePreview then self.editModePreview:Hide() end
    for _, dimmer in ipairs(self.outsideDimmers or {}) do dimmer:Hide() end
    for _, dimmer in ipairs(self.dimmers or {}) do dimmer:Hide() end
    if addon.GUI then
        addon.GUI.temporaryExpandedSections = nil
        addon.GUI:RefreshEditor()
    end
    if completed and BabyAurasDB then BabyAurasDB.tutorialCompleted = true end
end

function Tutorial:EnsureInactiveCleanup()
    if self.active then return end
    if self.dialog then self.dialog:Hide() end
    if self.highlight then self.highlight:Hide() end
    if self.cdmBlocker then self.cdmBlocker:Hide() end
    if self.editModePreview then self.editModePreview:Hide() end
    if self.cdmArrow then self.cdmArrow:Hide() end
    if self.confetti then self.confetti:Hide() end
    for _, dimmer in ipairs(self.outsideDimmers or {}) do dimmer:Hide() end
    for _, dimmer in ipairs(self.dimmers or {}) do dimmer:Hide() end
end

function Tutorial:Next()
    if self.stepIndex >= #self.steps then
        self:Stop(true)
    else
        self:ShowStep(self.stepIndex + 1)
    end
end

function Tutorial:Previous()
    if self.stepIndex > 1 then self:ShowStep(self.stepIndex - 1) end
end

function Tutorial:OnUpdate(elapsed)
    if not self.active then return end
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.04 then return end
    self.elapsed = 0
    local pulse = 0.72 + (math.sin(GetTime() * 4) * 0.25)
    self.highlight:SetBackdropBorderColor(0.25, 0.85, 1, pulse)
    if self.targetGlow then self.targetGlow:SetAlpha(pulse) end
    if self.cdmArrow and self.cdmArrow:IsShown() then
        self.cdmArrow:SetAlpha(0.82 + (pulse * 0.18))
        local anchor = self.arrowAnchor
        if anchor and anchor.relativeTo then
            local bounce = math.sin(GetTime() * 4.5) * 4
            self.cdmArrow:ClearAllPoints()
            self.cdmArrow:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x + bounce, anchor.y)
        end
    end
    self:LayoutOverlay()
end
