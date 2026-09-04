-- ============================================================
-- AUTO SHOP: search engine
--
-- Unlike Brainstorm's ante-1 tag/pack/soul search (which can predict the
-- outcome of a seed with pure math before ever starting a run), shop
-- contents depend on the live RNG state built up over the whole run so far.
-- There's no shortcut: we have to actually trigger reroll after reroll and
-- look at what comes back. What we CAN do is drive that loop silently, one
-- reroll at a time every frame the game is ready for another, instead of
-- making the player click a button hundreds of times.
--
-- A few lines below are marked "VERIFY" -- these are the spots most likely
-- to need a tweak once checked against your local game files (see the
-- calibration section in README.md). Nothing here will crash the game if
-- one of these guesses is wrong; the search will just fail to find matches
-- until it's corrected.
-- ============================================================

AutoShop.SEARCH = { running = false, attempts = 0, pending_since = nil, pending_shop_id = nil }

-- Keep a handle to the vanilla button handler so we can still call it.
local _vanilla_reroll_shop = G.FUNCS.reroll_shop

-- VERIFY: card identity. Vanilla Balatro cards generally expose their
-- center's key at card.config.center.key (this is the standard field used
-- across most joker/consumable-editing mods). If matches never trigger,
-- print(card.config.center.key) here to confirm the field name in your
-- version.
local function card_key(card)
    return card and card.config and card.config.center and card.config.center.key
end

-- Normalizes AutoShop.SETTINGS.target_keys to a plain list, accepting a
-- bare string too (so an old single target_key-style config doesn't hard
-- error, it just behaves as a one-item list). Covers Jokers, Tarot,
-- Planet, and Spectral, all matched by center key.
local function target_keys()
    local t = AutoShop.SETTINGS.target_keys
    if type(t) == "table" then
        return t
    end
    if type(t) == "string" and t ~= "" then
        return { t }
    end
    return {}
end

-- Normalizes AutoShop.SETTINGS.target_editions the same way. Editions
-- (Foil/Holographic/Polychrome/Negative) are stored as flags directly on
-- a card (card.edition.negative etc., functions/common_events.lua's
-- ease_dollars-adjacent card-creation code), layered on top of whatever
-- the card's own center identity is -- a Negative Blueprint is still
-- center key "j_blueprint" with card.edition.negative also true. That
-- means an edition can never be matched by center key: it needs its own
-- list and its own check, against every card's .edition table instead of
-- .config.center.key.
local function target_editions()
    local t = AutoShop.SETTINGS.target_editions
    if type(t) == "table" then
        return t
    end
    return {}
end

-- Human-readable label for an edition flag name, used both in
-- notify() messages and (via AutoShop.EDITION_LABELS/EDITION_ORDER) by
-- AutoShop_UI.lua's Edition tab. "holo" is spelled out as
-- "Holographic" to match the card's actual in-game name.
AutoShop.EDITION_ORDER = { "foil", "holo", "polychrome", "negative" }
AutoShop.EDITION_LABELS = {
    foil = "Foil",
    holo = "Holographic",
    polychrome = "Polychrome",
    negative = "Negative",
}

-- Returns a matched label (truthy) if the shop currently contains ANY of
-- the configured target_keys or target_editions, or nil. target_keys
-- matches return the raw center key (unchanged); target_editions matches
-- return a friendly "<Label> Edition" string instead, since there's no
-- single card identity to report -- the match could be on any card in the
-- shop that happens to carry that edition.
function AutoShop.shop_has_target()
    if not G.shop_jokers then
        return nil
    end
    local keys = target_keys()
    local editions = target_editions()
    if #keys == 0 and #editions == 0 then
        return nil
    end
    for _, card in ipairs(G.shop_jokers.cards) do
        local key = card_key(card)
        for _, target in ipairs(keys) do
            if key == target then
                return key
            end
        end
        if card.edition then
            for _, edition in ipairs(editions) do
                if card.edition[edition] then
                    return (AutoShop.EDITION_LABELS[edition] or edition) .. " Edition"
                end
            end
        end
    end
    return nil
end

