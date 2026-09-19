class_name Zones
extends RefCounted
## Zone palettes, obstacle tables and the friend roster.
##
## Zones cycle endlessly; a Coral Gate marks the entrance to the next one, so a
## steady run walks the whole list in roughly five minutes.

enum Obstacle { CRAB, SEAWEED, JELLYFISH, PUFFERFISH, ANCHOR, ANGLER, SEAGULL }

const FRIEND_SPECIES := ["turtle", "seahorse", "octopus", "ray"]

const FRIEND_NAMES := {
	"turtle": "Baby Turtle",
	"seahorse": "Baby Seahorse",
	"octopus": "Baby Octopus",
	"ray": "Baby Ray",
}

## Two-line rhymes shown when the daily Golden Friend is freed.
const FRIEND_RHYMES := {
	"turtle": "A little green turtle, as round as a plate,\nsays thank you for helping — you're never too late!",
	"seahorse": "A curly wee seahorse with bubbles for hair,\ngoes bobbing off gladly to somewhere out there.",
	"octopus": "Eight tiny arms give eight tiny waves,\nfor the bravest of bubbles and the kindest of saves.",
	"ray": "A soft little ray does a flap and a flip,\nand thanks you for freeing the tip of her tip!",
}

const DATA := [
	{
		"name": "Coral Gardens",
		"water_top": Color(0.42, 0.85, 0.90),
		"water_bottom": Color(0.11, 0.48, 0.66),
		"sand": Color(0.98, 0.86, 0.66),
		"far": Color(0.52, 0.78, 0.82),
		"mid": Color(0.96, 0.52, 0.55),
		"near": Color(1.0, 0.72, 0.45),
		"obstacles": [Obstacle.CRAB, Obstacle.SEAWEED],
		"critters": "parrotfish",
	},
	{
		"name": "Kelp Forest",
		"water_top": Color(0.55, 0.85, 0.62),
		"water_bottom": Color(0.07, 0.34, 0.31),
		"sand": Color(0.90, 0.82, 0.52),
		"far": Color(0.30, 0.56, 0.42),
		"mid": Color(0.18, 0.45, 0.30),
		"near": Color(0.85, 0.87, 0.42),
		"obstacles": [Obstacle.PUFFERFISH, Obstacle.ANCHOR, Obstacle.SEAWEED],
		"critters": "otter",
	},
	{
		"name": "Sunken Ship",
		"water_top": Color(0.40, 0.66, 0.84),
		"water_bottom": Color(0.13, 0.26, 0.46),
		"sand": Color(0.78, 0.68, 0.53),
		"far": Color(0.45, 0.50, 0.62),
		"mid": Color(0.62, 0.42, 0.30),
		"near": Color(0.93, 0.78, 0.50),
		"obstacles": [Obstacle.JELLYFISH, Obstacle.CRAB, Obstacle.ANCHOR],
		"critters": "manta",
	},
	{
		"name": "Deep Trench",
		"water_top": Color(0.42, 0.55, 0.88),
		"water_bottom": Color(0.20, 0.16, 0.45),
		"sand": Color(0.58, 0.55, 0.78),
		"far": Color(0.34, 0.30, 0.62),
		"mid": Color(0.45, 0.32, 0.70),
		"near": Color(0.62, 0.92, 0.95),
		"obstacles": [Obstacle.ANGLER, Obstacle.JELLYFISH, Obstacle.SEAWEED],
		"critters": "plankton",
	},
	{
		"name": "Surface Shine",
		"water_top": Color(0.85, 0.98, 1.0),
		"water_bottom": Color(0.30, 0.76, 0.90),
		"sand": Color(0.97, 0.92, 0.76),
		"far": Color(0.72, 0.92, 0.97),
		"mid": Color(0.55, 0.86, 0.94),
		"near": Color(1.0, 1.0, 1.0),
		"obstacles": [Obstacle.SEAGULL, Obstacle.PUFFERFISH, Obstacle.CRAB],
		"critters": "clouds",
	},
]


static func count() -> int:
	return DATA.size()


static func get_zone(index: int) -> Dictionary:
	return DATA[posmod(index, DATA.size())]


static func zone_name(index: int) -> String:
	return get_zone(index)["name"]
