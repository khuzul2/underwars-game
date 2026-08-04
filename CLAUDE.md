# Underwars — Agent Operating Manual

Turn-based 4X / base-builder / tactical warfare in a carved subterranean underworld.
**Engine:** Godot 4.7 (GDScript, 3D) · **Development model:** autonomous AI agent loop with headless test loop.

## Source of truth

`docs/GAME_DESIGN.md` (GDD v2.0, agent-ready) is the **single source of truth**. Binding rules:

- **Read before coding.** Before implementing any task, (re)read the GDD sections the task cites. Part B (§11–§18) is the operational contract: architecture, schemas, test loop, milestones.
- **Tables win.** Where prose and a numeric table disagree, the table wins. All constants live in `data/` JSON — **never hard-coded**.
- **Deviations** go in `docs/decisions.md` (dated entry: what changed, why, which section) and the affected GDD table cell is updated **by the Land stage, in the same commit** as the decisions.md entry — that is the only sanctioned edit to `docs/GAME_DESIGN.md`. Never silently diverge. Test authors and verifiers must read `docs/decisions.md`: a logged, dated override supersedes the printed GDD table value.
- **Never invent** new resources, stats, or systems not in the GDD. If a rule is ambiguous, pick the simplest interpretation consistent with the design pillars (§1.1), implement it, log it in `decisions.md`. Never stall (§13.4).
- **Non-goals (§17.2) are binding** — read §17.2 itself for the authoritative list and its qualifiers (e.g. fluid/lava *simulation* is out, but one-shot flood fill events ARE in scope — §4.2 Deep Water, §8.2 Underground Stream; modding docs are not a v1 deliverable though the data pipeline enables it later).

## Architecture (GDD §11 — binding)

`data/*.json → Sim Core (engine-free) → EventBus → Renderer/UI`, mutations only via **Commands**.

- Sim core (`scripts/core`, `scripts/sim`): pure `RefCounted`, **no Node/SceneTree/singletons/`randi()`** — must run headless byte-identically. One seeded RNG in `GameState` (`state.rng`); stable-ID iteration order; integer/percent math, round-half-up at the final step only.
- Every `GameState` mutation flows through a Command with `validate(state) -> Error?` and `apply(state) -> Array[Event]`. A match is fully described by `(seed, command_log)`.
- Renderer/UI observe the EventBus; the sim never calls them. UI may not import sim internals except read-only views + Command construction.
- Directory layout: GDD §11.2. Coding conventions: GDD §11.3 (static typing everywhere, `class_name` PascalCase, files snake_case, one class per file, rule functions annotated with the GDD § they implement).

## Toolchain (this machine)

- **Pinned Godot binary:** `C:\Users\aless\bin\godot47\Godot_v4.7-stable_win64_console.exe` (4.7.stable.official.5b4e0cb0f, headless verified). `tools/run_tests.sh` resolves it via `$GODOT_BIN` with this pinned default — prefer the script over the bare `godot` PATH shim, which is NOT pinned (it prefers a Google-Drive copy when `G:` is mounted; a re-mount would silently switch binaries mid-loop).
- **GUT 9.7.1** is vendored at `addons/gut/` (do not upgrade/modify it; it is not project code).
- Shell scripts (`tools/run_tests.sh`) run under Git Bash (the Bash tool), not PowerShell.
- Repo: `https://github.com/khuzul2/underwars-game` (branch `main`).

## Test commands (GDD §13.1, as amended — see decisions.md 2026-08-04)

```bash
bash tools/run_tests.sh          # from M0 — imports (.godot cache), then GUT with -ginclude_subdirs; hardened: exits non-zero if zero tests ran
godot --headless -s tools/sim_smoke.gd -- seed=42 turns=60 map=small factions=dwarves,goblins   # fully meaningful from M7 (needs M6 factions + M7 AI)
godot --headless -s tools/content_cli.gd -- validate data/    # delivered in E4 (Phase 2); Phase-1 substitute: GUT tests on RulesLoader (M0 acceptance)
godot --headless -s tools/balance_lab.gd -- matches=100 out=reports/balance.csv   # delivered in E5 (Phase 2)
```

**Applicability rule:** run every command that applies to the current milestone (`run_tests.sh` always, once M0 lands). A command whose tool is not yet due — or not yet built — is **not** a blocker and must not be reported as a failure. `tools/run_tests.sh` is pre-provided as the harness *contract*: make it pass, never weaken it (it deliberately fails when GUT collects zero tests — GUT itself exits 0 in that state; `reports/` contents are gitignored, so balance tooling must `mkdir -p` its output dir and evidence files are force-added deliberately).

**Definition of done (§13.6):** tests green headless · static typing clean (mechanical gate = the M0 CI script with `--warnings-as-errors` per §11.3; until it lands, verify by diff review) · constants read from data, not code · events emitted for every state change · goldens re-recorded only with a logged reason (same commit) · relevant GDD table cell updated by Land if numbers moved (same commit as the decisions.md entry).

## The agent loop

State lives in `docs/PROGRESS.md` (current milestone, task log, next-task pointer). One iteration = the `underwars-iteration` workflow (`.claude/workflows/underwars-iteration.js`), implementing GDD §13.3:

1. **Orient** (Opus) — read PROGRESS/decisions/git log + the GDD milestone table; pick the single next task (≤ ~300 LOC; split anything larger); spec it with GDD section citations.
2. **Tests** (Opus) — write failing tests first when the rule is tabular; confirm they fail for the right reason.
3. **Implement** (Sonnet) — make the tests pass within the spec'd scope, following §11.3 conventions.
4. **Verify & Fix** (Opus) — run every §13.1 command that applies to the current milestone (see Applicability rule above), headless; fix until green. Rule-table values must match the GDD (as amended by logged decisions.md overrides) — fix code to match tables, not tables to match code.
5. **Land** (Opus) — update `docs/PROGRESS.md` (+ `decisions.md` if deviated), commit `«task-id»: «title»`, push.

Work strictly in milestone order (M0…M8, then E1…E5, then C1…C6 — GDD §14–§16). A milestone is done only when its acceptance criteria pass headless. Commit messages start with the task ID (e.g. `M2-T3: vein nodes + extractor income`). If verify cannot reach green, land as `WIP(blocked) «task-id»: …` and record the blocker in PROGRESS.md so the next iteration starts there.

## House rules for loop agents

- Tasks ≤ ~300 LOC of change. Bigger → split and do only the first slice.
- Tests are first-class code: same typing standards; each test cites the GDD § it pins.
- `addons/` is read-only. `docs/GAME_DESIGN.md` is read-only for the Tests/Implement/Verify stages; only the Land stage may edit it, and only the specific table cell covered by a decisions.md entry in the same commit.
- Determinism is sacred: no `randi()`, no wall-clock, no frame-time, no float accumulation in rules. Same seed + same commands ⇒ identical `GameState.hash()`.
- From M6 onward, adding content must require **zero engine-code changes** (§13.5 canary).
