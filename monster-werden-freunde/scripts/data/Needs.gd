class_name Needs
extends RefCounted
## Bedürfnis-Typen der Monster (GDD Kap. 3). Jedes Monster hat genau ein primäres Bedürfnis.
## Ein Bedürfnis wird immer über Farbe, Icon UND Animation dargestellt (nie nur Farbe).

enum Type { HUNGRY, DIRTY, SAD, TIRED, HYPER }

const ICONS := {
	Type.HUNGRY: &"apple",
	Type.DIRTY: &"bubble",
	Type.SAD: &"note",
	Type.TIRED: &"moon",
	Type.HYPER: &"pinwheel",
}

const LABELS := {
	Type.HUNGRY: "hat Hunger",
	Type.DIRTY: "ist schmutzig",
	Type.SAD: "ist traurig",
	Type.TIRED: "ist müde",
	Type.HYPER: "ist überdreht",
}

const COLORS := {
	Type.HUNGRY: Color("ff7a59"),
	Type.DIRTY: Color("a7835c"),
	Type.SAD: Color("4f8fe8"),
	Type.TIRED: Color("a074e0"),
	Type.HYPER: Color("ffc93c"),
}


static func icon_for(need: int) -> StringName:
	return ICONS.get(need, &"heart")


static func label_for(need: int) -> String:
	return LABELS.get(need, "")


static func color_for(need: int) -> Color:
	return COLORS.get(need, Color.WHITE)
