local _, addon = ...

addon.GUISections = addon.GUISections or {}
local Icon = {}
addon.GUISections.Icon = Icon

local Widgets = addon.GUIWidgets

function Icon:Build(editor, anchor, frame)
    local title, line = Widgets.CreateSectionTitle(editor, "ICON CUSTOMIZATION")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    frame.IconTestingTitle = title

    local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    label:SetText("Custom icon spell ID (blank = Blizzard icon)")
    frame.IconLabel = label

    local spellID = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    spellID:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -7)
    spellID:SetSize(120, 26)
    spellID:SetAutoFocus(false)
    spellID:SetNumeric(true)
    spellID:SetScript("OnEscapePressed", spellID.ClearFocus)
    spellID:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addon.GUI:CommitEditor()
    end)
    spellID:SetScript("OnTextChanged", function() addon.GUI:ScheduleAutoSave() end)
    frame.IconSpellID = spellID

    local prismatic, prismaticLabel = Widgets.CreateCheckbox(editor, "Show Prismatic Bolt icon instead", 235)
    prismatic:SetPoint("TOPLEFT", spellID, "BOTTOMLEFT", -4, -5)
    prismatic:SetScript("OnClick", function() addon.GUI:OnPrismaticIconClicked() end)
    frame.PrismaticIcon = prismatic
    frame.PrismaticIconLabel = prismaticLabel

    local autoSave = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    autoSave:SetPoint("LEFT", spellID, "RIGHT", 10, 0)
    autoSave:SetText("Changes save automatically")

    local message = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    message:SetPoint("TOPLEFT", spellID, "BOTTOMLEFT", -4, -16)
    message:SetWidth(330)
    message:SetJustifyH("LEFT")
    frame.Message = message

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "icon")
    return {
        title = title,
        line = line,
        label = label,
        spellID = spellID,
        prismatic = prismatic,
        prismaticLabel = prismaticLabel,
        autoSave = autoSave,
        message = message,
        toggle = toggle,
        descriptor = {
            key = "icon", title = title, toggle = toggle, bottom = message,
            gap = -14, collapseHeight = 112,
            elements = { label, spellID, prismatic, prismaticLabel, autoSave, message },
        },
    }
end
