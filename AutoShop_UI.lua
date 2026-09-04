-- Auto Shop's UI lives entirely in its Steamodded "Mods" menu entry (the
-- Config tab -- see AutoShop_smods.lua, which is what actually attaches
-- create_config_tab_uibox() below to the Mods menu).

-- Rebuilds and reopens Auto Shop's Mods-menu entry in place, so it
-- reflects a change (a delete, a hotkey capture, a keystroke while editing
-- Max Cost) immediately instead of showing a stale row/label until the
-- player backs out and back in. Exposed on AutoShop (not just local)
-- because AutoShop_keyhandler.lua also needs to call it, once a
-- captured hotkey lands or on every keystroke while editing Max Cost.
--
-- This used to just call Steamodded's own "openModUI_autoshop" button
-- handler (src/preflight/loader.lua, initializeModUIFunctions), but that
-- always goes through G.FUNCS.overlay_menu with its default {x=0,y=10}
-- entrance offset -- the same "slide up into place" animation that
-- bounced the Add Target picker on every click (see refresh_add_ui's own
-- comment). Typing digits into Max Cost calls this on every keystroke, so
-- the same bounce showed up there too. Fixed the same way: call the same
-- two building blocks openModUI_autoshop itself calls
-- (create_UIBox_mods + G.FUNCS.overlay_menu), but with offset={x=0,y=0}
-- ourselves. G.ACTIVE_MOD_UI (which create_UIBox_mods reads) is already
-- set to our mod from having navigated in here in the first place, so
-- this is safe -- but fall back to the original path if it's ever not
-- set (shouldn't happen: every caller of this function is a button that
-- only exists inside the already-open Config tab).
function AutoShop.refresh_config_tab(e)
    if G.ACTIVE_MOD_UI and create_UIBox_mods then
        G.FUNCS.overlay_menu({
            definition = create_UIBox_mods(e),
            config = { offset = { x = 0, y = 0 } },
        })
        return
    end
    local open = G.FUNCS["openModUI_autoshop"]
    if open then
        open(e)
    end
end

-- Builds one "<label>: <KEY>" hotkey-setting row for the Config tab.
-- setting_key names the field in AutoShop.SETTINGS this row edits (e.g.
-- "search_key", "manage_targets_key") -- shared by both hotkey rows below
-- and by autoshop_set_hotkey/AutoShop_keyhandler.lua's capture logic,
-- so adding another configurable hotkey later is just another call to
-- this plus a branch in key_press_update.
local function hotkey_row(label, setting_key)
    local capturing = AutoShop.AWAITING_KEYBIND_FOR == setting_key
    local button_label = capturing
        and "Press any key..."
        or (label .. ": " .. tostring(AutoShop.SETTINGS[setting_key] or "none"):upper())
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            UIBox_button({
                minw = 3,
                button = "autoshop_set_hotkey",
                label = { button_label },
                colour = capturing and HEX('D2691E') or HEX('4F6367'),
                ref_table = { setting_key = setting_key },
            }),
        },
    }
end

-- Builds one "<label>: $<value>" numeric-setting row for the Config tab
-- (Max Cost, Min Cash), mirroring hotkey_row above: setting_key names the
-- AutoShop.SETTINGS field this row edits, shared with
-- autoshop_edit_numeric and AutoShop_keyhandler.lua's digit-capture logic
-- (AutoShop.EDITING_NUMERIC_FOR/NUMERIC_BUFFER) so adding another numeric
-- setting later is just another call to this plus reading it in
-- key_press_update. no_limit_label is what's shown when the setting is
-- nil/0 (they mean different things per setting, e.g. "No Limit" vs "No
-- Minimum").
local function numeric_row(label, setting_key, no_limit_label)
    local editing = AutoShop.EDITING_NUMERIC_FOR == setting_key
    local value_label
    if editing then
        value_label = label .. ": $" .. AutoShop.NUMERIC_BUFFER .. "_"
    elseif AutoShop.SETTINGS[setting_key] and AutoShop.SETTINGS[setting_key] > 0 then
        value_label = label .. ": $" .. AutoShop.SETTINGS[setting_key]
    else
        value_label = label .. ": " .. no_limit_label
    end
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            UIBox_button({
                minw = 3,
                button = "autoshop_edit_numeric",
                label = { value_label },
                colour = editing and HEX('D2691E') or HEX('4F6367'),
                ref_table = { setting_key = setting_key },
            }),
        },
    }