-- Identity fingerprint of the current shop, used to detect that a reroll we
-- dispatched has actually landed. We can't trust a fixed delay or a lock
-- flag for this: other installed mods (Brainstorm-Rerolled, Steamodded,
-- etc.) patch shop/reroll behavior too and can change or remove whatever
-- timing vanilla Balatro normally uses, so "wait N seconds" or "wait for
-- G.CONTROLLER.locks.shop_reroll" guesses can be wrong on any given modlist.
-- What can't lie is the *card objects themselves*: create_card_for_shop
-- always builds brand new tables, so comparing raw table identity (via
-- tostring, which embeds the table's address) catches a real reroll even in
-- the rare case the new cards happen to have the exact same keys as before.
local function shop_identity()
    if not G.shop_jokers then
        return "no-shop"
    end
    local ids = {}
    for i, card in ipairs(G.shop_jokers.cards) do
        ids[i] = tostring(card)
    end
    return table.concat(ids, "|")
end

-- Small on-screen/console feedback. Kept deliberately simple (just chat log
-- + console print) rather than reimplementing Brainstorm's custom
-- attention_text popup, so this has no dependency on exact UI internals.
local function notify(msg)
    print("[Auto Shop] " .. msg)
    if G.HUD and G.HUD.states and G.HUD.states.visible then
        -- best-effort in-run toast; safe no-op if the field doesn't exist
    end
end

-- skip_animations support: G.SETTINGS.GAMESPEED (a real, vanilla setting,
-- normally adjusted 1-4x from the options menu) scales both card animation
-- updates and the game's own internal event timers each frame (see
-- game.lua: SPEEDFACTOR derives from it, and TIMERS.TOTAL advances by
-- dt*SPEEDFACTOR) -- this is the exact same trick ZokersModMenu uses to
-- blast through its own setup animations. Boosting it for the duration of
-- a search makes shop-reroll card animations resolve close to instantly;
-- restoring it is just as important; forgetting to would leave the whole
-- game running at that speed after the search ends.
local function boost_gamespeed()
    if AutoShop.SETTINGS.skip_animations and not AutoShop.SEARCH._saved_gamespeed then
        AutoShop.SEARCH._saved_gamespeed = G.SETTINGS.GAMESPEED
        G.SETTINGS.GAMESPEED = 1000
    end
end

local function restore_gamespeed()
    if AutoShop.SEARCH._saved_gamespeed then
        G.SETTINGS.GAMESPEED = AutoShop.SEARCH._saved_gamespeed
        AutoShop.SEARCH._saved_gamespeed = nil
    end
end

-- Suppresses the floating "-$cost" popup for the *entire* duration a
-- search runs, not just around each reroll_shop() call. ease_dollars
-- (functions/common_events.lua) is what pops it, called synchronously
-- from reroll_shop() for the cost itself -- but reroll_shop() also queues
-- a delayed (~0.3s+) event that recalculates every owned joker with a
-- {reroll_shop = true} context, and any joker/voucher that reacts to
-- rerolls (money, its own popup, etc.) fires from *that*, well after any
-- narrow per-call suppression window would have already restored things.
-- Keeping it suppressed for the whole search sidesteps needing to predict
-- that delay at all. Doesn't touch G.GAME.dollars -- only the popup.
local function suppress_attention_text()
    if not AutoShop.SEARCH._saved_attention_text then
        AutoShop.SEARCH._saved_attention_text = attention_text
        attention_text = function() end
    end
end

local function restore_attention_text()
    if AutoShop.SEARCH._saved_attention_text then
        attention_text = AutoShop.SEARCH._saved_attention_text
        AutoShop.SEARCH._saved_attention_text = nil
    end
end

-- Marks the search as stopped, but doesn't restore gamespeed/attention_text
-- immediately -- reroll_shop's own ~0.3s delayed event (from the very last
-- reroll we dispatched) may not have fired yet at the moment we decide to
-- stop, since search_step() only waits for the card swap itself, not that
-- extra delay. Restoring right away would un-suppress the popup right
-- before that delayed event's joker recalculation gets a chance to react
-- to the reroll -- which is exactly the leak that showed up when running
-- out of money (a case that, unlike "found", always stops immediately
-- after a real dispatch rather than after several idle waiting frames).
-- cleanup_step() below releases the suppression once enough real frames
-- have passed to be confident that delayed event has landed.
local function begin_stopping()
    AutoShop.SEARCH.running = false
    AutoShop.SEARCH._pending_restore = 90
end

-- Unconditional per-frame cleanup, run regardless of whether a search is
-- currently active (see the Game:update wrapper at the bottom of this
-- file) -- _search_step_body() itself returns immediately once
-- SEARCH.running is false, so this can't live there.
function AutoShop.cleanup_step()
    if not AutoShop.SEARCH._pending_restore then
        return
    end
    AutoShop.SEARCH._pending_restore = AutoShop.SEARCH._pending_restore - 1
    if AutoShop.SEARCH._pending_restore <= 0 then
        AutoShop.SEARCH._pending_restore = nil
        restore_gamespeed()
        restore_attention_text()
    end
