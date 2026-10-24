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
  Pressing `4`, `9` or `0` again cycles through that belt's worlds (Ceres, Vesta, Hygiea; Pluto, Haumea; Eris, Sedna).
- **Hover and zoom:** hovering over a counter, base, world or destination shows a short description. Right-click a
  counter to see it large, front and back.
- **Moving a ship:** in the Movement phase, ships that can move are outlined in blue. Drag one onto a highlighted
  destination, or click it to light up its destinations and then click one. The buttons in the **Selected** tab also
  let you choose the launch vehicle and load supplies at launch.
- **Animated board:** stars drift behind the map, the planets and moons turn, the sun's corona flares, and the
  exploration boxes glow in their research colour (changed values are repainted, with a flash). This can be turned
  off in Settings.
- **Flat map layout:** the nine printed map sections are laid out left to right along a gentle winding path
  (Mercury/Venus through Alpha Centauri), joined by dashed lanes with arrowheads. The 2.5D view keeps the printed
  sheet layout. The spacing and wave are `LAYOUT_GAP`, `LAYOUT_AMP` and `LAYOUT_FREQ` at the top of `ui/board.gd`.
- **Launch pad pairing:** on the Faction tab, drag a launch-vehicle counter (from your stock, or the faded "Buy at
  launch" row) onto a ship to pair them, or onto the pad. Click the paired counter to unpair.
- **Title screen, developer console and saves:** the illustrated title screen opens first. The developer console opens
  with the backtick key or from the pause menu. The load screen can export and import all saves as one file
  (Godot save format; not interchangeable with the web version's saves).
- **Backdrop and planets:** the galaxy backdrop is `assets/sky_flat.png` (flat view) and `assets/sky_pano.png` (2.5D
  sky). The planet maps are procedural (`tools/make_bodies.py`, `tools/make_sky.py`). After changing images run
  `godot --headless --path . --import`.
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
- **2.5D view:** the **2.5D** button under the map (or `V`) switches to the web version's 2.5D space view, ported
  line for line: the systems as glass plates on their orbits round the Sun, holographic transfer and flyby boxes,
  digital world boxes (information plate, card slot, life slot and base tray), spinning planets, ray-marched moons
  and rocks, hovering counters, the Main and Kuiper Belts, and a deep-sky backdrop. Drag a counter onto a highlighted
  box to move it, tap to select. Left-drag pans, right-drag (or Shift-drag) turns, the wheel zooms; the buttons under
  the map turn and tilt the view, zoom, show the whole map or your ships.
- **Sound:** sound effects for clicks, dice, exploring, launches, building, trade, combat and phase changes, and an
  ambient music loop. Both volumes are in Settings. The sounds are synthesized by `tools/make_sounds.py`.
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
| `ui/board_fx.gd`, `ui/shaders/` | Spinning planets, the sun and the animated exploration boxes. |
| `ui/starfield.gd` | The starfield and nebula behind the map. |
| `ui/v25/` | The 2.5D view: `v25.gd` (a port of `view25.js`), `v25_layout.gd` (of `layout25.js`), `v25_paint.gd` (its text, labels and world plates) and the shaders. |
| `assets/v25/` | The 2.5D view's galaxy, nebula and deep-sky art, rendered from the web version's own code by `tools/export_v25_art.js`. |
| `ui/audio.gd`, `assets/audio/` | Sound effects and music. |
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

## Differences from the web version

- The web version's font (IBM Plex Sans Condensed) isn't included. The 2.5D view's labels and plates use DejaVu Sans
  Condensed instead; put `IBMPlexSansCondensed-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf` and `-Bold.ttf` in
  `assets/fonts/` and they are used automatically.

To compare the 2.5D view with the web version, `node tools/web_v25_shots.js /tmp/web na 0` renders the web version's
view of the same seeded game as the Godot screenshot test's `3d` plan.
