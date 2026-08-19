local _, addon = ...

addon.Audio = {}
local Audio = addon.Audio

local customSoundDirectory = "Interface\\AddOns\\BabyAuras\\Media\\Sounds\\"
Audio.channels = {
    { key = "Master", name = "Master" },
    { key = "SFX", name = "Sound Effects" },
    { key = "Dialog", name = "Dialog" },
    { key = "Music", name = "Music" },
    { key = "Ambience", name = "Ambience" },
}
local soundFiles = {
    "Aggro.mp3", "Arrow Swoosh.mp3", "Bam.mp3", "bcs.mp3", "Bear Polar.mp3",
    "Big Kiss.mp3", "Burp.mp3", "Chant1.mp3", "Chant2.mp3", "Chimes.mp3",
    "Cookie.mp3", "Espark.mp3", "Fireball.mp3", "Gasp.mp3", "Glass.mp3",
    "guild.mp3", "Heartbeat.mp3", "Hic.mp3", "Huh.mp3", "Hurricane.mp3",
    "Hyena.mp3", "Moan.mp3", "Panther.mp3", "Phone.mp3", "Punch.mp3",
    "Rainroof.mp3", "Rocket.mp3", "Ship Horn.mp3", "short_bongo.mp3", "Shot.mp3",
    "Snake.mp3", "Sneeze.mp3", "Splash.mp3", "Squeaky.mp3", "Sword.mp3",
    "text.mp3", "text2.mp3", "Throw.mp3", "Thunder.mp3", "Wicked Laugh Female.mp3",
    "Wicked Laugh Male.mp3", "Wolf.mp3", "Yeehaw.mp3",
    "absorb.ogg", "AirHorn.ogg", "BananaPeelSlip.ogg", "Barrier.ogg", "BikeHorn.ogg",
    "Bite.ogg", "BoP.ogg", "BoxingArenaSound.ogg", "CatMeow.ogg", "CatMeow2.ogg",
    "dispel.ogg", "Kaching.ogg", "kick.ogg", "Phone.ogg", "RobotBlip.ogg",
    "Sonar.ogg", "WarningSiren.ogg", "WaterDrop.ogg", "whisper.ogg", "Wilhelm.ogg",
    "FrontalsGunshot.wav",
}

-- Preserve keys used by earlier versions so existing profiles keep working.
local legacyKeys = {
    ["AirHorn.ogg"] = "airhorn", ["BananaPeelSlip.ogg"] = "banana",
    ["BikeHorn.ogg"] = "bikehorn", ["Bite.ogg"] = "bite",
    ["BoxingArenaSound.ogg"] = "boxing", ["CatMeow.ogg"] = "catmeow",
    ["CatMeow2.ogg"] = "catmeow2", ["FrontalsGunshot.wav"] = "gunshot",
    ["Glass.mp3"] = "glass", ["Kaching.ogg"] = "kaching",
    ["Phone.ogg"] = "phone", ["RobotBlip.ogg"] = "robotblip",
    ["Sonar.ogg"] = "sonar", ["WarningSiren.ogg"] = "siren",
    ["WaterDrop.ogg"] = "water", ["Wilhelm.ogg"] = "wilhelm",
}

local displayNames = {
    ["bcs.mp3"] = "BCS", ["Espark.mp3"] = "Electric Spark",
    ["guild.mp3"] = "Guild", ["Rainroof.mp3"] = "Rain on Roof",
    ["short_bongo.mp3"] = "Short Bongo", ["text.mp3"] = "Text 1",
    ["text2.mp3"] = "Text 2", ["absorb.ogg"] = "Absorb",
    ["AirHorn.ogg"] = "Air Horn", ["BananaPeelSlip.ogg"] = "Banana Peel Slip",
    ["Barrier.ogg"] = "Barrier", ["BikeHorn.ogg"] = "Bike Horn",
    ["BoP.ogg"] = "Blessing of Protection", ["BoxingArenaSound.ogg"] = "Boxing Arena",
    ["CatMeow.ogg"] = "Cat Meow", ["CatMeow2.ogg"] = "Cat Meow 2",
    ["dispel.ogg"] = "Dispel", ["kick.ogg"] = "Kick",
    ["Phone.ogg"] = "Phone (OGG)", ["Phone.mp3"] = "Phone (MP3)",
    ["RobotBlip.ogg"] = "Robot Blip", ["WarningSiren.ogg"] = "Warning Siren",
    ["WaterDrop.ogg"] = "Water Drop", ["whisper.ogg"] = "Whisper",
    ["FrontalsGunshot.wav"] = "Frontals Gunshot",
}

