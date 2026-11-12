# Status — paused 2026-11-12 (owner paused all threads)

Done:
- Design doc (docs/DESIGN.md), Godot 4.3 Compatibility project, all code-generated.
- Deck generator + builder + grid nav; 18 headless tests pass (`tools/test.sh`), 600 seeds validated.
- Player controller, 4 weapons, bands, Pulse; 5 enemy types + Conductor boss; director; core → uplink → lift loop;
  HUD, menus, Patch Bay mods, procedural audio, autopilot bot.
- `tools/check.sh` parses all scripts cleanly.

In progress / next:
1. Autoplay smoke run (`godot --headless --path . -- --autoplay --god --seed=7 --quit-after=150 --timescale=4`)
   boots and plays; bot fires too rarely (aim threshold / fire toggle in game/player/autopilot.gd) — tune, then
   confirm a full deck completes.
2. Silence headless dummy-renderer "Parameter m is null" noise in logs (harmless) or filter it in scripts.
3. Screenshots via xvfb-run (mesa llvmpipe available) to check visuals/winding.
4. CI workflow (.github/workflows/ci.yml): tests + Windows/Linux export; export_presets.cfg.
5. Windows build to the owner's PC for playtest.
