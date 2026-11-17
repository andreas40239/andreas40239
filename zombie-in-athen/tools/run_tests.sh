#!/usr/bin/env bash
# Automatische Tests:
#   0) Wohnungsgenerator über 300 Seeds
#   1) komplette Matches im Zeitraffer, alle Figuren KI-gesteuert (headless)
#   2) Netzwerkrunde: Gastgeber + 2 Mitspieler auf diesem Rechner, inkl. Spielsuche
#   3) Touch-Steuerung mit simulierten Fingern (braucht ein Fenster; unter Linux
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
# Netzwerk: ein Gastgeber und zwei Mitspieler als eigene Prozesse auf diesem Rechner.
# Alle drei müssen dasselbe Ergebnis und dieselbe Abschlusstabelle melden.
tmp=$(mktemp -d)
"$GODOT" --headless --path . -- --host=3 --name=Wirt --autoplay --seed=5 --fast=6 --quit-after=400 > "$tmp/host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join=127.0.0.1 --name=Gast1 --autoplay --quit-after=400 > "$tmp/c1.log" 2>&1 &
"$GODOT" --headless --path . -- --join=auto --name=Gast2 --autoplay --quit-after=400 > "$tmp/c2.log" 2>&1 &
wait
ref=$(grep -E "^STATS" "$tmp/host.log" | head -1)
net_ok=1
[ -n "$ref" ] || net_ok=0
for f in host c1 c2; do
	[ "$(grep -E "^STATS" "$tmp/$f.log" | head -1)" = "$ref" ] || net_ok=0
	[ "$(grep -c "SCRIPT ERROR" "$tmp/$f.log")" = "0" ] || net_ok=0
done
grep -q "NET found host" "$tmp/c2.log" || net_ok=0
if [ "$net_ok" = "1" ]; then
	echo "Netzwerk (3 Geräte, Spielsuche): OK  ${ref}"
else
	echo "Netzwerk: FEHLGESCHLAGEN (Logs in $tmp)"; fail=1
fi
if [ -n "${DISPLAY:-}" ]; then
	"$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --touch-test --seed=7 2>&1 | grep -E "\[ok\]|FAIL|TOUCHTEST"
	[ "${PIPESTATUS[0]}" = "0" ] || fail=1
else
	echo "Touch-Test übersprungen (kein DISPLAY)."
fi
exit $fail
