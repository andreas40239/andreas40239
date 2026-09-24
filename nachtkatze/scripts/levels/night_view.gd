extends CanvasLayer
class_name NightView
## Eingeschraenkte Sicht (ab Level 7): dunkelt das Bild ausserhalb eines
## Bereichs um die Katze ab. Liegt unter dem HUD, Anzeigen bleiben sichtbar.

const SHADER_PATH := "res://assets/shaders/night_view.gdshader"

var radius := 0.4
var darkness := 0.78

var _player: Node3D = null
var _rect: ColorRect = null
var _material: ShaderMaterial = null

func setup(player: Node3D, view_radius: float, view_darkness: float) -> void:
	_player = player
	radius = view_radius
	darkness = view_darkness

func _ready() -> void:
	layer = 0
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	_rect = ColorRect.new()
	_rect.name = "Dunkelheit"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)
	_update()

func _process(_delta: float) -> void:
	_update()

## Mittelpunkt des hellen Bereichs in Bildkoordinaten (0..1).
func get_center() -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var size := get_viewport().get_visible_rect().size
	if camera == null or _player == null or size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var screen := camera.unproject_position(_player.global_position + Vector3.UP * 0.2)
	return screen / size

func _update() -> void:
	var size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter("center", get_center())
	_material.set_shader_parameter("radius", radius)
	_material.set_shader_parameter("darkness", darkness)
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
