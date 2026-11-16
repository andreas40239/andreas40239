#!/usr/bin/env bash
# Automatische Tests:
#   0) Wohnungsgenerator über 300 Seeds
#   1) komplette Matches im Zeitraffer, alle Figuren KI-gesteuert (headless)
#   2) Touch-Steuerung mit simulierten Fingern (braucht ein Fenster; unter Linux
#      ohne Bildschirm: xvfb-run -a -s "-screen 0 1280x720x24" tools/run_tests.sh)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
fail=0
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --script tests/gen_test.gd 2>&1 | grep -E "^GENTEST" || fail=1
for seed in ${SEEDS:-1 2 3}; do
	out=$("$GODOT" --headless --path . -- --autoplay --seed="$seed" --fast=10 --quit-after=400 2>&1)
	res=$(echo "$out" | grep -E "^RESULT" | head -1)
	errs=$(echo "$out" | grep -c "SCRIPT ERROR")
	echo "Seed $seed: ${res:-KEIN ERGEBNIS}  (Skriptfehler: $errs)"
	if [ -z "$res" ] || [ "$errs" != "0" ]; then fail=1; fi
done
if [ -n "${DISPLAY:-}" ]; then
	"$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --touch-test --seed=7 2>&1 | grep -E "\[ok\]|FAIL|TOUCHTEST"
	[ "${PIPESTATUS[0]}" = "0" ] || fail=1
else
	echo "Touch-Test übersprungen (kein DISPLAY)."
fi
exit $fail
