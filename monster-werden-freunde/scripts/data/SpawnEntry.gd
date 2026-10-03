class_name SpawnEntry
extends Resource
## Ein Abschnitt einer Welle (GDD 9.2).

@export var monster_id: StringName
@export var count: int = 1
@export var spawn_interval: float = 1.5
@export var start_delay: float = 0.0
@export var path_id: StringName = &"main"
