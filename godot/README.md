# Stellar Horizons: Godot 4 version

The game as a stand-alone application, built with [Godot 4](https://godotengine.org) (made and tested with 4.7).
The web version in the folder above stays the reference: this project uses the same rules, bots, data and art.

## Opening and running it

1. Install Godot 4.7 (the standard version; the .NET version isn't needed).
2. In the Godot Project Manager choose **Import**, pick `godot/project.godot` from this repository, then **Import & Edit**.
3. Press **F5** (or the Play button) to run the game.

The first import takes a minute while Godot converts the map and counter images.

## Playing

- **Start screen:** pick your faction, choose solo or with the other factions played by bots, then **Start campaign**.
- **Map:** drag to pan, mouse wheel (or pinch) to zoom. Hotkeys jump the camera: `1` Mercury, `2` Venus, `Space` Earth,
  `3` Mars, `4` Main Belt, `5` Jupiter, `6` Saturn, `7` Uranus, `8` Neptune, `9` Kuiper Belt, `0` Scattered Disk, `A` Alpha Centauri.
- **Moving a ship:** in the Movement phase, ships that can move are outlined in blue. Click one: its legal destinations
  light up on the map. Click a zone to move there, or use the buttons in the **Selected** tab, which also let you
  choose the launch vehicle and load supplies at launch.
- **Faction board:** opening the **Faction** tab covers the map with your faction board, a digital copy of the
  printed sheet using its flag and base artwork. It shows relations, Earth production, resources and launch-vehicle
  counters, base population, your six base slots, victory points, missions, politics, the shipyard and technologies.
  Ships built and waiting on Earth appear only here, in **New builds**. Drag one onto the **launch pad** (or click it),
  then in the Movement step pick a destination to launch it. **Show the printed faction sheet** opens the original sheet.
- **Technology and policy trees:** the **Tech** and **Policy** tabs cover the map with the full trees. Cards you can
  develop or adopt now are highlighted; click one to confirm. In a multi-faction game the research turns (develop one
  or pass) are shown in the Tech tab.
- **Exploring:** choosing Explore opens a confirmation with the value and the odds, then a result screen with the
  dice, the markers earned, the recall or malfunction check and any search for life. Producing and harvesting work the
  same way.
- **Combat:** searches, ship combat and pirate fights open a screen with both sides, the dice, the strike and
  direct-fire table and your tactics-point plan (direct fire, extra damage, less damage taken, picking targets, or
  calling the combat off). Damage on units and hits on a base can be assigned by hand or left to the game.
- **Side panel:** **Turn** shows what the current phase or step offers (building, research, policies, diplomacy,
  exploring, bases and trade). **Selected** shows the ship, base or world you clicked. **Faction** shows your faction,
  missions, relations, policies, technologies and score. **Log** shows the game log, with filters (yours, bots,
  highlights) and a search box.
- **Next** (or `Enter`) ends the current phase or step. It first lists anything you have not used yet (ships that can
  still move or explore, affordable technologies and so on); `Enter` again confirms. This check can be turned off.
- **Questions** (pirates, world cards, flyby transfers, combat and so on) pop up in the middle of the screen.
- **Menu** (or `Esc`): save to one of three slots, load, settings and a new campaign. The game also autosaves each
  time you press Next and when you quit. Saves are kept in Godot's user folder
  (on Windows `%APPDATA%\Godot\app_userdata\Stellar Horizons`).
- **Settings:** the Next check, autosave, animations, and the optional rules (engine rerolls, scrapping explorers and
  launch vehicles, enhanced trading).

## Project layout

| Path | What it is |
| --- | --- |
| `engine/rules.gd` | The rules engine (`SHRules`): a line-by-line port of `rules.js`, pure logic with no nodes. |
| `engine/ai.gd` | The bot factions and the multi-faction turn order (`SHAI`), ported from `ai.js`. |
| `engine/data_loader.gd` | Loads `data/game_data.json` (exported from `data.js` and `units.json`). |
| `engine/game.gd` | The `Game` autoload: the current campaign, saving and loading, and the signals the UI listens to. |
| `engine/rng.gd` | A seeded random number generator, used for tests and repeatable games. |
| `ui/board.gd` | Draws the map, counters, markers and move targets, and works out what a click hit. |
| `ui/board_camera.gd` | Pan, zoom and camera jumps. |
| `ui/faction_board.gd` | The faction board screen, with drag-and-drop between New builds and the launch pad. |
| `ui/main.gd` | The HUD: top bar, side panel tabs, question dialog, Next check, menus, save slots and settings. |
| `ui/tech_tree.gd` | The technology and policy tree overlays. |
| `ui/screens.gd` | The exploration and combat screens (dice, results, combat plans, assigning damage). |
| `ui/ui_kit.gd`, `ui/theme.tres` | Helpers and the look of the panels and buttons. |
| `scenes/main.tscn` | The main scene. |
| `assets/` | Maps, counter sheets, markers and fonts, copied from the web version. |
| `tests/` | Parity checks against the web engine, and a screenshot driver. |

The engine keeps the JavaScript function names (`moves`, `move`, `explore`, `buildUnit`, `advance`…) and the same
game-state layout, so a change made to `rules.js` can be carried over to `rules.gd` almost line for line.

## Keeping the two versions in step

After changing the data or art in the web version, refresh the copies here:

```sh
tools/sync_godot_assets.sh
```

To check that the Godot engine still plays exactly like the web engine, run:

```sh
tools/godot_parity.sh 1 10
```

This script plays the same seeded games in both engines and compares every log line. It covers solo games with
random choices and full seven-faction bot campaigns. It needs `node`, `python3` and `godot` on the path.

Screenshots of the running game (for checking the layout without opening the editor):

```sh
xvfb-run godot --path godot --rendering-driver opengl3 res://tests/shots.tscn -- /tmp/shots eu 0 basic
```

## Exporting a build

In the editor, open **Editor → Manage Export Templates** and download the templates for 4.7. Then use
**Project → Export**, add a preset (Windows Desktop, macOS or Linux) and choose **Export Project**.

## Not in the Godot version yet

- The 2.5D view.
- Sound and music.
