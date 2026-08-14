local _, addon = ...

addon.GUISections = addon.GUISections or {}
local AudioSection = {}
addon.GUISections.Audio = AudioSection

local Widgets = addon.GUIWidgets

function AudioSection:Build(editor, anchor, frame)
    local GUI = addon.GUI
    local title, line = Widgets.CreateSectionTitle(editor, "VOICE & AUDIO")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    frame.VoiceTitle = title

    local tts, ttsLabel = Widgets.CreateCheckbox(editor, "TTS", 35)
    tts:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    tts:SetScript("OnClick", function() GUI:OnTTSClicked() end)
    frame.TTS, frame.TTSLabel = tts, ttsLabel

    local textLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", tts, "BOTTOMLEFT", 4, -8)
    textLabel:SetText("Custom TTS")
    textLabel:SetTextColor(0.56, 0.69, 0.78)
    local textBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    textBox:SetPoint("TOPLEFT", textLabel, "BOTTOMLEFT", 4, -7)
    textBox:SetSize(220, 26)
    textBox:SetAutoFocus(false)
    textBox:SetMaxLetters(200)
    textBox:SetScript("OnEscapePressed", textBox.ClearFocus)
    textBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GUI:CommitEditor() end)
    textBox:SetScript("OnTextChanged", function() GUI:ScheduleAutoSave() end)
    frame.TextBox = textBox

    local speechRateLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    speechRateLabel:SetPoint("TOPLEFT", textLabel, "TOPLEFT", 238, 0)
    speechRateLabel:SetText("Speech speed")
    speechRateLabel:SetTextColor(0.56, 0.69, 0.78)
    frame.SpeechRateLabel = speechRateLabel
    local speechRate = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    speechRate:SetPoint("TOPLEFT", speechRateLabel, "BOTTOMLEFT", 4, -7)
    speechRate:SetSize(78, 26)
    speechRate:SetAutoFocus(false)
    speechRate:SetMaxLetters(3)
    speechRate:SetScript("OnEscapePressed", speechRate.ClearFocus)
    speechRate:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GUI:CommitEditor() end)
    speechRate:SetScript("OnTextChanged", function() GUI:ScheduleAutoSave() end)
    frame.SpeechRate = speechRate
    local rateHint = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    rateHint:SetPoint("TOP", speechRate, "BOTTOM", 0, -2)
    rateHint:SetText("-10 to 10")

    local volume = CreateFrame("Slider", nil, editor, "OptionsSliderTemplate")
    volume:SetPoint("TOPLEFT", textBox, "BOTTOMLEFT", 7, -11)
    volume:SetSize(135, 16)
    volume:SetMinMaxValues(0, 100)
    volume:SetValueStep(5)
    volume:SetObeyStepOnDrag(true)
    volume.Low:SetText("0")
    volume.High:SetText("100")
    volume.Text:SetText("")
    volume:SetScript("OnValueChanged", function(_, value) GUI:OnTTSVolumeChanged(value) end)
    frame.TTSVolume = volume
    local volumeValue = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    volumeValue:SetPoint("LEFT", volume, "RIGHT", 10, 0)
    volumeValue:SetText("Volume 100%")
    frame.TTSVolumeValue = volumeValue

    local audio, audioLabel = Widgets.CreateCheckbox(editor, "Audio", 55)
    audio:SetPoint("TOPLEFT", volume, "BOTTOMLEFT", -7, -13)
    audio:SetScript("OnClick", function() GUI:OnAudioClicked() end)
    frame.Audio, frame.AudioLabel = audio, audioLabel
    local dropdown = FrameUtil.CreateFrame(nil, editor, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", audioLabel, "RIGHT", 12, 0)
    dropdown:SetSize(195, 26)
    dropdown:SetSelectionText(function() return addon.Audio:GetName(GUI.selectedAudio) end)
    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:SetTag("BABY_AURAS_SOUND_PICKER")
        addon.Audio:BuildMenu(rootDescription, function() return GUI.selectedAudio end, function(soundEnum)
            GUI:SetAudioSound(soundEnum)
        end)
    end)
    dropdown:EnableRegenerateOnResponse()
    frame.AudioDropdown = dropdown

    local preview = CreateFrame("Button", nil, editor)
    preview:SetPoint("LEFT", dropdown, "RIGHT", 7, 0)
    preview:SetSize(20, 20)
    local previewIcon = preview:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints()
    previewIcon:SetTexture("Interface\\Common\\VoiceChat-Speaker")
    previewIcon:SetVertexColor(0.85, 0.85, 0.85)
    local previewHighlight = preview:CreateTexture(nil, "HIGHLIGHT")
    previewHighlight:SetAllPoints()
    previewHighlight:SetTexture("Interface\\Common\\VoiceChat-On")
    preview:SetScript("OnClick", function() GUI:PreviewAudio() end)
    preview:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Preview selected audio")
        GameTooltip:Show()
    end)
    preview:SetScript("OnLeave", GameTooltip_Hide)
    frame.AudioPreview = preview

    local channel = FrameUtil.CreateFrame(nil, editor, "WowStyle1DropdownTemplate")
    channel:SetPoint("TOPLEFT", audio, "BOTTOMLEFT", -8, -7)
    channel:SetSize(150, 26)
    channel:SetSelectionText(function()
        return "Channel: " .. addon.Audio:GetChannelName(GUI.selectedAudioChannel)
    end)
    channel:SetupMenu(function(_, rootDescription)
        for _, option in ipairs(addon.Audio.channels) do
            rootDescription:CreateRadio(option.name, function(value)
                return GUI.selectedAudioChannel == value
            end, function(value)
                GUI:SetAudioChannel(value)
            end, option.key)
        end
    end)
    channel:EnableRegenerateOnResponse()
    frame.AudioChannel = channel

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "voice")
    return {
        title = title, line = line, toggle = toggle,
        tts = tts, ttsLabel = ttsLabel,
        textLabel = textLabel, textBox = textBox,
        speechRateLabel = speechRateLabel, speechRate = speechRate, rateHint = rateHint,
        volume = volume, volumeValue = volumeValue,
        audio = audio, audioLabel = audioLabel, dropdown = dropdown, preview = preview, channel = channel,
        descriptor = {
            key = "voice", title = title, toggle = toggle, bottom = channel,
            gap = -14, collapseHeight = 172,
            elements = {
                tts, ttsLabel, textLabel, textBox, speechRateLabel, speechRate, rateHint,
                volume, volumeValue, audio, audioLabel, dropdown, preview, channel,
            },
        },
    }
end
