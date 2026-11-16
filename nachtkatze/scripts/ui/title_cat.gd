extends Node3D
## Die Katze auf dem Startbild (GDD Abschnitt 12): sitzt als Silhouette auf dem
## Dach und blickt zum angestrahlten Kirchturm.

@export var silhouette: Material

func _ready() -> void:
	var rig := CreatureRig.new()
	rig.name = "Figur"
	add_child(rig)
	rig.setup(CreatureRig.Preset.SPIELERKATZE)
	rig.play(&"sit")
	rig.rotation.y = PI
	# Die Pfoten sollen auf der Dachkante stehen, nicht darin.
	rig.position.y = 0.21
	if silhouette != null:
		for mesh in rig.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = silhouette
