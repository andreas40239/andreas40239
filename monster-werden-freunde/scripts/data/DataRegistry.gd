class_name DataRegistry
extends RefCounted
## Zentrale Liste aller datengetriebenen Inhalte (.tres-Resources).

const MONSTERS := {
	&"knurri": "res://data/monsters/knurri.tres",
	&"matschi": "res://data/monsters/matschi.tres",
	&"troepfli": "res://data/monsters/troepfli.tres",
	&"schlummi": "res://data/monsters/schlummi.tres",
	&"flitzi": "res://data/monsters/flitzi.tres",
}

const STATIONS := {
	&"seifenblasen": "res://data/stations/seifenblasen.tres",
	&"musikbox": "res://data/stations/musikbox.tres",
	&"keksstand": "res://data/stations/keksstand.tres",
	&"ventilator": "res://data/stations/ventilator.tres",
	&"ruhe": "res://data/stations/ruhe.tres",
}

## Reihenfolge der Stationskarten im HUD.
const STATION_ORDER: Array[StringName] = [&"seifenblasen", &"musikbox", &"keksstand", &"ventilator", &"ruhe"]

const LEVELS: Array[String] = [
	"res://data/levels/level_01.tres",
	"res://data/levels/level_02.tres",
	"res://data/levels/level_03.tres",
	"res://data/levels/level_04.tres",
	"res://data/levels/level_05.tres",
]

static var _cache: Dictionary = {}


static func _load(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func monster(id: StringName) -> MonsterData:
	return _load(MONSTERS[id]) as MonsterData


static func station(id: StringName) -> StationData:
	return _load(STATIONS[id]) as StationData


static func level(number: int) -> LevelData:
	return _load(LEVELS[number - 1]) as LevelData


static func level_count() -> int:
	return LEVELS.size()
