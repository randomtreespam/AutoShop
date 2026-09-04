-- ============================================================
-- AUTO SHOP CONFIG
-- These are only the *first-launch* defaults. Once you change anything
-- from the in-game Config tab (targets, hotkey, max cost, skip
-- animations), that gets saved to AutoShop_settings.jkr in Balatro's
-- own save folder and takes over completely from here on -- editing this
-- file afterward has no effect until that save is deleted. Safe to still
-- hand-edit before ever touching the in-game menu, e.g. to seed a
-- different starting target_keys list.
-- ============================================================

AutoShop.SETTINGS = {
    -- Card(s) you want the shop to contain -- a list of one or more center
    -- "keys", not display names. The search stops as soon as ANY of these
    -- shows up. Jokers use a "j_" prefix (e.g. "j_blueprint" for Blueprint);
    -- Tarot/Planet/Spectral cards use "c_" (e.g. "c_hermit" for The Hermit,
    -- "c_temperance" for Temperance). Find exact keys in your game files
    -- under resources/localization/en-us.lua or items.lua, or by hovering a
    -- card with a debug overlay mod. Leave as an empty table to disable --
    -- easiest way to set these is the in-game Manage Targets picker rather
    -- than hand-editing this file (see README's Use section).
    target_keys = {},

    -- Editions (Foil/Holographic/Polychrome/Negative) you want the shop to
    -- contain, e.g. { "negative" } to stop on ANY card with a Negative
    -- edition, regardless of which joker/card it's on. Unlike target_keys,
    -- an edition isn't its own card -- it's a modifier layered on top of a
    -- card's own identity (a Negative Blueprint and a plain Blueprint
    -- share the same center key), so it needs its own list and its own
    -- match logic; see shop_has_target() in AutoShop_reroll.lua. Valid
    -- values: "foil", "holo", "polychrome", "negative".
    target_editions = {},

    -- Safety valve so a bad key or unlucky pool can't hang the game. Rerolls
    -- are dispatched one at a time -- each one waits for the shop to
    -- actually change before the next is fired -- so this is a real ceiling
    -- on total rerolls tried, not a per-frame batch size.
    max_total_attempts = 3000,      -- give up after this many total attempts

    -- Keybind to start/stop a search, checked in AutoShop_keyhandler.lua.
    -- Uses LÖVE key constants, e.g. "f6", "t", "kp+".
    search_key = "f6",

    -- Keybind that jumps straight to the Add Target picker (Mods -> Auto
    -- Shop -> Config -> Manage Targets), from anywhere in the game --
    -- same LÖVE key constant format as search_key above.
    manage_targets_key = "f7",

    -- Stop the search the moment the shop's reroll cost climbs above this
    -- many dollars (reroll cost rises each time you reroll within a shop
    -- visit). nil/0 means no limit.
    max_reroll_cost = nil,

    -- Stop the search if paying for the next reroll would drop your
    -- dollars below this amount, e.g. 10 to always keep at least $10 in
    -- reserve. nil/0 means no minimum -- the search then only stops once
    -- it can't afford the reroll at all (dollars would go negative).
    min_cash = nil,

    -- Cranks G.SETTINGS.GAMESPEED way up for the duration of a search, the
    -- same trick ZokersModMenu uses to blow through its own setup
    -- animations -- Balatro scales card animation updates and its own
    -- internal event timers (including the shop reroll's card-swap
    -- animation) by this value, so pushing it up makes them resolve
    -- almost instantly instead of playing out at normal speed. Restored
    -- automatically the moment the search stops, however it stops.
    skip_animations = false,

    -- Prints a couple of extra breadcrumb lines to the lovely console log
    -- for the first few rerolls of each search (how many frames a reroll
    -- took to actually land). Useful while calibrating against your
    -- modlist; safe to leave on, or set false once things look right.
    debug = true,
}
