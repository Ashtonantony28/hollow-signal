# Hollow Signal — v0.3 "Full-fledged" overhaul plan

Trigger: owner playtest of v0.1 (2026-11-12): "decent, but doesn't look full-fledged — want way better graphics,
way better mechanics, much better movement, gun selection options".

Principle change: still **code-first** (layouts, gameplay, AI, materials, tests all in code), but visuals stop being
limited to flat-coloured primitives. Where code can't compete with real art, use **CC0** assets (ambientCG,
Poly Haven) fetched by a script and checked in with a license manifest. Pending owner decision.

## 1. Graphics

| Area | Now | Overhaul |
|---|---|---|
| Renderer | Compatibility only | Two tiers: **Forward+** (Vulkan) "High" with SSAO, SSIL, volumetric fog, glow, shadowed key lights, reflection probes, ACES tonemap; **Compatibility** "Low" fallback. Switched from Settings (writes `override.cfg`, restarts) |
| Surfaces | vertex colours | CC0 PBR texture sets (albedo/normal/roughness/metal) triplanar-mapped onto generated geometry; per-theme material palettes; grime/edge-wear via shader |
| Geometry | flat quads | Procedural modular kit: bevelled wall panels, ribs, ceiling beams, floor grates, door frames, pillars with caps, cable runs, light fixtures that cast light |
| Effects | spheres/boxes | GPU particles: muzzle smoke, sparks, debris, shell casings, steam vents, dust motes; bullet-hole decals; enemy hit flashes + break-apart deaths |
| Weapons | box viewmodels | Detailed procedural/CC0 viewmodels with PBR, sight alignment for ADS, animated reload/inspect/equip |
| Lighting | 1–2 omni per room | Light fixtures in the kit, emissive panels, flickering faults, coloured alarm lights during hold-outs |

## 2. Movement (genre conventions, tuned in data)

- Momentum-preserving slide (slopes accelerate), slide-jump keeps speed, crouch-jump
- **Mantle/vault** onto ledges up to ~1.6 m
- **Wall-run** (1.2 s, camera tilt) + wall-jump
- **Double jump** (thrusters), air dash (existing Snap Drive becomes base kit)
- Grapple hook as an unlockable ability
- Camera: FOV kick on speed, landing compression, weapon sway/inertia
- Tests: physics scripts assert mantle heights, wall-run duration, slide-hop speed retention

## 3. Guns + selection

- Arsenal grows to ~9: Rivet Driver (pistol), Hammer revolver, Needle SMG, Arc Carbine (AR, full-auto), Scattercoil
  (shotgun), Longwire (marksman, scope), Arc Lance (charge beam), Pressure Launcher, Hailstorm LMG
- **ADS** on every gun (right mouse), per-gun recoil patterns, hip-fire spread bloom, sprint-to-fire delay
- **Loadout screen** before a run: pick primary + secondary + ability from unlocked items
- **Weapon wheel** (hold Tab / middle mouse) with slow-mo; number keys still work
- Weapon pickups in decks with rarity tiers (Standard/Tuned/Resonant) and mods per gun (mag, fire-rate, band-lock)
- Between runs: **Salvage** currency unlocks guns/abilities (meta progression)

## 4. Mechanics

- Enemy hit reactions, limb/plate destruction on bigger enemies, staggers on weak-point hits
- Two new enemies (sniper "Lamplighter", shield-drone swarm) and elite affixes
- Environmental hazards: explosive canisters, steam vents, electrified floors
- Boss rework with arena changes per phase

## 5. Order of work

1. Movement overhaul + ADS/recoil + weapon wheel + loadout (no asset dependency) — **starting now**
2. Renderer tiers + procedural modular kit + particles/decals
3. CC0 texture pipeline (if approved) + detailed viewmodels
4. New guns, pickups/rarity, meta progression
5. Enemies/hazards/boss rework, balance via bot runs, Windows builds each step
