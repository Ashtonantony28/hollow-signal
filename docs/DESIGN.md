# Hollow Signal — Game Design Document

Version 1.0 · 2026-11-12 · Status: Approved (pre-approved by the owner; build proceeds without sign-off)

## 1. Pitch

**Hollow Signal** is a fast, run-based first-person shooter set inside *Relay Hollow*, a derelict deep-space
signal relay. Its maintenance automata — collectively called **the Choir** — have spent forty years obeying a
corrupted broadcast, and they now treat every living thing as a fault to be repaired. You are a **Lineman**, a
repair specialist sent down the relay's spine. Each run descends through procedurally generated **decks**,
recovering **Tuning Cores**, calibrating **uplinks** under fire, and finally silencing **the Conductor**, the
mind that keeps the corrupted signal alive.

Three words: *tense, readable, kinetic.*

Design pillars:

1. **Every fight is a puzzle you solve at speed.** Enemies are shielded on a signal *band*; you retune your
   weapons mid-fight to break them. Positioning, band choice, and target priority beat raw aim.
2. **The station is the antagonist.** Decks are generated, lit, and populated by code from a seed. No two runs
   share a layout, but every layout is guaranteed fair (validated by tests on thousands of seeds).
3. **Light on hardware, heavy on feel.** It must run at 60 fps on integrated graphics with 4 GB RAM. Feel comes
   from movement, sound, and feedback, not from expensive rendering.
4. **Everything is code.** Levels, meshes, materials, sounds, music, enemy behaviour, balance tables, tests,
   and builds are generated or defined in text in this repository. The only manual step is playtesting.

## 2. Platform and technical constraints

