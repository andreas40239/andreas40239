extends RefCounted
class_name Palette
## Gemeinsame Farbpalette des Asset-Kits (GDD Abschnitt 9).
##
## Statt Texturen traegt jeder Eckpunkt seine Farbe. Der Alphakanal wird
## zweckentfremdet: er steuert, wie stark eine Flaeche leuchtet (Fenster,
## Laternen, Leuchtband). So kommt das ganze Kit mit einem Material aus.

## Baut eine Farbe mit Leuchtanteil.
static func glow(color: Color, strength: float) -> Color:
	return Color(color.r, color.g, color.b, strength)

# --- Bauten -----------------------------------------------------------------
const PUTZ_HELL := Color(0.87, 0.80, 0.66, 0.0)
const PUTZ_WARM := Color(0.82, 0.70, 0.52, 0.0)
const PUTZ_SCHATTEN := Color(0.62, 0.55, 0.45, 0.0)
const ZIEGEL_ROT := Color(0.66, 0.29, 0.20, 0.0)
const BETON := Color(0.58, 0.57, 0.55, 0.0)
const BETON_DUNKEL := Color(0.48, 0.47, 0.46, 0.0)
const ASPHALT := Color(0.62, 0.62, 0.66, 0.0)

# --- Material ---------------------------------------------------------------
const METALL := Color(0.55, 0.57, 0.62, 0.0)
const METALL_DUNKEL := Color(0.44, 0.46, 0.50, 0.0)
const HOLZ := Color(0.54, 0.38, 0.25, 0.0)
const STOFF_HELL := Color(0.88, 0.84, 0.76, 0.0)
const STOFF_STREIFEN := Color(0.78, 0.34, 0.28, 0.0)
const GLAS := Color(0.38, 0.52, 0.58, 0.0)

# --- Vegetation (Schwarzgruen, GDD Abschnitt 9) -----------------------------
const LAUB_DUNKEL := Color(0.20, 0.40, 0.26, 0.0)
const LAUB_MITTEL := Color(0.29, 0.51, 0.31, 0.0)
const LAUB_OLIVE := Color(0.44, 0.52, 0.31, 0.0)
const STAMM := Color(0.42, 0.32, 0.24, 0.0)
const BLUETE := Color(0.85, 0.45, 0.55, 0.0)

# --- Fahrzeuge --------------------------------------------------------------
const LACK_ROT := Color(0.58, 0.18, 0.18, 0.0)
const LACK_BLAU := Color(0.30, 0.44, 0.66, 0.0)
const LACK_WEISS := Color(0.80, 0.80, 0.78, 0.0)
const REIFEN := Color(0.20, 0.20, 0.23, 0.0)

# --- Spielobjekte -----------------------------------------------------------
const GRAETE := Color(0.94, 0.93, 0.86, 0.0)
const FISCH := Color(0.55, 0.74, 0.88, 0.0)
const NAPF := Color(0.86, 0.52, 0.24, 0.0)
const FUTTER := Color(0.72, 0.45, 0.30, 0.0)

# --- Leuchtendes ------------------------------------------------------------
## Fensterlicht, Laternen und das Leuchtband der Tankstelle.
const FENSTER_LICHT := Color(1.0, 0.82, 0.52, 1.1)
const LATERNE_LICHT := Color(1.0, 0.72, 0.38, 1.6)
const SCHEINWERFER := Color(1.0, 0.95, 0.80, 1.5)
const TANKSTELLE_GRUEN := Color(0.25, 0.95, 0.55, 1.2)
const KUPPEL := Color(0.52, 0.66, 0.68, 0.25)
