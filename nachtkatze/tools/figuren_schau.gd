extends Node3D
## Schauszene fuer die Figuren: jede Figur in jeder Animation nebeneinander.
## Dient zum Sichten der Posen (GDD Abschnitt 10).
##
## Bilder: xvfb-run godot --rendering-driver opengl3 --path nachtkatze \
##           --resolution 1600x900 res://tools/screenshot.tscn -- figuren

const SPACING := 1.15
const ROW_SPACING := 1.6

## Je Reihe: Figur, Massstab und die Animationen (Name, Parameter).
const ROWS := [
	{"preset": CreatureRig.Preset.SPIELERKATZE, "scale": 1.0, "animations": [
		["idle", {}], ["run", {"move_speed": 1.0}], ["jump", {"vertical_speed": 6.0}],
		["jump", {"vertical_speed": -6.0}], ["climb", {"climb_speed": 1.0}], ["hang", {}],
		["balance", {"move_speed": 0.7}], ["hurt", {}], ["victory", {}], ["dead", {}],
		["idle", {"overlay": "eat"}], ["idle", {"overlay": "land"}]]},
	{"preset": CreatureRig.Preset.REVIERKATZE, "scale": 1.0, "animations": [
		["sit", {}], ["walk", {"move_speed": 1.0}], ["warn", {}], ["attack", {"vertical_speed": 3.0}],
		["retreat", {"move_speed": 1.0}], ["idle", {}]]},
	{"preset": CreatureRig.Preset.KLEINER_HUND, "scale": 0.8, "animations": [
		["sleep", {}], ["rest", {}], ["walk", {"move_speed": 1.0}], ["warn", {}],
		["chase", {"move_speed": 1.0}], ["bark_up", {}], ["retreat", {"move_speed": 1.0}]]},
	{"preset": CreatureRig.Preset.GROSSER_HUND, "scale": 1.25, "animations": [
		["sleep", {}], ["rest", {}], ["walk", {"move_speed": 1.0}], ["warn", {}],
		["chase", {"move_speed": 1.0}], ["bark_up", {}], ["retreat", {"move_speed": 1.0}]]},
]

var rigs: Array[CreatureRig] = []
var row_nodes: Array[Node3D] = []

func _ready() -> void:
	AssetKit.configure_material()
	AssetKit.set_sun(Vector3(0.30, -0.78, -0.55), Color(1.0, 0.96, 0.88))
	for row_index in ROWS.size():
		var row: Dictionary = ROWS[row_index]
		var row_node := Node3D.new()
		row_node.name = "Reihe%d" % row_index
		row_node.position = Vector3(0, -float(row_index) * ROW_SPACING, 0)
		add_child(row_node)
		row_nodes.append(row_node)
		var animations: Array = row["animations"]
		for column in animations.size():
			var entry: Array = animations[column]
			var holder := Node3D.new()
			holder.position = Vector3(float(column) * SPACING, 0, 0)
			holder.scale = Vector3.ONE * float(row["scale"])
			row_node.add_child(holder)
			var rig := CreatureRig.new()
			holder.add_child(rig)
			rig.setup(row["preset"])
			rig.play(StringName(entry[0]))
			var params: Dictionary = entry[1]
			rig.move_speed = params.get("move_speed", 0.0)
			rig.vertical_speed = params.get("vertical_speed", 0.0)
			rig.climb_speed = params.get("climb_speed", 0.0)
			if params.has("overlay"):
				rig.set_meta("overlay", StringName(params["overlay"]))
			rigs.append(rig)
			var label := Label3D.new()
			label.text = String(entry[0]) + (" +" + String(params["overlay"]) if params.has("overlay") else "") \
				+ (" ↑" if params.get("vertical_speed", 0.0) > 0.0 else "") \
				+ (" ↓" if params.get("vertical_speed", 0.0) < 0.0 else "")
			label.font_size = 28
			label.pixel_size = 0.004
			label.position = Vector3(float(column) * SPACING, -0.62, 0)
			label.modulate = Color(0.1, 0.1, 0.12)
			row_node.add_child(label)

## Loest die einmaligen Ueberlagerungen aus (kurz vor der Aufnahme).
func trigger_overlays() -> void:
	for rig in rigs:
		if rig.has_meta("overlay"):
			rig.trigger(rig.get_meta("overlay"))
