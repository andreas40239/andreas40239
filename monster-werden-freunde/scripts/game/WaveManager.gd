class_name WaveManager
extends Node
## Spawnt Monster wellenweise (GDD 9.2). Die nächste Welle darf erst starten,
## wenn die Spawnliste der aktuellen Welle vollständig abgearbeitet ist.

signal monster_spawned(monster: Monster)
signal wave_started(index: int, total: int)
## Spawnliste der Welle 'index' (1-basiert) ist vollständig abgearbeitet.
signal wave_completed(index: int)

var waves: Array[WaveData] = []
## 0-basierter Index der aktuellen Welle (-1 = noch keine gestartet).
var current_wave: int = -1
var spawning := false
var _queue: Array[Dictionary] = []
var _timer := 0.0
var _spawn_func: Callable


## spawn_func: Callable(monster_id: StringName) -> Monster
func setup(level_waves: Array[WaveData], spawn_func: Callable) -> void:
	waves = level_waves
	_spawn_func = spawn_func
	current_wave = -1
	spawning = false


func total_waves() -> int:
	return waves.size()


func has_next_wave() -> bool:
	return current_wave + 1 < waves.size()


func start_next_wave() -> bool:
	if spawning or not has_next_wave():
		return false
	current_wave += 1
	_queue.clear()
	for entry in waves[current_wave].entries:
		for i in entry.count:
			var delay: float = entry.start_delay if i == 0 else entry.spawn_interval
			_queue.append({"id": entry.monster_id, "delay": delay})
	if _queue.is_empty():
		wave_started.emit(current_wave + 1, waves.size())
		wave_completed.emit(current_wave + 1)
		return true
	# Erste Kreatur einer Welle erscheint sofort (plus evtl. start_delay)
	_timer = _queue[0].delay
	spawning = true
	wave_started.emit(current_wave + 1, waves.size())
	return true


func _process(delta: float) -> void:
	if not spawning:
		return
	_timer -= delta
	while spawning and _timer <= 0.0:
		var item: Dictionary = _queue.pop_front()
		var m: Monster = _spawn_func.call(item.id)
		if m:
			monster_spawned.emit(m)
		if _queue.is_empty():
			spawning = false
			wave_completed.emit(current_wave + 1)
		else:
			_timer += float(_queue[0].delay)
