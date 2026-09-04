-- Loaded by lovely.toml's [[patches.copy]], appended to the end of main.lua.
-- Mirrors how Brainstorm bootstraps itself (see Brainstorm.lua).

AutoShop = {}

-- Settings persistence: everything in AutoShop.SETTINGS is saved as a
-- whole and restored as a whole across launches, rather than merged
-- field-by-field onto the shipped defaults. Steamodded has its own
-- built-in per-mod config save/load (SMODS.load_mod_config /
-- save_mod_config), but its load merges saved values ONTO the defaults
-- key-by-key -- which can't represent removing an item from a list. A
-- saved target_keys with an entry taken out would still get that entry
-- merged back in from AutoShop_config.lua's defaults, since the merge
-- only overwrites keys present in the save, never deletes keys that
-- aren't. Full replacement (use the save as-is if one exists, otherwise
-- the defaults) avoids that entirely, at the cost of not being able to
-- pick up a newly-added default field once a save exists -- fine for a
-- settings blob this small.
--
-- love.filesystem (not the bundled nativefs, which is for reading files
-- out of the mod folder by absolute path) is what targets Balatro's own
-- per-installation save directory -- the same sandboxed location vanilla
-- save games and Steamodded's own mod configs live in.
local SETTINGS_SAVE_PATH = "AutoShop_settings.jkr"

-- serialize() is a Steamodded utility (src/utils.lua), not a vanilla
-- Balatro function -- safe to depend on since everything else here
-- (the Config tab, native text input, the Mods menu integration) already
-- requires Steamodded to be installed.
function AutoShop.save_settings()
    local ok, err = pcall(function()
        love.filesystem.write(SETTINGS_SAVE_PATH, "return " .. serialize(AutoShop.SETTINGS))
    end)
    if not ok then
        print("[Auto Shop] Failed to save settings: " .. tostring(err))
    end
end

local function load_saved_settings()
    local contents = love.filesystem.read(SETTINGS_SAVE_PATH)
    if not contents then
        return nil
    end
    local ok, saved = pcall(function()
        return assert(load(contents))()
    end)
    if ok and type(saved) == "table" then
        return saved
    end
    print("[Auto Shop] Saved settings file was unreadable, using defaults.")
    return nil
end

function initAutoShop()
    local lovely = require("lovely")
    local nativefs = require("nativefs")

    -- Order matters: config defines AutoShop.SETTINGS before anything else
    -- reads it; reroll defines the search engine; UI/keyhandler wire it to
    -- the player.
    assert(load(nativefs.read(lovely.mod_dir .. "/AutoShop/AutoShop_config.lua")))()

    local saved = load_saved_settings()
    if saved then
        AutoShop.SETTINGS = saved
    end

    assert(load(nativefs.read(lovely.mod_dir .. "/AutoShop/AutoShop_reroll.lua")))()
    assert(load(nativefs.read(lovely.mod_dir .. "/AutoShop/AutoShop_UI.lua")))()
    assert(load(nativefs.read(lovely.mod_dir .. "/AutoShop/AutoShop_keyhandler.lua")))()

    local targets = AutoShop.SETTINGS.target_keys
    local targets_str = type(targets) == "table" and table.concat(targets, ", ") or tostring(targets)
    print("[Auto Shop] loaded. Current target(s): " .. targets_str)
end
