class_name Needs
extends RefCounted
## Bedürfnis-Typen der Monster (GDD Kap. 3). Jedes Monster hat genau ein primäres Bedürfnis.
## Ein Bedürfnis wird immer über Farbe, Icon UND Animation dargestellt (nie nur Farbe).

enum Type { HUNGRY, DIRTY, SAD, TIRED, HYPER, CHARGE, FLY, COLD, LONELY }

const ICONS := {
	Type.HUNGRY: &"apple",
	Type.DIRTY: &"bubble",
	Type.SAD: &"note",
	Type.TIRED: &"moon",
	Type.HYPER: &"pinwheel",
	Type.CHARGE: &"battery",
	Type.FLY: &"wing",
	Type.COLD: &"snowflake",
	Type.LONELY: &"friends",
}

const LABELS := {
	Type.HUNGRY: "hat Hunger",
	Type.DIRTY: "ist schmutzig",
	Type.SAD: "ist traurig",
	Type.TIRED: "ist müde",
	Type.HYPER: "ist überdreht",
	Type.CHARGE: "ist ganz leer",
	Type.FLY: "möchte fliegen",
	Type.COLD: "friert",
	Type.LONELY: "ist einsam",
}

const COLORS := {
	Type.HUNGRY: Color("ff7a59"),
	Type.DIRTY: Color("a7835c"),
	Type.SAD: Color("4f8fe8"),
	Type.TIRED: Color("a074e0"),
	Type.HYPER: Color("ffc93c"),
	Type.CHARGE: Color("3cc6a0"),
	Type.FLY: Color("ff8fb1"),
	Type.COLD: Color("7fc4f5"),
	Type.LONELY: Color("b8a6e8"),
}


static func icon_for(need: int) -> StringName:
	return ICONS.get(need, &"heart")


## Übersetzter Text, z. B. "hat Hunger".
static func label_for(need: int) -> String:
	return TranslationServer.translate(LABELS.get(need, ""))


static func color_for(need: int) -> Color:
	return COLORS.get(need, Color.WHITE)
