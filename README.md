# Underwars

Turn-based 4X / base-builder / tactical warfare in a carved subterranean underworld.
The map is solid rock: every player digs their own fortress, economy, and battlefield out of
the dark — then meets the neighbors, and the things that live below.

**Engine:** Godot 4.7 (GDScript, 3D) · **Tests:** GUT 9.7.1 (vendored at `addons/gut/`)
**Development model:** autonomous AI agent loop with a headless test loop.

## Self-contained toolchain

The engine lives **inside the repo** at `godot/` and everything (tests, tools, agents) uses only
that copy — no PATH shims, no machine-global installs. `godot/` is gitignored because the main
exe (178 MB) exceeds GitHub's file limit, so after a fresh clone restore it once:

1. Download **Godot 4.7-stable win64** (official build, `4.7.stable.official.5b4e0cb0f`).
2. Put `Godot_v4.7-stable_win64.exe` and `Godot_v4.7-stable_win64_console.exe` in `godot/`.

`tools/run_tests.sh` exits 2 with instructions if the binaries are missing.

## Key documents

| File | Purpose |
| --- | --- |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | GDD v2.0 — single source of truth (rules, content, architecture, milestones) |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Agent-loop state: current milestone, task log, next task |
| [docs/decisions.md](docs/decisions.md) | Binding log of deviations & ambiguity resolutions |
| [CLAUDE.md](CLAUDE.md) | Operating manual for the coding agents |
| `.claude/workflows/underwars-iteration.js` | One loop iteration: Orient → Tests → Implement → Verify → Land |

## The agent loop

Each iteration runs one task (≤ ~300 LOC) of the current milestone (M0…M8 → E1…E5 → C1…C6):
**Opus 5** orients (picks & specs the task), writes the tests first, verifies/fixes to green, and
lands the commit; **Sonnet 5** does the implementation heavy lifting. State persists in
`docs/PROGRESS.md`, so iterations resume cleanly across sessions.

Start it from Claude Code by asking to run the `underwars-iteration` workflow (optionally in a
repeating loop). One-off iterations can be steered with `args: { "taskHint": "..." }`.

## Test commands (GDD §13.1 — availability by milestone)

Delivered by **M0** (the harness script already exists as the contract; M0 makes it pass):

```bash
bash tools/run_tests.sh
```

Delivered by **M7** (needs M6 factions + M7 AI; the tool may exist earlier but this run is M7's
acceptance bar):

```bash
./godot/Godot_v4.7-stable_win64_console.exe --headless -s tools/sim_smoke.gd -- seed=42 turns=60 map=small factions=dwarves,goblins
```

Delivered by **E4** and **E5** (Phase 2):

```bash
./godot/Godot_v4.7-stable_win64_console.exe --headless -s tools/content_cli.gd -- validate data/
```

```bash
./godot/Godot_v4.7-stable_win64_console.exe --headless -s tools/balance_lab.gd -- matches=100 out=reports/balance.csv
```
