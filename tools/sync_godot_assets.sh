#!/bin/sh
# Copies the shared art and map geometry from the web version into the Godot project.
cd "$(dirname "$0")/.." || exit 1
mkdir -p godot/assets/maps godot/assets/boards godot/data
cp atlas_*.webp atlas_*.json markers.webp markers.json lifemk.webp bodies.png bodies.json expbox.json godot/assets/
cp sun.json godot/data/sun.json
cp maps/*.webp godot/assets/maps/
cp boards/*.webp godot/assets/boards/
cp geo.json godot/data/geo.json
node tools/export_godot_data.js
