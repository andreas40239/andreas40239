@tool
extends Area3D
class_name BalanceWire
## Stromleitung zum Balancieren (GDD Abschnitt 2, ab Level 5).
##
## Die Leitung haengt zwischen zwei Masten durch. Faellt die Katze von oben auf
## sie, balanciert sie darauf - langsamer als am Boden, Hunde erreichen sie
## dort nicht. Sichtbar ist sie ueber das Kit-Bauteil STROMLEITUNG; diese Zone
## liefert nur die Hoehe entlang der Leitung.

## Abstand der beiden Masten (entspricht dem Kit-Bauteil).
@export var span := 8.0:
	set(value):
		span = value
		_apply()
## Durchhang in der Mitte.
@export var sag := 0.5:
	set(value):
		sag = value
		_apply()

func _ready() -> void:
	add_to_group("balance")
	collision_layer = 4    # Kletterzone - der Kletterfuehler der Katze sieht sie
	collision_mask = 0
	monitoring = false
	monitorable = true
	_apply()

## Liegt diese Stelle (Weltkoordinate) ueber der Leitung?
func covers(x: float) -> bool:
	return absf(x - global_position.x) <= span * 0.5

## Hoehe der Leitung an einer Stelle - folgt dem Durchhang wie das Mesh.
func height_at(x: float) -> float:
	var t := clampf((x - (global_position.x - span * 0.5)) / span, 0.0, 1.0)
	return global_position.y - sag * sin(t * PI)

func _apply() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision == null:
		return
	# Von knapp unter dem tiefsten Punkt bis gut ueber die Aufhaengung.
	var top := 1.0
	var bottom := -sag - 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(span, top - bottom, 1.0)
	collision.shape = shape
	collision.position = Vector3(0.0, (top + bottom) * 0.5, 0.0)
