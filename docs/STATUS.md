# Status

## v0.1 playable (2026-11-12)

- Full run loop: 5 procedural decks (Intake, Cisterns, Foundry, Archive, Spire) → Conductor boss.
- 4 weapons, band retuning, Pulse; Tick, Warden, Lobber, Shrieker, Bulwark; director pacing; Patch Bay mods.
- Cloud verification: 23 headless tests (unit, 600-seed deck invariants, enemy/boss tests, bot smoke test).
  A god-mode bot clears decks 1–4 and reaches the boss; a non-god bot clears deck 1 and usually dies on deck 2–3.
- Rendering checked through software-GL screenshots (xvfb + llvmpipe).
- Windows + Linux exports build in CI.

## Known gaps / next

- Owner playtest feedback (feel, difficulty, performance on the target PC).
- Visual variety: room props are boxes; add pipes, consoles, catwalks/ramps (DESIGN §6.2 step 7).
- Enemy readability at range; damage direction indicator; gamepad look.
- Bot can't finish the boss reliably in time limits (fine for a human; consider boss HP tuning after playtest).
