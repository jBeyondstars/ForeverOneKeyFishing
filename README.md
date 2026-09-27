# Forever OneKey Fishing

A lightweight World of Warcraft addon for the Forever client: use the same key to cast Fishing and interact with the bobber when a fish bites. An optional herbalism mode reuses that key to interact with nearby gathering nodes.

Every cast and interaction requires a physical key press. Watch the bobber or listen for the splash before retrieving your catch.

## Features

- One configurable key for casting and retrieving.
- Keyboard shortcuts with modifiers, mouse buttons 3 and above, and mouse wheel support.
- Manual recast preparation when the bobber cannot be selected.
- Optional automatic preparation of a recast when no interaction target is detected.
- Herbalism mode using the game's native interaction action.
- Saved preferences and restoration of displaced key bindings.
- Temporary interaction settings, configurable detection range, and diagnostic commands.
- No external addon dependencies.

## Compatibility

The addon targets the Forever client and declares interface version `16001`. The documented development client is `1.60.1.69913`; compatibility with other WoW clients is unverified.

Fishing is resolved from the localized spellbook, including French **Pêche**. Current in-game messages are in French. Casting and bobber interaction have been confirmed on Forever; secure recasting and herbalism gathering still need in-game verification.

## Installation

1. Download the repository ZIP from GitHub and extract it.
2. Rename the extracted addon folder to `ForeverOneKeyFishing`.
3. Place it in your client's `Interface/AddOns` directory so the layout is:

   ```text
   Interface/
   └── AddOns/
       └── ForeverOneKeyFishing/
           ├── ForeverOneKeyFishing.toc
           └── ForeverOneKeyFishing.lua
   ```

4. Start or restart the game, then enable **Forever OneKey Fishing** in the AddOns list.

The repository also includes `BudgetFishing.toc` for installations using the folder name `BudgetFishing`. Use either folder name and keep its matching `.toc` file alongside the Lua file. Install only one copy, and avoid an extra nested folder from the ZIP.

## Quick start

1. Learn Fishing and meet your client's fishing requirements.
2. Outside combat, enter `/fkf on`, then `/fkf bind`.
3. Press the key or supported mouse input you want to use. Press Escape to cancel. If the key already has an action, the addon announces the replacement and saves that action for restoration.
4. Stand near fishable water and press the configured key to cast.
5. When the bobber splashes, press the same key to interact with it.
6. Press the key again when ready for your next cast.

Looting follows your existing auto-loot preferences; the addon does not change them.

### Recasting an undetected bobber

Enter `/fkf recast`, then press your configured key. That press stops the current Fishing channel and casts again.

To enable automatic recast preparation, enter `/fkf autorecast on`. If no Soft Interact target is detected two seconds after casting, the addon prepares the key for a recast and prints a message. You must still press the key to cast. A target detected later returns the key to retrieval while the channel remains active.

This option is off by default. Any detected interaction target can prevent automatic recast preparation, even if it is not your bobber.

### Herbalism

Enter `/fkf herbs on` to switch your configured key to native interaction. If you have not selected a key yet, use `/fkf bind`. Approach a gatherable herb and press the key.

This mode does not require Fishing. It can interact with other objects or NPCs, and gathering still depends on your position, skill, and the client's selected interaction target.

Use `/fkf herbs off` to disable herbalism and restore the previous key action and interaction settings. Use `/fkf on` to switch back to fishing.

## Commands

| Command | Effect |
| --- | --- |
| `/fkf` | Show status, current mode, configured key, and command help. |
| `/fkf bind` | Capture a key, mouse button 3+, or wheel direction. |
| `/fkf unbind` | Remove the configured key and restore its previous action if still owned by the addon. |
| `/fkf on` | Enable fishing mode with the saved key. |
| `/fkf off` | Disable the addon, restore the displaced binding, and reset managed interaction settings to client defaults. Keep the selected key and range. |
| `/fkf reset` | Alias for `/fkf off`. |
| `/fkf recast` | Prepare a forced recast for the next physical key press. |
| `/fkf autorecast on\|off` | Enable or disable automatic recast preparation. Default: off. |
| `/fkf herbs on\|off` | Enable or disable herbalism mode. |
| `/fkf range 50` | Set the requested interaction reporting range, from 10 to 100. Default: 50. |
| `/fkf debug` | Toggle diagnostic event logging. |
| `/fkf diag` | Show spell, channel, effective binding, interaction target information, and interaction settings. |
| `/fkf hud on\|off` | Save the HUD preference. The HUD currently remains hidden because no reliable bite signal is available. |

Binding, mode, range, and recast configuration must be changed outside combat. Protected changes pending during combat are deferred until combat ends.

## Settings and restoration

Preferences are stored in `ForeverOneKeyFishingDB` through WoW's SavedVariables system.

In fishing mode, the addon applies its interaction settings during a Fishing channel and restores the previous values when the channel ends. Herbalism keeps those settings active throughout the gathering session and restores them when you exit the mode or unbind. Backups persist across UI reloads.

**`/fkf off` and `/fkf reset` reset the addon-managed interaction settings to client defaults.** They do not preserve custom values for those settings. To release the key and restore the saved interaction values, use `/fkf unbind`; to end herbalism while keeping the selected key, use `/fkf herbs off`.

Only supported interaction CVars are changed. The addon does not move the camera or cursor.

## Known limitations and troubleshooting

- **No bite alarm:** an interaction target does not prove that a fish has bitten. The HUD remains hidden, even when enabled.
- **Distant bobbers may not be detected:** `/fkf range 70` can request a larger reporting range, but cannot bypass client or server distance, visibility, or selection restrictions. Use `/fkf diag` to inspect effective values.
- **Unexpected interaction target:** native interaction may select another object or NPC. The addon cannot guarantee that the selected target is your bobber or a herb.
- **Key does not behave as expected:** disable other fishing addons while troubleshooting, configure the key outside combat, and inspect `/fkf diag`.
- **Fishing spell not found:** learn Fishing before configuring a key in fishing mode. Herbalism mode can be configured independently.

## Development

The addon consists of one Lua file and two alternative installation manifests. Developer notes are in [Obsidian/Forever OneKey Fishing.md](Obsidian/Forever%20OneKey%20Fishing.md).

The existing regression suite uses Python and Lupa's Lua 5.1 runtime:

```sh
python -m pip install lupa
python tests/check.py
```

Lupa is a development dependency only. Tests exercise mocked WoW APIs for bindings, combat deferral, setting restoration, recast transitions, delayed target detection, HUD suppression, and herbalism mode. They do not verify protected actions or actual target selection in the game.
