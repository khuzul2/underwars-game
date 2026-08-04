# Underwars — Agent Operating Manual

Turn-based 4X / base-builder / tactical warfare in a carved subterranean underworld.
**Engine:** Godot 4.7 (GDScript, 3D) · **Development model:** autonomous AI agent loop with headless test loop.

## Source of truth

`docs/GAME_DESIGN.md` (GDD v2.0, agent-ready) is the **single source of truth**. Binding rules:

- **Read before coding.** Before implementing any task, (re)read the GDD sections the task cites. Part B (§11–§18) is the operational contract: architecture, schemas, test loop, milestones.
- **Tables win.** Where prose and a numeric table disagree, the table wins. All constants live in `data/` JSON — **never hard-coded**.
- **Deviations** go in `docs/decisions.md` (dated entry: what changed, why, which section) and the affected GDD table is updated. Never silently diverge.
- **Never invent** new resources, stats, or systems not in the GDD. If a rule is ambiguous, pick the simplest interpretation consistent with the design pillars (§1.1), implement it, log it in `decisions.md`. Never stall (§13.4).
- **Non-goals (§17.2) are binding**: no multiplayer, campaign, diplomacy, heroes, fluid sim, stacked strata.

## Architecture (GDD §11 — binding)

`data/*.json → Sim Core (engine-free) → EventBus → Renderer/UI`, mutations only via **Commands**.

- Sim core (`scripts/core`, `scripts/sim`): pure `RefCounted`, **no Node/SceneTree/singletons/`randi()`** — must run headless byte-identically. One seeded RNG in `GameState` (`state.rng`); stable-ID iteration order; integer/percent math, round-half-up at the final step only.
- Every `GameState` mutation flows through a Command with `validate(state) -> Error?` and `apply(state) -> Array[Event]`. A match is fully described by `(seed, command_log)`.
- Renderer/UI observe the EventBus; the sim never calls them. UI may not import sim internals except read-only views + Command construction.
- Directory layout: GDD §11.2. Coding conventions: GDD §11.3 (static typing everywhere, `class_name` PascalCase, files snake_case, one class per file, rule functions annotated with the GDD § they implement).

## Toolchain (this machine)

- `godot` is on PATH (shim `C:\Users\aless\bin\godot.cmd` → local `C:\Users\aless\bin\godot47\Godot_v4.7-stable_win64_console.exe`). Verified working headless: `godot --headless --version` → 4.7.stable.
- **GUT 9.7.1** is vendored at `addons/gut/` (do not upgrade/modify it; it is not project code).
- Shell scripts (`tools/run_tests.sh`) run under Git Bash (the Bash tool), not PowerShell.
- Repo: `https://github.com/khuzul2/underwars-game` (branch `main`).

## Test commands (GDD §13.1)

```bash
bash tools/run_tests.sh          # GUT: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --headless -s tools/sim_smoke.gd -- seed=42 turns=60 map=small factions=dwarves,goblins
godot --headless -s tools/content_cli.gd -- validate data/
godot --headless -s tools/balance_lab.gd -- matches=100 out=reports/balance.csv   # Phase 2+
```

(These tools are M0+ deliverables; until a tool exists its command is expected to fail.)

**Definition of done (§13.6):** tests green headless · static typing clean · constants read from data, not code · events emitted for every state change · goldens re-recorded only with a logged reason (same commit) · relevant GDD table updated if numbers moved.

## The agent loop

State lives in `docs/PROGRESS.md` (current milestone, task log, next-task pointer). One iteration = the `underwars-iteration` workflow (`.claude/workflows/underwars-iteration.js`), implementing GDD §13.3:

1. **Orient** (Opus) — read PROGRESS/decisions/git log + the GDD milestone table; pick the single next task (≤ ~300 LOC; split anything larger); spec it with GDD section citations.
2. **Tests** (Opus) — write failing tests first when the rule is tabular; confirm they fail for the right reason.
3. **Implement** (Sonnet) — make the tests pass within the spec'd scope, following §11.3 conventions.
4. **Verify & Fix** (Opus) — run the full §13.1 suite headless; fix until green. Rule-table values must match the GDD — fix code to match tables, not tables to match code.
5. **Land** (Opus) — update `docs/PROGRESS.md` (+ `decisions.md` if deviated), commit `«task-id»: «title»`, push.

Work strictly in milestone order (M0…M8, then E1…E5, then C1…C6 — GDD §14–§16). A milestone is done only when its acceptance criteria pass headless. Commit messages start with the task ID (e.g. `M2-T3: vein nodes + extractor income`). If verify cannot reach green, land as `WIP(blocked) «task-id»: …` and record the blocker in PROGRESS.md so the next iteration starts there.

## House rules for loop agents

- Tasks ≤ ~300 LOC of change. Bigger → split and do only the first slice.
- Tests are first-class code: same typing standards; each test cites the GDD § it pins.
- `addons/`, `docs/GAME_DESIGN.md` are read-only for implementation agents (GDD tables change only via a decisions.md-logged tuning task).
- Determinism is sacred: no `randi()`, no wall-clock, no frame-time, no float accumulation in rules. Same seed + same commands ⇒ identical `GameState.hash()`.
- From M6 onward, adding content must require **zero engine-code changes** (§13.5 canary).
