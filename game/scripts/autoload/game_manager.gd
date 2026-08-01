extends Node

## Vertical-slice progression: 15 growth levels, no day/night cycle.
## Growth stage values (scale/speed/color) are computed from formulas
## rather than a hand-written table, since hand-authoring 15 entries
## doesn't scale well; the map's half-extent is derived the same way so
## world.gd and the enemy spawner can share one source of truth.

signal leveled_up(new_level: int)
signal satiety_changed(value: float, max_value: float)
signal player_caught

const MAX_LEVEL := 21
const SPIKES_LEVEL := 5
const TREX_LEVEL := 10
const GODZILLA_LEVEL := 20

const BASE_SATIETY := 90.0
const SATIETY_GROWTH := 35.0

const BASE_HALF_WIDTH := 450.0
const BASE_HALF_HEIGHT := 325.0
const WIDTH_GROWTH_PER_LEVEL := 130.0
const HEIGHT_GROWTH_PER_LEVEL := 95.0

const BASE_MAX_HEALTH := 100.0
const HEALTH_GROWTH_PER_LEVEL := 8.0
const BASE_BITE_DPS := 40.0
const BITE_DPS_PER_LEVEL := 2.5

const COLOR_ANCHORS := [
	[1, Color(0.35, 0.65, 0.35)],
	[5, Color(0.55, 0.45, 0.2)],
	[10, Color(0.45, 0.55, 0.4)],
	[15, Color(0.32, 0.38, 0.34)],
	[20, Color(0.22, 0.32, 0.22)],
]

var growth_level: int = 1
var satiety: float = 0.0
var run_complete: bool = false

func get_satiety_threshold() -> float:
	if growth_level >= MAX_LEVEL:
		return 0.0
	return BASE_SATIETY + (growth_level - 1) * SATIETY_GROWTH

func get_current_stage() -> Dictionary:
	return get_stage_for_level(growth_level)

func get_stage_for_level(level: int) -> Dictionary:
	return {
		"scale": 1.0 + (level - 1) * 0.11,
		"speed": 210.0 + (level - 1) * 9.0,
		"color": _stage_color(level),
		"has_spikes": level >= SPIKES_LEVEL,
		"is_trex": level >= TREX_LEVEL and level < GODZILLA_LEVEL,
		"is_godzilla": level >= GODZILLA_LEVEL,
	}

func get_max_health() -> float:
	return BASE_MAX_HEALTH + (growth_level - 1) * HEALTH_GROWTH_PER_LEVEL

func get_bite_dps() -> float:
	return BASE_BITE_DPS + growth_level * BITE_DPS_PER_LEVEL

func _stage_color(level: int) -> Color:
	for i in range(COLOR_ANCHORS.size() - 1):
		var a: Array = COLOR_ANCHORS[i]
		var b: Array = COLOR_ANCHORS[i + 1]
		if level >= a[0] and level <= b[0]:
			var t := float(level - int(a[0])) / float(int(b[0]) - int(a[0]))
			return (a[1] as Color).lerp(b[1], t)
	return COLOR_ANCHORS[COLOR_ANCHORS.size() - 1][1]

func get_map_half_extent() -> Vector2:
	return Vector2(
		BASE_HALF_WIDTH + (growth_level - 1) * WIDTH_GROWTH_PER_LEVEL,
		BASE_HALF_HEIGHT + (growth_level - 1) * HEIGHT_GROWTH_PER_LEVEL
	)

func add_satiety(amount: float) -> void:
	var threshold := get_satiety_threshold()
	if threshold <= 0.0:
		return
	satiety = clamp(satiety + amount, 0.0, threshold)
	satiety_changed.emit(satiety, threshold)

func can_level_up() -> bool:
	var threshold := get_satiety_threshold()
	return threshold > 0.0 and satiety >= threshold and growth_level < MAX_LEVEL

func level_up() -> void:
	if not can_level_up():
		return
	growth_level += 1
	satiety = 0.0
	if growth_level >= MAX_LEVEL:
		run_complete = true
	leveled_up.emit(growth_level)
	satiety_changed.emit(satiety, get_satiety_threshold())
	SaveManager.save_game()

func can_eat_rival(rival_level: int) -> bool:
	return growth_level > rival_level

func notify_player_caught() -> void:
	player_caught.emit()
