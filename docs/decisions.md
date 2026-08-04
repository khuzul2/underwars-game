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

## 2026-08-04 — M1-T2 (tests stage; SUPERSEDED — see the M1-T2 completion entry below) — Hex-line/ring conventions (C)–(G) fixed and test-pinned

> **STATUS SUPERSEDED 2026-08-04 by the "M1-T2 (COMPLETE)" entry at the end of this file.** The
> blocked status described in the next paragraph is **no longer current**: the following iteration
> resumed M1-T2 at the Implement stage, the five bodies landed, and the suite is **green** at
> Scripts 8 / Tests 106 / Passing 106 / Failing 0 / Asserts 1023. **This entry's body (items 1–14) is
> NOT superseded** — resolutions **(C)/(C2)/(D)/(E)/(F)/(G)** remain the binding record of the
> hex-line/ring/range conventions and are unchanged by the completion. Only the status header below
> is historical.

**Status of the commit this entry accompanied: `WIP(blocked)`. The suite was RED on purpose** —
`bash tools/run_tests.sh` exited **1** at Scripts 8 / Tests 106 / Passing 87 / **Failing 19** /
Asserts 950/1023, while `bash tools/typecheck.sh` exited **0** over 13 files. The Tests stage
completed and was committed; the **Implement stage returned no result** (agent died or was skipped),
so Verify ran nothing (`green: false`, zero suites run) and the loop degraded to `WIP(blocked)` per
CLAUDE.md rather than landing a false green. `scripts/core/hex_math.gd` therefore shipped four public
members plus one private helper as **deliberately-wrong stubs** under an explicit banner comment.
The next iteration resumed M1-T2 **at the Implement stage** and completed it.

§4.1 gives an **algorithm** for this task, not a table — *"Line of sight uses standard hex
line-drawing (lerp in cube space, round)"*, *"Distance = cube distance"*, *"Neighbor order (fixed,
index 0–5): E, NE, NW, W, SW, SE"* — so there is **no printed cell to transcribe** and every
expected value in the new tests is **derived**. `docs/decisions.md` carries **no override touching
§4.1**. The resolutions below are therefore §13.4 decisions, not deviations. Their lettering
continues M1-T1's `(A)`/`(B)` sequence and is cross-referenced by the header doc blocks of
`scripts/core/hex_math.gd` and `tests/unit/test_hex_math.gd` — **keep it stable**. Each is pinned by
test today and will be pinned by *passing* test when Implement lands.

