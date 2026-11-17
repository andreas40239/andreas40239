extends Node
## Autoload: hält die Level-Konfiguration zwischen Szenen und liest Test-Parameter
## von der Kommandozeile (nach "--"): --autoplay --seed=N --fast=N --shots=DIR --as-zombie --quit-after=SEC

var level_index := 0
var level: Dictionary = Cfg.LEVELS[0].duplicate(true)
var cli := {}               # Werte von der Kommandozeile, die jedes Level überschreiben
var look := {"color": 0, "hair": 0, "hair_color": 0, "hat": 0}   # eigene Figur
var last_ip := ""

# Test-/Debug-Optionen
var autoplay := false       # Spielerfigur wird von der KI gesteuert
var as_zombie := false      # Spieler startet als Zombie (zum Testen der Zombie-Sicht)
var fast := 1.0             # Zeitraffer
var shots_dir := ""         # Verzeichnis für automatische Screenshots
var quit_after := 0.0       # Spiel nach N Sekunden (Spielzeit) beenden
var follow := ""            # Kamera folgt dieser Figur (Namensanfang), nur für Tests
var debug := false
var touch_test := false
var items_test := false
var overview := 0.0        # Test: Kamera zeigt den ganzen Ort (Bildhöhe in Metern)
var keep_seed := false       # --seed gilt auch für Netzwerk-Runden
var net_host := 0           # Test: Spiel eröffnen und bei N Spielern starten
var net_join := ""          # Test: dieser Adresse beitreten
var net_name := ""
var rematch := 0            # Test: so viele weitere Runden nach Spielende starten
var start_game := false     # Menü überspringen
var music_on := true
var sfx_on := true


func set_level(idx: int) -> void:
	level_index = clampi(idx, 0, Cfg.LEVELS.size() - 1)
	level = Cfg.LEVELS[level_index].duplicate(true)
	for k in cli:
		level[k] = cli[k]


func look_array() -> Array:
	return [int(look.color), int(look.hair), int(look.hair_color), int(look.hat)]


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		Net.my_name = "Spieler %d" % randi_range(10, 99)
		return
	Net.my_name = cf.get_value("net", "name", Net.my_name)
	last_ip = cf.get_value("net", "last_ip", "")
	look.color = clampi(int(cf.get_value("look", "color", 0)), 0, Cfg.SHIRT_COLORS.size() - 1)
	look.hair = clampi(int(cf.get_value("look", "hair", 0)), 0, Cfg.HAIR_NAMES.size() - 1)
	look.hair_color = clampi(int(cf.get_value("look", "hair_color", 0)), 0, Cfg.HAIR_COLORS.size() - 1)
	look.hat = clampi(int(cf.get_value("look", "hat", 0)), 0, Cfg.HAT_NAMES.size() - 1)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("net", "name", Net.my_name)
	cf.set_value("net", "last_ip", last_ip)
	for k in look:
		cf.set_value("look", k, look[k])
	cf.save("user://settings.cfg")


func _ready() -> void:
	load_settings()
	var lvl := 0
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
			cli["prep_time"] = 600.0
		elif a == "--items-test":
			items_test = true
			start_game = true
			cli["prep_time"] = 600.0
		elif a == "--debug":
			debug = true
		elif a == "--game":
			start_game = true
		elif a.begins_with("--seed="):
			cli["seed"] = int(a.get_slice("=", 1))
			keep_seed = true
		elif a.begins_with("--overview="):
			overview = float(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			lvl = int(a.get_slice("=", 1))
		elif a.begins_with("--look="):
			var parts := a.get_slice("=", 1).split(",")
			if parts.size() == 4:
				look = {"color": int(parts[0]), "hair": int(parts[1]), "hair_color": int(parts[2]), "hat": int(parts[3])}
		elif a == "--zombie-computer":
			Net.player_zombie = false
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
			cli["prep_time"] = float(a.get_slice("=", 1))
		elif a.begins_with("--match="):
			cli["match_time"] = float(a.get_slice("=", 1))
	set_level(lvl)