end

-- Wrap the real reroll button so a *manual* click also gets checked and
-- reported, independent of the auto-search loop below.
G.FUNCS.reroll_shop = function(e)
    _vanilla_reroll_shop(e)
    local found = AutoShop.shop_has_target()
    if found then
        notify("Found " .. found .. "!")
    end
end

-- Called once per frame while a search is active (see the Game:update
-- wrapper at the bottom of this file). Dispatches at most ONE silent reroll
-- at a time, and never checks or re-rolls again until that reroll has
-- provably landed (see shop_identity() above).
--
-- reroll_shop() doesn't swap G.shop_jokers.cards synchronously in vanilla
-- Balatro -- it queues the actual card swap as an event that lands some
-- unknown number of frames later. Earlier versions of this file guessed at
-- that delay (a fixed budget-per-frame, then a wait on
-- G.CONTROLLER.locks.shop_reroll); both guesses turned out wrong on a
-- modded install (Steamodded, Brainstorm-Rerolled, etc. all touch shop/
-- reroll code), which let search_step() fire hundreds of reroll_shop()
-- calls per second while only ever reading one, ancient snapshot of the
-- shop -- so a match got buried under a huge backlog before it was ever
-- observed, and F6 stopping *new* dispatches didn't stop the backlog's
-- worth of shop-swaps still working through the queue.
--
-- Waiting for the shop's actual identity to change removes the guesswork:
-- it's true regardless of how any installed mod times the swap.
-- Wrapped in pcall below: something in this modded environment is causing
-- search_step() to behave as if it's erroring every call (attempts race
-- ahead with zero of the debug/stuck breadcrumbs below ever printing, which
-- shouldn't be possible unless an exception is aborting the function body
-- early and something upstream (Steamodded etc. commonly wrap the main
-- loop in pcall) is silently swallowing it). Surfacing that error is the
-- fastest way to find out what's actually happening instead of guessing.
function AutoShop._search_step_body()
    if not AutoShop.SEARCH.running then
        return
    end

    if AutoShop.SEARCH.pending_shop_id then
        if shop_identity() == AutoShop.SEARCH.pending_shop_id then
            -- The reroll we fired hasn't landed yet. Give it a while, but
            -- don't wait forever -- if nothing ever changes (e.g. some mod
            -- silently blocked the reroll), unstick ourselves rather than
            -- hang with the search flag stuck "running" forever.
            AutoShop.SEARCH.pending_since = (AutoShop.SEARCH.pending_since or 0) + 1
            if AutoShop.SEARCH.pending_since < 240 then
                return
            end
            notify("Reroll seems stuck (shop hasn't changed in 240 frames) -- retrying.")
        elseif AutoShop.SETTINGS.debug and AutoShop.SEARCH.attempts <= 3 then
            -- Debug breadcrumb for the first few rerolls of a search only,
            -- so the lovely log shows how many frames a real reroll takes
            -- to land on this modlist without spamming every attempt.
            notify("debug: reroll #" .. AutoShop.SEARCH.attempts .. " landed after "
                .. tostring(AutoShop.SEARCH.pending_since) .. " frame(s).")
        end
        AutoShop.SEARCH.pending_shop_id = nil
        AutoShop.SEARCH.pending_since = nil
    end

    local settings = AutoShop.SETTINGS

    -- Always reroll at least once: skip the target check entirely on the
    -- very first pass (attempts == 0) so pressing the hotkey never just
    -- reports the shop's pre-existing state as an instant "find" -- it
    -- falls straight through to dispatching the first reroll below.
    local found = AutoShop.SEARCH.attempts > 0 and AutoShop.shop_has_target()
    if found then
        begin_stopping()
        notify("Found " .. found .. " after "
            .. AutoShop.SEARCH.attempts .. " rerolls.")
        return
    end

    if AutoShop.SEARCH.attempts >= (settings.max_total_attempts or 3000) then
        begin_stopping()
        notify("Gave up after " .. AutoShop.SEARCH.attempts
            .. " rerolls -- check your targets are correct and actually rollable.")
        return
    end

    -- VERIFY: the live reroll cost. G.GAME.current_round.reroll_cost is
    -- the commonly-referenced field in other shop-focused mods; confirm it
    -- matches what you see in your game.lua.
    local cost = (G.GAME.current_round and G.GAME.current_round.reroll_cost) or 5

    if settings.max_reroll_cost and settings.max_reroll_cost > 0 and cost > settings.max_reroll_cost then
        begin_stopping()
        notify("Stopped: reroll cost ($" .. cost .. ") exceeds your limit ($"
            .. settings.max_reroll_cost .. ").")
        return
    end

    -- Stop *before* paying if doing so would drop you below the reserve
    -- the player asked to keep -- distinct from the "can't afford it at
    -- all" check below, which only fires once dollars would go negative.
    if settings.min_cash and settings.min_cash > 0 and (G.GAME.dollars or 0) - cost < settings.min_cash then
        begin_stopping()
        notify("Stopped: rerolling would drop your cash below your $" .. settings.min_cash .. " minimum.")
        return
    end

    -- Every reroll spends real money and stops the search the moment you
    -- can't afford the next one -- the same consequence clicking reroll by
    -- hand would have. reroll_shop() itself (called below) is what
    -- actually deducts G.GAME.dollars and pops the floating "-$cost"
    -- indicator (ease_dollars, functions/common_events.lua); this is just
    -- the check that stops us from calling it when we can't pay.
    if (G.GAME.dollars or 0) < cost then
        begin_stopping()
        notify("Ran out of money while searching (needed $" .. cost .. ").")
        return
    end

    AutoShop.SEARCH.attempts = AutoShop.SEARCH.attempts + 1
    AutoShop.SEARCH.pending_shop_id = shop_identity()
    AutoShop.SEARCH.pending_since = 0

    -- VERIFY: reroll_shop's expected argument. In the button-callback
    -- system this is normally the UI element that was clicked; most
    -- mods that call it programmatically pass an empty table and it
    -- works fine because the function only reads e.config in cost
    -- calculations it does itself. If this errors in your console,
    -- open functions/button_callbacks.lua's reroll_shop definition and
    -- adjust what's passed here.
    _vanilla_reroll_shop({ config = {} })
