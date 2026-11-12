# Hollow Signal

An original, code-first roguelite FPS. Descend through procedurally generated decks of *Relay Hollow*, a
derelict signal relay, recover Tuning Cores, hold uplinks under fire, and silence the Conductor.

Everything — levels, meshes, materials, sounds, music, enemy AI, menus — is generated from GDScript in this
repo. No imported art or audio. Built with **Godot 4.3 (Compatibility renderer)** so it runs on integrated
graphics.

- Design: [docs/DESIGN.md](docs/DESIGN.md) · Status: [docs/STATUS.md](docs/STATUS.md)

## Play

Download `HollowSignal-windows` from the latest CI run (Actions tab) and run `HollowSignal.exe`.
Low-end PC: Settings → Render scale 0.6–0.7 and Quality Low.

Controls: WASD, mouse, Space jump (again in the air = double jump; at a ledge = mantle; on a wall = wall-jump),
Shift sprint, Ctrl/C crouch (slide when moving fast), LMB fire, RMB aim down sights, R reload, 1–4 / wheel /
hold Tab weapons, **Q retune band**, **F Pulse**, E interact, Esc pause, F3 debug overlay.
Loadout & Armory in the main menu: pick 4 guns, unlock more with Salvage earned per run.

Core mechanic: enemy shields glow amber/teal/violet. Retune (Q) to the same band for triple shield damage.

## Develop (all headless)

```bash
tools/test.sh                 # unit tests, 600-seed deck invariants, bot smoke tests
tools/check.sh                # parse every script
# a bot plays the game (god mode), prints progress
godot --headless --path . -- --autoplay --god --seed=7 --quit-after=120 --timescale=4
# screenshots with software GL
xvfb-run -a godot --path . -- --autoplay --seed=7 --screenshot=shots --shot-every=8 --quit-after=60
# exports
godot --headless --path . --export-release "Windows" build/windows/HollowSignal.exe
```

Flags after `--`: `--seed=N --deck=N --autoplay --god --skip-menu --quit-after=S --screenshot=DIR
--shot-every=S --timescale=X --botlog`.

## Layout

`game/autoload` run state, settings + input map, synth audio · `game/world` deck generator/builder, nav,
level loop · `game/player` controller, weapons, autopilot · `game/enemies` Choir AI, director, boss ·
`game/ui` HUD and menus · `game/data` balance tables · `tests/` headless runner.
