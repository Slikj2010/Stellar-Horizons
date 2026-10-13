# Stellar Horizons (Campaign)

An adaptation of Compass Games' *Stellar Horizons* campaign (2030–2169), built on the Vassal module's board and counter art. Designed with AI.

## Play
Open `index.html` through any static web server (the page loads its data with `fetch`, so opening the file directly from disk will not work):

```
python3 -m http.server 8000
# then visit http://localhost:8000/
```

## Layout
- `index.html` — title screen, pause menu, board renderer (canvas + WebGL planet spin), all UI.
- `rules.js` — the rules engine (no DOM; runs in Node too).
- `data.js` — worlds, technologies, policies, factions, missions, world cards, events, combat tables.
- `units.json` — every faction's named vehicles (costs, search, cargo, combat).
- `geo.json`, `expbox.json`, `bodies.json`, `sun.json`, `menu.json` — board geometry and effect data.
- `maps/`, `atlas_*.webp`, `markers.webp`, `boards/`, `bodies.png`, `menu*.` — art.
- `tools/` — Python scripts that generated the assets from the Vassal module (`Stellar_Horizons_1_2.vmod`, not included).
- `tests/bot.js` — headless random bot that plays full campaigns for all factions: `node tests/bot.js $PWD 7`.
- `RULES.md` — rules notes transcribed from the rulebook, clarifications and tech chart.

Saves are kept in the browser's localStorage.

Board, counter and card art come from the Stellar Horizons Vassal module and remain the property of their owners.

## Desktop app (Electron)
The `desktop/` folder wraps the game as a desktop program (saves stay in the app's own data folder).
- Run it: `cd desktop && npm install && npm start`
- Build installers: `npm run dist` (Windows .exe, macOS .dmg, Linux AppImage; build each on its own system).
- Or push a tag like `v1.0.0` (or run "Build desktop apps" under GitHub Actions) and download the installers from the run.

### Releases and updates
Push a version tag (for example `git tag v1.1.0 && git push --tags`) and the workflow builds all three platforms and publishes them as a GitHub Release.
Installed copies check for a newer release at start-up (Help menu → Check for updates) and offer to restart into it; saves are kept.
The portable .exe cannot replace itself, so it opens the releases page instead.
Saves can be moved between the browser page and the desktop app with Load game → Export saves / Import saves.
