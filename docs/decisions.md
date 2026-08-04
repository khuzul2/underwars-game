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

## 2026-08-04 — M0-T3 — EventBus dispatch contract (six §13.4 ambiguity resolutions)

§11.1 specifies *that* there is an EventBus ("typed events emitted by `apply()` … Renderer/UI
subscribe; the sim never calls them") but legislates **no** delivery semantics. The six
resolutions below are therefore §13.4 decisions, not deviations: each picks the simplest
deterministic reading and each is test-pinned in `tests/unit/test_event_bus.gd`, whose assertion
messages cite these letters — **keep the lettering stable**.

- **What changed / was decided:**
  1. **(a) Delivery order = per-type registration order, oldest subscriber first.** The per-type
     subscriber list is an ordered `Array[Callable]`; `_subscribers` (the `StringName → Array`
     `Dictionary`) is **only ever touched by key lookup** — never iterated, never `.keys()` /
     `.values()` — so `Dictionary` key order can never leak into behaviour (§11.1 "iterate
     collections in stable ID order"). `emit_all()` delivers in array order, matching
     `apply(state) -> Array[Event]`.
  2. **(b) Nested emits are QUEUED FIFO, never depth-first.** An `emit()` issued from inside a
     handler appends to a single shared queue and returns; the outer drain delivers it after the
     current event is fully dispatched. Two handlers of `X` that each emit a `Y` therefore produce
     `A1, A2, Y1, Y2` — never `A1, Y1, A2, Y2`. `is_dispatching()` is `false` before `emit()`,
     `true` inside a handler, and `false` again when the outer `emit()` returns (the whole queue
     drains before it returns). **Sub-point (b), added at Verify:** `emit_all()` queues the
     **entire** incoming `Array[Event]` before draining, so the batch is atomic — an event nested
     by a handler mid-batch lands *after* the whole batch, never interleaved between its elements.
     The Implement stage flagged this as an unpinned judgement call; Verify confirmed it
     (a Command's returned event array is one coherent result, and one shared FIFO queue is the
     simplest deterministic reading) and test-pinned it
     (`test_emit_all_batch_is_atomic_against_nested_emits`).
  3. **(c) The subscriber list is snapshotted per event, with a liveness re-check, so nothing done
     inside a handler can affect the in-flight event.** `_dispatch` prunes invalid entries, takes a
     `duplicate()` snapshot, then re-checks each entry is still present in the **live** table
     immediately before calling it. A `subscribe()` made during dispatch misses the in-flight event
     and receives the next emit of that type; an `unsubscribe()` made during dispatch cancels
     delivery to handlers that have not run yet. **WIDENED at Verify:** `clear()` is a
     mass-unsubscribe and therefore behaves identically — handlers of the in-flight event that have
     not run yet are skipped. As implemented, the re-check consulted a stale local reference to the
     per-type array, so `clear()` mid-dispatch was ignored while `unsubscribe()` was honoured;
     delivery must not depend on which teardown call an observer happens to use. Fixed by
     re-reading `_subscribers` before each call; pinned by
     `test_clear_during_dispatch_cancels_the_rest_of_the_event`.
  4. **(d) `subscribe` is idempotent per `(type, Callable)` pair; the boring cases are silent
     no-ops.** A double `subscribe` leaves `subscriber_count == 1` and yields exactly one
     invocation per emit, and a single `unsubscribe` removes it. Unsubscribing a never-subscribed
     Callable, unsubscribing on an unknown type, emitting with zero subscribers, `emit(null)` and
     `emit_all([])` all complete without error and create no phantom entries.
  5. **(e) Callables whose target has been freed are skipped AND pruned at dispatch.**
     **WIDENED at Verify:** validity is re-checked immediately before **each** handler call, not
     only in the pre-snapshot prune, so a target freed by an *earlier handler of the same event* is
     skipped too (and pruned on the next dispatch of that type). As implemented this case called
     into a freed instance and raised a live engine error ("Attempt to call function
     `null::on_event (Callable)` on a null instance"). Pinned by
     `test_target_freed_during_dispatch_is_skipped`.
  6. **(f) No concrete event classes and no event-name whitelist exist at M0.** §11.1's list
     (`hex_changed, unit_moved, …`) ends in "…" and is therefore illustrative, not a vocabulary:
     engine code contains no enum, constant or string literal naming any of them, and the bus
     routes an entirely unknown type correctly. Concrete `Event` subclasses belong to the
     milestones that emit them (§13.4: invent nothing ahead of its milestone), which keeps the
     §13.5 zero-engine-code-change rule reachable from M6. Both properties are guarded by source
     scans in the test file (also rejecting `extends Node`, `SceneTree`, `get_tree`, `Engine.`,
     `randi(`, `randf(`, `Time.`, `OS.` in non-comment text), so a future regression fails the
     suite rather than rotting.
  7. **Typing defect caught at Verify (§11.3, would have detonated M0-T4).**
     `_dispatch(_queue.pop_front())` passes a `Variant` into a statically-typed `Event` parameter.
     That is not a warning but a hard *Parse Error* under a warnings-as-errors gate — the script
     **fails to load**, which in a test file is exactly the PROGRESS "Known risk" silent-skip false
     green. Fixed with a typed local. Both sim-core files are now clean under a **maximal** warning
     configuration (every GDScript warning at level 2).
  8. **Goldens:** none re-recorded — none exist yet (the first golden lands with M1's mapgen hash).
  9. **Scope, deliberately not exceeded:** no `GameState`, no `Command`, no hex/map code, no
     concrete event class, and nothing added to or read from `data/ruleset.json` — the EventBus
     carries **zero** §12.1 constants, so "constants read from data, not code" (§13.6) is vacuous
     here and the only numeric literals in either core file are `-1` / `0` index arithmetic.
- **Why:** §11.1 fixes the *direction* of the observer contract but not its ordering, re-entrancy,
  mutation-during-dispatch or lifetime semantics — and every one of those is observable and would
  otherwise be settled accidentally by whichever milestone first emits two events. Pinning them now
  makes "same seed + same commands ⇒ identical delivery order" a property of the bus rather than of
  the caller. The (b) sub-point and the (c)/(e) widenings are recorded because they resolve cases
  the original spec text left open, in one instance inconsistently (two teardown calls disagreeing
  about the same event) and in another incorrectly (calling into a freed instance).
- **GDD section affected:** §11.1 (semantics *specified*, none amended); §11.2 (`scripts/core/`
  layout — the EventBus is core infrastructure); §11.3 (conventions followed); §13.4 (procedure
  exercised); §13.5 (open vocabulary guarded from M0); §14 M0 row — the **EventBus deliverable is
  now built**; the two acceptance clauses were already MET and their printed text is unchanged.
  **No table value moved and no `docs/GAME_DESIGN.md` cell was edited** — nothing numeric exists in
  this task.

## 2026-08-04 — M0-T4 — The §11.3 static-typing gate: mechanism, curated warning set, CI script

§11.3 is **prose**, not a table: *"Static typing everywhere (`--warnings-as-errors` in CI where
feasible)"*. It names neither a mechanism nor a warning set, and its own **"where feasible"**
qualifier is what authorises the three exclusions below. Everything here is therefore a §13.4
resolution, not a deviation, and every value was **measured** this iteration on the pinned
repo-local `godot/Godot_v4.7-stable_win64_console.exe` (4.7.stable.official.5b4e0cb0f) —
independently by Tests and again by Verify. The gate configuration is test-pinned in
`tests/unit/test_typing_gate.gd`, so it cannot be silently downgraded.

- **What changed / was decided:**
  1. **(a) Godot 4.7 has NO `--warnings-as-errors` CLI flag** (re-confirmed via `--help`), so the
     §11.3 gate is **project-setting driven**: `project.godot` gains a `[debug]` section setting
     `gdscript/warnings/enable=true` plus one level per warning, and the gate is *surfaced*
     headlessly by `godot --headless --path <root> --check-only --script res://<file>`, which exits
     **1** and prints `SCRIPT ERROR: Parse Error: <text> (Warning treated as error.)` followed by
     `   at: GDScript::reload (res://<file>:<line>)`. An `--import` pass must run first (same cache
     reason as `run_tests.sh`, decisions.md SETUP-2). **The file path and line arrive on the `at:`
     line, not the `SCRIPT ERROR:` line** — `typecheck.sh` therefore prints the engine's captured
     block verbatim instead of reconstructing `file:line` itself.
  2. **(b) Only levels 0 and 2 are meaningful for a headless gate: a level-1 warning prints
     NOTHING under `--check-only`.** This is why the three exclusions below sit at **0**, not 1 —
     "softening" them to 1 preserves no visibility whatsoever, it only makes the config lie. The
     gate is **46 warnings at level 2**, **3 at level 0**, out of the engine's 49 warning levels
     (52 keys under `debug/gdscript/warnings/` minus the 3 non-level keys `enable`,
     `directory_rules`, `renamed_in_godot_4_hint`). `test_gate_covers_every_gdscript_warning_setting`
     asserts that partition exactly, so a future Godot adding a warning turns the suite **red**
     instead of the gate quietly losing coverage — and a **typo'd warning name registers as a brand
     new setting**, pushing the count to 50 and failing the same test. That is intentional.
  3. **(c) Three documented exclusions at level 0, each because it is incompatible with vendored
     GUT or is not a typing warning** (§11.3 "where feasible"). They are written **explicitly** as
     `=0` rather than omitted, and the test asserts their presence at 0 citing this entry, so a
     future agent who wants them on must log the change rather than drift into it:
     - `unsafe_call_argument` — GUT 9.7.1's assert API (`assert_eq(v1, v2, text)`) is untyped, so
       every assert call site in `tests/` trips it. The callee is exempt (`addons/`), the **call
       site is not**. Unfixable without casting every assert argument. Also trips
       `scripts/sim/rules_loader.gd`.
     - `unsafe_cast` — trips **only** `scripts/sim/rules_loader.gd`, at ~6 `as Dictionary` / `as
       Array` sites (≈ lines 57, 135, 155, 310, 314, 339) that are each already guarded by an
       immediately preceding `is` check; Godot flags the cast regardless of the guard. Excluded to
       keep M0-T4 purely additive. **A later task may tighten this to 2** once `rules_loader`'s JSON
       `Variant` decoding is refactored — that tightening carries its own decisions.md entry.
     - `return_value_discarded` — trips `tests/unit/test_rules_loader.gd` (`insert()`) and
       `tests/unit/test_event_bus.gd` (`PackedStringArray.append()`); not a typing warning at all.
  4. **(d) `integer_division` is deliberately set to 2, and the friction is the point.** §11.1
     mandates integer/percent math with round-half-up **at the final step only**, so from M2 onward
     every intentional `int/int` division must carry an explicit `@warning_ignore("integer_division")`
     at the site — a per-site acknowledgement exactly where a rounding bug would break determinism.
     If a future stage finds this obstructive, downgrading requires a **logged decision**, never a
     silent edit.
  5. **(e) `directory_rules` semantics (measured) and why the default must be re-stated.** The
     setting is a `Dictionary` mapping a `res://` directory prefix to an exemption; **value 0
     exempts that tree entirely, and value 1 does NOT downgrade a level-2 warning** (measured — a
     level-2 warning under a rule-1 directory still errors), so it is effectively binary. Writing
     the setting **REPLACES** Godot's default, therefore the written value keeps
     `{"res://addons": 0}` verbatim — otherwise vendored GUT would be gated, and `addons/` is
     read-only (CLAUDE.md). **No project tree is exempt:** the test asserts `res://scripts`,
     `res://tests` and `res://tools` are absent from `directory_rules`.
  6. **(f) The 46-warning set is clean on the whole tree with ZERO source changes** —
     `--check-only` over all 10 project `.gd` files (`scripts/core/event.gd`,
     `scripts/core/event_bus.gd`, `scripts/sim/rules_error.gd`, `scripts/sim/rules_loader.gd` and
     the six test files) exits 0 for each, and GUT still collects everything. M0-T4 is therefore
     purely additive: **no existing `.gd` file was refactored to satisfy the gate**, and neither
     `tools/run_tests.sh` nor `tools/verify_harness.sh` was touched (harness contract — make it
     pass, never weaken it; `verify_harness.sh`'s planted canary is fully typed and only trips the
     excluded `unsafe_call_argument`). A hand-written `[debug]` section **survives `--import`
     byte-identically**, including lines whose value equals Godot's default, which is what makes the
     "explicitly off" assertions satisfiable at all.
  7. **(g) `tools/ci.sh` is the §14 M0 "CI script" deliverable and mechanizes CLAUDE.md's
     applicability rule.** It runs `typecheck.sh` then `run_tests.sh` (aggregating at stage level —
     a failing first stage does not prevent the second from running), and **skips non-fatally, with
     a printed notice**, the §13.1 tools that later milestones deliver (`sim_smoke` → M7,
     `content_cli` → E4, `balance_lab` → E5). It exits non-zero **iff** an applicable stage failed.
  8. **(h) `typecheck.sh --self-test` proves the TOOL, not the engine (hardened at Verify).** As
     first implemented, Phase B invoked the engine *directly* on the planted probe, so it proved the
     engine mechanism both ways but never exercised `typecheck.sh`'s own enumeration, aggregation
     and exit-code plumbing — a `run_gate` that swallowed a failure (the exact
     `$?`-through-a-pipeline class this task's spec warns about, and the SETUP-2 false-green class)
     would still have produced a PASSing self-test. Phase B now runs the tool's own `run_gate` over
     the real file list, mirroring `verify_harness.sh`'s Phase B (which re-invokes `run_tests.sh`,
     not `godot`). **Proved load-bearing by negative control:** a copy with `run_gate` forced to
     `return 0` fails the self-test where the old Phase B passed. `typecheck.sh` also fails loudly
     if enumeration finds **zero** `.gd` files — the same zero-collected guard class that makes
     `run_tests.sh` trustworthy.
  9. **(i) MEASURED CORRECTION TO THE QUEUED M0-T5 PLAN — it contradicts the recorded assumption
     and supersedes it.** M0-T2 item 11 recorded that a parse error in a test file makes GUT log
     `Ignoring script … because it does not extend GutTest` and exit 0, and queued M0-T5 to add that
     string to the runner's refusal grep. Verify measured (reproduced twice) that a **syntactic**
     parse error (probe: `extends GutTest` + `var x: int = (`) makes `bash tools/run_tests.sh` exit
     **0** with Scripts 6 / Tests 57 / Passing 57 — *identical to the healthy tree* — and print **no
     diagnostic whatsoever**: zero `Ignoring script` lines, zero `Failed to load script` lines, and
     no mention of the filename anywhere in the 106-line output. The M0-T2 case (`loader is Node`,
     a statically-impossible cast) **did** print `Ignoring script`. **So the planned grep closes only
     one of two variants; M0-T5 must additionally assert an expected script/test-count floor.**
  10. **(j) Bonus, NOT a substitute for M0-T5:** because `--check-only` exits 1 on any parse error,
     `typecheck.sh` independently catches **both** variants above (the syntactic probe yields
     `Failed to load script "res://tests/unit/_verify_parse_error.gd" with error "Parse error"`), so
     `ci.sh` already gives incidental coverage today. M0-T5 stays queued as the **in-harness** fix,
     because `run_tests.sh` is what every stage runs directly.
  11. **Known simplification, recorded not fixed:** `ci.sh`'s applicability skip is a plain
     **file-existence** check, so it does not distinguish "built but not yet due" (e.g. a WIP
     `sim_smoke.gd` landing before M7) from "built and due" — in that case it prints a NOTE and
     still skips rather than running or failing. Correct against CLAUDE.md today (a not-yet-due tool
     is never a failure); **the milestone that builds each of those three tools must wire its real
     invocation** (with the §13.1 argument list) as part of that task.
  12. **§13.6 clauses that are vacuous here, stated explicitly:** this task adds **zero game rules**
     and reads **zero** §12.1 constants, so *"constants read from data, not code"* and *"events
     emitted for every state change"* have no subject matter in M0-T4. **Goldens: none
     re-recorded — none exist yet** (the first golden lands with M1's mapgen hash). Scope held:
     no `GameState`, no `Command`, no hex/map code, no concrete `Event` subclass, no new keys in
     `data/ruleset.json`, no `addons/` change.
  13. **Doc-only:** `README.md` gained a *"CI (GDD §14 M0 deliverable)"* section documenting
     `ci.sh` / `typecheck.sh` / `--self-test` / `verify_harness.sh` and the project-setting
     mechanism, pointing here. The `--self-test` probe extends `RefCounted` (it is a standalone
     `--check-only` target, not a GUT test) and uses `var v = 1` read twice, so the tripped warning
     is unambiguously `untyped_declaration` and not also `unused_variable`.
- **Why:** §11.3 asks for a CI typing gate but the flag it names does not exist in this engine, so
  the mechanism had to be established empirically once and recorded so no future stage re-derives it
  from memory and gets it wrong (items a, b, e). A maximal warning set is not reachable without
  refactoring already-landed code and fighting vendored GUT's untyped assert API, so the set is
  **curated and each exclusion justified individually** rather than the gate being abandoned or
  quietly set to a level that prints nothing (item c). Item d converts an §11.1 determinism
  requirement into a compiler-enforced per-site acknowledgement. Items h–j exist because this
  iteration found two false-green mechanisms — one in the new tool itself, one contradicting the
  recorded M0-T5 plan — and a false green is the single failure mode that can silently invalidate
  every later milestone.
- **GDD section affected:** §11.3 (prose *implemented*, not amended — the "where feasible"
  qualifier is exercised, not overridden); §13.1 (command list unchanged; `typecheck.sh`/`ci.sh` are
  tooling **around** it, and `ci.sh` mechanizes the applicability rule); §13.6 (mechanical typing
  gate now exists, so "verify by diff review" no longer applies); §14 M0 row — the **"CI script"
  deliverable is now built**, completing that row's deliverable list; both acceptance clauses were
  already MET and their printed text is unchanged. **No numeric table value moved, so NO
  `docs/GAME_DESIGN.md` cell was edited in this commit.**

## 2026-08-04 — M0-T5 — Harness hardening: the silent-skip false green closed (and M0-T4 item (i) CORRECTED)

`tools/run_tests.sh` is the harness **contract** (CLAUDE.md: "make it pass, never weaken it").
M0-T5 is the sanctioned *strengthening* task: every pre-existing guard, exit code and refusal
string is kept verbatim, only new checks are added. The whole task pins harness behaviour — **zero
game rules, zero §12.1 constants read or written** — and is test-pinned in
`tests/unit/test_run_tests_harness.gd` (5 tests, one of which is explicitly an *anti-weakening*
test re-asserting all seven original guards), so the hardening cannot be silently undone.

- **What changed / was decided:**
  1. **(a) MEASURED CORRECTION — this supersedes M0-T4 item (i), whose measurement was
     confounded.** M0-T4 recorded that a **syntactic** parse error in a test file prints *"no
     diagnostic whatsoever"* and yields totals identical to a healthy tree. Measured again this
     iteration, three times independently (Orient, Tests, Verify) on the pinned repo-local
     `godot/Godot_v4.7-stable_win64_console.exe` (4.7.stable.official.5b4e0cb0f): **both**
     parse-error variants DO print `ERROR: Failed to load script "res://tests/unit/<probe>.gd"
     with error "Parse error".` **and** `[GUT WARNING]:  Ignoring script res://tests/unit/<probe>.gd
     because it does not extend GutTest`. M0-T4's probe was named `_verify_parse_error.gd` — it
     **lacked GUT's `test_` collection prefix** (`addons/gut/gut.gd:229` `_file_prefix = 'test_'`,
     `:980` `begins_with(prefix) and ends_with(suffix)`), so GUT never *attempted* to load it. The
     "no diagnostic / identical counts" claim was an artefact of that naming, **not** a property of
     syntactic parse errors. What **is** confirmed for both variants: `run_tests.sh` exited **0**
     (false green) with `Scripts 6 / Tests 57 / Passing 57` — byte-identical to healthy — while
     **7** `test_*.gd` files sat on disk.
  2. **(b) The load-bearing guard is the disk-vs-collected count, NOT the grep.** `run_tests.sh`
     now enumerates every `tests/**/test_*.gd` on disk using **exactly** GUT 9.7.1's own
     prefix/suffix/recursive rule, requires each enumerated `res://…` path to appear in GUT's
     output (printing **every** missing path, never stopping at the first), and requires GUT's own
     `Scripts` total (parsed after `sed 's/\x1b\[[0-9;]*m//g'` strips ANSI) to **equal** that
     count. An absent or non-numeric Totals block is exit 1, and a zero-file enumeration is exit 1
     (same zero-collected guard class as `typecheck.sh`). It is an **enumeration, never a magic
     number** — a magic number cannot catch this failure at all (counts are unchanged), and a
     diagnostic grep only catches it for as long as GUT chooses to log a file it failed to open.
  3. **(c) The coverage guard is proven load-bearing BY NEGATIVE CONTROL** — the same standard of
     proof as M0-T4 item (h), and necessary because in the live tree the refusal grep always fires
     *first*, so the guard would otherwise ship unexercised. With the grep neutered in a
     **scratchpad copy** (no repo file weakened), both parse-error variants still exit 1 via the
     count check (`GUT reported Scripts=7 but 8 test_*.gd files exist on disk`) and a healthy tree
     still exits 0.
  4. **(d) The refusal grep is extended, never narrowed.** `Failed to load script|Ignoring script`
     were **added** to the SETUP-2 item 2 alternation; `Nothing was run|does not exist|have not
     been imported` all remain. Anti-weakening was verified two ways: `test_run_tests_harness.gd`
     test 3 re-asserts `--import`, `-ginclude_subdirs`, `-gdir=res://tests`, `-gexit`, `exit 2`,
     `-o pipefail` and the repo-local binary path (SETUP-3), and Verify diff-reviewed that no
     guard, exit code or refusal alternative was removed.
  5. **(e) `verify_harness.sh` gains Phase C (syntactic: `var x: int = (`) and Phase D
     (statically-impossible: `r is Node` against a `RefCounted`)**, one per measured variant —
     they fail in *different* engine phases, so proving one proves nothing about the other. Each
     requires a **non-zero exit AND that the captured output names its probe file**, so the phase
     proves the guard fired for the right reason. Probe filenames (not dictated by the spec) are
     `tests/unit/test_harness_syntaxcanary.gd` and `tests/unit/test_harness_typecanary.gd`; Phase
     B's `test_harness_redcanary.gd` is unchanged. **Both probes MUST carry GUT's `test_` prefix**
     — a probe without it is invisible to GUT *and* to the disk enumeration, which is precisely the
     mistake that confounded item (i). Both probes and their `.uid` sidecars are registered in the
     existing `cleanup()` under `trap … EXIT`, so the tree self-cleans on failure or interruption.
  6. **(f) Which mechanism protects which half, stated so no future stage assumes otherwise.**
     Phases C/D do **not** by themselves protect the coverage guard, because the refusal grep
     short-circuits before it. The guard's regression protection comes from the **source-scan
     assertions** in `test_run_tests_harness.gd` test 1 (`test_*.gd`, `find`, `-name`, `Scripts`
     must be present in the script). Both halves are pinned — by different mechanisms.
  7. **(g) Known-weak assertion, recorded not fixed (test quality, not a rule).** Test 1's
     positional check `runner.find("Scripts") < runner.rfind('exit "$CODE"')` is satisfied by the
     word `Scripts` appearing in a header comment, so it does not by itself prove the guard
     *executes* before the final exit. The behavioural proof (live Phases C/D + the negative
     control) covers that property today. A future task may anchor it on the guard's own code
     line; doing so now is scope creep.
  8. **(h) Three inline comments corrected at Verify (comment-only, no logic change).** Both shell
     scripts carried the superseded item (i) claim — "no diagnostic at all", "the refusal grep
     above cannot see it", and Phase C's "this phase proves that guard, not the refusal grep" —
     each contradicted by this iteration's own measurement and each capable of misleading a future
     agent into deleting the wrong guard. All three now state the measured behaviour and cite the
     negative control.
  9. **(i) Boilerplate-vs-spec conflict, resolved in the spec's favour and recorded.** The
     Implement stage's generic boilerplate said "do not modify `tools/run_tests.sh`" while the task
     spec made it the primary subject. CLAUDE.md governs: `run_tests.sh` is the harness contract —
     *make it pass, never weaken it* — so strengthening edits are permitted and weakening is not.
     Every change in this diff is additive. The Implement stage also correctly deferred
     `docs/decisions.md` and `docs/PROGRESS.md` to Land, and made **no** edit to
     `tests/unit/test_run_tests_harness.gd` (the shell scripts were fixed to satisfy the tests, not
     the reverse).
  10. **(j) §13.6 clauses that are vacuous here, stated explicitly:** zero §12.1 constants are read
     or written, so *"constants read from data, not code"* and *"events emitted for every state
     change"* have no subject matter. **Goldens: none re-recorded — none exist yet** (the first
     golden lands with M1's mapgen hash). Scope held: no `GameState`, no `Command`, no hex/map
     code, no concrete `Event` subclass, no new keys in `data/ruleset.json`, no `addons/` change.
  11. **(k) Environment note for a future CI change:** the coverage guard uses
     `find … -print0` / `read -r -d ''` / a bash array under `set -u -o pipefail` (no `-e`), and
     reads `$?` immediately into a named variable, never through a pipeline — the exact false-green
     class M0-T4 item (h) documents. Correct on the pinned Git-Bash 5.3 used here; re-verify if the
     loop ever changes shells.
- **Why:** A false green is the single failure mode that can silently invalidate every later
  milestone, and this one lived inside the signal every stage runs directly. Item (a) is recorded
  loudly because a *wrong* measurement in the decisions log is worse than no measurement — it was
  about to send M0-T5 down the wrong path (M0-T4 concluded the grep was useless and only a count
  *floor* could work; the truth is the opposite in the short term and stronger in the long term:
  the grep works today, but only the enumeration is evasion-proof). Items (c) and (f)–(g) exist so
  the guard's proof and the exact shape of its regression protection are traceable rather than
  assumed.
- **GDD section affected:** §13.1 (the runner's contract is **strengthened**, not amended — the
  printed command list is unchanged); §13.2 (`tests/**` layout and GUT's `test_` prefix rule are
  now mechanically enforced, so a test file that does not follow them fails the run); §13.6
  (definition of done exercised; two clauses vacuous, see item j); §14 M0 row — **all deliverables
  built and BOTH acceptance clauses MET headless, now proven against the false-green mode that
  reported clause (a). M0 is CLOSED by this commit.** Acceptance criterion text unchanged. **No
  numeric table value moved, so NO `docs/GAME_DESIGN.md` cell was edited in this commit.**

## 2026-08-04 — M1-T1 — HexMath slice 1: two §13.4 resolutions + an arithmetic correction to the task spec

First task of **M1 — World**, and the first task in the project that writes actual §4.1 *game
geometry*. Everything §4.1 legislates was transcribed verbatim and pinned by test
(`tests/unit/test_hex_math.gd`, 24 tests); the two resolutions below cover the only points §4.1
leaves open. Their **lettering (A)/(B) is referenced by the header comments of both
`scripts/core/hex_math.gd` and `tests/unit/test_hex_math.gd` — keep it stable.** No numeric GDD
table value moved, so **no `docs/GAME_DESIGN.md` cell was edited in this commit**.

- **What changed / was decided:**
  1. **(A) FLAT-TOP vs. THE DIRECTION NAMES — §13.4 ambiguity resolution.** §4.1 says both
     *"Flat-top hexes"* and *"Neighbor order (fixed, index 0–5): E, NE, NW, W, SW, SE"*. Those six
     labels are the **pointy-top** naming of the six standard axial deltas; a strictly flat-top
     screen layout would name them N/NE/SE/S/SW/NW. **Resolution: the sim stores the deltas in the
     GDD's stated index order and uses the GDD's stated names verbatim as index labels** —
     `0 E (+1,0)`, `1 NE (+1,-1)`, `2 NW (0,-1)`, `3 W (-1,0)`, `4 SW (-1,+1)`, `5 SE (0,+1)` —
     and hex-to-screen orientation is a **renderer** concern, owned by the later M1 renderer/camera
     task, which changes no sim value. Verified self-consistent: this assignment makes
     `opposite(i) == (i+3)%6` a true geometric property
     (`DIRECTIONS[i] + DIRECTIONS[opposite(i)] == Vector2i.ZERO` for all six), which is test-pinned.
     The index order is load-bearing for every later system that keys off it (rings, pathfinding,
     mapgen goldens) — **do not reorder or rename it to "fix" orientation.**
  2. **(B) AN OUT-OF-RANGE DIRECTION INDEX IS THE IDENTITY — §13.4 ambiguity resolution.** §4.1
     legislates no behaviour for an index outside 0–5. **Resolution: `neighbor(h, dir)` returns `h`
     unchanged and `opposite(dir)` returns `dir` unchanged** — no crash, no engine error, no assert
     abort headless (§11.1: a bad index must never tear down a 60-turn headless run). A hex grid has
     no seventh neighbour, so the identity is the simplest total function. Six probes pinned
     (`-1`, `6`, `99` on each).
  3. **ARITHMETIC CORRECTION TO THE M1-T1 TASK SPEC — not a rule change, recorded so no later stage
     re-derives the wrong number.** The Orient spec's hand-computed case
     `distance((1,-3),(4,2)) == 5` is a **miscalculation**. With §4.1's mapping (x = q, z = r,
     y = -q - r): cube `a = (1, 2, -3)`, cube `b = (4, -6, 2)`, delta `(-3, 8, -5)` ⇒ max form
     **8**, and the half-sum form `(3+8+5)/2` = **8** agrees. Re-derived independently three times
     (Tests, Implement, Verify). §4.1 states only *"Distance = cube distance"* — a **formula**, not
     a table row for this pair — so the formula governs, the test pins **8**, and **no GDD value
     moved**. All eight other hand-computed cases and all three map-size counts were re-derived
     independently and are correct.
  4. **No map-size constant in engine code (§13.6, deliberate).** §4.1's radii (Small 24 / Medium 32
     / Large 40 ⇒ 1,801 / 3,169 / 4,921 hexes) appear **only as literals inside the test file**,
     pinning the §4.1 table; `hex_math.gd` exposes only the formula `3*r*(r+1)+1`, and a source-scan
     test mechanically forbids those six numbers from appearing in it. Rationale: the radii are
     **tunable generator parameters** and belong to `data/mapgen/*.json` (§4.4) at the generator
     task, whereas the six direction deltas and the cube-distance formula are geometry/algorithm,
     not tunable content. **`data/ruleset.json` gained no keys** and has no hex-geometry section —
     this task reads **zero** §12.1 constants, so §13.6's "constants read from data, not code" is
     satisfied by having no constants to read, not by an omission.
  5. **§13.6 clauses vacuous here, stated explicitly:** HexMath mutates no `GameState` and
     references no `EventBus`, so *"events emitted for every state change"* has no subject matter.
     **Goldens: none re-recorded — none exist yet** (the project's first golden lands with the M1
     mapgen terrain hash; get seeded generation deterministic before recording it).
  6. **Scope held (§13.4: invent nothing ahead of its milestone).** Exactly the 11 spec'd members
     and nothing else. **Not** written: LOS, hex lines, rings or ranges (M1-T2 — PROGRESS splits the
     slice that way); elevation/movement-cost/cliff rules (§4.1 prose, but §14 assigns
     "Movement/pathfinding/ZOC/elevation costs" to **M4**); the concentric-bowl generator (§4.4);
     renderer, camera rig, hex picking; `GameState`; any `Command`; any concrete `Event` subclass.
  7. **Determinism (§11.1) is mechanically scanned, not merely asserted.** `hex_math.gd` is pure
     `RefCounted`, all-static, and its comment-stripped source is scanned for `randi(`, `randf(`,
     `extends Node`, `SceneTree`, `get_tree`, `Engine.`, `Time.`, `OS.` — plus **no float literal**
     (regex `\.[0-9]`) and no `float` token, so the file is integer-only and carries no
     platform-rounding exposure ahead of M1's first golden. `Vector2i`/`Vector3i` are integer
     Variant built-ins (not Nodes/singletons), so §11.1 purity holds while a 4,921-hex Large map
     allocates no per-hex objects. Non-Node-ness is asserted via `get_class()`, never `is Node` —
     the latter is the statically-impossible construct that parse-errors (decisions.md M0-T2 item 11
     / M0-T5 item (a)). `distance` uses `maxi`/`absi` with **no division**, so no
     `@warning_ignore("integer_division")` was needed (M0-T4 item d).
  8. **`neighbors()` returns a FRESH `Array[Vector2i]` per call.** A `const Array[Vector2i]` is not
     deeply immutable in GDScript, so a cached/shared return value would let one caller's mutation
     corrupt every later caller. Pinned by test — and **proven live**: Verify mutated the shipped
     file to return a shared static cache and the suite went red on exactly that assertion, then
     swapped `DIRECTIONS[1]`/`[2]` and it went red again, restoring the file byte-identically after
     each probe (md5 re-verified). The two subtlest pins in this task are live, not vacuous.
  9. **No test was weakened or edited by the Implement stage** — `tests/unit/test_hex_math.gd` was
     consumed verbatim and made to pass legitimately. The Tests stage's deliberately-wrong
     placeholder `hex_math.gd` (which existed only so the test file would *load* — a parse error
     would have silently un-collected it, M0-T5 item (a)) was replaced wholesale by the
     implementation. Verify made zero code and zero test edits.
- **Why:** §4.1 fixes the neighbour **order** and the distance **metric** but is internally in
  tension about the *names* (item 1) and silent about a bad index (item 2); both are observable and
  would otherwise be settled accidentally by whichever later system first indexes the table. Pinning
  them now makes the direction order a property of the sim rather than of its first caller. Item 3
  is recorded loudly for the same reason M0-T5 item (a) was: a wrong number that survives into the
  log is worse than no number, because a later stage will "fix" the code to match it. Item 4 draws
  the data-vs-code line for §4.1 explicitly, so the generator task inherits the radii as content
  instead of finding them already hard-coded in core.
- **GDD section affected:** §4.1 (values transcribed verbatim — **no table value moved, no cell
  edited**; two silences resolved under §13.4); §11.1 (determinism/purity followed and scanned);
  §11.2 (`scripts/core/hex_math.gd` — §11.2's first named `core/` entry); §11.3 (conventions
  followed; every public rule function carries a `## §4.1` doc comment, mechanically pinned);
  §13.2 (tier 1 "every core/ function"); §13.6 (definition of done exercised; two clauses vacuous,
  see item 5); **§14 M1 row — the row is now OPEN but NOT met: `HexMath` is partially delivered
  (slice 1 of 2) and NONE of the three M1 acceptance criteria pass yet** (no golden mapgen test, no
  greybox to measure 60 fps on, no LOS to property-test). Acceptance criterion text unchanged.
  **No numeric table value moved, so NO `docs/GAME_DESIGN.md` cell was edited in this commit.**