local customSounds, usedKeys, reservedKeys = {}, {}, {}
for _, key in pairs(legacyKeys) do reservedKeys[key] = true end
for _, file in ipairs(soundFiles) do
    local base, extension = file:match("^(.*)%.([^%.]+)$")
    local legacyKey = legacyKeys[file]
    local key = legacyKey or base:lower():gsub("[^%w]+", "_"):gsub("^_", ""):gsub("_$", "")
    if not legacyKey and reservedKeys[key] then key = key .. "_" .. extension:lower() end
    if usedKeys[key] then key = key .. "_" .. extension:lower() end
    usedKeys[key] = true
    customSounds[#customSounds + 1] = {
        key = key,
        name = displayNames[file] or base,
        file = file,
        format = extension:upper(),
    }
end
table.sort(customSounds, function(left, right) return left.name:lower() < right.name:lower() end)
local customByKey = {}
for _, sound in ipairs(customSounds) do customByKey[sound.key] = sound end

local function GetCustomSound(token)
    if type(token) ~= "string" then return nil end
    local key = token:match("^[^:]+:(.+)$") or token
    return customByKey[key]
end

local function BuildPickerSounds()
    local sounds = {}
    for _, sound in ipairs(customSounds) do sounds[#sounds + 1] = sound end

    local seen = {}
    local function AddBlizzardSounds(soundData)
        for _, value in ipairs(type(soundData) == "table" and soundData or {}) do
            if type(value) == "table" and value.soundEnum and value.text then
                if not seen[value.soundEnum] then
                    seen[value.soundEnum] = true
                    sounds[#sounds + 1] = {
                        soundEnum = value.soundEnum,
                        name = value.text,
                        format = "CDM",
                    }
                end
            elseif type(value) == "table" then
                AddBlizzardSounds(value)
            end
        end
    end
    AddBlizzardSounds(_G.CooldownViewerSoundData)

    table.sort(sounds, function(left, right)
        local leftName, rightName = left.name:lower(), right.name:lower()
        if leftName == rightName then return left.format < right.format end
        return leftName < rightName
    end)
    return sounds
end

local function GetPickerSoundValue(sound)
    return sound.soundEnum or ("baby:" .. sound.key)
end

function Audio:GetName(soundEnum)
    if not soundEnum then return "Select sound" end
    if type(soundEnum) == "string" then
        local sound = GetCustomSound(soundEnum)
        return sound and ("Baby Auras: " .. sound.name) or "Select sound"
    end
    return CooldownViewerUtil.GetSoundTypeText(soundEnum) or "Select sound"
end

function Audio:GetChannelName(channel)
    for _, data in ipairs(self.channels) do
        if data.key == channel then return data.name end
    end
    return "Master"
end

function Audio:IsMuted()
    return BabyAurasDB and BabyAurasDB.muteAllAudio == true
end

function Audio:Play(soundEnum, channel)
    if self:IsMuted() then return false end
    channel = self:GetChannelName(channel) ~= "Master" and channel or "Master"
    if type(soundEnum) == "string" then
        local sound = GetCustomSound(soundEnum)
        if not sound then return false end
        return PlaySoundFile(customSoundDirectory .. sound.file, channel)
    end
    local soundKitID = soundEnum and CooldownViewerUtil.GetSoundTypeSoundKit(soundEnum)
    if not soundKitID then return false end
    return PlaySound(soundKitID, channel)
end

function Audio:RefreshPicker()
    local picker = self.picker
    if not picker then return end
    local search = strtrim(picker.Search:GetText() or ""):lower()
    wipe(picker.filtered)
    for _, sound in ipairs(BuildPickerSounds()) do
        if search == "" or sound.name:lower():find(search, 1, true)
            or sound.format:lower():find(search, 1, true) then
            picker.filtered[#picker.filtered + 1] = sound
        end
    end
    local maximum = math.max(0, #picker.filtered - #picker.Rows)
    picker.ScrollBar:SetMinMaxValues(0, maximum)
    picker.ScrollBar:SetValue(Clamp(picker.offset or 0, 0, maximum))
    picker.ScrollBar:SetShown(maximum > 0)
    picker.Count:SetText(#picker.filtered .. " sounds")
    picker.offset = math.floor(picker.ScrollBar:GetValue() + 0.5)
    for index, row in ipairs(picker.Rows) do
        local sound = picker.filtered[picker.offset + index]
        row.sound = sound
        if sound then
            local token = GetPickerSoundValue(sound)
            row.Name:SetText(sound.name)
            row.Format:SetText(sound.format)
            row.Selected:SetShown(picker.getSelected and picker.getSelected() == token)
            row:Show()
        else
            row:Hide()
        end
    end
end

function Audio:CreatePicker()
    if self.picker then return self.picker end
    local picker = CreateFrame("Frame", "BabyAurasSoundPicker", UIParent, "BackdropTemplate")
    picker:SetSize(390, 460)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetMovable(true)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    picker:SetBackdropColor(0.025, 0.025, 0.04, 0.98)
    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local title = picker:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText("Alert Sounds")
    title:SetTextColor(0.52, 0.82, 1)
    local count = picker:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    count:SetPoint("TOPRIGHT", -44, -23)
    picker.Count = count
    local search = CreateFrame("EditBox", nil, picker, "SearchBoxTemplate")
    search:SetPoint("TOPLEFT", 18, -52)
    search:SetPoint("TOPRIGHT", -18, -52)
    search:SetHeight(26)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        picker.offset = 0
        Audio:RefreshPicker()
    end)
    picker.Search = search
    picker.filtered = {}
    picker.Rows = {}

    for index = 1, 14 do
        local row = CreateFrame("Button", nil, picker, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 18, -86 - ((index - 1) * 24))
        row:SetPoint("RIGHT", -34, 0)
        row:SetHeight(23)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        row:SetBackdropColor(0.08, 0.09, 0.14, index % 2 == 0 and 0.55 or 0.35)
        local selected = row:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(0.12, 0.5, 0.8, 0.42)
        selected:Hide()
        row.Selected = selected
        local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        name:SetPoint("LEFT", 8, 0)
        name:SetPoint("RIGHT", -50, 0)
        name:SetJustifyH("LEFT")
        row.Name = name
        local format = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        format:SetPoint("RIGHT", -7, 0)
        row.Format = format
        row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.16, 0.24, 0.4, 0.85) end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(0.08, 0.09, 0.14, index % 2 == 0 and 0.55 or 0.35) end)
        row:SetScript("OnClick", function(self)
            if not self.sound then return end
            local token = GetPickerSoundValue(self.sound)
            if picker.setSelected then picker.setSelected(token) end
            Audio:Play(token, picker.getChannel and picker.getChannel() or "Master")
            Audio:RefreshPicker()
        end)
        picker.Rows[index] = row
    end

    local scrollBar = CreateFrame("Slider", nil, picker, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", -13, -88)
    scrollBar:SetPoint("BOTTOMRIGHT", -13, 30)
    scrollBar:SetValueStep(1)
    scrollBar:SetObeyStepOnDrag(true)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        picker.offset = math.floor(value + 0.5)
        Audio:RefreshPicker()
    end)
    picker.ScrollBar = scrollBar
    picker:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(Clamp(scrollBar:GetValue() - delta * 3, 0, select(2, scrollBar:GetMinMaxValues())))
    end)
    picker:Hide()
    self.picker = picker
    return picker
end

function Audio:OpenPicker(getSelected, setSelected, getChannel)
    local picker = self:CreatePicker()
    picker.getSelected = getSelected
    picker.setSelected = setSelected
    picker.getChannel = getChannel
    picker.offset = 0
    picker.ScrollBar:SetValue(0)
    picker.Search:SetText("")
    self:RefreshPicker()
    picker:Show()
end

function Audio:BuildMenu(rootDescription, getSelected, setSelected)
    rootDescription:CreateRadio("None", function()
        return getSelected() == nil
    end, function()
        setSelected(nil)
    end)

    rootDescription:CreateButton("Browse Sounds...", function()
        Audio:OpenPicker(getSelected, setSelected, function() return addon.GUI.selectedAudioChannel end)
    end)
end
