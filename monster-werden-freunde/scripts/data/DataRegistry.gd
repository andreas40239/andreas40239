class_name DataRegistry
extends RefCounted
## Zentrale Liste aller datengetriebenen Inhalte (.tres-Resources).

const MONSTERS := {
	&"knurri": "res://data/monsters/knurri.tres",
	&"matschi": "res://data/monsters/matschi.tres",
	&"troepfli": "res://data/monsters/troepfli.tres",
	&"schlummi": "res://data/monsters/schlummi.tres",
	&"flitzi": "res://data/monsters/flitzi.tres",
	&"elektro": "res://data/monsters/elektro.tres",
	&"fluegel": "res://data/monsters/fluegel.tres",
	&"bibber": "res://data/monsters/bibber.tres",
	&"flocki": "res://data/monsters/flocki.tres",
}

const STATIONS := {
	&"seifenblasen": "res://data/stations/seifenblasen.tres",
	&"musikbox": "res://data/stations/musikbox.tres",
	&"keksstand": "res://data/stations/keksstand.tres",
	&"ventilator": "res://data/stations/ventilator.tres",
	&"ruhe": "res://data/stations/ruhe.tres",
	&"batterie": "res://data/stations/batterie.tres",
	&"fluegelladen": "res://data/stations/fluegelladen.tres",
	&"disco": "res://data/stations/disco.tres",
	&"kakao": "res://data/stations/kakao.tres",
	&"schneemann": "res://data/stations/schneemann.tres",
}

## Reihenfolge der Stationskarten im HUD.
const STATION_ORDER: Array[StringName] = [&"seifenblasen", &"musikbox", &"keksstand", &"ventilator", &"ruhe",
	&"batterie", &"fluegelladen", &"kakao", &"schneemann", &"disco"]

## Welten: Name, Thema und Level-Nummern.
const WORLDS: Array[Dictionary] = [
	{"name": "Sonnental", "theme": &"meadow", "levels": [1, 2, 3, 4, 5]},
	{"name": "Strand und Meer", "theme": &"beach", "levels": [6, 7, 8, 9, 10]},
	{"name": "Schnee und Berge", "theme": &"snow", "levels": [11, 12, 13, 14, 15]},
]

const LEVELS: Array[String] = [
	"res://data/levels/level_01.tres",
	"res://data/levels/level_02.tres",
	"res://data/levels/level_03.tres",
	"res://data/levels/level_04.tres",
	"res://data/levels/level_05.tres",
	"res://data/levels/level_06.tres",
	"res://data/levels/level_07.tres",
	"res://data/levels/level_08.tres",
	"res://data/levels/level_09.tres",
	"res://data/levels/level_10.tres",
	"res://data/levels/level_11.tres",
	"res://data/levels/level_12.tres",
	"res://data/levels/level_13.tres",
	"res://data/levels/level_14.tres",
	"res://data/levels/level_15.tres",
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



static func world_count() -> int:
	return WORLDS.size()


## Welt (1-basiert), zu der ein Level gehört.
static func world_of_level(number: int) -> int:
	for i in WORLDS.size():
		if WORLDS[i]["levels"].has(number):
			return i + 1
	return 1


static func world_levels(world: int) -> Array:
	return WORLDS[world - 1]["levels"]


static func world_name(world: int) -> String:
	return WORLDS[world - 1]["name"]


static func world_theme(world: int) -> StringName:
	return WORLDS[world - 1]["theme"]
