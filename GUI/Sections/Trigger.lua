local _, addon = ...

addon.GUISections = addon.GUISections or {}
local Trigger = {}
addon.GUISections.Trigger = Trigger

function Trigger:Build(editor, frame)
    local GUI = addon.GUI
    local controls = {}

    local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, -108)
    label:SetText("TRIGGER EVENT")
    label:SetTextColor(0.56, 0.69, 0.78)
    frame.TriggerLabel = label

    local button = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    button:SetSize(395, 26)
    button:SetScript("OnClick", function() GUI:CycleTrigger() end)
    frame.Trigger = button

    local hint = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", button, "RIGHT", 6, 0)
    hint:SetText("cycle")
    frame.TriggerHint = hint

    local eventButtons = {}
    for index = 1, #addon.TriggerOrder do
        local eventButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
        eventButton:SetPoint("TOPLEFT", button)
        eventButton:SetSize(395, 26)
        eventButton:SetScript("OnClick", function(self) GUI:SelectTrigger(self.trigger) end)
        eventButton:Hide()
        eventButtons[index] = eventButton
    end
    frame.EventTriggerButtons = eventButtons

    controls.label = label
    controls.button = button
    controls.hint = hint
    controls.eventButtons = eventButtons
    controls.descriptor = {
        key = "trigger", title = label, bottom = button,
        gap = -14, collapseHeight = 0,
        elements = { button, hint, unpack(eventButtons) },
    }
    return controls
end

