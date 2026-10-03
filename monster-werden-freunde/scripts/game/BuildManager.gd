class_name BuildManager
extends Node
## Bauplätze, Bauen, Verbessern und Verkaufen von Stationen inkl. Sonnenpunkte (GDD 2.2).

signal station_built(station: Station)
signal station_upgraded(station: Station)
signal station_sold(station: Station, refund: int)

const STATION_SCENE := preload("res://scenes/stations/StationBase.tscn")
const SELL_FACTOR := 0.75

var spots: Array[BuildSpot] = []
var stations: Array[Station] = []
var _spots_root: Node2D
var _stations_root: Node2D
var _projectiles_root: Node2D
var _fx_root: Node2D


func setup(spots_root: Node2D, stations_root: Node2D, projectiles_root: Node2D, fx_root: Node2D) -> void:
	_spots_root = spots_root
	_stations_root = stations_root
	_projectiles_root = projectiles_root
	_fx_root = fx_root


func create_spots(points: PackedVector2Array) -> void:
	for i in points.size():
		var s := BuildSpot.new()
		s.index = i
		s.position = points[i]
		_spots_root.add_child(s)
		spots.append(s)


func free_spot_at(p: Vector2, radius: float) -> BuildSpot:
	var best: BuildSpot = null
	var best_d := radius
	for s in spots:
		var d := s.position.distance_to(p + Vector2(0, 8))
		if s.is_free() and d <= best_d:
			best = s
			best_d = d
	return best


func station_at(p: Vector2, radius: float) -> Station:
	var best: Station = null
	var best_d := radius
	for st in stations:
		var d := minf((st.position + Vector2(0, -45)).distance_to(p), st.position.distance_to(p))
		if d <= best_d:
			best = st
			best_d = d
	return best


## Baut eine Station auf einem freien Platz. Zieht die Kosten ab. null bei Misserfolg.
func build(spot: BuildSpot, data: StationData) -> Station:
	if spot == null or data == null or not spot.is_free():
		return null
	if not GameState.spend(data.cost):
		return null
	var st: Station = STATION_SCENE.instantiate()
	st.position = spot.position
	st.setup(data, spot, _projectiles_root, _fx_root)
	st.invested = data.cost
	_stations_root.add_child(st)
	spot.station = st
	spot.selected = false
	stations.append(st)
	station_built.emit(st)
	return st


## Stufe 2: path = &"range" (+20 % Reichweite) oder &"power" (+25 % Wirkung).
func upgrade(st: Station, path: StringName) -> bool:
	if st == null or st.level >= 2:
		return false
	if not GameState.spend(st.data.upgrade_cost):
		return false
	st.invested += st.data.upgrade_cost
	st.apply_upgrade(path)
	station_upgraded.emit(st)
	return true


## Verkauft eine Station für 75 % der kumulierten Investition.
func sell(st: Station) -> int:
	if st == null or not stations.has(st):
		return 0
	var refund := st.get_sell_value()
	GameState.earn(refund)
	if st.spot:
		st.spot.station = null
	stations.erase(st)
	st.queue_free()
	station_sold.emit(st, refund)
	return refund


func pulse_free_spots() -> void:
	for s in spots:
		if s.is_free():
			s.pulse()


func first_free_spot(preferred: int = 0) -> BuildSpot:
	if preferred >= 0 and preferred < spots.size() and spots[preferred].is_free():
		return spots[preferred]
	for s in spots:
		if s.is_free():
			return s
	return null
