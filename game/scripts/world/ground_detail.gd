extends Node2D

## Scatters procedural ground clutter (grass tufts, pebbles, dirt patches)
## across the whole possible map area, so there's always something on
## screen to read the player's motion against instead of a single flat
## background color. Laid out once with a fixed seed across
## GameManager.get_max_map_half_extent() (not the current, smaller extent)
## so nothing reshuffles as the map grows on level-up - it's simply
## revealed further out as the camera limits expand.

const SEED := 1337
const COUNT := 420
const DEN_CLEAR_RADIUS := 100.0

func _ready() -> void:
	z_index = -9
	queue_redraw()

func _draw() -> void:
	var half: Vector2 = GameManager.get_max_map_half_extent()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in COUNT:
		var pos := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		if pos.length() < DEN_CLEAR_RADIUS:
			continue
		match rng.randi_range(0, 2):
			0:
				_draw_tuft(pos, rng)
			1:
				_draw_pebble(pos, rng)
			_:
				_draw_patch(pos, rng)

func _draw_tuft(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(6.0, 12.0)
	var col := Color(0.3, 0.55, 0.28).lerp(Color(0.44, 0.63, 0.3), rng.randf())
	for i in 3:
		var off: float = (i - 1) * 2.6
		draw_line(pos + Vector2(off, 0.0), pos + Vector2(off * 1.4, -h), col, 1.3)

func _draw_pebble(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(2.0, 4.5)
	draw_circle(pos, r, Color(0.55, 0.5, 0.42, 0.8))

func _draw_patch(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(10.0, 22.0)
	draw_circle(pos, r, Color(0.8, 0.72, 0.5, 0.3))
