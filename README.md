# Auto Shop

A Balatro QoL mod that rerolls the shop for you until any of a list of
cards you pick shows up, in the same fast/keybind-driven spirit as
Brainstorm's seed rerolling -- just aimed at the shop instead of the run
seed.

## Requirements

- [lovely-injector](https://github.com/ethangreen-dev/lovely-injector)
  (same requirement Brainstorm has)

## Install

1. Install lovely-injector and Steamodded (Auto Shop's Config tab and
   native text input both require Steamodded).
2. Copy this whole `AutoShop` folder into your Balatro `Mods` directory
   (`%AppData%/Balatro/Mods` on Windows).
3. Launch Balatro. `AutoShop_config.lua`'s `target_keys` is only the
   first-launch default -- everything is manageable in-game from here on
   (see Use below).

## Use

- In-game, go to **Mods -> Auto Shop -> Config**. From there you can:
  - Set the Reroll Hotkey (F6 by default) and the Target Menu Hotkey (F7
    by default, jumps straight to Manage Targets from anywhere) -- click
    either, then press any key.
  - Toggle Skip Animations, set a Max Cost limit, and set a Min Cash
    reserve (stops the search if paying for the next reroll would drop
    your dollars below this amount).
  - Click "Manage Targets" to add/remove targets -- one tab per type
    (Joker/Tarot/Planet/Spectral/Edition), a search bar, and a
    "Selected Only" filter to review what's already picked.
- Open a shop and press your Reroll Hotkey to start silently rerolling
  until any target appears, or press it again to stop early.
- Every change made in the Config tab is saved immediately to
  `AutoShop_settings.jkr` in Balatro's own save folder and persists
  across relaunches -- editing `AutoShop_config.lua` afterward has no
  effect until that save file is deleted.
- Console output (visible in lovely's log) reports when the search
  starts, which target it found, or that it gave up.

## Finding a card's key

You shouldn't need this if you're picking targets from the in-game menu --
it's only relevant if hand-editing `AutoShop_config.lua`'s `target_keys`
before ever touching the Config tab. It needs the game's internal ids, not
display names -- e.g. `j_blueprint` for the Blueprint joker, `j_joker` for
the base Joker, `c_hermit` for The Hermit tarot card, `c_temperance` for
Temperance. Jokers use a `j_` prefix; Tarot/Planet/Spectral cards use `c_`
-- all these kinds can show up in the same shop row and `target_keys` can
mix them freely, e.g. `{ "j_blueprint", "c_hermit", "c_temperance" }`.
These live in your game files under the item definition tables (search
for the card's display name in the localization files to find its key
nearby). If you're not sure, start Balatro with the debug console and
print a card's `card.config.center.key` while hovering it in your
collection.

## Editions as targets

Editions (Foil/Holographic/Polychrome/Negative, e.g. "roll until a
Negative shows up") live in a *separate* setting, `target_editions`
(values `"foil"`, `"holo"`, `"polychrome"`, `"negative"`), not
`target_keys` -- an edition is a modifier layered on top of a card's own
identity (a Negative Blueprint is still center key `j_blueprint`, just
with `card.edition.negative` also true), so it's matched against every
shop card's edition flags separately rather than by center key. The
Edition tab in Manage Targets edits this list for you; no manual key
needed.

## Why this can't "predict" the shop like Brainstorm predicts seeds

Brainstorm's ante-1 search works because a seed alone determines the very
first tag/pack/soul before you've made a single decision -- so it can
simulate a candidate seed mathematically and only commit to the ones that
match. Shop contents depend on the RNG state built up by everything you've
done in the run so far, so there's no equivalent shortcut: Auto Shop
actually triggers reroll after reroll and checks the real result each time,
rather than pre-solving anything. It fires at most one reroll at a time and
waits for the shop to actually change before firing the next (see the note
in `AutoShop_reroll.lua` above `search_step()`), so its speed follows
whatever your modlist's real reroll timing is rather than a fixed guess.

## Verified against the actual game files

The three "VERIFY" spots from the original scaffold have been checked
against `Balatro.exe`'s own embedded `card.lua` / `engine/controller.lua` /
`functions/button_callbacks.lua` (extract them yourself with 7-Zip -- the
.love archive is appended to the exe) and are all correct as written:

- `card.config.center.key` is exactly the field `card.lua` itself uses to
  look up a card's display name, so `card_key()` is right.
- `G.GAME.current_round.reroll_cost` is the real field `reroll_shop`
  deducts from `G.GAME.dollars` (via `ease_dollars`).
- `reroll_shop(e)`'s argument `e` is never read anywhere in the function
  body, so the empty `{config = {}}` table is fine.

The one thing that *wasn't* right: vanilla `reroll_shop` doesn't swap
`G.shop_jokers.cards` synchronously -- it queues the actual card swap as an
event that lands some number of frames later. The original loop fired
several reroll calls per frame regardless, which piled up a huge backlog:
the search would roll right past a match because `shop_has_target()` was
reading stale, not-yet-applied shop state, and toggling off with F6 looked
broken because the backlog kept firing rerolls long after `SEARCH.running`
was set to false.

A first attempt at fixing this waited on `G.CONTROLLER.locks.shop_reroll`
(vanilla's own "reroll animation in flight" flag) between rerolls. That
guess turned out wrong on a real modded install -- other installed mods
(Steamodded, Brainstorm-Rerolled, etc.) patch shop/reroll code too and
changed the actual timing, so the lock wasn't gating anything in practice
(a test run fired ~8,700 rerolls in under a minute). `search_step()` now
instead waits for the shop's card *identity* to actually change (comparing
the live card objects, not just their keys -- see `shop_identity()`) before
allowing the next reroll, which is true regardless of what any given mod
does to reroll timing. Set `debug = true` in the config (on by default) to
get a couple of log lines per search showing how many frames a reroll
actually took to land on your modlist.

Happy to help debug anything else once you've got it loaded and can share
what the console prints.
