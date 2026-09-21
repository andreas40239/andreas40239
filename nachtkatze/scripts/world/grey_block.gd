@tool
extends StaticBody3D
class_name GreyBlock
## Graubox-Baustein fuer Meilenstein 1: eine Kiste, deren Groesse und Farbe
## ueber den Inspektor gesetzt wird. Ersetzt spaeter das modulare Asset-Kit
## (GDD Abschnitt 8).

enum Kind { STRASSE, FASSADE, BALKON, DACH, PROP, ZAUN }

const COLORS := {
	Kind.STRASSE: Color(0.52, 0.52, 0.56),
	Kind.FASSADE: Color(0.80, 0.73, 0.60),
	Kind.BALKON: Color(0.68, 0.64, 0.55),
	Kind.DACH: Color(0.62, 0.50, 0.44),
	Kind.PROP: Color(0.52, 0.58, 0.52),
	Kind.ZAUN: Color(0.46, 0.50, 0.56),
}

@export var size := Vector3(2.0, 1.0, 2.0):
	set(value):
		size = value
		_apply()

@export var kind: Kind = Kind.STRASSE:
	set(value):
		kind = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if mesh_instance == null or collision == null:
		return
	# Eigene Ressourcen je Instanz, sonst teilen sich alle Bloecke eine Groesse.
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS.get(kind, Color.WEB_GRAY)
	# Flat-/Toon-Naehe schon in der Graubox: wenig Glanz, klare Flaechen.
	material.roughness = 0.95
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh_instance.set_surface_override_material(0, material)
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
