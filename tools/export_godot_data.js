// Exports the game data (data.js + units.json) to JSON for the Godot port. Usage: node tools/export_godot_data.js
const path = require('path'), fs = require('fs');
const root = path.join(__dirname, '..');
const D = require(path.join(root, 'data.js'));
const UNITS = require(path.join(root, 'units.json'));
const out = JSON.stringify({ D, UNITS }, (k, v) => (v === Infinity ? 1e9 : v), 1);
fs.writeFileSync(path.join(root, 'godot', 'data', 'game_data.json'), out);
console.log('wrote godot/data/game_data.json', out.length, 'bytes');
