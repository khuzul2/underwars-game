# Decisions Log

Binding record of every deviation from `docs/GAME_DESIGN.md` and every ambiguity resolved
during implementation (GDD §0.3, §13.4). One dated entry per decision. Never silently diverge.

Format:

```
## YYYY-MM-DD — «task-id» — «short title»
- **What changed / was decided:**
- **Why:**
- **GDD section affected:** §X.Y (table updated: yes/no)
```

---

## 2026-08-04 — SETUP — Toolchain baseline

- **What changed / was decided:** Target engine is Godot **4.7 stable** (GDD requires 4.3+). Test framework pinned to vendored **GUT 9.7.1** at `addons/gut/`. Shell tooling runs under Git Bash on Windows.
- **Why:** 4.7 is what is installed and verified headless on the dev machine; satisfies the 4.3+ requirement. Vendoring GUT keeps the headless loop free of network fetches.
- **GDD section affected:** GDD preamble / doc header ("Engine: Godot 4.3+") — 4.7 satisfies it; no table updated. (§13.1 commands unchanged by this entry; see SETUP-2 below for the §13.1 amendment.)

## 2026-08-04 — SETUP-2 — Test-runner hardening (§13.1 command amended; M0 acceptance strengthened)

- **What changed / was decided:**
  1. The §13.1 GUT invocation gains two mandatory elements, wrapped in `tools/run_tests.sh` (pre-provided as the harness contract): a `godot --headless --import` pass first, and `-ginclude_subdirs` on the gut_cmdln run.
  2. `run_tests.sh` fails (exit 1) when GUT collects zero tests ("Nothing was run" / bad `-gdir` path / unimported project), and exits 2 when `project.godot` doesn't exist yet.
  3. M0's acceptance criterion "Empty suite runs green headless" (§14) is strengthened to: *a passing sentinel test suite exits 0, and a deliberately failing sentinel makes `run_tests.sh` exit non-zero* — proving the harness both ways.
  4. Ownership rule: GDD table edits accompanying a logged deviation are made by the **Land** stage only, in the same commit as the decisions.md entry.
- **Why:** Verified empirically on this machine (Godot 4.7 + GUT 9.7.1, scratch project): without `--import`, `gut_cmdln.gd` quits **0** having run nothing (missing `.godot/global_script_class_cache.cfg`); without `-ginclude_subdirs`, `-gdir=res://tests` ignores `tests/unit|sim|golden` — the exact §11.2/§13.2 layout — printing "[GUT ERROR]: Nothing was run" with exit **0**; GUT exits 0 whenever `fail_count == 0`, so "no tests collected" is indistinguishable from "all passed" by exit code alone. Any of these would have made the loop's green signal permanently false from M1 onward.
- **GDD section affected:** §13.1 (command text updated in the same commit) and §14 M0 acceptance row (updated in the same commit).

## 2026-08-04 — SETUP-3 — Self-contained engine: repo-local Godot binary

