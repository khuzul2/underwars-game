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

- **What changed / was decided:** Target engine is Godot **4.7 stable** (GDD says 4.3+). Test framework pinned to vendored **GUT 9.7.1** at `addons/gut/`. Shell tooling runs under Git Bash on Windows.
- **Why:** 4.7 is what is installed and verified headless on the dev machine; satisfies the 4.3+ requirement. Vendoring GUT keeps the headless loop free of network fetches.
- **GDD section affected:** §13.1 (none of the commands change); no table updated.
