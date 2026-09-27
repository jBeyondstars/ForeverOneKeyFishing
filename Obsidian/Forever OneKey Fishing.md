# Forever OneKey Fishing

## GitHub documentation

The root [README](../README.md) is the English public entry point for the project. It covers supported installation folder names, fishing setup, herbalism, every slash command, settings restoration, current limitations, and the Python/Lupa regression test workflow. Compatibility statements distinguish documented Forever observations from features that still require in-game verification. Keep the README aligned with user-visible behavior when commands or defaults change.

## Repository organization

The initial Git history separates the addon implementation and installation manifests, the regression test suite, and the public README with these developer notes into three commits. The existing `python tests/check.py` suite passed under Lua 5.1 on September 27, 2026 before committing. This validation uses mocked APIs; the in-game verification limitations below still apply.

## Installation

Installed in `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\BudgetFishing`.
Client WowB.exe reports 1.60.1.69913. Interface 16001 matches the installed Angleur_Camelot and BleakfibersQuestTracker-Forever addons. BudgetFishing.toc loads the Lua file from the current folder. ForeverOneKeyFishing.toc supports installation under that folder name; do not install both copies.

## Commands

- `/fkf bind`: capture a keyboard key, modifiers, mouse buttons 3+, or wheel. Escape cancels. Existing bindings are announced and saved for restoration.
- `/fkf unbind`: release the fishing key and restore its displaced action if it still belongs to this addon.
- `/fkf recast`: arm a forced recast on the configured key. The next real key press runs a secure macro that stops the Fishing channel and casts the localized Fishing spell. No cast occurs when the command or any event executes. The old channel's stop event does not disarm the pending recast; the next channel start resumes normal interaction behavior. This is a manual override, not automatic bobber detection.
- `/fkf autorecast on|off`: enable or disable automatically preparing the next key press for recast when no Soft Interact target is detected two seconds after channel start. Off by default; persisted in ForeverOneKeyFishingDB.autorecast. The timer never casts or clicks. A late soft target returns the key to retrieval while the channel is active. Any detected soft target conservatively suppresses automatic recast; the API does not prove that it is the player's bobber. Manual recast remains available when another object is selected.
- `/fkf off` (alias `/fkf reset`): disable the addon, clear overrides, restore the displaced key binding, and reset only the addon-managed interaction CVars to client-reported defaults. Keep the selected fishing key and range for reactivation. Missing default APIs or rejected writes are reported.
- `/fkf on`: select fishing mode and restore the saved fishing binding. If leaving herbalism mode, restore its previous interaction settings first. Fishing settings apply only during a fishing channel.
- `/fkf herbs on`: select herbalism mode and bind the same saved key directly to INTERACTTARGET. If no key exists, configure one with `/fkf bind`. Learning Fishing is not required for this mode. Soft Interact settings remain active for the whole herbalism session so nearby nodes can be detected before gathering starts.
- `/fkf herbs off`: disable herbalism, restore the displaced key action and the interaction settings captured before enabling it. Keep the key and preferred mode for later reactivation. This command does not enable fishing; use `/fkf on` to switch to fishing. `/fkf off` still disables everything and resets the managed CVars to client defaults.
- `/fkf range 50`: save a requested reporting range, applied immediately only during an active fishing session. Accepted addon input is 10 to 100; this does not establish client limits. Default request is 50; 30 was the initial setting.
- `/fkf debug`: toggle event logs.
- `/fkf hud on|off`: retain the saved HUD preference. The user now requests bite-ready notifications only, positioned at the top center (100 pixels below the top). No reliable bite-ready signal has been identified on this client, so the HUD currently stays hidden even when enabled. Enabling it reports this limitation in chat. Waiting, detected-target, recast and combat overlays have been removed.
- `/fkf diag`: show channel, configured spell, effective binding, soft-interaction target/event, requested range and effective CVars.

Configuration commands and recast arming are rejected in combat. Diagnostics remain available.

## Interaction setting lifecycle

The addon requests SoftTargetInteract=3, SoftTargetInteractGameObject=1, SoftTargetInteractArc=2, SoftTargetInteractRange=50 (configurable), SoftTargetInteractRangeIsHard=0, SoftTargetIconInteract=1 and SoftTargetIconGameObject=1 only when each CVar exists.

Before applying interaction settings, the addon saves current values in ForeverOneKeyFishingDB.cvarBackup. In fishing mode, channel termination restores the snapshot. Herbalism keeps settings active until mode exit, unbinding or disabling, so interaction icons may appear throughout that session. Backups persist across UI reloads. Combat-delayed restoration runs after combat. Enabling fishing and changing range outside an active session do not turn on world interaction icons. No camera or cursor movement is performed.

