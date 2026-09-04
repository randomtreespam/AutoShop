# Auto Shop

A Balatro QoL mod that rerolls the shop for you until any of a list of
cards you pick shows up

## Requirements

- [lovely-injector](https://github.com/ethangreen-dev/lovely-injector)

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

Huge thanks to chariot (https://github.com/Aurelius7309/chariot) for being the original version of this mod and ZokersModMenu (https://github.com/1Zoker/ZokersModMenu) for the menu design
