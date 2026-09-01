extends Node
## Central input signal bus (GDD 3, 11.6).
## TouchControls (and keyboard fallback) translate raw input into these
## signals; the Player consumes them. "D-pad = where I stand,
## button swipes = how I hit."

signal lane_up
signal lane_down
signal attack_tap
signal attack_charge_start
signal attack_charge_release
signal attack_swipe(dir: Vector2)  # RIGHT=dash-claw, UP=anti-air, DOWN=ground pound
signal jump_tap
signal jump_swipe(dir: Vector2)    # UP=high leap, DOWN=dive slam
signal special_tap

# Held d-pad state, polled by the player for walking/blocking.
var move_axis := 0.0   # -1 back, +1 forward
