-- This is Steamodded's entry point for Auto Shop (see manifest.json's
-- "main_file"), loaded by Steamodded's own preflight mod loader -- NOT by
-- our own initAutoShop() in AutoShop.lua, which lovely.toml triggers
-- separately, much later (tied to self:load_profile(), well after
-- Steamodded finishes booting). The two loaders run independently; this
-- file's only job is to give the "Auto Shop" entry in the Mods menu a
-- Config tab.
--
-- SMODS.current_mod is set to our own registered mod object right before
-- Steamodded requires this file (see Steamodded's src/preflight/loader.lua
-- around "SMODS.current_mod = mod"), so this is the correct place to
-- attach config_tab. The function we assign is only actually CALLED much
-- later, when a player opens the tab in-game -- by then AutoShop.lua's
-- own loader has long since run and AutoShop.create_config_tab_uibox
-- exists, even though it doesn't exist yet at the moment this file itself
-- executes.
if SMODS and SMODS.current_mod then
    SMODS.current_mod.config_tab = function()
        if AutoShop and AutoShop.create_config_tab_uibox then
            return AutoShop.create_config_tab_uibox()
        end
        -- AutoShop hasn't finished loading yet (shouldn't normally happen
        -- since the Mods menu is only reachable after full boot) -- render
        -- an empty tab instead of erroring.
        return { n = G.UIT.ROOT, config = { align = "cm", colour = G.C.CLEAR }, nodes = {} }
    end
end
