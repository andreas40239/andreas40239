class_name HelpEffect
extends RefCounted
## Ein Hilfs-Effekt, den eine Station auf ein Monster anwendet (GDD 8.4).
## Es gibt keinen Schaden: der Effekt verringert nur das Bedürfnis (need_value).

## Needs.Type -> Stärke
var strengths: Dictionary = {}
## Stärke für Monster mit unpassendem Bedürfnis ("hilft nur ein bisschen").
var fallback_amount: float = 0.0
var tag: StringName
var slow_amount: float = 0.0
var slow_duration: float = 0.0


func helps(need: int) -> bool:
	return strengths.has(need)


func amount_for(need: int) -> float:
	return float(strengths.get(need, fallback_amount))


## Erzeugt einen Effekt mit fester Stärke für genau ein Bedürfnis (praktisch für Tests).
static func simple(need: int, amount: float, effect_tag: StringName = &"") -> HelpEffect:
	var e := HelpEffect.new()
	e.strengths[need] = amount
	e.tag = effect_tag
	return e
