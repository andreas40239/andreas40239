extends SceneTree
## Prüft den Wohnungsgenerator über viele Seeds:
##   godot --headless --path . --script tests/gen_test.gd

func _init() -> void:
	var cfg := {"width": 22, "height": 16, "extra_rooms": 2}
	var fails := 0
	var min_spots := 99
	var min_open := 99
	for s in range(1, 301):
		var apt := ApartmentGen.new()
		if not apt.generate(s, cfg):
			fails += 1
			continue
		var types := {}
		for r in apt.rooms:
			types[r.type] = true
		var cap := 0
		var spots := 0
		for f in apt.furniture:
			if f.hide > 0:
				spots += 1
				cap += f.hide
				if f.access.is_empty():
					fails += 1
		if not (types.has(ApartmentGen.RoomType.BEDROOM) and types.has(ApartmentGen.RoomType.BATH) and types.has(ApartmentGen.RoomType.KITCHEN)):
			fails += 1
		# jede freie Zelle muss von jeder anderen erreichbar sein
		var nav := Nav.new()
		nav.setup(apt)
		var a := Nav.center(nav.free[0])
		for c in nav.free:
			if c != nav.free[0] and nav.astar.get_point_path(nav._id(nav.free[0].x, nav.free[0].y), nav._id(c.x, c.y)).is_empty():
				fails += 1
				break
		min_spots = mini(min_spots, spots)
		min_open = mini(min_open, apt.openings.size())
	print("GENTEST seeds=300 fails=%d min_spots=%d min_openings=%d" % [fails, min_spots, min_open])
	quit(0 if fails == 0 else 1)
