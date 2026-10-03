class_name WaveData
extends Resource
## Eine Welle: Spawn-Einträge werden der Reihe nach abgearbeitet (GDD 9.2).

@export var entries: Array[SpawnEntry] = []


func monster_count() -> int:
	var n := 0
	for e in entries:
		n += e.count
	return n