| Item | Decision |
|---|---|
| Engine | Godot 4.3-stable, GDScript only (no .NET, so no extra runtime on the player's PC) |
| Renderer | `gl_compatibility` (OpenGL 3.3 / GLES3); runs on Intel UHD 620-class iGPUs |
| Target | 60 fps at 1280×720, render scale 0.5–1.0 adjustable; ≤ 1.5 GB RAM; ≤ 150 MB download |
| Platforms | Windows x86_64 (primary playtest), Linux x86_64 (CI / cloud smoke tests) |
| Assets | No imported binary art. Meshes built with `SurfaceTool`/primitive meshes, materials built in code, audio synthesised into `AudioStreamWAV` at load |
| Determinism | All generation is driven by a seeded `RandomNumberGenerator`; the same seed yields the same deck |
| Budgets | ≤ 24 active enemies, ≤ 6 dynamic lights visible per room, ≤ 150k triangles on screen, no real-time shadows by default (one optional shadowed light on "High") |

## 3. Player

### 3.1 Movement (the core verb)

| Move | Detail |
|---|---|
| Run | 7.5 m/s, high ground acceleration, little friction lag — snappy |
| Sprint | 10.5 m/s, cannot fire while sprinting, 0.15 s to recover aim |
| Jump | 1.3 m apex; coyote time 0.12 s; jump buffer 0.12 s |
| Crouch | 0.9 m capsule, 3.5 m/s |
| Slide | Crouch while sprinting: 1.0 s burst at 13 m/s decaying, 1.2 s cooldown; keeps momentum down slopes |
| Air control | Strafe-steer at 30 % of ground accel; small air speed cap so skilled players chain slide→jump |
| Dash ("Snap") | Short horizontal burst (8 m over 0.18 s), 2 charges, 3 s recharge each — unlocked as an early upgrade |

### 3.2 Vital stats

- **Integrity** (health) 100. No regeneration; restored by repair packs dropped by enemies and found in caches.
- **Plating** (armour) 0–100, absorbs 60 % of damage while it lasts.
- **Charge** 0–100: earned by dealing damage; spent on **Pulse**.

### 3.3 Pulse (signature ability)

Press `F` with ≥ 50 Charge: a sonar shockwave (12 m radius) that **staggers** enemies for 1.2 s, **reveals**
all enemies within 30 m through walls for 6 s, and **strips 1 shield layer** regardless of band. It is the
panic button and the setup tool for a big kill.

### 3.4 Bands (signature mechanic)

The Choir's shields resonate on one of three bands: **LOW (amber)**, **MID (teal)**, **HIGH (violet)**.
The player's weapons carry a **tuner** cycled with `Q` (or the mouse wheel click).

| Hit vs. shield | Multiplier |
|---|---|
| Matching band | ×3.0 to shield |
| Off band | ×0.5 to shield |
| Unshielded body | ×1.0 (band irrelevant) |
| Weak point (head/core) | ×2.0 to body |

Retuning takes 0.25 s (cannot fire). Shield colour on the enemy *and* a HUD ring show the active band, and
an audio pitch cue plays on matching hits, so the mechanic is readable by colour, shape, and sound
(colour-blind safe: each band also has a distinct shield pattern — stripes, dots, hexes).

## 4. Weapons

All weapons are procedural meshes (boxes, cylinders, prisms) with emissive accents that take the current band
colour. Damage numbers live in `game/data/weapons.gd` so balance is a text diff.

| # | Weapon | Role | Fire | Damage | Ammo |
|---|---|---|---|---|---|
| 1 | **Rivet Driver** | Sidearm, always reliable | Semi-auto hitscan, 5 shots/s | 18 | Infinite, 12-round mag |
| 2 | **Scattercoil** | Close range | 9 pellets hitscan, spread 6° | 9 ×9 | 24 shells |
| 3 | **Arc Lance** | Precision / penetration | Hold to charge (0.8 s) beam that pierces up to 3 enemies | 30–110 | 40 cells |
| 4 | **Pressure Launcher** | Area / mobility | Arcing grenade, 4 m splash, self-boost possible | 85 splash | 10 canisters |

Ammo pickups are generic "feedstock" converted into the active weapon's ammo, so the player is never stuck.

Feel checklist per weapon: muzzle flash (unshaded quad + 1-frame omni light), procedural recoil (camera kick
with spring return), viewmodel sway and bob, synthesised fire sound with random pitch ±5 %, hit marker,
distinct kill marker, impact particles coloured by surface (metal sparks vs. shield shards).

## 5. Enemies — the Choir

Every enemy is assembled from primitives in code (`game/enemies/meshes/`), with a readable silhouette and a
glowing weak point. Shields, when present, are a translucent shell coloured by band.

| Enemy | Role | HP / Shield | Behaviour |
|---|---|---|---|
| **Tick** | Swarm melee | 30 / 0 | Fast crawler, leaps the last 3 m, attacks in packs of 3–6. Pressures the player to move |
| **Warden** | Ranged line | 80 / 40 | Hitscan rifle with a 0.6 s telegraph laser; takes cover, strafes, flanks if squad-mates suppress |
| **Lobber** | Area denial | 120 / 60 | Slow; arcs explosive globs that leave a burning pool for 4 s; keeps distance |
| **Shrieker** | Support / flyer | 50 / 0 | Hovers, recharges shields of allies in 10 m, flees when targeted. High priority target |
| **Bulwark** | Heavy | 300 / 150 (front only) | Frontal barrier blocks all damage from the front; slow charge attack; must be flanked or Pulsed |
| **The Conductor** | Boss (deck 5) | 2500 / 3×300 | Three phases, rotates band each phase, summons adds, sweeping beam, arena hazards (see §8) |

### 5.1 AI architecture

- **Perception:** sight cone + line-of-sight raycast at 5 Hz per enemy (staggered across frames), hearing for
  gunfire within a radius, shared squad alert.
- **Behaviour:** a small hierarchical state machine per archetype (`idle → alert → engage{approach, attack,
  strafe, take_cover, flee} → stagger → dead`) written as plain GDScript classes so it is unit-testable.
- **Navigation:** `NavigationRegion3D` baked at runtime from the generated deck geometry; `NavigationAgent3D`
  with avoidance for crowds.
- **Attack tokens:** a squad coordinator grants at most *N* (difficulty-scaled, default 3) simultaneous
  attack tokens so the player is pressured but not instantly deleted.
- **Director:** a pacing system tracks an *intensity* value (damage taken, enemies near, time since last
  fight). It schedules waves into rooms the player has not seen, holds back during low-health moments, and
  spikes during uplink calibrations. Budget per wave is computed from deck number and difficulty.

## 6. The station — procedural decks

### 6.1 Structure of a run

```
Deck 1 (Intake) → Deck 2 (Cisterns) → Deck 3 (Foundry) → Deck 4 (Archive) → Deck 5 (Spire: Conductor)
```

Each deck has a **theme** (palette, fog colour, prop set, enemy weights) defined in `game/data/themes.gd`.

### 6.2 Deck generation algorithm

1. **Grid:** decks live on a cell grid (cell = 4 m, wall height 4–8 m).
2. **Room placement:** place *n* rooms (10–18 depending on deck) of typed templates using rejection sampling
   with 1-cell padding: `start`, `hub`, `arena`, `corridor`, `cache`, `vault` (holds the Tuning Core),
   `uplink`, `lift` (exit).
3. **Connectivity:** Delaunay-free approach — build a complete graph of room centres weighted by Manhattan
   distance, take its **minimum spanning tree** (guaranteed connected), then add back ~20 % of remaining edges
   for loops (so fights can be flanked and escaped).
4. **Corridors:** carve L-shaped corridors (width 2–3 cells) between connected rooms.
5. **Critical path:** BFS from `start` to `lift`; the `vault` and `uplink` must be reachable and the vault must
   not lie on the shortest start→lift path (forces exploration). Re-roll the seed if constraints fail.
6. **Geometry:** floor, walls, ceilings emitted as merged meshes per room (`SurfaceTool`, flat shading,
   vertex colour) plus `BoxShape3D` colliders; doorway frames, light strips, pipes, crates, and cover pieces
   placed from the theme's prop set with density rules (cover in arenas, clutter in corridors).
7. **Verticality:** arenas may get raised catwalks / ramps (2 m platforms) so fights are 3D.
8. **Lighting:** each room gets 1–3 omni lights (respecting the compatibility renderer's per-object light
   limit) and emissive strips; fog + ambient give mood cheaply.
9. **Navmesh** baked from the generated colliders at load; spawn points placed on the navmesh away from the
   player's line of sight.

All of this is pure, seedable code. `tests/test_deckgen.gd` generates hundreds of seeds and asserts:
connectedness, vault/uplink/lift reachability, no overlapping rooms, spawn points valid, generation time
< 200 ms per deck.

## 7. Run loop

1. **Arrive** in the deck's start room (safe for 5 s).
2. **Explore** — rooms trigger director waves as the player enters; caches hold ammo/repair/plating.
3. **Retrieve the Tuning Core** from the vault (guarded by an elite wave).
4. **Calibrate the uplink** — insert the core, then survive a 45–75 s hold-out while the progress ring fills;
   leaving the uplink zone pauses progress. Enemy pressure peaks here.
5. **Ride the lift** — the deck is clear. Between decks the **Patch Bay** offers **1 of 3 mods**.
6. Repeat; deck 5 is the Conductor's arena.
7. **Death** ends the run: summary screen (time, kills, accuracy, deck reached, seed), with *Retry Seed* and
   *New Run*.

### 7.1 Mods (upgrades) — examples

| Mod | Effect |
|---|---|
| Snap Drive | Unlocks the dash (2 charges) |
| Harmonic Rounds | Matching-band hits also deal 25 % to adjacent enemies' shields |
| Reclaimer | Kills have +15 % chance to drop repair |
| Deep Pockets | +50 % max ammo |
| Overclocked Pulse | Pulse costs 35 Charge |
| Plated | +25 plating at the start of each deck, max plating 125 |
| Quick Tuner | Retune time 0.1 s; first shot after retuning deals +50 % |
| Momentum Core | Damage +20 % while moving faster than 9 m/s |

Mods are data-driven (`game/data/mods.gd`) and stack where sensible.

### 7.2 Difficulty

`Lineman` (normal), `Foreman` (hard: +attack tokens, +30 % enemy HP), `Story` (half damage taken). Scaling also
per deck: wave budget ×1.25 per deck, elite chance +8 % per deck.

## 8. Boss — the Conductor

A suspended machine-choir in a circular arena with three rings of cover.

- **Phase 1 (LOW):** sweeping beam at chest height (jump/slide under), summons Ticks.
- **Phase 2 (MID):** detaches 3 shield nodes that must be destroyed on rotating bands; floor panels electrify
  in sequence.
- **Phase 3 (HIGH):** core exposed, aggressive homing volleys, Shriekers spawn; enrage below 15 %.

Victory → run complete screen, credits, and a "station restored" ending sting.

## 9. Presentation

- **Art direction:** low-poly brutalist sci-fi, flat-shaded, strong silhouettes; dark environment, bright
  emissive accents carry information (band colours are reserved for gameplay meaning).
- **Readability rules:** enemies always contrast against walls (rim emissive), projectiles glow, hazards pulse.
- **Camera:** FOV 90 default (70–110 setting), head-bob toggle, motion sickness-safe defaults.
- **Audio:** all SFX synthesised at runtime (noise bursts + filtered oscillators + envelopes); ambient music is
  a generative drone with layers that rise with director intensity. 3D positional audio for enemies.
- **UI:** HUD (integrity, plating, ammo, band ring, charge, objective text, compass pips toward objective), hit
  and kill markers, damage direction indicators, main menu, pause, settings, run summary.

## 10. Controls

| Action | Keyboard / mouse | Gamepad (later) |
|---|---|---|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Crouch / slide | Ctrl or C | B |
| Sprint | Shift | L3 |
| Fire / alt | LMB / RMB | RT / LT |
| Reload | R | X |
| Retune band | Q | Y |
| Pulse | F | RB |
| Dash | E (once unlocked) | LB |
| Weapons | 1–4, wheel | D-pad |
| Interact | E (context, on objectives) | X |
| Pause | Esc | Start |

## 11. Architecture

```
project.godot            Godot config (compatibility renderer, input map, autoloads)
game/
  autoload/              Game (run state), Events (signal bus), Audio (synth bank), Settings
  core/                  rng helpers, damage model, math utils
  player/                controller, weapon system, viewmodel
  weapons/               weapon defs + projectile scenes built in code
  enemies/               base enemy, archetypes, AI states, squad coordinator, director
  world/                 deck generator (pure data), deck builder (nodes), props, themes
  ui/                    HUD, menus — all built from code (no hand-made .tscn layouts)
  data/                  weapons.gd, enemies.gd, themes.gd, mods.gd (balance tables)
  main.tscn              minimal entry scene (only scene file kept; everything else is code)
tests/                   headless test runner + unit tests + smoke tests
tools/                   build/export scripts, screenshot capture, balance simulator
.github/workflows/       CI: tests on every push; Windows + Linux exports as artifacts
```

Principles: data and logic separate (the deck *generator* outputs a plain data layout; the deck *builder*
turns it into nodes), signal bus for decoupling, no scene files beyond the entry point so diffs stay readable.

## 12. Verification strategy (cloud-side)

1. **Unit tests** (custom zero-dependency runner, `godot --headless -s tests/run_tests.gd`): damage model, band
   multipliers, deck generator invariants on 500 seeds, AI state transitions, mod stacking, weapon fire rates.
2. **Smoke tests:** boot the full game headless, generate and build each deck theme, spawn every enemy, let an
   autopilot bot walk the critical path and fire for N seconds; fail on any script error or a stuck state.
3. **Screenshots:** a capture tool renders deck/enemy/weapon views with a software GL fallback in CI for visual
   review without the player's PC.
4. **Performance probes:** headless counts of nodes, draw calls estimate, triangle count per deck, generation
   time — asserted against budgets.
5. **Playtest (owner):** download the Windows build from CI artifacts / the project folder, play, report.

## 13. Milestones

| M | Name | Deliverable | Verify |
|---|---|---|---|
| M0 | Foundation | Repo, project config, test runner, CI, design doc | `tools/test.sh` green |
| M1 | Feel | Player controller (run/jump/crouch/slide), Rivet Driver, test room, HUD skeleton | unit tests + smoke boot |
| M2 | Station | Deck generator + builder, themes, lighting, navmesh | 500-seed invariants |
| M3 | Choir I | Damage/band model, Tick + Warden AI, squad tokens, hit feedback | AI unit tests + smoke |
| M4 | Loop | Vault → core → uplink hold-out → lift → next deck, director, pickups, menus, death/summary | smoke bot completes a deck |
| M5 | Arsenal | Scattercoil, Arc Lance, Pressure Launcher, Pulse, Lobber, Shrieker, Bulwark | per-weapon/enemy tests |
| M6 | Juice | Synth audio bank, generative music, particles, screen shake, damage indicators | audio gen tests, screenshots |
| M7 | Patch Bay + Boss | Mods, difficulty, the Conductor, run completion | boss phase tests |
| M8 | Ship | Settings menu, perf pass on low preset, Windows export, playtest feedback loop | export in CI, owner playtest |

## 14. Risks

| Risk | Mitigation |
|---|---|
| Owner's PC too weak | Compatibility renderer, render-scale slider, low preset default, no shadows |
| Procedural levels feel samey | Typed room templates, themes, verticality, loops, prop rules; tune with screenshots |
| Can't feel-test in the cloud | Numbers in data tables, quick owner feedback loop, debug overlay with tunables |
| Navmesh baking cost at runtime | Bake per deck at load behind a loading screen; simple geometry; measured in tests |
| Godot API drift | Pin 4.3-stable in CI and docs |

## 15. Originality note

Hollow Signal's world, names, enemies, and mechanics are original to this project. It borrows only genre
conventions (run-based structure, arena combat, upgrade choices) common to the FPS and roguelite genres.
