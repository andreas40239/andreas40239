# GODZILLA: Kaiju Lane Fighter

A 2.5D lane-based kaiju beat-'em-up for Android, built with **Godot 4.2** from the
[Game Design Document](../GODZILLA_Kaiju_Lane_Fighter_GDD.md) (MVP scope: Levels 1–3).

## MVP contents

- **3 levels** — Primeval Shores, Jungle Ruins, The Tyrant's Throne (march → arena → boss flow)
- **3-lane combat** — high / mid / ground with lane-coded threats
- **Enemies** — Raptor packs (rush + leap, scatter), Pteranodons (diving swoops),
  Ankylosaurus (armored front, tail-spin, grab it during recovery)
- **Military/hybrid enemies** — tanks (laser lock-on, shells), helicopters (lane strafes,
  homing missiles), jetpack raptors, shielded Mechagodzilla prototype. Tail-whip missiles back!
- **Bosses** — TYRANNOKING (bite / tail cyclone / roar, Blood Frenzy), SUPER X (colour-coded
  laser / missiles / shield / drones / gravity, self-destruct countdown), MECHAGODZILLA
  (plasma column, barrages, diamond coating, teleport grab, absolute-zero cannon, overdrive)
- **Gesture controls** — D-pad moves, swipes on the attack/jump buttons pick the move:
  - Tap **ATK**: tail whip (x3 = combo uppercut) · Hold: charged Atomic Breath
  - Swipe ATK ←/→: dash-claw that way · ↑: anti-air tail · ↓: ground pound
  - Tap **JMP**: jump · Swipe ↑: high leap · ↓: dive slam · ←/→: hop sideways
  - **NUKE**: 360° Nuclear Pulse (cooldown)
  - D-pad ←/→ walks and turns Godzilla; walking away from an attack blocks 40% of it
  - Walk into a stunned enemy to **grab**, tap ATK to throw
- **POWER UP screen** for kids: big icons (FIRE, CLAWS, HEALTH, SPEED, BLAST), 5 stars each,
  a green ➕ spends one gem. Every level cleared gives at least 1 gem (first clears give 1–5).
- One save slot, checkpoints per segment,
  mercy mode after 5 deaths, story cards, adaptive fin-glow "living HUD"
- All pixel art + SFX/music generated procedurally by `tools/gen_art.py`, `tools/gen_art_ext.py`
  and `tools/gen_audio.py`

## Desktop test keys

Arrows = move (left/right turns around) / lanes · Z = attack · A (hold) = atomic breath · Q/E/R = anti-air/pound/dash ·
X = jump · V = high leap · C = dive slam · Space = nuclear pulse

## Building the APK

1. Godot 4.2.2 + Android export templates
2. Editor Settings → Android SDK path (build-tools 34), JDK 17, debug keystore
3. `godot --headless --export-debug "Android" build/kaiju-lane-fighter.apk`

Regenerate assets with
`cd tools && python3 gen_art.py && python3 gen_art_ext.py && python3 gen_audio.py`
(requires `pillow` + `numpy`).

Smoke tests: `godot --headless tools/test_scene.tscn -- <level 1-8>` and
`godot --headless tools/move_scene.tscn` (walk-left regression test)
