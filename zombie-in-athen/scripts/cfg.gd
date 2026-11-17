class_name Cfg
## Zentrale Spielkonstanten (Balancing). Alle Werte in Metern / Sekunden.

# --- Menschen ---
const HUMAN_RUN := 4.0          # Rennen (macht Lärm)
const HUMAN_SNEAK := 1.7        # leise gehen
const HUMAN_SOUVLAKI := 6.2     # Souvlaki-Bonus (schneller als sprintende Zombies)
const HUMAN_FRAPPE_SNEAK := 3.2 # Frappé: leise gehen, aber schneller als ein verfolgender Zombie
const MAX_LIVES := 3            # Bisse bis zur Verwandlung
const FREEZE_MAX := 10.0        # Sekunden "bewegungslos stehen"
const FREEZE_REGEN := 0.5       # Sekunden Budget pro Sekunde Erholung
const FREEZE_LOCK := 3.0        # Sperre nach vollständigem Verbrauch
const INVULN_AFTER_BITE := 3.0  # so lange kann man nicht erneut gebissen werden

# --- Zombies ---
const ZOMBIE_WALK := 1.5        # schlurfen (Suche)
const ZOMBIE_CHASE := 2.9       # Verfolgung auf Sicht
const ZOMBIE_SPRINT := 5.2      # 3-Sekunden-Sprint nach Geräusch
const SPRINT_TIME := 3.0
const SPRINT_COOLDOWN := 4.0
const BITE_STUN := 3.0          # Zombie verharrt nach Biss
const BITE_RANGE := 1.05
const SNIFF_TIME := 1.6         # Schnüffeln an einem Versteck
const LISTEN_WARMUP := 0.5      # Spieler-Zombie: so lange still stehen bis Horchen wirkt
const ZOMBIE_FOV_DEG := 220.0

# --- Wahrnehmung ---
const RUN_NOISE_RADIUS := 10.0  # Reichweite von Renn-Geräuschen für KI-Zombies
const SIGHT_RUN := 12.0         # Sichtweite auf rennende Menschen
const SIGHT_SNEAK := 8.0        # ... auf schleichende
const SIGHT_IDLE := 3.5         # ... auf (ohne Button) stillstehende
const NOISE_MARK_TIME := 0.8    # so lange bleibt das gelbe Oval nach einem Geräusch

# --- Upgrades ---
const GARLIC_TIME := 20.0
const GARLIC_RADIUS := 3.2
const SOUVLAKI_TIME := 20.0
const FRAPPE_TIME := 20.0
const OIL_RADIUS := 0.8         # Größe der Ölpfütze
const OIL_TIME := 45.0          # so lange bleibt sie liegen
const OIL_USES := 3             # so viele Ausrutscher, dann ist sie weg
const SLIP_TIME := 2.5          # so lange liegt ein ausgerutschter Zombie am Boden
const MELON_RANGE := 7.0
const MELON_LURE_TIME := 6.0
const PICKUP_RADIUS := 0.85
const PICKUP_MAX := 3
const PICKUP_FIRST := 6.0
const PICKUP_MIN_DELAY := 9.0
const PICKUP_MAX_DELAY := 15.0

# --- Kamera ---
const CAM_YAW_DEG := 45.0
const CAM_PITCH_DEG := -50.0
const CAM_SIZE := 11.0

# Kollisions-Layer
const LAYER_WORLD := 1

const SHIRT_COLORS := [
	Color(0.2, 0.55, 0.95),   # blau
	Color(0.9, 0.3, 0.25),    # rot
	Color(0.35, 0.8, 0.4),    # grün
	Color(0.75, 0.45, 0.9),   # violett
	Color(0.95, 0.78, 0.2),   # gelb
	Color(0.3, 0.8, 0.8),     # türkis
	Color(0.95, 0.55, 0.15),  # orange
	Color(0.95, 0.5, 0.7),    # rosa
	Color(0.92, 0.92, 0.9),   # weiß
	Color(0.25, 0.27, 0.32),  # anthrazit
]
const HAIR_COLORS := [
	Color(0.1, 0.08, 0.07),   # schwarz
	Color(0.32, 0.19, 0.1),   # braun
	Color(0.85, 0.68, 0.3),   # blond
	Color(0.7, 0.25, 0.1),    # rot
	Color(0.65, 0.65, 0.68),  # grau
	Color(0.95, 0.4, 0.7),    # pink
	Color(0.25, 0.5, 0.95),   # blau
	Color(0.3, 0.8, 0.35),    # grün
]
const PICKUP_KINDS := ["garlic", "souvlaki", "melon", "oil", "frappe"]
const BOT_NAMES := ["Nikos", "Eleni", "Kostas", "Maria", "Giorgos", "Sofia", "Yannis", "Katerina"]
const ZOMBIE_NAMES := ["Stavros", "Thanos", "Vasilis", "Despina"]


## Die spielbaren Orte. Der erste ist das Testlevel laut Auftrag:
## 1 menschlicher Spieler, 3 Computerspieler, 1 Zombie.
##   ai_humans: Computer-Menschen neben dem Spieler (im Mehrspieler füllen sie nur auf)
##   layout:    "single" = ein Flur, "double" = zwei Flure mit Rundweg
##   rooms:     Zimmer je Streifen (oben, [Mitte,] unten)
const LEVELS := [
	{"name": "Wohnung", "info": "6 Zimmer · 1 Zombie",
		"theme": "home", "layout": "single", "width": 22, "height": 16, "extra_rooms": 2,
		"ai_humans": 3, "zombies": 1, "prep_time": 30.0, "match_time": 300.0, "seed": 0},
	{"name": "Große Wohnung", "info": "11 Zimmer, zwei Flure · 2 Zombies",
		"theme": "home", "layout": "double", "width": 30, "height": 22, "rooms": [4, 3, 4],
		"ai_humans": 3, "zombies": 2, "prep_time": 30.0, "match_time": 360.0, "seed": 0},
	{"name": "Taverne", "info": "Gastraum, Küche, Vorrat · 2 Zombies",
		"theme": "taverna", "layout": "single", "width": 28, "height": 18, "rooms": [3, 2],
		"ai_humans": 4, "zombies": 2, "prep_time": 30.0, "match_time": 330.0, "seed": 0},
	{"name": "Schule", "info": "14 Räume, Spinde im Flur · 2 Zombies",
		"theme": "school", "layout": "double", "width": 34, "height": 24, "rooms": [5, 4, 5],
		"ai_humans": 4, "zombies": 2, "prep_time": 30.0, "match_time": 420.0, "seed": 0},
]

## Auswahl für die eigene Figur
const HAIR_NAMES := ["Kurz", "Lang", "Glatze", "Irokese", "Pferdeschwanz", "Locken", "Zöpfe"]
const HAT_NAMES := ["Kein Hut", "Kappe", "Strohhut", "Fischermütze", "Mütze", "Spartaner-Helm", "Lorbeerkranz", "Krone", "Kochmütze"]


static func sight_range(motion: float) -> float:
	if motion <= 0.0:
		return 0.0
	if motion <= 0.25:
		return SIGHT_IDLE
	if motion <= 0.6:
		return lerpf(SIGHT_IDLE, SIGHT_SNEAK, (motion - 0.25) / 0.35)
	return lerpf(SIGHT_SNEAK, SIGHT_RUN, (motion - 0.6) / 0.4)
