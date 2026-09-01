# GODZILLA: KAIJU LANE FIGHTER
## Comprehensive Game Design Document
### Version 1.0 | Target Engine: Godot 4.2+ | Target Platform: Android (Phone + Tablet)

---

## 1. EXECUTIVE SUMMARY

**Genre:** 2.5D Side-Scrolling Beat-'Em-Up / Lane-Based Fighter Hybrid  
**Inspiration:** *Golden Axe II* (beat-'em-up flow, grab-throw, crowd control) × *Street Fighter II* (combo depth, special inputs, boss pattern recognition)  
**Core Fantasy:** You are a 100-meter tall force of nature. The controls are simple because *you* are the weapon. Depth comes from deciding whether to brawl (crowd-clearing) or precision-fight (spacing and punishes) based on what each lane throws at you.

**Unique Selling Point:** A 3-lane auto-scrolling beat-'em-up where combat happens in discrete horizontal lanes (ground/mid/high). Touch-optimized gesture controls separate movement (D-pad) from attack type (button swipes), eliminating the motion-input problem that plagues fighting games on mobile.

**Target Audience:** Retro arcade fans, kaiju enthusiasts, mobile gamers who want depth without complexity.

---

## 2. CORE GAMEPLAY LOOP

### 2.1 Game Structure
Each level is a **single continuous auto-scroll** broken into three segments:

| Segment | Duration | Purpose |
|---------|----------|---------|
| **March** | ~40% of level | Auto-scroll forward. Light enemy density. Build meter, learn rhythm. Background parallax sets mood. |
| **Arena** | ~40% of level | Screen locks. 2–3 waves spawn from edges. Kill all waves to proceed. Spend upgrades here. |
| **Boss** | ~20% of level | Dedicated boss arena. Screen stops. Pattern-based fight with phase transitions. |

**Non-boss levels (1, 2, 4, 5, 7):** March → Arena → March → Arena → Exit gate.  
**Boss levels (3, 6, 8):** Short march (20%) → Single large arena → Boss fight.

### 2.2 The 3-Lane System
All action occurs in 3 horizontal lanes. This removes pixel-perfect platforming and makes threats readable on small screens.

| Lane | Position | Typical Enemies |
|------|----------|-----------------|
| **High** | Top third | Pteranodons, helicopters, jetpack raptors |
| **Mid** | Center | T-Rex (occupies mid+ground), Mechagodzilla |
| **Ground** | Bottom third | Raptors, tanks, Ankylosaurus |

**Visual Coding:**
- Ground lane = subtle warm tint (brown/orange ground texture)
- Mid lane = neutral gray
- High lane = subtle blue sky gradient
- Enemies have lane-matching highlight colors (warm = ground, cool = high)

### 2.3 Camera
- Fixed distance, auto-scrolls horizontally at slow pace during march
- Locks during arena and boss segments
- No vertical scrolling — all action fits in a 16:9 or 19.5:9 band
- Background parallax: 4 layers (sky 0×, far city 0.2×, near rubble 0.6×, foreground 1.2×)

---

## 3. CONTROL SCHEME

### 3.1 Philosophy
**"D-pad = where I stand, button swipes = how I hit."**

Motion inputs on a touch D-pad are broken because the D-pad is already committed to lane movement. Down→Right+Attack reads as "move down, move right, attack" — not a special move. All directional attacks are executed via **gestures on the action buttons**, never the D-pad.

### 3.2 Layout (Phone Screen)
- **Bottom-left:** D-pad (110px square, 36px buttons)
- **Bottom-right:** Attack (48px red circle) + Jump (48px blue circle) stacked, Special (56px purple circle) below

### 3.3 D-Pad Inputs
| Input | Action |
|-------|--------|
| Up | Switch to higher lane (ground→mid→high) |
| Down | Switch to lower lane (high→mid→ground) |
| Left | Move backward within current lane |
| Right | Move forward within current lane |

### 3.4 Action Button Inputs
| Input | Action | Description |
|-------|--------|-------------|
| **Tap Attack** | Tail whip | Fast, wide arc, hits behind too. Default attack. |
| **Tap Attack ×3** | 3-hit combo → uppercut | Rapid tap to juggle enemies. |
| **Hold Attack** | Charged Atomic Breath | Drains energy meter. Release at desired charge level. |
| **Swipe Right on Attack** | Dash-claw | Lunge forward across lane to close gap. |
| **Swipe Up on Attack** | Anti-air tail | Hits high lane. Counters aerial enemies. |
| **Swipe Down on Attack** | Ground pound | Smashes low lane. Knocks down ground enemies. |
| **Tap Jump** | Standard jump | Crosses 2 lanes, knocks down on landing. |
| **Swipe Up on Jump** | High leap | Crosses all 3 lanes. Escape ground swarms. |
| **Swipe Down on Jump** | Dive slam | Drop from any lane to ground with shockwave. |
| **Tap Special** | 360° Nuclear Pulse | Clears immediate lane. Cooldown-based. |
| **Attack + Jump** | 360° Nuclear Pulse | Alternative input for accessibility. |
| **Block** | Hold back on D-pad | Reduces damage by 40% (60% with upgrade). |
| **Grab** | Walk into stunned enemy | Lift and hurl. Directional throw (left/right). |

### 3.5 Input Buffering
- Buffer last 0.15 seconds of directional input for special moves
- Swipe threshold: 15px minimum on a 48px button
- If tap has slight drift (< 15px), register as tap — not swipe

---

## 4. PLAYER CHARACTER (GODZILLA)

### 4.1 Base Stats
| Stat | Base Value | Notes |
|------|------------|-------|
| HP | 100 | Upgradeable to 150 |
| Atomic Meter | 100 | Upgradeable to 150 |
| Melee Damage | 10 per hit | Upgradeable |
| Move Speed | 1 lane / 0.3s | Upgradeable |
| Grab Range | Adjacent pixel | Upgradeable to 1.4× |

### 4.2 Sprite Specs
| Property | Value |
|----------|-------|
| Base size | 32×40 pixels |
| In-engine render | 128×160 (4× scale) |
| Outline | 1px black on all sprites |
| Colors | Skin #4a6741, Shadow #3d5236, Fin glow #5eead4, Fin core #2dd4bf, Eyes #fbbf24, Claws #e5e7eb |
| Animation FPS | 10–12 fps (hold each frame 3–4 engine frames) |

### 4.3 Animation List
| Animation | Frames | Duration | Notes |
|-----------|--------|----------|-------|
| Idle | 2–4 | 0.8s loop | Chest expands 1px, tail sways 2px |
| Walk | 4 | 0.6s | Exaggerated leg lift, 3px up, stomp with screen shake |
| Tail whip | 3 | 0.15s | Wind-up (tail back 4px) → snap (forward 6px, blur frame) → recovery |
| Jump | 4 | 0.25s | Crouch 2px → launch 4px up → apex → land with dust cloud |
| Atomic breath | 6 | 1.0s + hold | Fins flash white (2 frames) → mouth opens → beam extends 1px/frame → hold → fade |
| Hit/Hurt | 2 | 0.1s | Flash white, knockback 4px |
| Grab | 3 | 0.2s | Arm extends → clamp → hold |
| Throw | 3 | 0.2s | Lift → arc → release |

### 4.4 Visual State Communication
Godzilla's dorsal fins ARE the HUD:
- **Dim blue** = Low atomic meter
- **Bright pulsing blue** = Meter full, special ready
- **White-hot** = Charging atomic breath
- **Green pulse** = Regenerating HP (if upgrade taken)
- **Gray** = Hurt, low HP

---

## 5. ENEMY ROSTER

### 5.1 Phase 1: Jurassic (Levels 1–4)

#### Raptor Pack
| Property | Value |
|----------|-------|
| Lane | Ground |
| HP | Low (25%) |
| Damage | Low (30%) |
| Speed | High (85%) |
| Behavior | Rushes from edge, leaps at Godzilla. If one is hit, others scatter briefly then re-engage from different angles. Can climb onto each other to reach mid lane. |
| Counter | Tail whip (wide arc hits whole pack). Ground pound for clusters. Grab-throw into pack for chain knockdown. |

#### Pteranodon
| Property | Value |
|----------|-------|
| Lane | High |
| HP | Low (20%) |
| Damage | Medium (50%) |
| Speed | High (90%) |
| Behavior | Hovers in high lane, swoops down in diagonal arc to ground lane. 2s cooldown after dive. Groups of 2–3 create crossing patterns. |
| Counter | Anti-air tail (swipe up on attack). Jump-claw as they descend. Atomic fireball during swoop. |

#### Ankylosaurus
| Property | Value |
|----------|-------|
| Lane | Ground |
| HP | High (80%) |
| Damage | Medium (55%) |
| Speed | Slow (20%) |
| Behavior | Slow advance. Every 3s, spins 180° and whips tail club — hits behind and stuns Godzilla for 1s. Frontal attacks bounce off armored back. Blocks lane until defeated. |
| Counter | Walk behind (turns slowly) and grab-throw. Bait tail spin, then dash-claw from behind during recovery. Atomic breath pierces armor. |

#### Tyrannosaurus (Mini-Boss)
| Property | Value |
|----------|-------|
| Lane | Ground + Mid (occupies 2 lanes) |
| HP | Very High (100%) |
| Damage | High (85%) |
| Speed | Medium (45%) |
| Behavior | **Bite:** lunges forward in ground lane (dodge to mid). **Tail sweep:** spins, hits mid+high (drop to ground). **Roar:** 0.5s windup, stuns all lanes for 1s — interrupt with charged atomic breath. |
| Counter | Lane-dance between attacks. Flank after bite. Save atomic breath for roar windup. Grab smaller enemies and throw at head for stun. |

### 5.2 Phase 2: Military (Levels 5–8)

#### Tank Column
| Property | Value |
|----------|-------|
| Lane | Ground |
| HP | High (75%) |
| Damage | High (80%) |
| Speed | None (0%) |
| Behavior | Stays at screen edge. Fires shells every 2.5s with 0.8s red laser lock-on warning. Shells arc and hit ground+mid. Groups of 2–3 create overlapping fire. Can be grabbed and wielded as melee weapon for 10s. |
| Counter | Jump over shells (arc low). Dash-claw to close distance. Grab and throw into other tanks for chain explosion. Wield as club. |

#### Attack Helicopter
| Property | Value |
|----------|-------|
| Lane | Mid |
| HP | Medium (45%) |
| Damage | Medium (55%) |
| Speed | High (80%) |
| Behavior | **Machine gun:** sweeps a lane for 1s — dodge up/down. **Missile volley:** 3 homing missiles track Godzilla for 2s, then dive to current lane. Missiles can be swatted back with tail whip. |
| Counter | Anti-air tail when hovering. Swat missiles back. Atomic fireball during strafing. High leap (swipe up on jump) to claw from above. |

#### Mechagodzilla Prototype (Elite)
| Property | Value |
|----------|-------|
| Lane | All lanes |
| HP | Very High (90%) |
| Damage | High (80%) |
| Speed | High (70%) |
| Behavior | **Missile barrage:** 6 missiles in spread (ground/mid/high). **Jet dash:** instantly changes lane and rams. **Energy shield:** every 8s, blocks all frontal attacks for 3s. Shield drops after grab or full-charge atomic breath. |
| Counter | Bait jet dash, grab during recovery. Swat missiles back. Save full-charge breath for shield-breaking. Lane-switch constantly — telegraphs lane target 0.5s before dash. |

### 5.3 Hybrid Enemies (Late Game)
- **Jetpack Raptor:** High lane raptor with jetpack. Appears alongside tanks in Level 7. Forces simultaneous aerial + ground threat management.

---

## 6. BOSS PATTERNS

### 6.1 Tyrannoking (Level 3 Boss)
**Theme:** Mutated alpha T-Rex. Teaches lane dancing and pattern recognition.

#### Phase 1 (100–60% HP)
| Attack | Tell | Counter |
|--------|------|---------|
| **Crushing Bite** | 0.6s windup. Jaws glow red. Stomps ground twice, drool drips. | Dodge to high lane. Dash-claw from above during recovery. |
| **Tail Cyclone** | Tail raises and trembles, then whips around. Hits mid+high for 1.5s. | Drop to ground lane immediately. Grab raptor during spin, throw at boss head for stun. |
| **Dominance Roar** | 0.8s windup. Chest puffs, head tilts back. Stuns all lanes for 1.2s. | Interrupt with charged atomic breath. Or block for reduced stun. |

**Strategy:** Stay in mid lane as default. Only attack during 1.5s recovery after bite or tail cyclone. Save atomic meter for roar interrupts.

#### Phase 2 (60–0% HP) — Blood Frenzy
- Speed increases 40%. Bite chains 2–3 times rapidly.
- **Earthquake Stomp:** Rears up in any lane, slams down. Shockwave hits all lanes unless airborne.
- **Raptor Summon:** Howls, spawning 4 raptors that heal boss (5% HP each) when they reach it.

**Strategy:** Never let raptors reach boss. High lane is safest during blood frenzy. Earthquake stomp is biggest damage window — jump just before impact, land with dive slam.

---

### 6.2 Super X (Level 6 Boss)
**Theme:** Anti-kaiju aerial battleship. Teaches ranged pattern reading.

#### Phase 1 (100–70% HP) — High Lane Hover
| Attack | Tell | Counter |
|--------|------|---------|
| **Cadmium Laser Sweep** | Locks onto Godzilla's lane for 1s (red reticle), then sweeps that lane for 1.5s. | Switch lane AFTER lock-on completes but BEFORE beam fires (0.4s dodge window). |
| **Missile Volley** | Bay doors open with mechanical clank. 5 missiles: 2 ground, 2 mid, 1 high. | Stand in mid lane, swat missiles back with tail whip. Or dodge to gap lane. |
| **Reflective Shield** | Hexagonal shield for 4s. Projectiles bounce back. | Do NOT use atomic breath. Close distance, tail whip repeatedly. 4 whips break shield. |

#### Phase 2 (70–35% HP) — Descent to Mid
- **Lightning Cage:** Drops 3 electric pylons (one per lane). After 1s, they connect with lightning between active pylons. Destroy one pylon (2 tail whips) to break cage.
- **Gravity Well:** Pulls Godzilla to center lane for 3s. Fires homing missiles during pull. Fight pull with opposite D-pad direction. Swat missiles back — the pull helps aim.
- **Drone Swarm:** 6 attack drones strafe random lanes with machine gun fire for 4s.

#### Phase 3 (35–0% HP) — Desperation Protocol
- **30-second self-destruct countdown.** All previous attacks at double speed/double damage.
- **Attack Roulette:** Randomly cycles between all attacks with 0.3s color flash tell (no other warning).
- If timer reaches zero: instant death regardless of HP.

**Strategy:** DPS race. Use every opening. Full-charge atomic breath when shield is down. Grab-throw drones into boss for burst damage. Color code: red = laser, yellow = missiles, purple = gravity, green = drones.

---

### 6.3 Mechagodzilla (Level 8 Final Boss)
**Theme:** Mirror match. Everything you can do, it can do better.

#### Phase 1 (100–66% HP)
| Attack | Tell | Counter |
|--------|------|---------|
| **Mirror Stance** | Eyes flash blue, stance shifts to match Godzilla's. Copies lane and mirrors movement for 4s. Counters any attack with same move. | Do not attack during mirror. Move to different lane and wait. Or grab — it can't mirror grabs. |
| **Plasma Breath** | Mouth glows white, chest reactor spins up. Lane-piercing beam through all 3 lanes. | Dodge left/right within lane (not up/down). Dash-claw sideways. Or jump over it. |
| **Diamond Coating** | Body sparkles, surface ripples. 5s duration. Melee bounces off, deals recoil damage. | Switch to atomic breath. Or grab — coating doesn't cover joints. Grab shatters coating early. |

#### Phase 2 (66–33% HP) — Endoskeleton Revealed
- **Finger Missiles:** 10 homing missiles from fingertips, track across lane switches for 3s. Stand in ground lane, spam tail whip. Or use 360° nuclear pulse to vaporize all 10.
- **Cross-Attack Beam:** Eye beam + chest missile barrage simultaneously. Must dodge two attack types at once. Jump to dodge low beam, immediately tail whip to swat chest missiles.
- **Teleport Dash:** Vanishes for 0.3s, reappears behind Godzilla and attempts grab. Static distortion → metallic clang 0.3s later. Attack behind you (ground pound) when you hear the clang.

#### Phase 3 (33–0% HP) — Core Overload
- **Absolute Zero Cannon:** 2s charge. Full-screen freeze beam. If hit, frozen for 3s, followed by guaranteed plasma breath. **You must grab Mechagodzilla during the 2s charge.** Core turns ice-blue, frost particles spread, screen edges frost over.
- **Clone Field:** Creates 2 holographic clones in other lanes. All three attack simultaneously. Only real one takes damage. Real one has solid outline; clones have 0.1s transparency pulse every 2s. Use 360° nuclear pulse to destroy clones instantly.
- **Final Overdrive:** At 10% HP, attack speed doubles, all tells halved. Uses every previous attack in rapid random sequence for 20 seconds. Survive 20s → core overheats, self-stuns for 5s (free kill window).

---

## 7. LEVEL STRUCTURE (8-LEVEL CAMPAIGN)

| Level | Name | Theme | New Enemies | Boss | Teaches | Reward |
|-------|------|-------|-------------|------|---------|--------|
| 1 | Primeval Shores | Beach at dusk | Raptor | — | D-pad, lane switch, tail whip | 1 EP |
| 2 | Jungle Ruins | Overgrown temple | Pteranodon, Ankylosaurus | — | Anti-air, grab-throw | 2 EP, Atomic T1 unlock |
| 3 | The Tyrant's Throne | Volcanic caldera | — | Tyrannoking | Boss patterns, add management | 3 EP, all T1 unlocks |
| 4 | Cretaceous Caverns | Crystal caves | T-Rex (mini-boss ×2) | — | Managing big threat + swarm | 2 EP, T2 unlocks |
| 5 | First Contact | Coastal military base | Tank, Helicopter | — | Ranged enemies, missile swatting | 2 EP |
| 6 | Skies of Fire | Burning city | — | Super X | Pattern recognition, DPS race | 3 EP, all T2 unlocks |
| 7 | The Hybrid War | Secret lab facility | Mechagodzilla Prototype, Jetpack Raptor | — | Two factions simultaneously | 3 EP, T3 (capstone) unlocks |
| 8 | Final Protocol | Mechagodzilla silo | — | Mechagodzilla | Pure execution test | 5 EP, New Game+ |

**Difficulty Curve:** Staircase, not slope. Plateaus after each boss, then jumps at next new threat.

**Checkpoint System:** 3 checkpoints per level (march start, arena start, boss start). Dying restarts at current segment with full HP and meter. Mercy mode offered after 5 deaths: enemies deal -30% damage, tells are 0.2s longer. Full rewards still earned.

---

## 8. UPGRADE & PROGRESSION SYSTEM

### 8.1 Currency
**Evolution Points (EP)** earned by clearing levels and defeating bosses. Spend across 4 trees. Can respec between levels for free.

### 8.2 Tree Structure
Each tree has 3 tiers. Final tier is a **binary fork**: pick one capstone, lock out the other. This forces build identity.

#### Tree 1: Atomic Power (Blue)
| Tier | Upgrade | Effect |
|------|---------|--------|
| 1 | Dorsal Capacitors | Atomic meter max +25%. Fins glow brighter. |
| 2 | Overcharge | Hold 1s past full for 50% stronger breath. 10% recoil damage if overheld. |
| 3A | **Sustained Beam** | Breath becomes continuous 3s beam, sweepable across lanes. |
| 3B | **Spiral Ray** | Charges 50% faster, 2× damage, single piercing bolt. |

#### Tree 2: Primal Combat (Red)
| Tier | Upgrade | Effect |
|------|---------|--------|
| 1 | Sharpened Claws | Melee damage +20%. Tail whip hitbox +1px wider. |
| 2 | Predator's Reach | Grab range +40%. Thrown enemies cross 2 lanes. Throw damage +30%. |
| 3A | **Berserker Rage** | Attack speed +40%. Combo extends to 5 hits, +10% per hit. Cannot block or grab while comboing. |
| 3B | **Titan Slam** | All attacks +50% damage, knock back 2 lanes. Ground pound shockwave hits adjacent lanes. |

#### Tree 3: Hide & Healing (Green)
| Tier | Upgrade | Effect |
|------|---------|--------|
| 1 | Thick Scales | Max HP +30%. Sprite gets darker, bulkier outline. |
| 2 | Unstoppable | Stun duration -50%. Block reduces damage by 60%. |
| 3A | **Cellular Regeneration** | Regen 2% HP/s after 3s without damage. Fins pulse green. Excess healing converts to atomic meter. |
| 3B | **Living Fortress** | Max HP +50%. Damage taken -25%. When hit, auto-emit small 360° pulse. Cannot regenerate HP — only pickups heal. |

#### Tree 4: Kaiju Agility (Purple)
| Tier | Upgrade | Effect |
|------|---------|--------|
| 1 | Reflexes | Lane switch speed +30%. Enemy tells display 0.15s earlier. |
| 2 | Jet Boost | Dash-claw crosses 2 lanes. Jump crosses all 3 lanes. Landing dust stun 0.5s. |
| 3A | **Sky Tyrant** | Hover indefinitely in high lane. Anti-air damage +100%. Flying body slam hits all lanes. Ground pound damage -50%. |
| 3B | **Earthshaker** | Ground pound hits all 3 lanes with massive shockwave. Stomp stun 1.5s. Lane switch speed -20%. Cannot be knocked back. |

### 8.3 Named Builds
| Build | Capstones | Playstyle |
|-------|-----------|-----------|
| The Radiation Storm | Sustained + Berserker + Regen + Aerial | Flying death laser. Hover and sweep beams. |
| The Unstoppable Wall | Spiral + Titan + Fortress + Ground | Walk forward, nothing stops you. |
| The Glass Cannon | Spiral + Berserker + Regen + Aerial | Max damage, minimal defense. |
| The Siege Engine | Sustained + Titan + Fortress + Ground | Area denial. Nothing enters your zone. |
| The Bruiser | Spiral + Titan + Regen + Ground | Balanced, reliable, safe first playthrough. |

---

## 9. VISUAL DESIGN

### 9.1 Art Style
- **Pixel art**, functional (not illustration-level detail)
- Side-view, chunky silhouettes, glowing dorsal fins
- Destroyed city backdrop (Tokyo Tower reference)
- 4-color limit per character: skin, shadow, highlight, accent

### 9.2 Sprite Sizes
| Entity | Design Size | Engine Render | Scale Factor |
|--------|-------------|---------------|--------------|
| Godzilla | 32×40 | 128×160 | 4× |
| Raptor | 24×24 | 96×96 | 4× |
| Tank | 28×20 | 112×80 | 4× |
| Pteranodon | 28×20 | 112×80 | 4× |
| Ankylosaurus | 32×28 | 128×112 | 4× |
| Tyrannoking (boss) | 48×64 | 192×256 | 4× |
| Super X (boss) | 56×40 | 224×160 | 4× |
| Mechagodzilla (boss) | 48×64 | 192×256 | 4× |

**CRITICAL:** Use **integer scaling only** (3× or 4×). Never fractional. Set Godot texture filter to **Nearest**.

### 9.3 Color Palette
**Godzilla:**
- Skin base: #4a6741
- Skin shadow: #3d5236
- Fin glow: #5eead4
- Fin core: #2dd4bf
- Eyes: #fbbf24
- Claws: #e5e7eb

**Environment:**
- Sky dark: #0d1117
- Sky mid: #1e293b
- Fire glow: #f97316
- Fire core: #ea580c
- Rubble: #374151
- Concrete: #6b7280

**Enemies:**
- Dino green: #0f3d0f
- Dino accent: #22c55e
- Tank metal: #4b5563
- Mecha blue: #1e3a5f
- Enemy red: #ef4444
- Mecha glow: #a855f7

### 9.4 Silhouette Rules
1. **1px black outline on everything** — separates from background
2. **Godzilla is always biggest** — 1.5× to 2× standard enemy size
3. **Glowing parts = gameplay state** — fins ARE the HUD
4. **Enemy tells must be 4+ pixels wide** — 1-pixel flashes are invisible on phones

### 9.5 HUD
- **Health bar:** Top-left, 48×4px, red fill, black outline. Flashes white + shakes 1px on hit.
- **Atomic meter:** Top-right, 48×4px, blue fill. Pulses when full.
- **Score:** Top-center, 8px pixel font (Press Start 2P), white with black outline.
- **Boss HP:** Appears on boss spawn. 120×6px, red with yellow phase markers (66%, 33%).

### 9.6 Background Parallax
| Layer | Scroll Speed | Content |
|-------|--------------|---------|
| Sky | 0× | Static gradient, 2–3 drifting clouds (32×16px) |
| Far city | 0.2× | Silhouetted buildings, Tokyo Tower, smoke. 48px tall max. |
| Near rubble | 0.6× | Destroyed cars, broken walls, fire sprites. 24×24 max. |
| Foreground | 1.2× | Dust, sparks, sparse rubble passing in front. |

**Backgrounds must be 540px wide minimum** to fill tablet screens.

---

## 10. AUDIO DESIGN

### 10.1 Adaptive Music System
Music split into 4 stem layers that crossfade over 2s based on game state:

| Stem | March | Arena | Boss |
|------|-------|-------|------|
| Percussion | 30% (light kick) | 70% (full kit) | 100% (double kick) |
| Bass | 50% (synth bass) | 80% (distorted) | 100% (driving) |
| Melody | 30% (ambient) | 60% (urgent) | 100% (screaming lead) |
| Atmosphere | 100% (always) | 100% | 100% |

### 10.2 Music by Phase
| Phase | BPM | Key | Feel |
|-------|-----|-----|------|
| Menu | 80 | D minor | Ominous, vast, slow dread |
| March | 90 | E minor | Steady, marching, building tension |
| Arena | 120 | F minor | Driving, urgent, +5 BPM per wave |
| Boss intro | 100→140 | G minor→B minor | Heartbeat kick accelerating |
| Boss fight | 140 | B minor | Relentless, phase transitions = key shift up semitone |
| Victory | 60→120 | E major | Low brass swell to triumphant fanfare |
| Game over | 0 | Atonal | 2s silence, then descending drone |

### 10.3 Boss Themes
**Tyrannoking — "Primal Rage" (140 BPM, G minor):** Taiko drums, didgeridoo bass, screeching strings, guttural choir. Phase 2 = drums double, choir joins.

**Super X — "Steel Judgment" (150→170 BPM, B minor):** Industrial techno, jet engine drone, alarm siren (Phase 3), synthesized brass.

**Mechagodzilla — "Mirror of God" (160 BPM, D minor→D major):** Distorted guitar, glitch electronics, orchestral hits. Phase 3 = pure noise, no melody.

### 10.4 Critical SFX
| Event | Sound Design | Priority |
|-------|-------------|----------|
| Tail whip | Swoosh-CRACK. 150ms. | High |
| Atomic breath charge | Rising electrical hum → jet engine scream. | High |
| Atomic breath fire | Deep white noise, metallic ring, 80–200Hz rumble. | High |
| Jump/Land | Whoosh + grunt / ground-shaking thud + debris rattle. | Medium |
| Grab | Wet "SCHLORP" + enemy squeal. | Medium |
| Throw | Whoosh + impact crunch. Bowling strike on chain hit. | Medium |
| Godzilla hurt | Pained roar (pitched down 2 semitones) + low rumble. | High |
| Enemy death | Raptor = squeal + crunch. Tank = metallic explosion. Pteranodon = wing flap + squawk cutoff. | Medium |
| Lane switch | Subtle whoosh, 0.3s, -12dB. | Low |
| Boss phase transition | Music cuts 1s → boss roar → music resumes in new key. | High |

### 10.5 Audio Tells (0.3s before visual windup)
- **Tyrannoking Bite:** Low growl rising in pitch → peak = dodge now.
- **Tyrannoking Stomp:** Bass rumble drops frequency → sub-bass = 0.2s to impact.
- **Super X Laser:** Charging whine → silence = 0.2s to beam.
- **Super X Missiles:** "Clank-clank-clank" = 5 missiles.
- **Mechagodzilla Teleport:** Static crackle → CLANG = attack behind you.
- **Mechagodzilla Zero Cannon:** Core hum drops pitch for 2s → lowest note = beam fires.

### 10.6 Mobile Audio
- **Phone speaker mix:** Boost 1–4kHz, heavy compression (4:1), mono downmix.
- **Headphone mix:** Full range, stereo panning by lane height, sub-bass rumble.
- **Performance mode:** 22kHz sample rate, mono mix, shorter reverb tails. Saves ~15% CPU.

---

## 11. TECHNICAL ARCHITECTURE

### 11.1 Engine
**Godot 4.2.2+** (Mobile renderer). Fallback to OpenGL ES 3.0 for older devices.

### 11.2 Critical Project Settings
```
[display]
window/size/viewport_width = 360
window/size/viewport_height = 640
window/stretch/mode = "canvas_items"
window/stretch/aspect = "expand"
window/handheld/orientation = "portrait"

[rendering]
renderer/rendering_method = "mobile"
textures/canvas_textures/default_texture_filter = "Nearest"
```

### 11.3 Viewport Strategy
- Base design: 360×640
- `canvas_items` + `expand` = fills any screen
- Phones (tall): show more vertically
- Tablets (wide): show more horizontally — backgrounds must be 540px+ wide
- **Texture filter: Nearest** — critical for crisp pixel art

### 11.4 Safe Area
- Use Godot's `SafeAreaContainer` for UI
- D-pad and buttons inside safe area
- Gameplay can use full viewport

### 11.5 Folder Structure
```
res://
├── autoload/
│   ├── GameState.gd      (score, upgrades, progress)
│   ├── AudioManager.gd   (music stems, SFX pooling)
│   └── InputHandler.gd   (touch → game actions)
├── entities/
│   ├── player/
│   │   ├── godzilla.tscn
│   │   └── godzilla.gd
│   ├── enemies/
│   │   ├── raptor.tscn
│   │   ├── pteranodon.tscn
│   │   ├── ankylosaurus.tscn
│   │   ├── tank.tscn
│   │   └── helicopter.tscn
│   └── bosses/
│       ├── tyrannoking.tscn
│       ├── super_x.tscn
│       └── mechagodzilla.tscn
├── levels/
│   ├── level_01.tscn through level_08.tscn
├── ui/
│   ├── hud.tscn
│   ├── main_menu.tscn
│   ├── upgrade_screen.tscn
│   ├── pause_menu.tscn
│   └── controls_overlay.tscn
├── assets/
│   ├── sprites/characters/
│   ├── sprites/backgrounds/     (540px wide minimum)
│   ├── sprites/fx/
│   ├── audio/music/             (OGG, looped)
│   ├── audio/sfx/               (WAV, short)
│   └── fonts/
└── shaders/
    ├── hit_flash.gdshader
    └── screen_shake.gdshader
```

### 11.6 Input Handler (Touch → Actions)
- Use `InputEventScreenTouch` and `InputEventScreenDrag`
- Track `touch_start_pos` by finger_id
- Swipe threshold: 30px
- If drift < 15px on action buttons, register as tap (not swipe)
- Buffer last 0.15s of directional input

### 11.7 Performance Targets
| Metric | Target |
|--------|--------|
| FPS | 60 (cap to save battery) |
| APK size | 35–50 MB |
| RAM usage | 80–120 MB |
| Max sprites | 20 animated on screen |
| Max particles | 50 total (CPUParticles2D) |
| Draw calls | < 30 per frame |
| Audio memory | < 20 MB |
| Texture memory | < 50 MB |
| Battery drain | ~8% per 15 min |

### 11.8 Android Export
- Target SDK: 34
- Min SDK: 26 (Android 8.0+)
- Use Gradle build
- Enable "Optimize" for PNGs
- Strip unused engine features (3D physics, VR)
- Generate keystore and keep it safe

---

## 12. MVP SCOPE (FIRST 3 LEVELS)

### 12.1 Goal
Answer: **"Is this fun to play on a phone?"**

### 12.2 What's In
| Feature | Detail |
|---------|--------|
| **Levels** | Level 1 (tutorial), Level 2 (combat test), Level 3 (Tyrannoking boss) |
| **Enemies** | Raptor, Pteranodon, Ankylosaurus, Tyrannoking |
| **Controls** | D-pad, attack, jump, special, gesture specials (swipe on buttons) |
| **Upgrades** | Tier 1 only (4 upgrades, no capstones) |
| **Graphics** | Godzilla + 3 enemies + 3 backgrounds + HUD + menus. All pixel art, all animated. |
| **Audio** | 3 music tracks (menu, march/arena, boss). All SFX for MVP enemies. Boss audio tells. |
| **UI** | Main menu, level select (3 levels), upgrade screen, pause, game over, victory |
| **Save** | Progress + upgrades between levels. One save slot. |
| **Story** | Static text cards between levels |

### 12.3 What's Out (Post-MVP)
- Levels 4–8
- Military enemies (tanks, helicopters, Mechagodzilla)
- Tier 2–3 upgrades and capstone forks
- Respec system
- Animated cutscenes
- Monetization
- Social features
- Settings menu, credits, achievements
- Cloud save

### 12.4 MVP Verification Checklist

**Controls & Feel (Critical)**
- [ ] D-pad registers lane switches 100% on 3+ screen sizes
- [ ] Gesture specials feel natural (discovered within 5 min without tutorial)
- [ ] No accidental inputs (tap vs swipe confusion)
- [ ] Grab-throw on Ankylosaurus feels weighty and satisfying

**Level Flow (Critical)**
- [ ] March → Arena → Boss transition is clear
- [ ] Level 1 teaches without text (movement, attack, jump)
- [ ] Boss phase transitions feel dramatic
- [ ] Checkpoints work (die → restart segment, not level)

**Audio (Critical)**
- [ ] Every player action has immediate audio feedback
- [ ] Boss audio tells readable without visuals (test eyes-closed)
- [ ] Music ducks appropriately for SFX

**Visuals (Critical)**
- [ ] Godzilla readable against background in all lighting
- [ ] Lane position obvious at a glance
- [ ] Boss tells visible on 5-inch screen (4+ pixels minimum)

### 12.5 4-Week Timeline (10–15 hrs/week)

| Week | Focus | Deliverable |
|------|-------|-------------|
| **Week 1** | Engine setup, input handler, basic player controller. Placeholder art (colored rectangles). | Godzilla moves and attacks on phone. |
| **Week 2** | Combat system (tail whip, jump, grab, throw, gestures). One enemy (raptor) with AI. Level 1 structure. | Playable Level 1 start to finish. |
| **Week 3** | Pixel art pass (Godzilla + all MVP enemies + backgrounds). Level 2 + 3. Tyrannoking boss. | All 3 levels playable with real art. |
| **Week 4** | Audio pass (SFX + music). UI polish (menus, upgrades, save). Playtest with 3 friends. | MVP complete. Feedback collected. |

### 12.6 Playtest Questions
1. After Level 1: "Do you understand how to move and attack without me explaining?"
2. After Level 2: "Did you figure out how to beat the Ankylosaurus? How many tries?"
3. After Level 3: "Was the boss hard but fair, or did you feel cheated? Would you play again?"

**If answer to #3 is "I'd play again," MVP succeeded. If not, fix the blocker before Level 4.**

---

## 13. POST-MVP DEVELOPMENT PHASES

### Phase 2: The Military Response (Months 2–3)
- Levels 4, 5, 6
- Military enemies: Tank, Attack Helicopter, Super X boss
- Tier 2 upgrades unlock
- Adaptive music stem system (full crossfading)
- Settings menu, credits
- **Deliverable:** Playable through Level 6. Boss: Super X.

### Phase 3: The Hybrid War (Months 3–4)
- Levels 7, 8
- Hybrid enemies: Jetpack Raptor, Mechagodzilla Prototype
- Mechagodzilla final boss
- Tier 3 capstones (binary forks)
- New Game+ mode (harder enemies, same levels, all upgrades unlocked from start)
- **Deliverable:** Full 8-level campaign complete.

### Phase 4: Polish & Ship (Month 5)
- Screen shake tuning
- Particle effects polish
- Leaderboards (local)
- Achievements
- Monetization integration (premium unlock: $4.99, or ad-supported with $2.99 remove-ads)
- Store page assets (screenshots, trailer, description)
- Beta test with 50+ players
- **Deliverable:** v1.0 release on Google Play Store.

### Phase 5: Live Ops (Post-Launch)
- Endless mode (procedurally generated arena waves)
- Daily challenge (preset enemy composition, leaderboard)
- New capstone paths (expand from 2 to 3 choices per tree)
- Skins (classic Godzilla, burning Godzilla, Shin Godzilla-style)
- **Deliverable:** Content updates every 6–8 weeks.

---

## 14. RISK MITIGATION

| Risk | Mitigation |
|------|------------|
| Controls feel bad on small screens | Week 1 is pure control testing. If D-pad doesn't work after 1 week, pivot to swipe-anywhere controls. |
| Pixel art takes too long | Use placeholder rectangles for Week 1–2. Commission artist or use asset packs if solo art is bottleneck. |
| Boss fights feel unfair | Audio tells are mandatory, not optional. If playtesters die without understanding why, add more tell time. |
| Performance issues on old phones | Test on budget device weekly. CPUParticles2D instead of GPU. Reduce sprite count if needed. |
| Scope creep | GDD is law. Any feature not in this doc waits until post-MVP. No exceptions without written justification. |

---

## 15. APPENDIX

### A. Godot Code Snippets

**Viewport Setup (project.godot):**
```
[display]
window/size/viewport_width = 360
window/size/viewport_height = 640
window/stretch/mode = "canvas_items"
window/stretch/aspect = "expand"
window/handheld/orientation = "portrait"

[rendering]
renderer/rendering_method = "mobile"
textures/canvas_textures/default_texture_filter = "Nearest"
```

**InputHandler.gd (Autoload):**
```gdscript
extends Node

signal action_pressed(action: String)
signal action_gestured(action: String, direction: Vector2)

var touch_start_pos: Dictionary = {}
const SWIPE_THRESHOLD = 30

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start_pos[event.index] = event.position
        else:
            var start = touch_start_pos.get(event.index, event.position)
            var swipe = event.position - start
            if swipe.length() > SWIPE_THRESHOLD:
                _handle_swipe(event.position, swipe)
            else:
                _handle_tap(event.position)
            touch_start_pos.erase(event.index)

func _handle_swipe(pos: Vector2, swipe: Vector2):
    if _is_in_attack_button(pos):
        var dir = _swipe_to_direction(swipe)
        action_gestured.emit("attack_special", dir)
    elif _is_in_jump_button(pos):
        var dir = _swipe_to_direction(swipe)
        action_gestured.emit("jump_special", dir)

func _swipe_to_direction(swipe: Vector2) -> Vector2:
    if abs(swipe.x) > abs(swipe.y):
        return Vector2(sign(swipe.x), 0)
    else:
        return Vector2(0, sign(swipe.y))
```

### B. Asset Pipeline
1. Draw in Aseprite at base resolution (32×40 for Godzilla)
2. Export as horizontal sprite sheet PNG
3. Import to Godot with "2D Pixel" preset
4. Create AtlasTexture, set regions per frame
5. Scale 4× in engine with Nearest filter

### C. Audio Pipeline
- Music: Compose in LMMS or Reaper. Export stems as OGG (q4, ~128kbps, looped).
- SFX: Generate in Bfxr or record. Export as WAV 16-bit mono.
- Implement: 10 pooled AudioStreamPlayer nodes. Reuse, don't create/destroy.
- Adaptive: Crossfade stem volumes over 2s based on game state.

### D. Recommended Tools
| Task | Tool | Cost |
|------|------|------|
| Pixel Art | Aseprite | $20 |
| Free Alternative | Libresprite | Free |
| Music | LMMS | Free |
| DAW | Reaper | $60 |
| SFX | Bfxr | Free |
| Samples | Splice | $8/mo |
| Godot Version | 4.2.2+ | Free |

---

*Document compiled for Kimi 3 development assistance. All specs, values, and code snippets are implementation-ready.*
