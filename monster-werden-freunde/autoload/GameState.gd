extends Node
## Laufzeit-Zustand eines Levels: Sonnenpunkte, Chaos, aktuelles Level, Bildschirmwechsel.

signal currency_changed(new_value: int)
signal chaos_changed(new_value: int, limit: int)
signal screen_requested(screen: StringName, params: Dictionary)

var currency: int = 0
var chaos: int = 0
var chaos_limit: int = 10
var current_level: int = 1


## Setzt Sonnenpunkte und Chaos für einen Levelstart zurück.
func reset_for_level(level: LevelData) -> void:
	current_level = level.number
	chaos_limit = level.chaos_limit
	set_currency(level.starting_currency)
	chaos = 0
	chaos_changed.emit(chaos, chaos_limit)


func set_currency(value: int) -> void:
	currency = maxi(0, value)
	currency_changed.emit(currency)


func can_afford(cost: int) -> bool:
	return currency >= cost


## Zieht 'cost' ab, wenn genug vorhanden ist. Gibt true bei Erfolg zurück.
func spend(cost: int) -> bool:
	if cost > currency:
		return false
	set_currency(currency - cost)
	return true


func earn(amount: int) -> void:
	set_currency(currency + amount)


func add_chaos(amount: int) -> void:
	chaos = mini(chaos + amount, chaos_limit)
	chaos_changed.emit(chaos, chaos_limit)


func is_chaos_full() -> bool:
	return chaos >= chaos_limit


## Wechselt den Bildschirm (wird vom ScreenRouter in Main.gd ausgeführt).
func goto_screen(screen: StringName, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)
