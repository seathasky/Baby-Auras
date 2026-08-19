local _, addon = ...

local Tutorial = addon.Tutorial

function Tutorial:ShowCooldownSettingsPreview()
    local panel = _G.CooldownViewerSettings
    local gui = addon.GUI.frame
    if not panel or not gui then return end
    if self.cdmPreviewState then return end

    local state = {
        shown = panel:IsShown(),
        scale = panel:GetScale(),
        strata = panel:GetFrameStrata(),
        level = panel:GetFrameLevel(),
        points = {},
    }
    for index = 1, panel:GetNumPoints() do
        state.points[index] = { panel:GetPoint(index) }
    end
    self.cdmPreviewState = state
    self.cdmPreviewPanel = panel

    panel:ClearAllPoints()
    panel:SetScale(math.min(0.62, state.scale or 1))
    panel:SetPoint("RIGHT", gui, "LEFT", -72, 0)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(120)
    panel:Show()

    self.cdmBlocker:ClearAllPoints()
    self.cdmBlocker:SetAllPoints(panel)
    self.cdmBlocker:Show()

    self.previewArrowActive = true
    self.cdmArrow:Hide()
end

function Tutorial:HideCooldownSettingsPreview()
    local panel, state = self.cdmPreviewPanel, self.cdmPreviewState
    if self.cdmArrow then self.cdmArrow:Hide() end
    self.previewArrowActive = nil
    self.arrowAnchor = nil
    if self.cdmBlocker then self.cdmBlocker:Hide() end
    if not panel or not state then return end

    panel:Hide()
    panel:SetScale(state.scale or 1)
    panel:SetFrameStrata(state.strata or "DIALOG")
    panel:SetFrameLevel(state.level or 1)
    panel:ClearAllPoints()
    for _, point in ipairs(state.points) do panel:SetPoint(unpack(point)) end
    if state.shown then panel:Show() end
    self.cdmPreviewPanel = nil
    self.cdmPreviewState = nil
end

function Tutorial:ShowBabyAurasSettings()
    local frame = addon.GUI.frame
    if not frame or not frame.SettingsPopup then return end
    frame.SettingsPopup:Show()
end

function Tutorial:HideBabyAurasSettings()
    local frame = addon.GUI.frame
    if frame and frame.SettingsPopup then frame.SettingsPopup:Hide() end
end

function Tutorial:CreateConfettiParticles()
    if not self.confetti or #self.confetti.particles > 0 then return end
    local colors = {
        { 1.00, 0.16, 0.20 }, { 1.00, 0.76, 0.08 }, { 0.20, 0.86, 1.00 },
        { 0.30, 1.00, 0.42 }, { 0.72, 0.30, 1.00 }, { 1.00, 0.34, 0.76 },
    }
    for index = 1, 90 do
        local particle = self.confetti:CreateTexture(nil, "OVERLAY")
        local color = colors[((index - 1) % #colors) + 1]
        particle:SetColorTexture(color[1], color[2], color[3], 1)
        particle:Hide()
        self.confetti.particles[index] = particle
    end
end

function Tutorial:StartCelebration()
    self:StopCelebration()
    self:CreateConfettiParticles()

    if not (BabyAurasDB and BabyAurasDB.muteAllAudio == true) then
        local played, handle = PlaySoundFile(
            "Interface\\AddOns\\BabyAuras\\Media\\Sounds\\ap.mp3", "Master"
        )
        if played then self.celebrationSoundHandle = handle end
    end

    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    self.confettiElapsed = 0
    for index, particle in ipairs(self.confetti.particles) do
        local angle = ((index * 137.5) % 360) * math.pi / 180
        local speed = 150 + math.random() * 290
        particle.x = (width * 0.5) + math.random(-70, 70)
        particle.y = (height * 0.56) + math.random(-20, 55)
        particle.vx = math.cos(angle) * speed
        particle.vy = math.sin(angle) * speed + 250
        particle.spin = (math.random() * 9) - 4.5
        particle.rotation = math.random() * math.pi * 2
        particle.delay = math.random() * 0.45
        particle:SetSize(math.random(5, 10), math.random(9, 18))
        particle:ClearAllPoints()
        particle:SetPoint("CENTER", UIParent, "BOTTOMLEFT", particle.x, particle.y)
        particle:SetRotation(particle.rotation)
        particle:SetAlpha(1)
        particle:Hide()
    end
    self.confetti:Show()
end

function Tutorial:UpdateConfetti(elapsed)
    if not self.confettiElapsed then return end
    self.confettiElapsed = self.confettiElapsed + elapsed
    if self.confettiElapsed >= 5.5 then
        self:StopCelebration(false)
        return
    end

    local gravity = 520
    for _, particle in ipairs(self.confetti.particles) do
        if self.confettiElapsed >= particle.delay then
            particle:Show()
            particle.vy = particle.vy - gravity * elapsed
            particle.vx = particle.vx * (1 - math.min(0.7 * elapsed, 0.2))
            particle.x = particle.x + particle.vx * elapsed
            particle.y = particle.y + particle.vy * elapsed
            particle.rotation = particle.rotation + particle.spin * elapsed
            particle:ClearAllPoints()
            particle:SetPoint("CENTER", UIParent, "BOTTOMLEFT", particle.x, particle.y)
            particle:SetRotation(particle.rotation)
            if self.confettiElapsed > 4.2 then
                particle:SetAlpha(Clamp((5.5 - self.confettiElapsed) / 1.3, 0, 1))
            end
        end
    end
end

function Tutorial:StopCelebration(stopSound)
    self.confettiElapsed = nil
    if self.confetti then
        self.confetti:Hide()
        for _, particle in ipairs(self.confetti.particles or {}) do particle:Hide() end
    end
    if stopSound ~= false and self.celebrationSoundHandle and StopSound then
        pcall(StopSound, self.celebrationSoundHandle, 250)
    end
    self.celebrationSoundHandle = nil
end

