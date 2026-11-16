class_name HidingSpot
extends Node3D
## Ein Versteck: Bett (2 Plätze), Schrank (1), Tisch (1).

var kind := "bed"            # bed | wardrobe | cabinet | table
var capacity := 1
var yaw := 0.0               # Ausrichtung des Möbels
var rect := Rect2i()
var access: Array[Vector3] = []   # freie Zellen neben dem Möbel (Weltkoordinaten)
var slots: Array = []             # Character oder null je Platz
var sniffed_by = null             # Zombie, der gerade am Versteck schnüffelt
var eyes: Node3D = null           # leuchtende Augen (nur für Menschen sichtbar)
var doors: Array[Node3D] = []     # Schranktüren (wackeln beim Ein-/Aussteigen)
var _wobble := 0.0


func label() -> String:
	match kind:
		"bed": return "Bett"
		"table": return "Tisch"
		_: return "Schrank"


func count() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func occupants() -> Array:
	return slots.filter(func(s): return s != null)


func has_room() -> bool:
	return count() < capacity


## Trägt die Figur ein und liefert den Platz-Index (-1 = voll).
func add(c) -> int:
	while slots.size() < capacity:
		slots.append(null)
	for i in capacity:
		if slots[i] == null:
			slots[i] = c
			return i
	return -1


func remove(c) -> void:
	for i in slots.size():
		if slots[i] == c:
			slots[i] = null


func nearest_access(from: Vector3) -> Vector3:
	var best := access[0]
	var bd := INF
	for a in access:
		var d := a.distance_squared_to(Vector3(from.x, 0, from.z))
		if d < bd:
			bd = d
			best = a
	return best


## Abstand eines Punktes zur Grundfläche des Möbels.
func distance_to(p: Vector3) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - p.z, 0.0), p.z - rect.end.y)
	return sqrt(dx * dx + dz * dz)


## Position und Pose für den i-ten Insassen.
func slot_transform(i: int) -> Dictionary:
	var b := Basis(Vector3.UP, yaw)
	match kind:
		"bed":
			var off := Vector3(-0.42 + 0.84 * i, 0.0, 0.8)
			return {"pos": global_position + b * off, "yaw": yaw, "pose": "lie"}
		"table":
			return {"pos": global_position, "yaw": yaw, "pose": "crouch"}
		_:
			return {"pos": global_position + b * Vector3(0, 0, -0.1), "yaw": yaw, "pose": "inside"}


func wobble() -> void:
	_wobble = 0.5


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble = maxf(0.0, _wobble - delta)
		var a := sin(_wobble * 30.0) * _wobble * 0.5
		for i in doors.size():
			doors[i].rotation.y = a * (1.0 if i == 0 else -1.0)
