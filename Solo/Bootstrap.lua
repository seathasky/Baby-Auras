local _, addon = ...

-- All Solo modules extend this one shared runtime object. Keep its state
-- initialization centralized so module load order never replaces live state.
addon.Solo = addon.Solo or {
    editMode = false,
    suspended = false,
    suspensionReasons = {},
    displays = {},
    sources = {},
    liveCooldownStates = setmetatable({}, { __mode = "k" }),
    itemCooldownIDs = setmetatable({}, { __mode = "k" }),
    mirrorHooks = setmetatable({}, { __mode = "k" }),
    nativeHostStates = setmetatable({}, { __mode = "k" }),
}

