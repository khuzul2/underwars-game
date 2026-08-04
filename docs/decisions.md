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
