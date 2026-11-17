extends SceneTree
## Prüft den Wohnungsgenerator über viele Seeds:
##   godot --headless --path . --script tests/gen_test.gd

func _init() -> void:
	var total_fails := 0
	for li in Cfg.LEVELS.size():
		var cfg: Dictionary = Cfg.LEVELS[li]
		var fails := 0
		var min_spots := 999
		var min_open := 999
		var n := 300 if li == 0 else 120
		for s in range(1, n + 1):
			var apt := ApartmentGen.new()
			if not apt.generate(s, cfg):
				fails += 1
				continue
			var spots := 0
			for f in apt.furniture:
				if f.hide > 0:
					spots += 1
					if f.access.is_empty():
						fails += 1
			if li == 0:
				var types := {}
				for r in apt.rooms:
					types[r.type] = true
				if not (types.has(ApartmentGen.RoomType.BEDROOM) and types.has(ApartmentGen.RoomType.BATH) and types.has(ApartmentGen.RoomType.KITCHEN)):
					fails += 1
			# jede freie Zelle muss von jeder anderen erreichbar sein
			var nav := Nav.new()
			nav.setup(apt)
			var first: Vector2i = nav.free[0]
			for c in nav.free:
				if c != first and nav.astar.get_point_path(nav._id(first.x, first.y), nav._id(c.x, c.y)).is_empty():
					fails += 1
					break
			min_spots = mini(min_spots, spots)
			min_open = mini(min_open, apt.openings.size())
		print("GENTEST %s seeds=%d fails=%d min_spots=%d min_openings=%d" % [cfg.name, n, fails, min_spots, min_open])
		total_fails += fails
	quit(0 if total_fails == 0 else 1)
