class_name TutorialStep
extends Resource
## Ein Tutorial-Hinweis. Wird angezeigt, bis das Ereignis 'trigger' eintritt.
## trigger: "spot_selected", "station_built", "station_built:<id>", "wave_started",
##          "station_selected", "station_upgraded", "time:<sekunden>"
## highlight: "", "spot:<index>", "card:<station_id>", "start", "station", "upgrade", "speed"

@export_multiline var text: String = ""
@export var trigger: String = ""
@export var highlight: String = ""
