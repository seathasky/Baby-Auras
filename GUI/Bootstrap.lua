local _, addon = ...

-- The controller table is created before any GUI submodule loads. Submodules
-- add focused behavior to this shared object; GUI/Controller.lua remains its public entry
-- point and owns the user's current editor selection/state.
addon.GUI = addon.GUI or {
    selected = nil,
    selectedTrigger = nil,
    selectedAudio = nil,
    selectedAudioChannel = "Master",
    selectedGlowStyle = "blizzard",
    refreshing = false,
    saveGeneration = 0,
}
