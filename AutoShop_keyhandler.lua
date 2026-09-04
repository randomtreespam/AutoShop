-- Called once per key press via the lovely.toml patch into
-- engine/controller.lua (fires on keydown, not held-repeat, so this toggles
-- a search on/off rather than needing the key held).

function AutoShop.key_press_update(key)
    -- The Config tab's hotkey buttons (Reroll Hotkey, Target Menu Hotkey)
    -- put us in capture mode, naming which AutoShop.SETTINGS field the
    -- very next key pressed should land in (see hotkey_row() in
    -- AutoShop_UI.lua) instead of being interpreted normally -- so
    -- pressing the *old* hotkey while capturing doesn't also trigger it.
    if AutoShop.AWAITING_KEYBIND_FOR then
        local setting_key = AutoShop.AWAITING_KEYBIND_FOR
        AutoShop.AWAITING_KEYBIND_FOR = nil
        if key ~= "escape" then
            AutoShop.SETTINGS[setting_key] = key
            AutoShop.save_settings()
        end
        if AutoShop.refresh_config_tab then
            AutoShop.refresh_config_tab()
        end
        return
    end

    -- The "Max Cost"/"Min Cash" buttons put us in digit-capture mode (same
    -- idea ZokersModMenu uses for its own numeric settings dialogs: capture
    -- digits into a buffer, Backspace to edit, Enter to confirm, Escape to
    -- cancel). AutoShop.EDITING_NUMERIC_FOR names which AutoShop.SETTINGS
    -- field the buffer applies to (see numeric_row/autoshop_edit_numeric in
    -- AutoShop_UI.lua), the same "capture mode names its own target field"
    -- pattern AWAITING_KEYBIND_FOR uses above. Everything else is swallowed
    -- for the duration (the trailing `return` below) so e.g. F6 can't
    -- toggle a search while you're mid-way through typing a number.
    if AutoShop.EDITING_NUMERIC_FOR then
        local setting_key = AutoShop.EDITING_NUMERIC_FOR
        if key == "return" or key == "kpenter" then
            local n = tonumber(AutoShop.NUMERIC_BUFFER)
            AutoShop.SETTINGS[setting_key] = (n and n > 0) and n or nil
            AutoShop.EDITING_NUMERIC_FOR = nil
            AutoShop.save_settings()
            AutoShop.refresh_config_tab()
        elseif key == "escape" then
            AutoShop.EDITING_NUMERIC_FOR = nil
            AutoShop.refresh_config_tab()
        elseif key == "backspace" then
            AutoShop.NUMERIC_BUFFER = AutoShop.NUMERIC_BUFFER:sub(1, -2)
            AutoShop.refresh_config_tab()
        elseif #key == 1 and tonumber(key) then
            AutoShop.NUMERIC_BUFFER = AutoShop.NUMERIC_BUFFER .. key
            AutoShop.refresh_config_tab()
        end
        return
    end

    -- The Add Target picker's search field is Balatro's own native text
    -- input now (create_text_input, see AutoShop_UI.lua), not our own
    -- key capture -- typing there is handled entirely by the engine via
    -- G.CONTROLLER.text_input_hook. Respect that same flag here too: while
    -- any native text field (ours or anyone else's) is focused, don't let
    -- a letter that happens to match search_key or manage_targets_key
    -- also fire.
    if G.CONTROLLER and G.CONTROLLER.text_input_hook then
        return
    end

    if key == AutoShop.SETTINGS.search_key then
        AutoShop.toggle_search()
    elseif key == AutoShop.SETTINGS.manage_targets_key then
        AutoShop.open_add_ui()
    end
end
