extends Node

## Vertical-slice progression: 3 growth levels, no day/night cycle.
## Growth stage data is kept here as a small inline table for now; if the
## full game later needs 10+ stages this can move to Resource/JSON files
## like the enemy data already does.

signal leveled_up(new_level: int)
signal satiety_changed(value: float, max_value: float)
signal player_caught

const MAX_LEVEL := 3

const SATIETY_THRESHOLDS := {
	1: 100.0,
	2: 150.0,
}

const GROWTH_STAGES := {
	1: {"scale": 1.0, "color": Color(0.35, 0.65, 0.35), "speed": 220.0},
	2: {"scale": 1.35, "color": Color(0.3, 0.55, 0.75), "speed": 250.0},
	3: {"scale": 1.75, "color": Color(0.75, 0.4, 0.25), "speed": 280.0},
}

var growth_level: int = 1
var satiety: float = 0.0
var run_complete: bool = false

func get_satiety_threshold() -> float:
	return SATIETY_THRESHOLDS.get(growth_level, 0.0)

func get_current_stage() -> Dictionary:
	return GROWTH_STAGES[growth_level]

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