- **What changed / was decided:** The Godot 4.7-stable binaries (`Godot_v4.7-stable_win64.exe` + console wrapper, build `4.7.stable.official.5b4e0cb0f`) now live at `godot/` inside the repo, and **everything uses only that copy** — `tools/run_tests.sh` hardcodes it (the `$GODOT_BIN` override was removed), and all documented commands invoke `./godot/Godot_v4.7-stable_win64_console.exe`. PATH shims and machine-global installs are forbidden. `godot/` is gitignored (the 178 MB exe exceeds GitHub's 100 MB file limit); a fresh clone restores the two exes per README.
- **Why:** Operator request (2026-08-04): the project must be self-contained; the previous user-profile pin depended on machine-global state, and the PATH shim could silently switch binaries when a Google-Drive mount reappears.
- **GDD section affected:** none (toolchain only; §13.1 command semantics unchanged).

## 2026-08-04 — M0-T1 — `verify_harness.sh` added; no rule deviations

- **What changed / was decided:**
  1. New tool `tools/verify_harness.sh` mechanizes the amended §14 M0 acceptance criterion (SETUP-2 item 3) end-to-end: Phase A requires `run_tests.sh` exit 0 on the real sentinel suite; Phase B plants a temporary deliberately-failing `tests/unit/test_harness_redcanary.gd` and requires exit non-zero; it then removes the canary (and its generated `.uid`) via `trap … EXIT` and re-requires green, leaving the tree clean. It is **not** a §13.1 command — it is the proof of the M0 acceptance row and re-runnable at any later milestone; its absence from §13.1 is never a failure.
  2. No game rules, constants, resources, stats or systems were introduced. M0-T1 is bootstrap only (`project.godot`, GUT wiring, §11.2 skeleton dirs pinned with `.gitkeep`, sentinel tests). `data/ruleset.json` and RulesLoader are deliberately **not** pre-created — they belong to M0-T2 (§13.4: never invent ahead of the milestone).
  3. Goldens: none were re-recorded — none exist yet (first golden lands with M1's mapgen hash).
  4. Operational note, deliberately **not** acted on: `.claude/settings.json` allowlists `bash tools/run_tests.sh` but not `bash tools/verify_harness.sh`. Loop agents do not edit permission/harness configuration; adding that entry is an operator decision. It did not prompt in this session, so it is not a blocker.
- **Why:** SETUP-2 strengthened M0's acceptance to a two-way proof, but nothing executed it; a criterion only checked by hand rots. Encoding it as a script makes "the harness still fails when it should" a repeatable check rather than a one-off claim. Items 2–4 are recorded to make explicit that the stage's reported "deviations" were scope statements and an environment note, not divergences from the GDD.
- **GDD section affected:** none. §14's M0 row already carries the SETUP-2 amendment (no table value moved, no cell edited this commit); §13.1's command list is unchanged.

## 2026-08-04 — M0-T2 — RulesLoader: line-numbering contract, engine quirks, API surface

- **What changed / was decided:**
  1. **Scope split (loop process, binding for the tracker).** PROGRESS's M0-T2 pointer bundled *EventBus + RulesLoader + ruleset.json*; that exceeds the ~300 LOC house cap, so M0-T2 shipped the **first slice only** — `data/ruleset.json` (full §12.1 constant set, values transcribed verbatim) + `scripts/sim/rules_loader.gd` + `scripts/sim/rules_error.gd` + `tests/unit/test_rules_loader.gd`. EventBus becomes **M0-T3** and the CI script (with the §11.3 `--warnings-as-errors` gate) **M0-T4**. No §14 deliverable was dropped, only re-sequenced.
  2. **Line-number contract (ambiguity resolution, §13.4).** `RulesError.line` is **1-based** — the first line of the document is line 1. **Line 0 means "no line" and is reserved exclusively for file-level errors** (missing/unreadable file); a schema error may never carry 0.
  3. **Schema-error line attribution (ambiguity resolution, §13.4).** The parsed Variant carries no line information, so lines are attributed by scanning the raw text: for a dotted path `a.b.c`, find the token `"a"`, then search **forward from that line** for `"b"`, then for `"c"`; fall back to the last segment that *was* found (a missing child inside a present group is attributed to the group's own line), and to **line 1** if not even the first segment exists (e.g. the whole group was deleted). Implemented as one helper (`RulesLoader._attribute_line`) — deliberately not a second parser.
  4. **Validation shape (§11.1 determinism).** Validation is driven by a single statically-typed, ordered spec table walked depth-first, so error order never depends on parsed `Dictionary` key order: the same invalid text always yields a byte-identical error list, and `errors[0]` is always the earliest defect in §12.1 spec order. All errors are collected (never stop at the first), and on **any** error `rules` is left **empty** — a half-valid ruleset can never be read.
  5. **Forward compatibility.** §12.1 is explicitly an "excerpt", so an unknown **extra** top-level key loads clean with zero errors; only missing or malformed **required** keys are errors.
  6. **API surface beyond the task spec's listed accessors:** `get_string(dotted_path) -> String` and `get_int_array(dotted_path) -> Array[int]` were added, required by §12.1's String `version` field and its four fixed-length int arrays (`combat.effective_armor_clamp`, `wrath.thresholds`, `train_turns_by_tier`, `tech_cost_by_tier`). `RulesError`'s render helper is `format_for(source)` → `"<source>:<line>: <message>"`.
  7. **`data/ruleset.json` layout is load-bearing, not cosmetic:** line 1 is a lone `{` and each §12.1 top-level group sits entirely on one line, so single-line defects are plantable and expected line numbers are derived from the fixture rather than magic constants. Only the pretty-printing differs from the GDD's prose rendering — **no numeric value differs from §12.1**.
  8. **Empirical Godot 4.7.stable facts the contract depends on** (probed independently twice — by Tests and again by Verify at three separate line positions — because the engine docs are unclear): `JSON.get_error_line()` is **0-based** (normalized `+1` inside `load_text`); Godot's JSON parser **accepts trailing commas**, so a trailing comma is unusable as a syntax-error fixture; **every** JSON number parses as `TYPE_FLOAT`, even `1` and `250`, therefore int leaves accept an integral float and **reject a fractional one** rather than silently truncating (`dig_turns.soft = 1.5` is an error, never `1`).
  9. **Goldens:** none re-recorded — none exist yet (the first golden lands with M1's mapgen hash).
  10. **Known gap between two GDD tables, deliberately not papered over:** §4.2's terrain table gives Artificial Granite a dig yield of **+2 Stone**, but the §12.1 excerpt's `dig_yields` omits `artificial_granite`. `data/ruleset.json` mirrors the §12.1 excerpt, so the key is absent and the schema does not require it. **M2 (Dig & Economy) must add it with its own decisions.md entry.** No table cell is edited now — nothing was decided against the GDD, the excerpt is simply narrower than the terrain table.
  11. **Harness hole found (not fixed here; `run_tests.sh` is off-limits outside a dedicated task).** A GDScript **parse error in a test file** makes GUT log `Ignoring script … because it does not extend GutTest` and exit **0** — the same class of false green SETUP-2 hardened against, and it fired live this iteration (a `loader is Node` cast, which GDScript rejects at parse time as statically impossible, silently un-collected the entire 26-test file while the run printed "All tests passed!"). It did **not** affect the landed result (counts verified: Scripts 4 / Tests 32). Queued as **M0-T5**: add `Ignoring script` / `Failed to load script` to the runner's refusal grep — a *strengthening* of the harness contract, which is permitted.
- **Why:** Items 2–4 and 7 resolve genuine ambiguities the GDD does not legislate (it requires a "line-numbered error" but not how a line is attributed to a schema violation, nor what "no line" means), picking the simplest deterministic interpretation per §13.4 rather than stalling. Item 6 is forced by the §12.1 data shape — the spec listed only `get_int`/`get_float`/`has`, which cannot express a String field or a fixed-length int array. Item 8 records measurements that contradict the obvious reading of the docs, so no future stage re-derives them from memory and gets them wrong. Items 1, 9, 10 and 11 are recorded so that scope re-sequencing, an untouched-goldens claim, a cross-table gap and a live false-green mode are all traceable instead of tribal knowledge.
- **GDD section affected:** §12.1 (all values transcribed verbatim — **no table value moved, no cell edited**); §11.1/§11.2/§11.3 (conventions followed, not amended); §13.4 (ambiguity-resolution procedure exercised); §14 M0 row — the "invalid ruleset rejected with a line-numbered error" acceptance clause is now **MET** headless, with no change to the printed criterion text. **No `docs/GAME_DESIGN.md` edit accompanies this entry because no numeric value changed.**