Herbalism uses the native interaction binding, not spell casts or protected function calls from Lua. It can select NPCs or other objects as well as herbs; it does not identify or exclusively target herb nodes. Gathering remains subject to proximity, skill requirements and successful Soft Interact selection on Forever. The user moves to the herb and presses the key; existing auto-loot preferences determine looting behavior. The addon does not change auto-loot settings. Fishing timers, recast and HUD behavior are inactive in herbalism mode. Mode and the exact installed binding action persist in SavedVariables for safe restoration.

For upgrades from the earlier implementation, run `/reload`, `/fkf off`, then `/fkf on` outside combat. Earlier versions did not save pre-installation CVars, so exact historical custom values cannot be recovered. Off/reset uses the client's defaults, not invented default constants. This affects only the seven managed CVars, not every WoW preference.

## Compatibility and observations

The user confirmed that casting and interaction work on Forever, but some distant bobbers are not detected. Increasing reporting range is experimental and cannot bypass server distance, visibility or selection restrictions. SoftTargetInteractGameObject is absent on the user's client and is treated as optional.

Fishing is resolved from the localized spellbook or known spell IDs, including French Pêche. Retail ID 131474 is only a checked fallback. A secure spell button handles ordinary casting; an INTERACTTARGET override handles user-driven retrieval. The separate secure recast button uses macrotext, also used by the installed AngleurForever.lua. Actual recast macro execution still requires in-game verification.

Unsupported events are skipped safely. PLAYER_SOFT_INTERACT_CHANGED records diagnostics and can return an automatically armed recast key to retrieval; it never triggers interaction. A single C_Timer.After callback per detection check uses a generation token to ignore checks from older casts or disabled sessions. There is no OnUpdate loop. Combat postpones binding changes and starts a fresh check after combat. Missing timer or detection APIs leave normal interaction intact with a message. No automatic bite detection or automatic casting is implemented.

The requested bite alarm remains unavailable. A soft interaction target does not establish that the fish has bitten or even that the target is the player's bobber. The player must still observe the splash or hear the fishing sound. The HUD remains hidden rather than displaying an early or fabricated collection alert. No timer is used to predict a bite. Existing chat diagnostics and recast messages are unchanged.

Blizzard describes SoftTargetInteractRange as a reporting-range control and SoftTargetInteractArc as facing tolerance; this is not a guarantee of Forever behavior: https://worldofwarcraft.blizzard.com/en-us/news/23876525

## Validation and in-game test

`python tests/check.py` runs against development-only Lupa Lua 5.1; the addon itself has no external dependency. Tests pass for binding restoration, rejected bindings, modifiers, channel filtering, combat deferral, missing optional APIs/events, configurable range, idle CVar preservation, per-channel restoration, persistent CVar snapshots, off/on across login, default reset, and forced-recast event transitions. Mocks verify macro configuration, not protected execution in the game.

Disable other fishing addons during testing. Reload, run off then on, and verify world icons return to normal. Cast with the saved key and retrieve with the same key at the bite. For an undetected bobber, run recast then press the saved key: the old line should stop and a new line should appear. After retrieval or channel cancellation, verify interaction settings return to their pre-cast values. Off must restore the old key action and remain disabled after reload; on must restore the saved fishing key without enabling idle interaction icons.

For automatic recast preparation: reload, run `/fkf autorecast on`, and cast. With no soft target after two seconds, chat should announce that the next saved-key press will recast. Waiting without pressing must not cast. A detected target should keep INTERACTTARGET; a late target should restore it before the key is pressed. `/fkf autorecast off` cancels pending checks and automatically armed recasts. Added mock tests pass for the grace period, absent and present targets, late detection, stop/disable cleanup, old timer invalidation, combat deferral and missing timer API. Actual target reporting and secure macro execution still require in-game testing.

HUD regression tests pass for the top anchor and absence of overlays during detected/undetected targets, toggling, recast, channel termination, combat and disabling. This validates suppression of premature messages, not a functioning bite alarm.

Herbalism regression tests pass for activation, INTERACTTARGET binding, channel-event isolation, stale fishing timers, recast rejection, combat rejection, login persistence, restoring previous CVars and bindings, changing the key, switching back to fishing, unbinding and use without knowing Fishing. In-game verification: reload, use `/fkf herbs on`, approach a gatherable herb and press the saved key. Confirm gathering, then `/fkf herbs off` and verify the original key action and interaction settings return. Use `/fkf on` to resume fishing. Actual herb selection and gathering on Forever have not yet been tested.