- **What changed / was decided:**
  1. **(C) ROUNDING IS ROUND-HALF-UP MEANING TOWARD +INFINITY, computed exactly over rationals,
     never in floats.** §11.1 mandates "integers + fixed percent math, round-half-up at the final
     step". Resolution: `round_half_up(n, d) == floor_div(2 * n + d, 2 * d)` for `d > 0`, where
     `floor_div` is a **true floor**. Two traps are recorded because both are silent and both break
     determinism: (i) **GDScript's `int / int` truncates toward zero** (`-1 / 3 == 0`, not `-1`), so
     `HexMath._floor_div` must correct the negative case — without it *every negative-coordinate
     line rounds the wrong way*; (ii) **Godot's `roundi()` rounds half AWAY FROM ZERO and is
     therefore the WRONG primitive here** — it maps `-1/2 → -1` and `-3/2 → -2` where half-up gives
     `0` and `-1`. `roundi`/`round`/`floor`/`snapped`/`lerp`/`Vector3` appear nowhere in the file,
     and the pre-existing no-float source scan (regex `\.[0-9]` plus the `float` token, comment
     stripped) mechanically keeps it that way. Two probes in the test file are chosen *precisely
     because* half-up and `roundi` disagree on them.
  2. **(C2) `cube_round_scaled(numerators, denom)` repairs the `x + y + z == 0` invariant with the
     standard largest-diff cascade on the SCALED integer diffs, and a tie repairs `z`.**
     `dx = |rx*denom - n.x|` (etc.), then `if dx > dy and dx > dz: rx = -ry - rz` /
     `elif dy > dz: ry = -rx - rz` / `else: rz = -rx - ry`. So a two-way **or** three-way tie
     deterministically repairs **z**. The result always satisfies `is_valid_cube()`. This is not a
     cosmetic choice: it is the only thing that decides two of the pinned line values, and the test
     file contains four assertions that go red if the final `else` repairs `y` instead.
     **`denom <= 0` returns `numerators` unchanged** — a total function, same spirit as M1-T1
     resolution (B): no crash, no assert abort headless.
  3. **(D) HEX LINES ARE EXACTLY REVERSIBLE, and that is a consequence of the exact-rational
     formulation rather than an extra rule.** `line(a, b)` takes `N = distance(a, b)`
     (`N == 0 ⇒ [a]`) and walks `i = 0..N` over the exact integer numerators
     `cube(a) * N + (cube(b) - cube(a)) * i` with denominator `N`. Because there is **no epsilon
     nudge** (the usual float implementation's tie-breaker), `line(a, b)` is **exactly**
     `reverse(line(b, a))`. That symmetry is pinned as a property over all 3,721 ordered pairs of
     the radius-4 disc — a float-plus-epsilon implementation fails it immediately, which is the
     point of pinning it.
  4. **(E) RING CORNER AND TRAVERSAL RULE.** Corner `i` of `ring(center, radius)` is
     `center + DIRECTIONS[i] * radius`; traversal starts at corner 0 and leaves corner `i` in
     direction `DIRECTIONS[(i + 2) % 6]`, `radius` steps per side, **appending before stepping**.
     The load-bearing consequence, pinned at eight sample centres: **`ring(c, 1)` equals
     `neighbors(c)` element-for-element**, which welds ring order to §4.1's fixed direction order
     (M1-T1 resolution (A)) instead of letting a second, independent ordering drift into existence.
  5. **(F) A NEGATIVE RADIUS IS THE EMPTY ARRAY** for both `ring` and `hexes_in_range`; radius `0`
     is `[center]`. Total functions, no crash — same spirit as (B).
  6. **(G) `hexes_in_range` IS THE SPIRAL COMPOSITION** `[center] + ring(c,1) + ring(c,2) + … +
     ring(c,radius)`, in that order. Its size is pinned **against `hex_count_for_radius(r)` (the
     `3r(r+1)+1` formula), not only against the literals 19 / 37 / 217**, so the two independent
     formulations cross-check each other.
  7. **WHERE LINES AND RINGS LIVE — the open question `docs/PROGRESS.md` raised at M1-T1 is now
     settled.** They are members of `HexMath` in `scripts/core/hex_math.gd`, **not** a new file:
     §14's M1 row names the deliverable *"HexMath (axial/cube, LOS, lines, rings)"*. §11.2 lists
     `Los` as a **separate** `scripts/core/` peer, so **only the LOS predicate splits out**, into
     `scripts/core/los.gd` at **M1-T3**. `los.gd` was deliberately **not** created here — it needs
     terrain, which does not exist until §4.4's generator, and M1-T3 must resolve under §13.4 how
     `Los` receives terrain (injected `Callable`s or a tiny typed read-only view) **without**
     inventing a map type ahead of its milestone.
  8. **ARITHMETIC RE-CONFIRMATION of M1-T1 item 3, from an independent direction.** The pinned line
     `line((1,-3),(4,2))` has **9** elements, which forces `distance((1,-3),(4,2)) == 8` — the same
     correction M1-T1 recorded against its own task spec's erroneous `5`. Re-derived here by hand
     from §4.1's mapping and again by an independent reference model built from the GDD text rather
     than from the task spec's answer list. **Do not "fix" it back to 5.**
  9. **Every derived value was re-derived independently before being pinned**, per M1-T1 item 3's
     lesson that a wrong number surviving into the log is worse than no number: all 10 line cases,
     all 6 ring/range cases, the 6 `_floor_div` probes, the 7 round-half-up probes, and the counts
     19 / 37 / 217. A 3,721-ordered-pair sweep of the radius-4 disc produced **zero** property
     violations in the reference model, so a red on those properties is a real defect, not a flaky
     bound.
  10. **The Tests-stage stub convention is deliberate and is what keeps this blocked state SAFE.**
     A call to a **missing** method is a GDScript parse error, which silently un-collects the whole
     test file — the M0-T5 false green (item (a) there). Shipping deliberately-wrong stubs makes the
     file parse, so the failure is **19 named value failures** rather than a silent skip, and
     `Scripts 8` still equals the number of `test_*.gd` on disk. The stubs use every parameter
     (`unused_parameter` is level 2) and keep both source scans green, so `typecheck.sh` stays at
     exit 0.
  11. **Source scans were STRENGTHENED, never weakened** (they are the harness-contract analogue for
     this file). The no-float scan (S1), the engine-free scan (`randi(`, `randf(`, `extends Node`,
     `SceneTree`, `get_tree`, `Engine.`, `Time.`, `OS.`), the `get_class()`-based non-Node assertion
     (**never `is Node`** — statically impossible, parse-errors: decisions.md M0-T2 item 11 /
     M0-T5 item (a)), and the map-size scan (S2: `24|32|40|1801|3169|4921` must not appear in
     `hex_math.gd`) are all kept verbatim and still green. The doc-comment scan (S3) was
     **tightened**: it now also asserts `cube_round_scaled` / `line` / `ring` / `hexes_in_range`
     exist as **public** functions, so a missing member fails the scan instead of passing vacuously.
  12. **§13.6 clauses that are vacuous here, stated explicitly:** this task reads **zero** §12.1
     constants — hex geometry is *algorithm, not tunable content*, the same line M1-T1 item 4 drew,
     and `data/ruleset.json` gained no key and must not gain one. `HexMath` mutates no `GameState`
     and references no `EventBus`, so *"events emitted for every state change"* has no subject
     matter. **Goldens: none re-recorded — none exist yet**; the project's first golden still lands
     with the mapgen terrain hash.
  13. **Scope held (§13.4: invent nothing ahead of its milestone).** Not written: `scripts/core/los.gd`
     or any LOS/blocking code (M1-T3); the concentric-bowl generator (§4.4); any golden file; the
     renderer, camera rig or hex picking; `GameState`; any `Command`; any concrete `Event` subclass;
     elevation / movement-cost / cliff rules (§4.1 prose, but §14 assigns *"Movement/pathfinding/ZOC/
     elevation costs"* to **M4**); any new key in `data/ruleset.json`; any `addons/` change.
  14. **No test was weakened.** Only `scripts/core/hex_math.gd` and `tests/unit/test_hex_math.gd`
     are touched by this commit's code diff (plus these two docs). The resume rule for the next
     iteration is the standing one: **fix code to match the derived values, never the reverse.**
- **Why:** §4.1 legislates the line-drawing *algorithm* but not its rounding convention, its
  invariant-repair tie-break, its ring traversal order, or its behaviour at degenerate radii — and
  every one of those is observable and would otherwise be settled accidentally by whichever system
  first calls into it (LOS at M1-T3, mapgen at M1's generator, then pathfinding and AI). Fixing them
  now, in exact integer arithmetic, is what makes *"same seed + same commands ⇒ identical
  `GameState.hash()`"* a property of the geometry layer rather than of the platform's floating-point
  behaviour — which matters especially because M1 records the project's **first golden**. The
  blocked status is logged rather than papered over because a committed red tree is only safe if the
  next agent can tell at a glance that it is *intentional and mid-task*.
- **GDD section affected:** §4.1 (algorithm **implemented and its silences resolved** under §13.4 —
  **no numeric table value moved, no cell edited**; there is no printed line/ring table cell to
  move); §11.1 (integer-only determinism, fresh-array contract); §11.2 (`scripts/core/hex_math.gd`;
  `Los` deferred to its own file at M1-T3, as §11.2 lists it); §11.3 (conventions followed; every
  new public function carries a `## §4.1` doc comment, mechanically scanned); §13.2 (tier 1 "every
  core/ function", plus the §14 property tests for lines/rings — the LOS half is M1-T3); §13.4
  (procedure exercised: five silences resolved, nothing stalled); §13.6 (definition of done **NOT**
  met — tests are red, see the status paragraph; two clauses vacuous, see item 12); **§14 M1 row —
  still OPEN and NOT met: `HexMath` slice 2 is spec'd and test-pinned but NOT implemented, and none
  of the three M1 acceptance criteria pass.** Acceptance criterion text unchanged. **NO
  `docs/GAME_DESIGN.md` edit accompanies this entry, because no numeric table value changed.**

## 2026-08-04 — M1-T2 (COMPLETE) — Slice 2 implemented and landed green; (C)–(G) unchanged, both subtle pins proven live

**This entry supersedes the STATUS HEADER — and only the status header — of the
"2026-08-04 — M1-T2 (tests stage)" entry above.** That entry's items 1–14 stand verbatim as the
binding record of resolutions **(C)/(C2)/(D)/(E)/(F)/(G)**; nothing in them was re-opened,
re-interpreted or amended by this iteration. What changed is the *state of the work*: the blocked
iteration was resumed **at the Implement stage** (no re-Orient, no re-spec, no new or edited test),
the five bodies landed in `scripts/core/hex_math.gd`, and the suite is **green**.

- **What changed / was decided:**
  1. **The blocker is cleared; the recorded red baseline is retired.** `bash tools/run_tests.sh`
     exits **0** at **Scripts 8 / Tests 106 / Passing 106 / Failing 0 / Asserts 1023** — all 19
     failing tests named in `docs/PROGRESS.md`'s Blockers section are green, with 0 pending and 0
     orphaned. `bash tools/typecheck.sh` exits 0 over 13 files; `bash tools/ci.sh` exits 0;
     `bash tools/verify_harness.sh` exits 0 across all four phases with the tree left clean. All four
     were run headless through the `tools/` scripts on the repo-local pinned
     `godot/Godot_v4.7-stable_win64_console.exe`, never the PATH shim (SETUP-3). The three §13.1
     tools that later milestones deliver (`sim_smoke` → M7, `content_cli` → E4, `balance_lab` → E5)
     were correctly **SKIPped, not failed**, per CLAUDE.md's applicability rule.
  2. **ZERO new rule interpretations.** The five bodies (`_floor_div`, `cube_round_scaled`, `line`,
     `ring`, `hexes_in_range`) implement (C)/(C2)/(D)/(E)/(F)/(G) clause-for-clause as already
     logged. The `(A)`–`(G)` lettering is untouched and stable; **M1-T3 continues the sequence at
     (H)**. No new letter was needed, which is the intended outcome for a task whose design was
     closed by its Tests stage.
  3. **Scope was exactly one code file.** `scripts/core/hex_math.gd` (+65/−28): the five stub bodies
     replaced and the `SLICE 2 (M1-T2) — DELIBERATELY-WRONG TESTS-STAGE STUBS` banner block deleted,
     with every public function retaining its `## §4.1` doc-comment block. Verified by
     `git status --porcelain` showing a single modified path. Deliberately **not** created (§13.4,
     invent nothing ahead of its milestone): `scripts/core/los.gd` (M1-T3), the §4.4 generator, any
     golden file, renderer/camera/hex-picking, `GameState`, any `Command`, any concrete `Event`
     subclass, any new key in `data/ruleset.json`, any `addons/` change. `tools/run_tests.sh` is
     byte-identical to HEAD (md5 re-checked) — the harness contract was neither weakened nor needed
     strengthening here.
  4. **NO TEST WAS EDITED, WEAKENED OR EXTENDED by any stage this iteration.**
     `tests/unit/test_hex_math.gd` is byte-identical to HEAD (md5 `b59171f7e6088cdf91a83aac2343afd7`,
     1,421 lines) and never appears in `git status`. Verify additionally diffed the Tests-stage
     commit itself (`1f49d84` → `f36c0ab`): **734 insertions, zero deleted lines** across `tests/`,
     so the M1-T1 assertions were extended, never relaxed. The standing rule held in both directions:
     **code was fixed to match the pinned values, never the reverse.**
  5. **BOTH required adversarial mutation probes were executed live AT VERIFY** — the same standard
     of proof M1-T1 item 8 set for `neighbors()`, and the reason a pin counts as load-bearing rather
     than decorative. Baseline md5 `8912d2125837ed1fcaa9135fbf11b38c` was captured first and
     re-verified identical after each probe; the final tree carries that same md5.
     - **Probe 1 (trap 1: a shared/cached return array).** `ring()` was made to return a
       module-level cached array. `test_line_ring_and_range_return_fresh_arrays_each_call` went
       **RED** (104/106) with the intended message — *"§11.1: ring((0,0),1) must return a fresh
       array, not a shared/cached one"* — plus the live second-result corruption assert. **Bonus
       signal:** the §11.3 doc-comment scanner also went red (`missing on: ["ring"]`), proving that
       guard is live too.
     - **Probe 2 (trap 3: the tie-break repairing `y` instead of `z`).** The cascade's final
       `else: rz = -rx - ry` was flipped to `ry = -rx - rz`.
       `test_line_tie_cases_resolve_through_the_z_repair` went **RED on both** pinned witnesses —
       `line((0,0),(2,-1))` yielded `[(0,0),(1,0),(2,-1)]` and `line((0,0),(1,1))` yielded
       `[(0,0),(1,1),(1,1)]` — and five further tests fell with it (the reversibility witnesses, the
       long off-origin case, and the 3,721-ordered-pair P4 sweep). **(C2) is therefore not a
       cosmetic choice: it is the sole determinant of two pinned line values, exactly as the tests
       stage claimed.**

     (Recorded for traceability: the Implement stage self-ran probe 2 as a non-authoritative sanity
     check before returning, restoring byte-identically. Verify re-ran **both** probes itself rather
     than taking that on trust. Self-checking at Implement is welcome; it is never a substitute for
     Verify executing the test plan.)
  6. **Determinism (§11.1) and typing (§11.3) were independently re-scanned at Verify, not merely
     trusted.** Over comment-stripped source: zero float literals (regex `\.[0-9]`) and zero `float`
     tokens; zero engine-bound tokens (`randi(`, `randf(`, `extends Node`, `SceneTree`, `get_tree`,
     `Engine.`, `Time.`, `OS.`); zero map-size literals (`24|32|40|1801|3169|4921`).
     `roundi`/`round`/`floor`/`snapped`/`lerp`/`Vector3(` appear **only inside doc comments that
     explain why they are forbidden** — never in code. All arithmetic is `Vector2i`/`Vector3i`/
     `absi`/`maxi`; the single `n / d` in `_floor_div` keeps its `@warning_ignore("integer_division")`
     at the site (M0-T4 item d). No `:=`, no untyped `var`, every loop variable typed.
     `line`/`ring`/`hexes_in_range` each allocate a **fresh** `Array[Vector2i]` per call and
     `hexes_in_range` `append_array`s `ring()`'s fresh arrays into its own. Magnitudes are safe: a
     Large map (radius 40) gives `n <= 80` and numerators ≈ 6,400, nowhere near int overflow.
  7. **The M1-T1/M1-T2 arithmetic correction was re-confirmed a third time and NOT reverted.**
     `distance((1,-3),(4,2)) == 8` (cubes `(1,2,-3)` and `(4,-6,2)`, diffs 3/8/5), so
     `line((1,-3),(4,2))` has **9** elements. The original M1-T1 task spec's `5` remains a
     miscalculation. Verify re-derived this by hand, along with `cube_round_scaled((-1,-1,2),2) ==
     (0,-1,1)` (where `roundi` genuinely disagrees), the two z-repair witnesses, the full 12-element
     `ring((0,0),2)` walk, and the `_floor_div` negatives — all agreeing with the frozen pins. **Do
     not "fix" it back to 5.**
  8. **§13.6 clauses that are vacuous here, restated because they were re-checked rather than
     assumed:** the task reads **zero** §12.1 constants — hex geometry is *algorithm, not tunable
     content*, the line M1-T1 item 4 drew — and `data/ruleset.json` gained no key. `HexMath` mutates
     no `GameState` and references no `EventBus`, so *"events emitted for every state change"* has no
     subject matter (no `Command`/`validate`/`apply` surface exists yet to violate).
     **Goldens: none re-recorded — none exist yet.** The project's first golden still lands with the
     §4.4 mapgen terrain hash; §13.6's re-record-only-with-a-logged-reason rule starts applying from
     that moment.
  9. **Stage-boundary note, recorded so it is not mistaken for a scope violation.** The task spec's
     top-level `files_expected` listed `docs/PROGRESS.md` and `docs/decisions.md` alongside the code
     file; the Implement stage correctly did **not** touch either, since both are **Land**-stage
     artefacts (this entry and the tracker update). That is the intended division of labour under
     CLAUDE.md's five-stage loop, not a missed deliverable — the same call M0-T5 item (i) records.
- **Why:** A blocked iteration is only safe if resuming it is mechanical, and this one was: the
  frozen tests plus the already-logged (C)–(G) meant the Implement stage had nothing to decide, only
  something to write. That is worth recording as a *process* result, because it validates the
  Tests-stage stub convention (item 10 of the entry above) end-to-end — red tree committed, blocker
  named test-by-test, resumed at the failed stage, landed green with zero test churn. Item 5 is
  recorded at length because a property test that has never been observed failing is
  indistinguishable from a property test that cannot fail; both of this task's subtlest invariants —
  the fresh-array contract and the z-repair tie-break — are now *measured* as load-bearing, and the
  probes also incidentally proved the §11.3 doc-comment scanner is live.
- **GDD section affected:** §4.1 (algorithm **implemented**; its silences were already resolved under
  §13.4 by the entry above — **no numeric table value moved, no cell edited**. §4.1's only numeric
  table, *Map sizes (hex radius): Small 24 (1,801), Medium 32 (3,169), Large 40 (4,921)*, is unmoved
  and remains pinned via `hex_count_for_radius(r) == 3r(r+1)+1`, with those six literals mechanically
  confirmed **absent** from `hex_math.gd`. `decisions.md` was re-scanned end-to-end this iteration:
  **no logged override touches §4.1**); §11.1 (integer-only determinism and the fresh-array contract,
  both re-scanned); §11.2 (`scripts/core/hex_math.gd`; `Los` still deferred to its own file at
  M1-T3); §11.3 (mechanical typing gate green over 13 files; every public function carries its
  `## §4.1` doc comment, scanner proven live); §13.2 (tier 1 "every core/ function" plus the §14
  property tests for lines and rings — the LOS half is M1-T3); §13.6 (definition of done **MET**:
  tests green headless, typing gate clean, no constants to read, no events to emit, no golden to
  re-record); **§14 M1 row — still OPEN and NOT met. The `HexMath` deliverable is now COMPLETE (both
  slices), but none of the three M1 acceptance criteria pass: no golden mapgen test, no greybox to
  measure 60 fps on, no LOS to property-test.** Acceptance criterion text unchanged. **NO
  `docs/GAME_DESIGN.md` edit accompanies this entry, because no numeric table value changed.**

## 2026-08-04 — M1-T3 — `Los`: the §4.1 line-of-sight blocking predicate; resolutions (H)–(L); landed GREEN

**Status: landed green.** `bash tools/run_tests.sh` exits **0** at **Scripts 9 / Tests 129 /
Passing 129 / Failing 0 / Asserts 1308** (the M1-T2 baseline was 8 / 106 / 106 / 0 / 1023);
`bash tools/typecheck.sh` exits 0 over **15** files (was 13); `bash tools/ci.sh` and
`bash tools/verify_harness.sh` both exit 0 with the tree left clean. All four were run headless
through the `tools/` scripts on the repo-local pinned `godot/Godot_v4.7-stable_win64_console.exe`,
never the PATH shim (SETUP-3). The three §13.1 tools that later milestones deliver
(`sim_smoke` → M7, `content_cli` → E4, `balance_lab` → E5) were correctly **SKIPped, not failed**,
per CLAUDE.md's applicability rule. `Scripts 9` equals the number of `test_*.gd` on disk, so the
M0-T5 enumeration guard is satisfied and nothing was silently un-collected.

**The sentence implemented, transcribed verbatim from `docs/GAME_DESIGN.md` §4.1 line 172 (re-read
at Land):** *"Line of sight uses standard hex line-drawing (lerp in cube space, round); a line is
blocked by any Solid hex, or by any hex whose elevation exceeds **both** endpoints' elevation."*
Supporting §4.1 facts used: *"Elevation: integer 0–3 per hex"* (line 173) and §4.2's *"Solid hexes
(volumetric rock; block movement, LOS, and light)"*. §4.1 legislates an **algorithm** here, not a
table, so there is **no printed cell to transcribe** and every expected value in
`tests/unit/test_los.gd` is **derived**. `docs/decisions.md` was re-scanned end-to-end this
iteration: **no logged override touches §4.1**, so the printed text governs unamended. The
resolutions below are therefore §13.4 decisions, not deviations from a printed value. Their
lettering continues M1-T1's `(A)`/`(B)` and M1-T2's `(C)`–`(G)` and is cross-referenced by the
header doc blocks of `scripts/core/los.gd` and `tests/unit/test_los.gd` — **keep it stable; M1-T4
continues at (M)**.

- **What changed / was decided:**
  1. **(H) TERRAIN INJECTION SHAPE — the open design question `docs/PROGRESS.md` raised at M1-T2 is
     now settled.** No `GameState`, no map type and no terrain enum exist yet (§4.4's generator is a
     later M1 task), so `Los` receives terrain as **two injected `Callable`s** —
     `is_solid(Vector2i) -> bool` and `elevation(Vector2i) -> int` — as parameters 3 and 4 of both
     public functions. Rationale: a `Callable` is a Variant built-in, not a `Node` or singleton, so
     §11.1 purity holds and the file stays headless-byte-identical; inventing a map type here would
     pre-empt §4.4 and force a rewrite. When `GameState` lands, callers bind closures over it and
     `los.gd` itself never changes. The alternative considered and rejected was a tiny typed
     read-only view class, which would have been a map type in all but name.
  2. **(I) ENDPOINT EXEMPTION.** Only **interior** hexes — line indices `1..N-1` where
     `N == path.size() - 1` — are tested. `path[0]` (`== a`) and `path[N]` (`== b`) are **never**
     tested, so a **Solid endpoint does not block its own line**: you can always see out of, and
     into, the hex you stand on or look at. The elevation half of the exemption is arithmetically
     vacuous under (J) (an endpoint's own elevation can never *exceed* `maxi` of the two endpoints),
     but it is stated explicitly so that no later stage "fixes" it into existence. Pinned by test
     case A2 (both endpoints Solid ⇒ open) and by properties P2/P4.
  3. **(J) "EXCEEDS BOTH ENDPOINTS' ELEVATION" IS A STRICT `>` AGAINST `maxi(elev(a), elev(b))`.**
     Equal elevation does **not** block. `elevation exceeds both endpoints` reads as "greater than
     the higher of the two", i.e. `elev(h) > cap` with `cap = maxi(elev(a), elev(b))` computed
     **once** before the loop (both for cost and, more importantly, so the cap cannot drift
     per-hex). An implementation using `>=` fails exactly at pinned case A4
     (`elev(a)=2, elev(b)=1, elev(mid)=2 ⇒ open`) — proven live by probe 1 below.
  4. **(K) DEGENERATE LINES ARE ALWAYS OPEN, as a CONSEQUENCE of (I) and not as a special case.**
     `distance == 0` (line `[a]`) and `distance == 1` (line `[a, b]`) have **zero** interior hexes,
     so they are unconditionally open regardless of terrain — even when the hex is Solid and at
     elevation 3. This is implemented with **no early return**: `range(1, path.size() - 1)` is
     naturally empty for path sizes 1 and 2, so the behaviour cannot drift away from (I). Pinned by
     cases A8/A9 and by properties P2 (reflexivity) and P4 (adjacency under worst-case terrain).
  5. **(L) AN INVALID `Callable` MEANS OPEN TERRAIN, and off-map semantics are the CALLER's.** If
     either `Callable` fails `is_valid()`, `has_line_of_sight` returns `true` and `blocking_hexes`
     returns `[]` (never `null`) — a **total function**: no crash, no engine error, no assert abort
     headless, the same spirit as M1-T1 resolution (B), and for the same reason (a bad argument must
     never tear down a 60-turn headless run). `Los` knows **no map bounds**, calls the `Callable`s
     only for the two endpoints and the interior hexes of the line, and imposes **no elevation range
     check** — §4.1's 0–3 is the *generator's* contract, not this file's. `Los` compares; it does not
     police. Pinned by case A10.
  6. **Public API is EXACTLY two functions and must not grow.**
     `static func has_line_of_sight(a: Vector2i, b: Vector2i, is_solid: Callable, elevation: Callable) -> bool`
     (may short-circuit on the first blocker) and
     `static func blocking_hexes(a: Vector2i, b: Vector2i, is_solid: Callable, elevation: Callable) -> Array[Vector2i]`
     (collects all blockers, in line order, nearest to `a` first, into a **fresh** `Array[Vector2i]`
     per call — M1-T2 trap 1, re-pinned here by P7 with a live mutation probe). One private helper
     `_blocks(h, cap, is_solid, elevation)` implements the OR, checking Solid first. Property P5 pins
     that the two public functions agree (`has_line_of_sight == blocking_hexes().is_empty()`).
     **Deliberately NOT added:** `visible_hexes` / fog-of-war / vision-range helpers — §4.3's
     *"Default unit vision: 4 hexes"* and the Dark/Darkvision rules (§4.7) belong to later
     milestones (§13.4: invent nothing ahead of its milestone).
  7. **The line-drawing half was CALLED, never re-implemented.** `los.gd` delegates to
     `HexMath.line(a, b)` (resolutions (C)/(C2)/(D)); the mechanical source scan asserts the literal
     text `HexMath.line(` is present, so a future "optimization" that inlines a second line walk
     fails the suite. This matters because §14's LOS **symmetry** property is true only because
     `line(a,b) == reverse(line(b,a))` exactly (resolution (D), no epsilon), combined with the
     symmetric `maxi()` cap.
  8. **Every derived value was re-derived independently — TWICE, by two different stages, from the
     GDD text rather than from the task spec's answer list** (M1-T1 item 3 / M1-T2 item 9: a wrong
     number that survives into the log is worse than no number). The Tests stage built a standalone
     reference model of §4.1 plus (C)/(C2)/(D) *without reading* `hex_math.gd`; Verify built a second,
     independent one *without reading* `los.gd`. Both re-derived: the direction-0 axis interior
     `[(1,0),(2,0),(3,0)]`; all ten hand-walked cases A1–A10; the fixture's 5 Solid / 14
     elevation-3 / 1 both (`(4,-3)`) over the 61-hex radius-4 disc; and all eight property sweeps
     (3,721 ordered pairs — **0** symmetry breaks, **0** reverse-blocker breaks, **0**
     agreement/membership/ordering breaks, blocked 2,044 vs open 1,677, of which solid-blocked 922
     and elevation-only 1,122, so **both clauses of the OR genuinely fire** and the fixture is not
     degenerate; P2 over 61 hexes; P3 over 3,721; P4 over 366 adjacency checks; P6 over 305 checks
     with 0 LOS creations and 5 genuine flips). **Zero mismatches, and zero corrections needed** to
     the task spec's ten values.
  9. **THREE adversarial mutation probes were executed live AT VERIFY** (the standard M1-T1 item 8
     and M1-T2 item 5 set: a property test never observed failing is indistinguishable from one that
     *cannot* fail). Baseline md5 `39d2e6e4020afab0380312bd4084c02d` was captured first and
     re-verified identical after each probe; the landed file carries that same md5, and Verify
     additionally `diff`ed against a pristine backup.
     - **Probe 1 — (J), `>` → `>=`.** `test_elevation_equal_to_the_higher_endpoint_does_not_block`
       went **RED on both its A4 and A6 assertions**, with documented collateral in A1/A2/A5/P3/P7
       (an unset hex reads elevation 0, so `>=` makes every elevation-0 interior hex block).
       Suite exit 1, 123 passing / 6 failing.
     - **Probe 2 — (I), the endpoint exemption dropped (`range(1, size-1)` → `range(0, size)`).**
       Exactly the predicted set went **RED**: `test_solid_endpoints_do_not_block_their_own_line`
       (A2), `test_degenerate_and_adjacent_lines_are_always_open` (A8/A9),
       `test_los_is_reflexive_even_on_solid_and_peak_hexes` (P2),
       `test_adjacent_hexes_always_see_each_other_even_on_worst_case_terrain` (P4), plus
       `test_predicate_and_blocker_list_agree_over_the_radius_four_disc` (P5) as documented
       collateral. 124 passing / 5 failing.
     - **Probe 3 (Verify-initiated, NOT in the task spec, and the most informative of the three) —
       an ASYMMETRIC cap: `cap = maxi(elev(a), elev(b))` → `cap = elev(a)` (viewer-only).** This
       variant is **invisible to every single hand-walked case** (in A4, `cap == elev(a) == 2`
       either way) and is caught **only** by the 3,721-ordered-pair symmetry sweep:
       `test_los_is_symmetric_over_the_radius_four_disc` (P1) and
       `test_adding_one_solid_hex_never_creates_line_of_sight` (P6) went red, 127 passing / 2
       failing. **This is direct evidence that §14's "LOS property tests" wording is doing real work
       that an example-based suite could not do**, and it is recorded here so no future task
       "simplifies" the sweep away as a slow restatement of the hand-walked cases.
  10. **TWO SMALL TEST-PLAN DEVIATIONS from the task spec, both introduced by the Tests stage, both
     deliberate and both verified harmless.** (a) The sweep disc is built by a local `_disc()` helper
     over the already-pinned `HexMath.distance` (mirroring `test_hex_math.gd`) rather than by
     `HexMath.hexes_in_range`, so the LOS suite does **not** take a dependency on resolution (G)'s
     spiral **ordering** — a change to (G)'s order must not be able to silently re-shape the LOS
     property sweeps. Verify confirmed independently that `_disc(4)` yields exactly 61 hexes and
     `_disc(5)` exactly 91. (b) Terrain is populated out to **radius 5** (91 hexes) while pairs are
     swept over **radius 4** (61 hexes / 3,721 ordered pairs), so no line ever leaves populated
     ground; off-disc hexes still read as open / elevation-0, which is a property of the **fixture**,
     not of `Los` (resolution (L)). No RNG appears anywhere in the suite (§11.1) — the fixture is
     hand-built and fully populated before the `Callable`s are created.
  11. **No test was weakened, edited or re-valued to make the implementation pass.**
     `tests/unit/test_los.gd` is byte-identical between the Tests stage and Land
     (md5 `36e1bb34dad8a872593d3f823d23651a`, 965 lines) and never appears in `git status` after the
     Implement stage. The Implement stage touched exactly one file, `scripts/core/los.gd` (stub
     bodies replaced, the `!!! M1-T3 TESTS-STAGE STUBS !!!` banner deleted), and Verify made **zero**
     fixes — the standing rule held in both directions: **code was fixed to match the derived values,
     never the reverse.** Zero tracked files were modified by this commit's code diff; `data/`,
     `project.godot`, `tools/`, `addons/` and `docs/GAME_DESIGN.md` are byte-identical to HEAD, so
     the harness contract was neither weakened nor touched.
  12. **The Tests-stage stub convention was used again and again paid for itself** (M1-T2 item 10):
     `los.gd` shipped from the Tests stage with deliberately-wrong bodies under an explicit banner,
     so the red was **10 named value failures** rather than the silent whole-file un-collection that
     M0-T5 closed, and `Scripts 9` already equalled the on-disk count while the tree was red. The
     Tests stage additionally **proved the suite satisfiable** before handing over — a correct
     implementation was swapped in live (129/129, exit 0), then the wrong stub restored
     byte-identically (md5 checked) — so the red was known-reachable rather than merely loud.
  13. **Source scans were written fresh for the new file, because a new file inherits nothing.**
     `test_hex_math.gd`'s scans cover `hex_math.gd` **only**. `test_los.gd` mirrors all five onto
     `los.gd` over comment-stripped source (comment stripping is load-bearing: the doc block contains
     "§4.1", which the no-float regex would otherwise hit): S1 no float literal (`\.[0-9]`) and no
     `float` token; S2 none of `randi(` / `randf(` / `extends Node` / `SceneTree` / `get_tree` /
     `Engine.` / `Time.` / `OS.`; S3 no map-size literal (`24|32|40|1801|3169|4921`); S4 doc comments
     naming `§4.1` on every public function **plus** the tightened assertion (M1-T2 item 11) that the
     public surface is **exactly** `has_line_of_sight` + `blocking_hexes`, so a missing or an extra
     member fails rather than passing vacuously, **plus** the presence of `HexMath.line(`; S5 purity
     via `Los.new().get_class() == "RefCounted"` — **never `x is Node`**, which is statically
     impossible against a `RefCounted` and is a parse error that silently un-collects the whole test
     file (decisions.md M0-T2 item 11 / M0-T5 item (a)). Verify re-ran all five independently rather
     than trusting the in-suite versions.
  14. **§13.6 clauses that are VACUOUS here, stated explicitly because they were re-checked rather
     than assumed:** this task reads **zero** §12.1 constants and `data/ruleset.json` gained **no**
     key — the blocking predicate is *algorithm, not tunable content*, the same data-vs-code line
     M1-T1 item 4 and M1-T2 item 12 drew for hex geometry. `Los` mutates no `GameState` and touches
     no `EventBus`, so *"events emitted for every state change"* has **no subject matter** (no
     `Command`/`validate`/`apply` surface exists yet to violate). **Goldens: NONE re-recorded —
     none exist yet**; the project's first golden still lands with the §4.4 mapgen terrain hash, and
     §13.6's re-record-only-with-a-logged-reason rule starts applying from that moment.
  15. **Scope held (§13.4).** Deliberately **not** written: the concentric-bowl generator (§4.4) or
     any map / terrain type or enum; any golden file; the chunked MultiMesh renderer, camera rig or
     hex picking; `GameState`; any `Command`; any concrete `Event` subclass; movement / pathfinding /
     ZOC / elevation-cost rules (§4.1 prose, but §14 assigns those to **M4**); fog-of-war knowledge
     states (§4.3); light / Dark / Darkvision rules (§4.7); any new key in `data/ruleset.json`; any
     `addons/` change; any edit to `tools/run_tests.sh` (harness contract — strengthening only, and
     nothing here needed it) or to `docs/GAME_DESIGN.md`.
  16. **SIZE OBSERVATION, recorded so it is not misread as scope creep.** The task estimated ~295 LOC
     and the delivered change is **27 code lines** in `los.gd` (90 lines with its doc block) plus
     **~626 code lines** in `test_los.gd` (965 total). The overshoot is entirely in the **test** file
     and is driven by §14's *"LOS property tests"* acceptance criterion — eight property sweeps over
     3,721 ordered pairs plus the five mechanical source scans. The production surface is exactly the
     two functions the spec allowed; no system, resource or stat was invented. The ≤ ~300 LOC house
     rule is a *change-size* budget for production scope, and it was honoured there; a §14 acceptance
     criterion that names property tests is not something to ration.
  17. **STAGE-BOUNDARY NOTE, so it is not mistaken for a missed deliverable** (the same call M0-T5
     item (i) and M1-T2 item 9 record). The task spec's `files_expected` listed `docs/decisions.md`
     and `docs/PROGRESS.md` alongside the code, and the Implement stage correctly did **not** touch
     either: both are **Land**-stage artefacts (this entry and the tracker update). That is the
     intended division of labour under CLAUDE.md's five-stage loop.
- **Why:** LOS is not a leaf utility — fog of war (§4.3), AI targeting (§10), ranged combat and cover
  (§7) and the light/Dark rules (§4.7) all key off this one predicate, so every silence in §4.1's
  single sentence had to be closed **now**, in integer arithmetic, before four systems close them
  accidentally and inconsistently. (H) is the load-bearing one: it lets M1-T3 exist at all without
  pre-empting §4.4's generator, and it costs nothing later because a closure over `GameState`
  satisfies the same signature. (I)+(K) are recorded together because the natural implementation of
  (I) *is* (K), and writing (K) as its own early return is precisely how the two would drift apart.
  (J) and probe 3 together are the strongest evidence in the log so far that §13.2's property tier
  earns its keep: the asymmetric-cap bug is a plausible one-token slip that **no** hand-walked case in
  this suite detects, and only the symmetry sweep does. Recording all three probe results at length
  follows M1-T2 item 5's precedent for the same reason.
- **GDD section affected:** §4.1 (the LOS sentence **implemented**; five silences resolved under
  §13.4 — **no numeric table value moved, no cell edited**. §4.1's only numeric table, *Map sizes
  (hex radius): Small 24 (1,801), Medium 32 (3,169), Large 40 (4,921)*, is unmoved, and those six
  literals are mechanically confirmed **absent** from `los.gd`. §4.1's *"Elevation: integer 0–3"* is
  honoured by the test fixture, which asserts its own elevations lie in 0–3, while `Los` itself
  deliberately imposes no range check — part of resolution (L). `decisions.md` was re-scanned
  end-to-end this iteration: **no logged override touches §4.1**); §4.2 (its *"Solid hexes … block
  movement, LOS, and light"* definition is the Solid clause's source; no terrain type or table was
  created here — that is §4.4's generator); §11.1 (engine-free determinism: pure `RefCounted`, no
  `Node`/`SceneTree`/singleton, no `randi()`/`randf()`, no wall-clock, no float anywhere — all
  `Vector2i`/`Vector3i`/`maxi` — plus the fresh-array contract, all re-scanned at Verify);
  §11.2 (`scripts/core/los.gd` — §11.2's second named `core/` peer, now built); §11.3 (mechanical
  typing gate green over **15** files; both public functions carry `## §4.1` doc-comment blocks,
  scanner proven live; every `Callable.call()` Variant converted through an explicit `bool()`/`int()`
  before use; no `:=`, no untyped `var`, no `@warning_ignore` anywhere since no division exists);
  §13.2 (tier 1 *"every core/ function"* plus the §14 property tests — the LOS half, now delivered);
  §13.4 (procedure exercised: five silences resolved (H)–(L), nothing stalled); §13.6 (definition of
  done **MET**: tests green headless, typing gate clean, no constants to read, no events to emit, no
  golden to re-record); **§14 M1 row — the row is STILL OPEN and NOT met. Exactly ONE of its three
  acceptance criteria now passes: *"LOS property tests"* (met headless). *"Golden mapgen test
  (seed ⇒ terrain hash)"* and *"60 fps on Medium map greybox"* remain unmet — no generator, no golden
  file, no renderer, camera rig or greybox scene exists. Of the five M1 deliverables, HexMath (both
  slices) and `Los` are complete; the concentric-bowl generator, chunked MultiMesh renderer, camera
  rig and hex picking are not.** Acceptance criterion text unchanged. **NO `docs/GAME_DESIGN.md` edit
  accompanies this entry, because no numeric table value changed.**