end

-- Builds the UIBox node tree for Auto Shop's Config tab: status, the
-- hotkey settings, and the full target_keys list with a delete button per
-- row.
function AutoShop.create_config_tab_uibox()
    local col_nodes = {}

    local status_text = AutoShop.SEARCH.running
        and ("Searching... (" .. AutoShop.SEARCH.attempts .. " rerolls so far)")
        or "Idle"
    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            { n = G.UIT.T, config = { text = "Status: " .. status_text, scale = 0.35, colour = G.C.WHITE } },
        },
    }

    col_nodes[#col_nodes + 1] = hotkey_row("Reroll Hotkey", "search_key")
    col_nodes[#col_nodes + 1] = hotkey_row("Target Menu Hotkey", "manage_targets_key")

    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            UIBox_button({
                minw = 3,
                button = "autoshop_toggle_skip_animations",
                label = { "Skip Animations: " .. (AutoShop.SETTINGS.skip_animations and "ON" or "OFF") },
                colour = AutoShop.SETTINGS.skip_animations and HEX('00A000') or HEX('4F6367'),
            }),
        },
    }

    col_nodes[#col_nodes + 1] = numeric_row("Max Cost", "max_reroll_cost", "No Limit")
    col_nodes[#col_nodes + 1] = numeric_row("Min Cash", "min_cash", "No Minimum")

    -- The full target list with per-item delete buttons used to live here
    -- too, but it's redundant now that the Add Target picker (below) can
    -- itself be filtered down to "Selected Only" -- that view already
    -- shows every target (green) with a single click to remove it, so
    -- there's no need for a second, separate place to review the list.
    -- Counts both lists: target_keys (Jokers/Tarot/Planet/Spectral, all
    -- matched by center key) and target_editions (Foil/Holographic/
    -- Polychrome/Negative, matched separately since an edition is a
    -- modifier on a card, not a card of its own).
    local keys = AutoShop.SETTINGS.target_keys
    local editions = AutoShop.SETTINGS.target_editions
    local target_count = (type(keys) == "table" and #keys or 0) + (type(editions) == "table" and #editions or 0)
    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            UIBox_button({
                minw = 3,
                button = "autoshop_open_add_ui",
                label = { "Manage Targets (" .. target_count .. ")" },
                colour = HEX('00A000'),
            }),
        },
    }

    return {
        n = G.UIT.ROOT,
        config = { align = "cm", colour = G.C.CLEAR, minw = 6 },
        nodes = {
            {
                n = G.UIT.C,
                config = { align = "cm", padding = 0.3, r = 0.1, colour = G.C.BLACK, emboss = 0.05 },
                nodes = col_nodes,
            },
        },
    }
end

G.FUNCS.autoshop_set_hotkey = function(e)
    local setting_key = e.config and e.config.ref_table and e.config.ref_table.setting_key
    AutoShop.AWAITING_KEYBIND_FOR = setting_key or "search_key"
    AutoShop.refresh_config_tab(e)
end

G.FUNCS.autoshop_toggle_skip_animations = function(e)
    AutoShop.SETTINGS.skip_animations = not AutoShop.SETTINGS.skip_animations
    AutoShop.save_settings()
    AutoShop.refresh_config_tab(e)
end

G.FUNCS.autoshop_edit_numeric = function(e)
    local setting_key = e.config and e.config.ref_table and e.config.ref_table.setting_key
    AutoShop.EDITING_NUMERIC_FOR = setting_key or "max_reroll_cost"
    AutoShop.NUMERIC_BUFFER = (AutoShop.SETTINGS[AutoShop.EDITING_NUMERIC_FOR] and tostring(AutoShop.SETTINGS[AutoShop.EDITING_NUMERIC_FOR])) or ""
    AutoShop.refresh_config_tab(e)
end

-- ============================================================
-- Add-target picker: its own overlay (opened from the "Manage Targets"
-- button above), with a tab per card type that can actually show up in a
-- shop row -- Seals/Decks/Vouchers/Boosters/Tags/Blinds are separate
-- collection categories built from different data, not from these pools,
-- so there's nothing to "exclude" for them; they're just never part of
-- this list. Card lists are read live from G.P_CENTER_POOLS, the same
-- registry the real Collection screen and shop generation itself read
-- from, so modded jokers/tarots/planets/spectrals from any installed mod
-- show up automatically with no extra wiring.
--
-- "Edition" is the one exception to "read straight from
-- G.P_CENTER_POOLS[category]": see pool_items_for_category below.
-- ============================================================

local ADD_UI_CATEGORIES = { "Joker", "Tarot", "Planet", "Spectral", "Edition" }
local ADD_UI_PER_PAGE = 20

AutoShop.ADD_UI = AutoShop.ADD_UI or { category = "Joker", page = 1, search = "", selected_only = false }

-- Which AutoShop.SETTINGS list a category's picks live in: editions are
-- their own separate list (see AutoShop_reroll.lua's target_editions
-- for why they can't share target_keys); every other category shares
-- target_keys.
local function target_list_for(category)
    local field = (category == "Edition") and "target_editions" or "target_keys"
    local list = AutoShop.SETTINGS[field]
    if type(list) ~= "table" then
        list = {}
        AutoShop.SETTINGS[field] = list
    end
    return list
end

local function index_in(list, key)
    for i, k in ipairs(list) do
        if k == key then
            return i
        end
    end
    return nil
end

-- Only Common/Uncommon/Rare jokers can actually turn up from a shop
-- reroll -- Legendary is real rarity 4 in vanilla Balatro, but it's never
-- picked by normal weighted selection (functions/common_events.lua's
-- get_current_pool() only ever rolls 1-3; rarity 4 is only reachable via
-- an explicit "this is a Soul card" flag elsewhere, bypassing the weight
-- system entirely) -- so it'd never actually show up no matter how long a
-- search runs. Rather than hardcode "only rarities 1/2/3" (an EXCLUSIVE
-- whitelist that would wrongly hide any custom rarity a mod adds), this
-- checks the opposite way: exclude a rarity only if it's a rarity we can
-- positively confirm has zero shop weight -- vanilla Legendary, or a
-- modded SMODS.Rarity registered with default_weight 0 (the same
-- convention Steamodded's own vanilla Legendary registration uses, see
-- Steamodded's src/game_object.lua). Anything else -- including a custom
-- rarity we don't recognize at all -- is treated as rollable and shown.
local function is_rollable_joker_rarity(rarity)
    if rarity == 4 then
        return false
    end
    if type(rarity) == "string" and SMODS and SMODS.Rarities and SMODS.Rarities[rarity] then
        local weight = SMODS.Rarities[rarity].default_weight
        if not weight or weight == 0 then
            return false
        end
    end
    return true
end

-- Every item a category can show, normalized to {key=, name=} (real
-- center objects from G.P_CENTER_POOLS already have both fields, so they
-- pass straight through unwrapped -- only the synthetic "Edition"
-- category needs building by hand, since Foil/Holographic/Polychrome/
-- Negative are flags on card.edition, not centers -- this is just a fixed
-- list built from AutoShop.EDITION_ORDER/EDITION_LABELS
-- (AutoShop_reroll.lua), which is also what shop_has_target() checks
-- against.
local function pool_items_for_category(category)
    if category == "Edition" then
        local items = {}
        for _, key in ipairs(AutoShop.EDITION_ORDER) do
            items[#items + 1] = { key = key, name = AutoShop.EDITION_LABELS[key] or key }
        end
        return items
    end
    return G.P_CENTER_POOLS[category] or {}
end

-- The pool for the active category, filtered by rarity (Jokers only, see
-- is_rollable_joker_rarity above), then "Selected Only" (if on), then the
-- search text (plain substring match against the display name, not a Lua
-- pattern -- card names can contain characters like "-" that would
-- otherwise need escaping).
--
-- "Selected Only" skips the rarity filter entirely: it's the one screen
-- that reviews/removes your actual target list (the Config tab's own list
-- view was dropped in favor of this), so it needs to keep showing
-- everything selected even if e.g. a Legendary joker somehow ended up
-- targeted before this filter existed -- otherwise there'd be no way to
-- see or remove it at all.
local function filtered_pool()
    local category = AutoShop.ADD_UI.category
    local pool = pool_items_for_category(category)
    if AutoShop.ADD_UI.selected_only then
        local list = target_list_for(category)
        local selected = {}
        for _, item in ipairs(pool) do
            if index_in(list, item.key) then
                selected[#selected + 1] = item
            end
        end
        pool = selected
    elseif category == "Joker" then
        local rollable = {}
        for _, item in ipairs(pool) do
            if is_rollable_joker_rarity(item.rarity) then
                rollable[#rollable + 1] = item
            end
        end
        pool = rollable
    end
    local search = (AutoShop.ADD_UI.search or ""):lower()
    if search == "" then
        return pool
    end
    local out = {}
    for _, item in ipairs(pool) do
        local name = (item.name or item.key or ""):lower()
        if name:find(search, 1, true) then
            out[#out + 1] = item
        end
    end
    return out
end

-- Rebuilds and reopens the picker in place, e.g. after a tab switch, page
-- turn, search, or pick -- mirroring the same "rebuild fresh" idiom
-- refresh_config_tab uses for the Config tab, since this overlay isn't
-- part of Steamodded's Mods-menu tab system and has to manage its own
-- redraw.
function AutoShop.refresh_add_ui()
    -- G.FUNCS.overlay_menu (functions/button_callbacks.lua) always tears
    -- down and rebuilds G.OVERLAY_MENU from scratch, and defaults its
    -- entrance offset to {x=0,y=10} -- a real "slide up into resting
    -- position" animation meant for opening a menu once. Since we call
    -- this same function again on every pick/tab/page/search to refresh
    -- the picker in place, that slide was replaying on every single click.
    -- Passing offset={x=0,y=0} ourselves means there's nothing to ease
    -- from, so it just appears already in place -- no more bounce.
    G.FUNCS.overlay_menu({
        definition = AutoShop.create_add_target_uibox(),
        config = { offset = { x = 0, y = 0 } },
    })
end

function AutoShop.create_add_target_uibox()
    local ui = AutoShop.ADD_UI
    local col_nodes = {}

    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            { n = G.UIT.T, config = { text = "Add Target", scale = 0.5, colour = G.C.WHITE } },
        },
    }

    local tab_nodes = {}
    for _, category in ipairs(ADD_UI_CATEGORIES) do
        tab_nodes[#tab_nodes + 1] = UIBox_button({
            col = true,
            minw = 2,
            minh = 0.6,
            scale = 0.35,
            button = "autoshop_add_ui_tab",
            label = { category },
            colour = (ui.category == category) and HEX('00A000') or HEX('4F6367'),
            ref_table = { category = category },
        })
    end
    col_nodes[#col_nodes + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = tab_nodes }

    -- create_text_input is Balatro's own native text field (functions/
    -- UI_definitions.lua), backed by G.CONTROLLER.text_input_hook -- the
    -- same focus flag other well-behaved mods check before handling their
    -- own hotkeys (confirmed: ZokersModMenu's own menu-toggle key checks
    -- `not G.CONTROLLER.text_input_hook` before firing). A hand-rolled key
    -- capture here had no way to stop other mods from also reacting to
    -- every letter typed; routing through the real focus system does,
    -- for any mod that plays by the same rules. Typing writes straight
    -- into ui.search live; callback fires on Enter (see button_callbacks
    -- .lua's text_input_key, the 'RETURN' branch), which is when we
    -- actually re-filter and rebuild -- not on every keystroke, since
    -- rebuilding the whole overlay mid-type would tear down and recreate
    -- this very input, losing focus. extended_corpus = true is required
    -- for space and "-" to be typable at all (the default corpus is just
    -- letters and 1-9).
    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            create_text_input({
                w = 4,
                h = 0.6,
                text_scale = 0.35,
                max_length = 24,
                extended_corpus = true,
                prompt_text = "Search...",
                ref_table = ui,
                ref_value = "search",
                callback = function()
                    ui.page = 1
                    AutoShop.refresh_add_ui()
                end,
            }),
            UIBox_button({
                col = true,
                minw = 2.2,
                minh = 0.6,
                scale = 0.3,
                button = "autoshop_toggle_selected_only",
                label = { ui.selected_only and "Selected: ON" or "Selected: OFF" },
                colour = ui.selected_only and HEX('00A000') or HEX('4F6367'),
            }),
        },
    }

    local pool = filtered_pool()
    local total_pages = math.max(1, math.ceil(#pool / ADD_UI_PER_PAGE))
    ui.page = math.min(math.max(1, ui.page), total_pages)
    local start_index = (ui.page - 1) * ADD_UI_PER_PAGE + 1
    local end_index = math.min(start_index + ADD_UI_PER_PAGE - 1, #pool)

    if #pool == 0 then
        col_nodes[#col_nodes + 1] = {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.1 },
            nodes = {
                { n = G.UIT.T, config = { text = "No matches.", scale = 0.35, colour = G.C.WHITE } },
            },
        }
    end

    -- 5 items per grid row, built the same "UIBox_button as a chip" way as
    -- the Config tab's old target list used to, so a target already
    -- picked and one that isn't both read as the same kind of element,
    -- just a different colour. Which list (target_keys or
    -- target_editions) "already picked" checks against depends on the
    -- active category -- see target_list_for.
    local active_list = target_list_for(ui.category)
    local per_row = 5
    local grid_row
    for i = start_index, end_index do
        local item = pool[i]
        if (i - start_index) % per_row == 0 then
            grid_row = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {} }
            col_nodes[#col_nodes + 1] = grid_row
        end
        local already_added = index_in(active_list, item.key) ~= nil
        table.insert(grid_row.nodes, UIBox_button({
            col = true,
            minw = 2.2,
            minh = 0.7,
            scale = 0.28,
            button = "autoshop_add_ui_pick",
            label = { item.name or item.key },
            colour = already_added and HEX('00A000') or HEX('4F6367'),
            ref_table = { key = item.key },
        }))
    end

    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            { n = G.UIT.T, config = { text = "Page " .. ui.page .. "/" .. total_pages, scale = 0.35, colour = G.C.WHITE } },
        },
    }

    col_nodes[#col_nodes + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.15 },
        nodes = {
            UIBox_button({
                col = true,
                minw = 2,
                minh = 0.7,
                scale = 0.35,
                button = "autoshop_add_ui_page",
                label = { "< Prev" },
                colour = HEX('4F6367'),
                ref_table = { delta = -1 },
            }),
            UIBox_button({
                col = true,
                minw = 2,
                minh = 0.7,
                scale = 0.35,
                button = "autoshop_add_ui_page",
                label = { "Next >" },
                colour = HEX('4F6367'),
                ref_table = { delta = 1 },
            }),
            UIBox_button({
                col = true,
                minw = 2.5,
                minh = 0.7,
                scale = 0.35,
                button = "autoshop_add_ui_back",
                label = { "Back" },
                colour = HEX('B23030'),
            }),
        },
    }

    return {
        n = G.UIT.ROOT,
        config = { align = "cm", colour = G.C.CLEAR, minw = 6 },
        nodes = {
            {
                n = G.UIT.C,
                config = { align = "cm", padding = 0.3, r = 0.1, colour = G.C.BLACK, emboss = 0.05 },
                nodes = col_nodes,
            },
        },
    }
end

-- Exposed on AutoShop (not just the button handler below) so
-- AutoShop_keyhandler.lua's manage_targets_key hotkey can jump straight
-- here too, from anywhere in the game -- not just via the Config tab.
function AutoShop.open_add_ui()
    AutoShop.ADD_UI.category = AutoShop.ADD_UI.category or "Joker"
    AutoShop.ADD_UI.page = 1
    AutoShop.ADD_UI.search = ""
    AutoShop.refresh_add_ui()
end

G.FUNCS.autoshop_open_add_ui = function(e)
    AutoShop.open_add_ui()
end

G.FUNCS.autoshop_add_ui_tab = function(e)
    local category = e.config and e.config.ref_table and e.config.ref_table.category
    if category then
        AutoShop.ADD_UI.category = category
        AutoShop.ADD_UI.page = 1
    end
    AutoShop.refresh_add_ui()
end

G.FUNCS.autoshop_add_ui_page = function(e)
    local delta = e.config and e.config.ref_table and e.config.ref_table.delta or 0
    AutoShop.ADD_UI.page = (AutoShop.ADD_UI.page or 1) + delta
    AutoShop.refresh_add_ui()
end

G.FUNCS.autoshop_add_ui_pick = function(e)
    local key = e.config and e.config.ref_table and e.config.ref_table.key
    if key then
        local list = target_list_for(AutoShop.ADD_UI.category)
        local existing = index_in(list, key)
        if existing then
            table.remove(list, existing)
        else
            list[#list + 1] = key
        end
        AutoShop.save_settings()
    end
    AutoShop.refresh_add_ui()
end

G.FUNCS.autoshop_add_ui_back = function(e)
    AutoShop.refresh_config_tab(e)
end

G.FUNCS.autoshop_toggle_selected_only = function(e)
    AutoShop.ADD_UI.selected_only = not AutoShop.ADD_UI.selected_only
    AutoShop.ADD_UI.page = 1
    AutoShop.refresh_add_ui()
end
