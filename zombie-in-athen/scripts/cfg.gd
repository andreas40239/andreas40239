class_name Cfg
## Zentrale Spielkonstanten (Balancing). Alle Werte in Metern / Sekunden.

# --- Menschen ---
const HUMAN_RUN := 4.0          # Rennen (macht Lärm)
const HUMAN_SNEAK := 1.7        # leise gehen
const HUMAN_SOUVLAKI := 6.2     # Souvlaki-Bonus (schneller als sprintende Zombies)
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
	Color(0.2, 0.55, 0.95),   # Spieler: blau
	Color(0.9, 0.35, 0.25),   # rot
	Color(0.35, 0.8, 0.4),    # grün
	Color(0.85, 0.5, 0.9),    # violett
	Color(0.95, 0.75, 0.2),   # gelb
	Color(0.3, 0.8, 0.8),
]
const BOT_NAMES := ["Nikos", "Eleni", "Kostas", "Maria", "Giorgos", "Sofia", "Yannis", "Katerina"]
const ZOMBIE_NAMES := ["Stavros", "Thanos", "Vasilis", "Despina"]


static func sight_range(motion: float) -> float:
	if motion <= 0.0:
		return 0.0
	if motion <= 0.25:
		return SIGHT_IDLE
	if motion <= 0.6:
		return lerpf(SIGHT_IDLE, SIGHT_SNEAK, (motion - 0.25) / 0.35)
	return lerpf(SIGHT_SNEAK, SIGHT_RUN, (motion - 0.6) / 0.4)
