extends Node
## Autoload: hält die Level-Konfiguration zwischen Szenen und liest Test-Parameter
## von der Kommandozeile (nach "--"): --autoplay --seed=N --fast=N --shots=DIR --as-zombie --quit-after=SEC

## Testlevel laut Auftrag: 1 menschlicher Spieler, 3 Computerspieler, 1 Zombie.
const TEST_LEVEL := {
	"name": "Testlevel: Wohnung in Kypseli",
	"seed": 0,            # 0 = zufällig
	"ai_humans": 3,
	"zombies": 1,
	"prep_time": 30.0,    # Sekunden bis die Zombies kommen
	"match_time": 300.0,  # danach geht die Sonne auf
	"width": 22,
	"height": 16,
	"extra_rooms": 2,     # zusätzlich zu Schlafzimmer, Bad, Küche
}

var level: Dictionary = TEST_LEVEL.duplicate()

# Test-/Debug-Optionen
var autoplay := false       # Spielerfigur wird von der KI gesteuert
var as_zombie := false      # Spieler startet als Zombie (zum Testen der Zombie-Sicht)
var fast := 1.0             # Zeitraffer
var shots_dir := ""         # Verzeichnis für automatische Screenshots
var quit_after := 0.0       # Spiel nach N Sekunden (Spielzeit) beenden
var follow := ""            # Kamera folgt dieser Figur (Namensanfang), nur für Tests
var debug := false
var touch_test := false
var keep_seed := false       # --seed gilt auch für Netzwerk-Runden
var net_host := 0           # Test: Spiel eröffnen und bei N Spielern starten
var net_join := ""          # Test: dieser Adresse beitreten
var net_name := ""
var rematch := 0            # Test: so viele weitere Runden nach Spielende starten
var start_game := false     # Menü überspringen
var music_on := true
var sfx_on := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
			start_game = true
		elif a == "--as-zombie":
			as_zombie = true
			start_game = true
		elif a == "--touch-test":
			touch_test = true
			start_game = true
			level["prep_time"] = 600.0
		elif a == "--debug":
			debug = true
		elif a == "--game":
			start_game = true
		elif a.begins_with("--seed="):
			level["seed"] = int(a.get_slice("=", 1))
			keep_seed = true
		elif a.begins_with("--host="):
			net_host = int(a.get_slice("=", 1))
		elif a.begins_with("--join="):
			net_join = a.get_slice("=", 1)
		elif a.begins_with("--rematch="):
			rematch = int(a.get_slice("=", 1))
		elif a.begins_with("--name="):
			net_name = a.get_slice("=", 1)
		elif a.begins_with("--fast="):
			fast = float(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			shots_dir = a.get_slice("=", 1)
		elif a.begins_with("--quit-after="):
			quit_after = float(a.get_slice("=", 1))
		elif a.begins_with("--follow="):
			follow = a.get_slice("=", 1)
		elif a.begins_with("--prep="):
			level["prep_time"] = float(a.get_slice("=", 1))
		elif a.begins_with("--match="):
			level["match_time"] = float(a.get_slice("=", 1))
