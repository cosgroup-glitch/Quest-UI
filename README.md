# Quest UI

Lua addon port of Labyrinth's `QuestObjectivesWindow`, Quest Log, Credos and Quest Helper. Install this folder as `client/addons/quest-ui` and enable **Quest UI** in Brodgar's addon manager.

## Open it

The on-screen **Quest Objectives** control is the original small circular Kami button, using its four original image states at 40 × 40. It toggles the objectives window and follows its open/closed state. The extra on-screen Quest Log and Helper shortcuts have been removed. Open Quest Log and Credos from the image buttons inside the objectives window. Each window has an assignable shortcut in Quest UI's addon settings. The console command `questui` opens the objectives window. Quest Helper is an optional all-quest task overview available in addon settings, without an on-screen shortcut.

Windows use Brodgar's own theme, title bars, close buttons and resizing grips. Their positions and sizes are remembered per character by the UI API. Closing a window hides it so it can be reopened. Each session has its own windows and objective snapshots.

Version 1.1 starts the corrected objectives layout at Kami's 224 × 277 content size using a new geometry key. The framed body fills the available height. The bottom row uses the original 81 × 34 Quest Log/Credos artwork and a 34 × 34 current-credo icon. Its title uses bold 16-point serif text; objective lines use 12-point sans-serif text and Kami's yellow/green/red status colours. Long lines wrap using Brodgar's text measurement API. Subsequent resizing is remembered normally.

## Features

- **Quest Objectives:** selected quest title, coloured objective status, objective status text, current credo level/quest progress, and buttons for Quest Log, Credos and the current credo quest. Clicking the heading opens Quest Log. With **Hide native objectives completely** enabled, an API layout rule places native objective HUDs off-screen as they arrive, and the arrival callback also hides them. Native objectives stay suppressed when this window is closed. Turning the setting off or disabling the addon restores the native HUD.
- **Quest Log:** opens the existing Quest Log tab directly in Brodgar's character sheet. The addon creates no separate quest-log window and does not move the native quest details.
- **Credos:** directly shows Labyrinth's 21 credos and artwork grouped as Pursuing, Available, Acquired and Unavailable, including descriptions, prerequisites and bonuses. Live status comes from the character API. The Live credos, Current credo quest and Full catalogue buttons have been removed from this menu. The objectives window retains its current-credo icon. Native pursuit controls remain in Brodgar's character sheet.
- **Quest Helper:** collects pending objectives as quests are viewed, keeps plain snapshots when another quest is selected, sorts the selected quest first, then credo objectives, then the last remaining objective according to **Ready first**, then alphabetically. Last remaining objectives are highlighted, matching Labyrinth's heuristic; this is not a server assertion that a quest can be handed in. Click an objective to select its quest. Existing named map markers provide quest-giver distance in tile metres. Changed, unviewed quests are marked `[refresh]`.
- **Refresh all:** explicitly loads each pending quest, waits for its objectives, and restores the previous selection (including no selection). **Cancel**, another Quest UI selection, switching sessions, relogging and addon disable stop the scan. There is no background quest selection on startup or while simply opening windows. Unloaded quests can be refreshed again if a server reply was unusually slow.

## Permissions and data safety

The manifest declares `widget.send` because Brodgar has no typed quest-selection verb. The addon sends only `qsel` from the nearest bound ancestor of the native QuestWnd, following the native list's route. Quest choices and credo pursuit remain native controls operated by the user. No console execution, item actions or movement permissions are requested.

Objective snapshots live in Lua memory and are cleared on relog/disable. UI geometry and addon preferences use Brodgar's own savedata API. No existing game cache is read directly or changed, and no map pins are added, removed or recoloured. Marker distance reads use the already-loaded marker list and current location. Unavailable or corrupt data is reported and skipped; there is no repair, purge or replacement path.

## API limits and differences

The native objectives HUD can still flash briefly when changing quests. Brodgar creates a new native `QView` for each selection; the addon uses an off-screen layout rule and hides it on `Added`, but these do not reliably suppress its first frame in the installed client. Our objectives window stays open while its contents update. A client-side suppression setting or earlier application of layout rules would be needed to reliably remove the native flash.

Brodgar publishes objectives only for the selected quest. The helper's other rows are snapshots from the current login; select a quest or use Refresh all to update them. Unlike Labyrinth's Java helper, the addon does not silently select every quest when it opens.

Credos use the complete copied catalogue. Unknown future credos remain available in Brodgar's native character sheet. Quest details remain in the native character sheet. Opening Quest Log temporarily shows its page; a native tab click or addon disable releases the temporary tab visibility controls.

Helper snapshots are confirmed by the native quest detail's `conds` replies. Selecting a quest alone does not mark its cached objectives fresh. Refresh waits for a confirmed reply and stable conditions, and reports unconfirmed quests after a timeout. If the addon was enabled after the current quest's objectives arrived, select that quest again or use Refresh all to confirm its helper snapshot. A native quest selection immediately cancels an active scan, including while its first reply is still pending.

Labyrinth's transient quest-giver marker recolouring is not reproduced by modifying Brodgar's pins: its marker colour API writes the map database. Existing marker colours and pins are retained. Helper row colours and distance readings are available.

## Verification

Run `java -cp ../../lib/luaj-jse-3.0.1.jar lua tests/review-regressions.lua` from this folder. It compiles all three Lua files and checks tab visibility release, confirmed snapshots, stale indicators, missing and empty objective replies, and native selection cancellation using isolated mocks. These checks load no Haven/cache classes and launch no game client. In-game rendering and server behaviour still require a live check by the user.

Official API references: [Quest](https://irongete.github.io/brodgar-io-client/addons/api/quest/), [Character](https://irongete.github.io/brodgar-io-client/addons/api/char/), [Native widgets](https://irongete.github.io/brodgar-io-client/addons/api/ui/native/), [Widget messages](https://irongete.github.io/brodgar-io-client/addons/api/ui/widget/), [Map markers](https://irongete.github.io/brodgar-io-client/addons/api/map/markers/).

Regenerate the copied catalogue and artwork with `python brodgar-addons/quest-ui/tools/build_catalog.py` from the Labyrinth repository. It reads only the source Java and existing PNG files.
