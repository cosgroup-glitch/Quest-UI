# Quest UI

A questing addon for the [Brodgar client](https://irongete.github.io/brodgar-io-client/), based on Labyrinth's Quest Objectives, Credos and Quest Helper.

## Installation

1. Download the repository ZIP and extract it.
2. Rename the extracted folder to `quest-ui` and place it in `client/addons/`.
3. Enable **Quest UI** in the client's addon manager and allow its widget-message permission.

## Usage

Click the circular **Quest Objectives** button to toggle the objectives window. Its buttons open the native Quest Log, the credo catalogue and the current credo quest.

Open **Quest Helper** from the addon settings. Shortcuts for Objectives, Quest Log, Credos and Helper can be assigned there. The client console command `questui` also opens Objectives.

Window positions and sizes are saved per character.

## Features

- Selected quest objectives with completion colours and credo progress.
- The native character-sheet Quest Log.
- A catalogue of 21 credos with requirements, bonuses and live status.
- Quest Helper with cached pending objectives, sorting and distances to existing named map markers.
- **Refresh all** to load pending quests and restore the previous selection. Manual quest selection cancels the scan.
- A setting to suppress the native objectives HUD.

## Known limitations

The native objectives HUD can still flash briefly when changing quests. The addon hides it and applies an off-screen layout rule, but the installed client's creation timing can allow its first frame to appear. Quest UI's own window stays open during quest changes.

Brodgar exposes objectives only for the selected quest. Helper rows for other quests are snapshots from the current login; use **Refresh all** to update them. Changed snapshots are marked `[refresh]`. If the addon was enabled after a quest's objectives arrived, reopen that quest or refresh to collect a confirmed snapshot.

Highlighted last remaining objectives are a convenience indicator, not confirmation that a quest can be handed in. Distances require an existing map marker matching the quest giver's name.

Unknown credos and native quest choices remain available in the client's character sheet.

## Permissions and data

`widget.send` is required to select quests using the client's `qsel` message. The addon does not request movement, item-action or console-execution permissions.

Quest snapshots are kept in memory and cleared on relog or disable. Preferences and window geometry use the client's savedata API. Map markers are read only; the addon does not create, delete or recolour pins.

## Credits

Quest UI is based on Labyrinth's quest interface and credo catalogue, with the original Kami-style controls and bundled artwork. It uses Brodgar's Lua addon API.
