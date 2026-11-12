# Status

## v0.1 playable (2026-11-12)

- Full run loop: 5 procedural decks (Intake, Cisterns, Foundry, Archive, Spire) → Conductor boss.
- 4 weapons, band retuning, Pulse; Tick, Warden, Lobber, Shrieker, Bulwark; director pacing; Patch Bay mods.
- Cloud verification: 23 headless tests (unit, 600-seed deck invariants, enemy/boss tests, bot smoke test).
  A god-mode bot clears decks 1–4 and reaches the boss; a non-god bot clears deck 1 and usually dies on deck 2–3.
- Rendering checked through software-GL screenshots (xvfb + llvmpipe).
- Windows + Linux exports build in CI.

## v0.3 movement + guns (2026-11-12, from owner playtest)

- Movement: momentum slide (boost + friction decay), slide-hop keeps speed, mantle onto ledges up to 1.9 m,
  wall-run (1.3 s, camera tilt) + wall-jump, double jump (thrusters), speed-based FOV.
- Guns: 9 weapons (Rivet Driver, Hammer, Needle, Arc Carbine, Scattercoil, Longwire, Arc Lance, Pressure
  Launcher, Hailstorm); ADS on all with sight alignment and FOV/sensitivity scaling; real-aim recoil with a
  learnable pattern + auto-recovery; spread bloom, movement/air penalties; Longwire scope; Hailstorm spin-up.
- Weapon wheel (hold Tab, slow-mo), 4-slot loadout, Armory with Salvage unlocks (persistent profile).
- `--guns=DIR` gun gallery QA mode. 29 headless tests (new: mantle, double jump, slide momentum, wall-run).
- Graphics: procedural PBR panel textures (albedo/normal/roughness) on walls, floors, ceilings; Quality
  renderer tier (Forward+/Vulkan: SSAO, SSIL, volumetric fog, shadows, ACES) chosen in Settings via
  override.cfg + restart, Fast (Compatibility) default. Cloud screenshots of Quality need mesa-vulkan-drivers
  (lavapipe): `xvfb-run -a godot --path . --rendering-method forward_plus --rendering-driver vulkan -- --tour=DIR`.
- FX: CPUParticles3D impact sparks, dust, bullet marks (80-quad ring buffer), casings, muzzle and death smoke.
- Models: chamfered boxes for all primitive parts, viewmodel key light.

## Known gaps / next

- Owner playtest feedback (feel, difficulty, performance on the target PC).
- Enemy models are still primitive-based (CC0 art decision pending with the owner).
- New enemies/hazards, boss rework, pickups with rarity (OVERHAUL.md).
- Bot can't finish the boss reliably in time limits (fine for a human; consider boss HP tuning after playtest).
