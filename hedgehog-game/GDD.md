# Hedgehog Highways: Game Design Document

> **Working title:** *Hedgehog Highways*
> **Genre:** 3D exploration / light stealth / collect-a-thon
> **Audience:** Children aged 5–10 (playable with parents)
> **Platforms (target):** PC, tablets (touch), consoles (controller)
> **Document status:** Draft v0.1

---

## Table of Contents

1. [Vision](#1-vision)
2. [Design Pillars](#2-design-pillars)
3. [Target Audience](#3-target-audience)
4. [Core Gameplay Loop](#4-core-gameplay-loop)
5. [The Hedgehog (Player Character)](#5-the-hedgehog-player-character)
6. [Controls](#6-controls)
7. [Player Stats](#7-player-stats)
8. [Food System](#8-food-system)
9. [Sniff Mode (Senses)](#9-sniff-mode-senses)
10. [Threats and Defence](#10-threats-and-defence)
11. [Hibernation and Nest Building (Level End)](#11-hibernation-and-nest-building-level-end)
12. [The Winter Clock](#12-the-winter-clock)
13. [Gardens (Levels)](#13-gardens-levels)
14. [World Map: Hedgehog Highways](#14-world-map-hedgehog-highways)
15. [Characters: Friends and Helpers](#15-characters-friends-and-helpers)
16. [Collectibles and Progression](#16-collectibles-and-progression)
17. [Nature Journal (Educational Layer)](#17-nature-journal-educational-layer)
18. [Home Nest Hub](#18-home-nest-hub)
19. [Failure and Difficulty](#19-failure-and-difficulty)
20. [Accessibility](#20-accessibility)
21. [Two-Player Co-op](#21-two-player-co-op)
22. [User Interface and HUD](#22-user-interface-and-hud)
23. [Art Direction](#23-art-direction)
24. [Audio](#24-audio)
25. [Technical Overview](#25-technical-overview)
26. [Ethics and Monetisation](#26-ethics-and-monetisation)
27. [Production Plan and Milestones](#27-production-plan-and-milestones)
28. [Open Questions](#28-open-questions)

---

## 1. Vision

Players guide a small hedgehog through a series of cozy, lively gardens as autumn turns to winter. To survive, the hedgehog has to:

- **find food** to stay healthy and nimble,
- **avoid or outsmart cats and dogs**, and
- **find and build a safe nest** to **hibernate** in. Entering hibernation in a secure spot ends each level.

The game should feel **warm, curious and gently exciting**. Kids should leave feeling clever and caring about real hedgehogs, not frightened or frustrated.

**Elevator pitch:** *"A cozy stealth adventure where you sniff, scurry and roll your way through back gardens to find the perfect place to sleep through winter."*

---

## 2. Design Pillars

| Pillar | Meaning | Design test |
|---|---|---|
| **Lovable** | The hedgehog is a character kids care about. | Does this make the player smile or say "aww"? |
| **Clever, not scary** | Danger is solved by outsmarting it, never by violence. | Can a 6-year-old understand and beat this with a plan? |
| **Curious** | Exploring is always rewarded. | Is there something to find just off the main path? |
| **Real nature** | Grounded in real hedgehog behaviour and conservation. | Would a wildlife charity approve of this message? |
| **Cozy** | Calm pacing, soft visuals, a satisfying ending ritual. | Does it still feel safe to play before bedtime? |

---

## 3. Target Audience

- **Primary:** Children aged 5–10.
- **Secondary:** Parents or older siblings playing co-op, and teachers using it as a nature resource.
- **Reading level:** The game must be playable by **pre-readers**. Rely on icons, voice and animation, with text optional.
- **Session length:** One level should take **10–20 minutes**. Kids should be able to stop at checkpoints.

---

## 4. Core Gameplay Loop

```
          ┌─────────────────────────────────────────────┐
          │                                             │
          ▼                                             │
   EXPLORE garden ──► SNIFF for food / danger / nest     │
          │                                             │
          ▼                                             │
   EAT food (Health & Dexterity ↑)                      │
          │                                             │
          ▼                                             │
   AVOID / OUTSMART cats & dogs (hide, roll, distract)  │
          │                                             │
          ▼                                             │
   COLLECT nesting material + collectibles ─────────────┘
          │
          ▼  (Winter Clock advances)
   BUILD NEST in a secure spot ──► HIBERNATE ──► Level complete
          │
          ▼
   Dream-bubble results ──► Spring ──► World map ──► next garden
```

**Moment to moment:** move, sniff, eat, hide, roll.
**Level to level:** build a better nest, earn stars, unlock new gardens via hedgehog highways.
**Long term:** fill the nature journal, decorate the home nest, raise hoglets.

---

## 5. The Hedgehog (Player Character)

### 5.1 Identity
- Players **name their hedgehog** at the start (default suggestion: *Prickles*).
- **Customisation** with cosmetic items found or earned: leaf hat, knitted scarf, acorn-cap helmet, berry backpack, flower crown, tiny wellies.
- Cosmetics are **purely visual** and have no gameplay advantage.

### 5.2 Personality and Animation
Expressive, readable animations carry the character:

| Situation | Animation |
|---|---|
| Idle | Sniffs the air, scratches an ear, looks around curiously |
| Eating | Happy crunching, a little wiggle after a tasty bug |
| Nervous (threat near) | Spines bristle, eyes widen |
| Hidden | Peeks out of a leaf pile, eyes blinking |
| Late autumn | Yawns, moves slightly slower, curls tail |
| Pollen / dandelions | Cute sneeze |
| Rolled up | Tight spiky ball, rocks gently |
| Level complete | Curls up in nest, snores softly |

### 5.3 Signature Move: Roll into a Ball
The hedgehog's main defence (see [Section 10](#10-threats-and-defence)). It is also used for movement: rolling down slopes, bowling over light obstacles, and squeezing through gaps.

---

## 6. Controls

The game is kept to **four core actions** so young kids can play.

| Action | Controller | Keyboard / Mouse | Touch |
|---|---|---|---|
| Move | Left stick | WASD / arrows | Virtual joystick (left) |
| Camera | Right stick | Mouse | Drag (right side) |
| **Sniff** | Button A / ✕ (hold) | Space (hold) | Nose button (hold) |
| **Roll** | Button B / ○ | Shift | Ball button |
| **Interact** (eat, pick up, use) | Button X / □ | E / click | Tap object |
| Pause / Journal | Start | Esc / J | Menu icon |

- **Auto-camera** with gentle follow; manual camera is optional.
- **Context prompts** appear as icons over objects (e.g. a mouth icon for food, a hand icon for nest material).
- Controls can be **fully remapped**.

---

## 7. Player Stats

### 7.1 Health ❤️
- Shown as **3–5 hearts** (hearts are added as the game progresses).
- Lost by being caught by a threat, eating bad food, or falling hazards.
- Regained by eating good food.
- At zero hearts the hedgehog **rolls back to the last checkpoint** (see [Section 19](#19-failure-and-difficulty)).

### 7.2 Dexterity 🐾
Agility and nimbleness, shown as a **paw meter**.

| Dexterity level | Effect |
|---|---|
| Low | Slower movement, clumsy footsteps (louder, easier to detect), cannot climb small steps |
| Medium | Normal speed, can climb low ledges and logs |
| High | Fast scurry, quiet footsteps, longer roll, can squeeze through tighter gaps |

- Raised by eating protein-rich food (beetles, worms, caterpillars).
- Slowly decreases as the Winter Clock advances (the hedgehog gets sleepy).

### 7.3 Power-ups (temporary)
Granted by **rare treats** (see [Section 8](#8-food-system)):

| Power-up | Effect | Duration |
|---|---|---|
| **Zoom** | +50% speed | 20 s |
| **Super Nose** | Sniff radius doubled | 30 s |
| **Tiptoe** | Silent footsteps, cannot be heard | 25 s |
| **Spiky Shield** | Next catch is blocked automatically | Until used |

---

## 8. Food System

### 8.1 Design Goal
Food is the main exploration reward **and** a teaching tool about what is really good for hedgehogs.

### 8.2 Food Table

| Food | Category | Effect | Real-world note (journal) |
|---|---|---|---|
| Beetle | Good | +Dexterity, satisfying crunch | Beetles are a hedgehog favourite |
| Earthworm | Good | +Health, +Dexterity | Come up after rain |
| Caterpillar | Good | +Dexterity | High in protein |
| Slug / snail | Good | +Health | Gardeners like hedgehogs for this |
| Fallen fruit (apple, berry) | Okay | Small +Health | An occasional snack |
| Cat food (left out by kind humans) | Good | +Health, +Dexterity | Meat-based cat food is a safe treat |
| Fresh water dish | Good | Restores 1 heart | Hedgehogs need water, especially in dry weather |
| **Milk** | Bad | Hedgehog feels sick (−1 heart, short wobble) | **Milk is harmful to hedgehogs** |
| **Bread** | Bad | No nutrition, slight slowdown | Bread fills them up without nutrition |
| Golden beetle | Rare treat | Grants a random power-up | Fictional |
| Glow-worm | Rare treat | Super Nose | Real glow-worms live in some gardens |

### 8.3 Rules
- Bad food is **never a big punishment**. The hedgehog pulls a funny face, wobbles, and a **Hedgehog Fact** card explains why.
- The first time any food is found, a **Fact Card** pops up and is added to the journal.
- Food respawns slowly so players are never stuck without health.
- The **satisfying crunch** sound for beetles is a key "juice" moment.

---

## 9. Sniff Mode (Senses)

Hedgehogs have **poor eyesight but an excellent sense of smell and hearing**. Sniff Mode reflects this and is a core navigation tool.

**While holding Sniff:**
- The world desaturates slightly and the camera lowers to hedgehog nose height.
- **Coloured scent trails** appear:

| Colour | Meaning |
|---|---|
| 🟢 Green | Food |
| 🟡 Yellow | Nesting material / collectibles |
| 🔵 Blue | Suitable hibernation spot |
| 🔴 Red (pulsing) | Threat nearby, with direction |

- The hedgehog **moves slower** while sniffing (a trade-off between information and speed).
- Threats out of sight show as **sound ripples** (barking, a bell on a cat collar).
- Super Nose power-up and high Dexterity increase the sniff radius.

---

## 10. Threats and Defence

### 10.1 Philosophy
Threats are **outsmarted, never fought**. No animal is ever hurt. Encounters end with the animal losing interest, getting distracted, or being called home by its owner.

### 10.2 Cats 🐱

| Behaviour | Tell (telegraph) |
|---|---|
| Patrol | Walks fixed routes along fences and walls |
| Stalk | Lowers body, tail twitches, before pouncing |
| Pounce | Short leap at the hedgehog |
| Lose interest | Bats at a rolled-up hedgehog, then wanders off |

- **Weakness:** easily distracted by feathers, yarn balls and butterflies.
- **Collar bell:** a cat with a bell can be heard in Sniff Mode from further away.

### 10.3 Dogs 🐶

| Behaviour | Tell (telegraph) |
|---|---|
| Sniff search | Sniffs in widening circles toward the last known position |
| Chase | Runs toward the hedgehog, barking |
| Bark at ball | Barks at a rolled-up hedgehog; nudging it gives an "ouch!" from the spikes and the dog backs off |
| Called home | Owner whistles and the dog leaves for a while |

- **Weakness:** thrown balls, sticks, and very strong smells (compost heap masks the hedgehog's scent).
- Dogs are **better noses, worse eyes** than cats, so hiding in scent-masking spots works well.

### 10.4 Friendly and Sleepy Animals
Not every cat or dog is a threat:
- **Sleepy cats** napping in the sun can be sneaked past. Waking them is a mild risk.
- **Friendly old dog** who ignores the hedgehog and may even block other threats.
- These make the world feel alive and teach kids that animals have different personalities.

### 10.5 Detection System
- Each threat has a **vision cone** (cats wider, dogs narrower) and a **hearing radius** (larger when the hedgehog has low Dexterity or is moving fast on noisy ground like gravel or dry leaves).
- A **detection meter** fills over the threat's head: `?` (curious) → `!` (spotted).
- Detection drains when the hedgehog breaks line of sight or hides.

### 10.6 Hiding Spots

| Spot | Works against |
|---|---|
| Hedge / bush | Cats and dogs (sight) |
| Leaf pile | Cats and dogs (sight); noisy to enter |
| Under shed / decking | All threats; too small for them to follow |
| Flower pot (tipped over) | Sight |
| Compost heap | Dogs (masks scent) |
| Long grass | Partial cover; slower movement |

An **eye icon** on the HUD shows hidden status: open eye = visible, closed eye = hidden.

### 10.7 Distractions
Items the hedgehog can push or nudge with Interact:

| Item | Effect |
|---|---|
| Ball | Rolls away; dogs chase it |
| Feather | Floats; cats chase it |
| Yarn ball | Unravels; cats play with it for a long time |
| Stick | Dogs fetch it |

### 10.8 Rolling into a Ball (Defence)
- **Instant** protection: while rolled up, cats and dogs cannot "catch" the hedgehog.
- Cats paw at it, get bored and leave. Dogs bark, nudge it, get a spike "ouch!" and back off.
- **Trade-off:** you cannot move (except downhill), sniff or eat while rolled. Staying rolled too long drains Dexterity slightly.
- **Rolling movement:** on slopes, the ball rolls, which is useful for fast escapes and some puzzles.

### 10.9 Environmental Hazards (kept light)

| Hazard | Behaviour | Outcome if hit |
|---|---|---|
| Robot lawnmower | Fixed pattern across the lawn | Hedgehog is knocked away safely (−1 heart), with a fact about checking lawns before mowing |
| Sprinkler | Rotating water jets | Soaked and briefly slowed |
| Pond edge | Steep sides | Splash, scramble out via a ramp; fact about pond escape ramps |
| Garden-hose maze | Tangled hose forms walls | Navigation puzzle, no damage |
| Garden netting | Can get tangled | Slowed; a helper character frees you; fact about netting dangers |

---

## 11. Hibernation and Nest Building (Level End)

### 11.1 Goal
Hibernating in a **secure spot** ends the level. It should feel like a **reward ritual**, not just an exit.

### 11.2 Steps
1. **Find a hibernation spot.** Blue scent in Sniff Mode. Spots vary in safety: under the shed, in a wild corner, in a hedgehog house, under a log pile.
2. **Collect nesting material:** dry leaves, moss, straw, grass. Each is carried back to the spot.
3. **Build the nest** by placing materials. A simple fill meter shows progress.
4. **Hibernate:** when the nest meets the minimum requirement, the "Sleep" prompt appears.

### 11.3 Nest Rating (1–3 stars)

| Factor | Contribution |
|---|---|
| Spot security (sheltered, dry, out of reach of threats) | Up to ⭐ |
| Material quantity and quality (dry leaves best, mixed materials bonus) | Up to ⭐ |
| Hedgehog condition at sleep time (Health + Dexterity) | Up to ⭐ |

- **1 star** completes the level. **3 stars** unlock bonus collectibles and journal entries.
- An **insecure spot** (e.g. open lawn, inside a bonfire pile) cannot be used. The hedgehog shakes its head, and a fact explains why (e.g. **always check bonfire piles before lighting**).

### 11.4 Hibernation Cut-scene
1. Snow begins to fall gently.
2. The hedgehog turns around three times and curls up in the nest.
3. The camera pulls back; the garden goes quiet and blue.
4. A **dream bubble** shows level stats: food eaten, times hidden, collectibles found, star rating.
5. A time-lapse: snow melts, flowers bloom, **spring arrives**.
6. The hedgehog wakes, stretches and waddles off toward the next garden on the world map.

---

## 12. The Winter Clock

A visible, **gentle** timer that adds mild urgency without a harsh countdown.

- Shown as a **season dial** (autumn leaf → bare tree → snowflake).
- As it advances:
  - leaves change colour and fall (more nest material appears),
  - days get shorter and evenings come sooner,
  - some food becomes scarcer,
  - the hedgehog yawns more and Dexterity slowly drops.
- **No hard fail:** when the dial reaches full winter, a friendly helper (e.g. the robin) guides the player to the nearest acceptable spot for a 1-star finish.
- In **Explorer mode** the clock is paused.

---

## 13. Gardens (Levels)

Each garden introduces **one new mechanic** as well as new scenery.

| # | Garden | Twist / new mechanic | Threats | Notable features |
|---|---|---|---|---|
| 1 | **Cottage Veg Patch** | Tutorial: move, sniff, eat, hide, roll, build nest | One sleepy cat | Lots of slugs, simple shed hibernation spot |
| 2 | **Fancy Hedge Maze** | Navigation, using Sniff to find the way | Cats, plus a **peacock "boss"** that struts and squawks | Topiary, fountains |
| 3 | **Allotments** | Lots of food, lots of dogs; distractions introduced | Several dogs | Compost heaps, sheds, netting hazards |
| 4 | **Night Garden** | Darkness; **fireflies light the path** | Cats with eye-shine, **owls overhead** (shadow warnings, hide when the shadow passes) | Moonlight, glow-worms |
| 5 | **Messy Wild Garden** | Many hiding spots and the **best hibernation spots**; teaches the value of wild areas | Mixed | Log piles, long grass, a hedgehog house |
| 6 | **Rainy Day Garden** | Puddles, slippery slopes, **worms come up** | Dogs (rain masks scent: easier) | Pond with escape ramp, dripping leaves |

**Possible later gardens:** school garden, rooftop garden, park edge, seaside garden, snowy first-frost bonus level.

### 13.1 Level Structure Template
- **Start:** hedgehog arrives through a hedgehog highway hole.
- **Checkpoints:** 3–4 per garden (marked by a cozy leaf circle).
- **Secrets:** at least 3 hidden areas per garden.
- **Hibernation spots:** 2–4 per garden of different quality.
- **Optional quest:** given by an NPC (see [Section 15](#15-characters-friends-and-helpers)).

---

## 14. World Map: Hedgehog Highways

- Gardens are connected on an illustrated **neighbourhood map**.
- Paths between gardens are **hedgehog highways**: small holes (about 13 × 13 cm) in fences. This is a real conservation idea that lets hedgehogs roam between gardens.
- Finishing a garden **opens a highway** to the next.
- Some highways are **hidden** and lead to bonus gardens; they are found by collecting secrets or completing NPC quests.
- The map changes with the seasons and shows the hedgehog's home nest.

---

## 15. Characters: Friends and Helpers

| Character | Role |
|---|---|
| **Wise Old Toad** | Gives hints, explains mechanics, lives by the pond |
| **Gossiping Robin** | Tells you where threats are, warns when winter is near, guides you if the Winter Clock runs out |
| **Mole** | Digs **shortcuts** between parts of a garden after a quest |
| **Kind Child (human)** | Leaves out cat food and water, builds a **hedgehog house** (premium hibernation spot). Models good real-world behaviour |
| **Gardener (human)** | Background character; can be "helped" by eating slugs; may leave out a log pile |
| **Baby Hoglets** | Appear in later levels (see below) |

### 15.1 NPC Quests (examples)
- *Toad:* "Find my lost lily pad" → reward: journal entry plus a shortcut.
- *Robin:* "Chase the cat away from my nest using a feather" → reward: a cosmetic feather hat.
- *Mole:* "Bring me 5 worms" → reward: a tunnel shortcut.

### 15.2 Baby Hoglets
- From around garden 4, the hedgehog finds **lost hoglets** that **follow in a line**, like ducklings.
- They must be kept safe: threats can scare them. A scared hoglet runs to the nearest hiding spot and must be fetched (no permanent loss).
- Bringing hoglets to the nest gives a **bonus star** and a heartwarming cut-scene of everyone curling up together.

---

## 16. Collectibles and Progression

### 16.1 Shiny Things
Hidden in every garden: **buttons, marbles, bottle caps, lost keys, glass beads, coins**. Used to **decorate the home nest** (see [Section 18](#18-home-nest-hub)).

### 16.2 Sticker / Badge Album

| Badge | Condition |
|---|---|
| Beetle Muncher | Eat 50 beetles |
| Ghost Hog | Finish a garden without being spotted by a cat |
| Secret Finder | Find the secret burrow in any garden |
| Five-Star Sleeper | Earn 3 stars in 5 gardens |
| Hoglet Hero | Bring all hoglets home in one garden |
| Fact Fan | Unlock 25 journal facts |
| Highway Explorer | Discover a hidden hedgehog highway |

### 16.3 Unlocks
- Extra **heart containers** (found in secret areas).
- **Cosmetics** for the hedgehog.
- **Decorations** for the home nest.
- **Bonus gardens** via hidden highways.

---

## 17. Nature Journal (Educational Layer)

A scrapbook-style **nature journal** collects everything the player discovers.

### 17.1 Sections
- **Food:** every food found, with a good/bad marker.
- **Creatures:** cats, dogs, owls, toads, robins, insects.
- **Plants and places:** hedges, ponds, log piles, compost.
- **Hedgehog Facts:** real facts unlocked through play.
- **How to Help Hedgehogs:** real-world actions for families.

### 17.2 Example Hedgehog Facts
- Hedgehogs have around 5,000–7,000 spines.
- Hedgehogs can walk up to 2 km a night looking for food.
- Milk makes hedgehogs poorly; water is best.
- Hedgehogs need holes in fences to travel between gardens.
- Always check bonfire piles and long grass before burning or mowing.
- Ponds need a ramp so hedgehogs can climb out.
- Hedgehogs need to be heavy enough before winter to hibernate safely.

### 17.3 "How to Help" Page (real-world)
Simple, parent-friendly tips: make a hedgehog highway, leave a wild corner, put out water and meat-based cat food, build a hedgehog house, avoid slug pellets, check before mowing or strimming.

*Fact content should be reviewed by a wildlife expert or a hedgehog charity before release.*

---

## 18. Home Nest Hub

- A cozy **hub area** visited between levels.
- Players **decorate** it with shiny things and items found in gardens.
- Shows the **badge album**, **journal** and **wardrobe** (cosmetics).
- Rescued **hoglets** live here and play.
- The hub shows the current season on the world map.
- It gives kids a **lasting thing they build** across the whole game.

---

## 19. Failure and Difficulty

### 19.1 No Harsh Failure
- Being caught: the hedgehog **rolls into a ball and bounces away** to the last checkpoint with **−1 heart** and a little lost food. No game-over screen.
- At zero hearts: restart from the last checkpoint with full hearts. Collectibles already picked up are **kept**.
- No permanent loss of progress, hoglets or collectibles.

### 19.2 Difficulty Modes

| Mode | Threats | Winter Clock | Health | Intended for |
|---|---|---|---|---|
| **Explorer** | None (animals are all friendly) | Paused | Not shown | Very young kids (4–5), pure discovery |
| **Adventurer** (default) | Normal, with clear telegraphs | Normal | 3–5 hearts | Ages 6–8 |
| **Night Owl** | Faster detection, more threats | Faster | Fewer food spawns | Older kids and parents |

Difficulty can be changed **at any time** from the pause menu without penalty.

---

## 20. Accessibility

- **Voice-over** for all prompts, facts and NPC dialogue, so pre-readers can play.
- **Icon-first UI**; text is always optional.
- **Colour-blind-safe scent colours**: each scent type also has a distinct **shape/pattern** (dots, waves, stars, zigzag).
- **Subtitles** for all speech and important sounds (e.g. `[dog barks to the left]`).
- **One-handed / simplified controls** option (auto-run, toggle sniff instead of hold).
- **Adjustable game speed** (e.g. 75% speed).
- **Reduced motion** option for camera shake and fast effects.
- **Touch, controller and keyboard** all fully supported.

---

## 21. Two-Player Co-op

- **Local co-op** (split screen or shared screen), designed for **parent + child** or **two siblings**.
- Two hedgehogs, each with their own name and cosmetics.
- **Cooperative mechanics:**
  - one hedgehog distracts a threat while the other sneaks past,
  - two hedgehogs can push heavier objects (open new paths),
  - shared nest building; nest rating includes both.
- If one player is caught, they **respawn next to the other player** instead of at the checkpoint.
- **Drop-in / drop-out** at any time.

---

## 22. User Interface and HUD

### 22.1 HUD Elements (minimal)
| Element | Position | Notes |
|---|---|---|
| Hearts (Health) | Top-left | 3–5 hearts |
| Paw meter (Dexterity) | Under hearts | 3 segments |
| Season dial (Winter Clock) | Top-right | Leaf → tree → snowflake |
| Eye icon (hidden / visible) | Bottom-centre | Only shown near threats |
| Nest material counter | Top-right, under dial | Leaf icon with count |
| Power-up timer | Near hearts | Small icon with ring timer |

### 22.2 Menus
- **Pause:** resume, journal, map, settings, difficulty, quit to hub.
- **Journal:** scrapbook pages with tabs.
- **Settings:** audio, controls, accessibility, difficulty, parental settings.

### 22.3 Feedback
- Detection indicator `?` / `!` above threats.
- Context icons above interactable objects.
- Gentle screen-edge vignette (soft, not red) when a threat is close.

---

## 23. Art Direction

- **Style:** soft, stylised 3D with a hand-painted or storybook feel (low-to-mid poly, warm textures). Think picture book brought to life.
- **Camera height:** low, at hedgehog level, so the garden feels **big and wondrous**: giant flowers, towering sheds, enormous dogs.
- **Palette:** warm autumn oranges, browns and golds that cool into blues and whites as winter approaches.
- **Threat design:** cats and dogs are **expressive and slightly comical**, never menacing. Big eyes, readable poses.
- **Lighting:** dynamic **day/night cycle** and **weather** (sun, rain, fog, first frost).
- **Readability:** interactable objects have a soft outline or sparkle.

---

## 24. Audio

### 24.1 Music
- Soft acoustic **adaptive soundtrack** (e.g. plucked strings, woodwind, glockenspiel).
- **Layers:** calm exploration → light tension when a threat is near → back to calm when hidden.
- Each garden has its own theme variation; a lullaby plays for the hibernation cut-scene.

### 24.2 Sound Effects
- Snuffly hedgehog sounds, little squeaks and sneezes.
- **Satisfying crunch** when eating beetles (a key "juice" moment).
- Rustling leaves (louder in dry leaves, which matters for stealth).
- Cat collar bells, distant barks, owl hoots, robin song, rain on leaves.
- A cozy "pop" when entering a hiding spot.

### 24.3 Voice
- Friendly narrator for facts and tutorials.
- Short, characterful voice lines for NPCs (gibberish-style or simple words, easy to localise).

---

## 25. Technical Overview

*Engine not yet decided; see [Open Questions](#28-open-questions).*

| Option | Pros | Cons |
|---|---|---|
| **Godot 4** | Free, open source, lightweight, good 3D, easy to learn | Smaller asset store; console export needs third parties |
| **Unity** | Huge ecosystem, mature tooling, many tutorials | Licensing considerations |
| **Unreal Engine 5** | Top visuals | Heavy for a stylised kids' game; steeper learning curve |
| **Three.js / Babylon.js** (browser) | Instant play in browser, easy to share | Harder to scale to a full game; performance limits on tablets |

### 25.1 Key Systems to Build
1. Character controller (walk, scurry, roll, slope physics).
2. Third-person camera at low height with collision.
3. Stats system (Health, Dexterity, power-ups).
4. AI for threats: patrol, stalk/search, chase, lose interest, distraction response.
5. Perception system: vision cones, hearing radius, scent masking.
6. Sniff Mode rendering (scent trails, desaturation post-process).
7. Interaction system (eat, pick up, push, place nest material).
8. Nest building and rating.
9. Winter Clock (season progression, lighting, leaf colour, food spawns).
10. Save system (progress, journal, collectibles, hub decorations).
11. Co-op input and camera.
12. UI / HUD, journal, menus, accessibility settings.

### 25.2 Performance Targets
- 60 FPS on mid-range PC and consoles; 30 FPS minimum on mid-range tablets.
- Short loading times (< 10 s per garden).

---

## 26. Ethics and Monetisation

As a game for children:
- **No ads, no loot boxes, no in-game currency purchases.**
- Preferred model: **one-time purchase** (optional later: paid garden expansion packs).
- **No online chat or data collection** from children; offline-first.
- **Parental settings** for play-time reminders ("The hedgehog is getting sleepy, time for a break!").
- Consider partnering with a **hedgehog conservation charity** (fact review, possible donation share).

---

## 27. Production Plan and Milestones

| Milestone | Content | Goal |
|---|---|---|
| **M0: Concept** | This GDD, mood board, engine decision | Agree on vision |
| **M1: Prototype** | Grey-box garden; move, sniff, eat, roll; one cat with basic AI; hide spot; nest + hibernate | Prove the core loop is fun |
| **M2: Vertical Slice** | Garden 1 (Cottage Veg Patch) fully art-complete with audio, HUD, journal basics, cut-scene | Show final quality for one level |
| **M3: Alpha** | Gardens 1–6 playable, all core systems, world map, hub | Feature complete |
| **M4: Beta** | Polish, co-op, accessibility, difficulty modes, fact review, playtests with kids | Content complete, bug fixing |
| **M5: Release** | Platform certification, store pages | Ship |

### 27.1 Playtesting
- Test early and often with **children in the target age range** (with parental consent).
- Watch for: confusion, frustration, fear, and what makes them laugh or explore.
- Key metrics: time to first hide, number of catches per level, which secrets are found, which facts are read.

---

## 28. Open Questions

1. **Engine / platform:** Godot, Unity or browser (Three.js)? Which platforms first?
2. **Art style:** stylised low-poly vs. storybook painterly?
3. **Number of gardens** at launch: 6, or fewer with more depth?
4. **Hedgehog weight mechanic:** should "enough body weight before winter" (a real fact) become a visible stat, or stay folded into Health?
5. **Co-op scope:** local only, or online later?
6. **Localisation:** which languages at launch (e.g. English, German)?
7. **Charity partnership:** which organisation, and what form?
8. **Team size and budget.**

---

*End of document.*