end

local _search_step_error_reported = false
function AutoShop.search_step()
    local ok, err = pcall(AutoShop._search_step_body)
    if not ok then
        begin_stopping()
        if not _search_step_error_reported then
            _search_step_error_reported = true
            notify("ERROR in search_step, stopped: " .. tostring(err))
        end
    end
end

function AutoShop.start_search()
    local keys = target_keys()
    local editions = target_editions()
    if #keys == 0 and #editions == 0 then
        notify("No targets configured -- add some from Mods -> Auto Shop -> Manage Targets.")
        return
    end
    if not G.shop_jokers then
        notify("Open the shop before starting a search.")
        return
    end
    AutoShop.SEARCH.running = true
    AutoShop.SEARCH.attempts = 0
    AutoShop.SEARCH.pending_shop_id = nil
    AutoShop.SEARCH.pending_since = nil
    -- If this search is starting again within the previous one's restore
    -- buffer (see begin_stopping/cleanup_step), cancel that countdown --
    -- otherwise it would fire mid-way through *this* search and wrongly
    -- undo the suppression/gamespeed boost we're about to (re)establish.
    AutoShop.SEARCH._pending_restore = nil
    -- The reroll loop rides on Game:update; if a search is started while
    -- something has the game paused (e.g. the Mods menu was still open),
    -- unpause so it actually runs instead of silently sitting idle.
    G.SETTINGS.paused = false
    boost_gamespeed()
    suppress_attention_text()

    local labels = {}
    for _, key in ipairs(keys) do
        labels[#labels + 1] = key
    end
    for _, edition in ipairs(editions) do
        labels[#labels + 1] = (AutoShop.EDITION_LABELS[edition] or edition) .. " Edition"
    end
    notify("Searching for " .. table.concat(labels, ", ") .. "...")
end

function AutoShop.stop_search()
    if AutoShop.SEARCH.running then
        notify("Search stopped manually after " .. AutoShop.SEARCH.attempts .. " rerolls.")
    end
    begin_stopping()
end

function AutoShop.toggle_search()
    if AutoShop.SEARCH.running then
        AutoShop.stop_search()
    else
        AutoShop.start_search()
    end
end

-- Drive search_step() once per game frame by wrapping Game:update, the same
-- top-level per-frame entry point LÖVE calls on the global Game object.
-- This is plain Lua function-wrapping (not a lovely pattern patch), so it
-- doesn't depend on matching an exact literal string in game.lua.
local _game_update = Game.update
function Game:update(dt)
    _game_update(self, dt)
    AutoShop.search_step()
    AutoShop.cleanup_step()
end
