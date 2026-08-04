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
