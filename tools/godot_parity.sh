#!/bin/sh
# Plays the same seeded games with the web engine (Node) and the Godot port, and compares every log line.
# Usage: tools/godot_parity.sh [first_seed] [last_seed]     (needs node and godot on the PATH)
cd "$(dirname "$0")/.." || exit 1
A=${1:-1}; B=${2:-5}; OUT=$(mktemp -d); FAIL=0
for s in $(seq "$A" "$B"); do
  f=$(echo na ru eu jp cn as sa | cut -d' ' -f$(( (s % 7) + 1 )))
  node tools/parity_solo.js "$s" "$f" "$OUT/sj$s.json" >/dev/null
  godot --headless --path godot -s res://tests/parity_solo.gd -- "$s" "$f" "$OUT/sg$s.json" >/dev/null 2>&1
  r=$(python3 tools/parity_compare_solo.py "$OUT/sj$s.json" "$OUT/sg$s.json" | tail -1); echo "solo  seed $s ($f): $r"
  case "$r" in MATCH*) ;; *) FAIL=1 ;; esac
  node tools/parity_dump.js "$s" "$OUT/jw$s.json" >/dev/null
  godot --headless --path godot -s res://tests/parity_dump.gd -- "$s" "$OUT/gw$s.json" >/dev/null 2>&1
  r=$(python3 tools/parity_compare_world.py "$OUT/jw$s.json" "$OUT/gw$s.json" | grep MISMATCHES); echo "world seed $s: $r"
  case "$r" in "MISMATCHES 0") ;; *) FAIL=1 ;; esac
done
rm -rf "$OUT"
[ $FAIL = 0 ] && echo "ALL OK" || { echo "DIFFERENCES FOUND"; exit 1; }
