#!/bin/sh
# Copies the shared art and map geometry from the web version into the Godot project.
cd "$(dirname "$0")/.." || exit 1
mkdir -p godot/assets/maps godot/assets/boards godot/data
cp atlas_*.webp atlas_*.json markers.webp markers.json lifemk.webp expbox.json godot/assets/  # bodies.png/json are made by tools/make_bodies.py (cleaner planet maps)
mkdir -p godot/assets/menu
cp menu.webp menu_clouds.webp menu_earth.webp menu_fx.png menu.json menu_earth.json godot/assets/menu/
cp sun.json godot/data/sun.json
cp maps/*.webp godot/assets/maps/
cp boards/*.webp godot/assets/boards/
cp geo.json godot/data/geo.json
node tools/export_godot_data.js
