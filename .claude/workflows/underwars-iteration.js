export const meta = {
  name: 'underwars-iteration',
  description: 'One Underwars agent-loop iteration (GDD §13.3): Opus orients/tests/verifies, Sonnet implements',
  whenToUse: 'Run exactly one task iteration of the Underwars implementation loop. Repeat invocations advance milestones M0…M8, E1…E5, C1…C6.',
  phases: [
    { title: 'Orient', detail: 'read loop state + GDD, pick and spec the next task', model: 'opus' },
    { title: 'Tests', detail: 'write failing tests pinning the GDD rules for the task', model: 'opus' },
    { title: 'Implement', detail: 'make the tests pass within spec scope', model: 'sonnet' },
    { title: 'Verify', detail: 'full headless suite, fix until green', model: 'opus' },
    { title: 'Land', detail: 'update PROGRESS/decisions, commit with task ID, push', model: 'opus' },
  ],
}

// ---------- Schemas ----------

const TASK_SPEC = {
  type: 'object',
  required: ['nothing_to_do', 'milestone', 'task_id', 'title', 'gdd_sections', 'deliverables', 'test_plan', 'implementation_notes', 'estimated_loc'],
  properties: {
    nothing_to_do: { type: 'boolean', description: 'true only if no task can/should run (all done, or hard-blocked)' },
    reason: { type: 'string', description: 'required when nothing_to_do is true' },
    milestone: { type: 'string', description: 'e.g. M0' },
    task_id: { type: 'string', description: 'e.g. M0-T2 — next sequential ID for this milestone per docs/PROGRESS.md' },
    title: { type: 'string' },
    gdd_sections: { type: 'array', items: { type: 'string' }, description: 'GDD sections the task implements, e.g. ["§6.1", "§6.3"]' },
    deliverables: { type: 'array', items: { type: 'string' } },
    test_plan: { type: 'string', description: 'what the failing tests must pin, incl. exact table values from the GDD' },
    implementation_notes: { type: 'string', description: 'constraints, files, approach hints for the implementer' },
    files_expected: { type: 'array', items: { type: 'string' } },
    estimated_loc: { type: 'number', description: 'must be ≤ 300; split otherwise' },
  },
}

const TESTS_RESULT = {
  type: 'object',
  required: ['test_files', 'red_confirmed', 'summary'],
  properties: {
    test_files: { type: 'array', items: { type: 'string' } },
    red_confirmed: { type: 'boolean', description: 'new tests were run and fail for the intended reason (or: task has no testable rule and this is explained in summary)' },
    summary: { type: 'string' },
    notes_for_implementer: { type: 'string' },
  },
}

const IMPL_RESULT = {
  type: 'object',
  required: ['summary', 'files_changed', 'tests_passing_locally'],
  properties: {
    summary: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    tests_passing_locally: { type: 'boolean' },
    concerns: { type: 'string', description: 'anything the verifier should scrutinize' },
  },
}

const VERIFY_RESULT = {
  type: 'object',
  required: ['green', 'suites_run', 'summary'],
  properties: {
    green: { type: 'boolean', description: 'entire applicable §13.1 suite passes headless' },
    suites_run: { type: 'array', items: { type: 'string' } },
    fixes_made: { type: 'array', items: { type: 'string' } },
    goldens_rerecorded: { type: 'boolean' },
    failures_remaining: { type: 'string' },
    summary: { type: 'string' },
  },
}

const LAND_RESULT = {
  type: 'object',
  required: ['committed', 'pushed', 'summary'],
  properties: {
    committed: { type: 'boolean' },
    commit_message: { type: 'string' },
    pushed: { type: 'boolean' },
    summary: { type: 'string' },
  },
}

// ---------- Shared prompt fragments ----------

const CONTEXT = `You are one stage of the Underwars agent loop, working in C:\\dev\\underwars-game.
Read CLAUDE.md first — it is the operating manual and its rules are binding.
The single source of truth for all game rules is docs/GAME_DESIGN.md (GDD); where prose and a
numeric table disagree, the table wins. Loop state lives in docs/PROGRESS.md; deviations are
logged in docs/decisions.md. Never invent systems/resources/stats not in the GDD.
Your final text is consumed by an orchestration script, not a human — return exactly what the
task asks for, no pleasantries.`

const hint = (args && args.taskHint) ? `\nOPERATOR HINT for this iteration (respect unless it contradicts the GDD): ${args.taskHint}` : ''

// ---------- Phase 1: Orient (Opus) ----------

phase('Orient')
log('Orienting: reading loop state and GDD to pick the next task')

const spec = await agent(`${CONTEXT}

ROLE: Orient — pick and spec the SINGLE next task of the loop (GDD §13.3).${hint}

Do, in order:
1. Read docs/PROGRESS.md, docs/decisions.md, and run: git log --oneline -15, git status --short.
   If the working tree is dirty or PROGRESS disagrees with reality (e.g. last iteration landed as
   WIP(blocked)), your task is to finish/unblock that work — continuity beats novelty.
2. Read the GDD milestone tables (§14–§16) and the sections relevant to the current milestone in
   docs/PROGRESS.md. Work strictly in milestone order; a milestone is only done when its
   acceptance criteria pass headless.
3. If code exists, sanity-run the test suite (bash tools/run_tests.sh) to know the true state.
4. Choose the single next task: ≤ ~300 LOC of change (split otherwise — spec only the first
   slice), directly advancing the current milestone's deliverables/acceptance criteria.
5. Spec it precisely. In test_plan, transcribe the exact GDD table values the tests must pin
   (dig times, yields, formulas, thresholds...) with their § citations, so later stages need no
   guessing. In implementation_notes, name target files per the §11.2 layout and any binding
   constraints (§11.1 determinism, §11.3 conventions, data-driven constants).

Set nothing_to_do=true only if every remaining milestone is complete or a hard external blocker
exists (explain in reason).`,
  { label: 'orient', phase: 'Orient', model: 'opus', schema: TASK_SPEC })

if (!spec) throw new Error('Orient agent returned no result')
if (spec.nothing_to_do) {
  log(`Nothing to do: ${spec.reason || 'no reason given'}`)
  return { status: 'nothing_to_do', reason: spec.reason || '', task: null }
}
log(`Task: ${spec.task_id} — ${spec.title} (${spec.milestone}, ~${spec.estimated_loc} LOC, GDD ${spec.gdd_sections.join(' ')})`)

const specText = JSON.stringify(spec, null, 2)

// ---------- Phase 2: Tests first (Opus) ----------

phase('Tests')
const tests = await agent(`${CONTEXT}

ROLE: Test author — write the tests for this task BEFORE implementation (GDD §13.2, §13.3).

TASK SPEC (from Orient):
${specText}

Do:
1. Re-read the GDD sections cited in the spec. Tests pin GDD table values EXACTLY — transcribe
   numbers from the tables, never from memory or from existing code.
2. Write/extend GUT tests under tests/ (unit/ for core functions & command validate/apply,
   sim/ for scripted mini-scenarios, golden/ for seed+command-log hashes). Static typing; each
   test file/case cites the GDD § it pins. If the harness itself doesn't exist yet (early M0),
   creating the harness IS the deliverable — wire GUT (vendored at addons/gut, v9.7.1, read-only)
   so 'bash tools/run_tests.sh' runs headless.
3. Run the new tests headless and confirm they FAIL for the intended reason (missing
   implementation), not for setup/syntax errors. If the task genuinely has no testable rule
   (pure scaffolding), say so in summary instead of writing vacuous tests.
4. Do NOT implement production code beyond minimal stubs strictly needed for tests to load.`,
  { label: `tests:${spec.task_id}`, phase: 'Tests', model: 'opus', schema: TESTS_RESULT })

if (!tests) throw new Error('Test-author agent returned no result')
log(`Tests: ${tests.test_files.length} file(s), red_confirmed=${tests.red_confirmed}`)

// ---------- Phase 3: Implement (Sonnet) ----------

phase('Implement')
const impl = await agent(`${CONTEXT}

ROLE: Implementer — make the task's tests pass. Heavy lifting only; scope is fixed by the spec.

TASK SPEC:
${specText}

TESTS ALREADY WRITTEN (make these pass; do not weaken them):
${JSON.stringify(tests, null, 2)}

Binding constraints (CLAUDE.md / GDD §11):
- Sim core = pure RefCounted, no Node/SceneTree/singletons/randi(); only state.rng for rolls.
- Every GameState mutation goes through a Command (validate/apply); apply() emits typed events.
- No magic numbers: constants come from data/*.json via RulesLoader.
- Static typing everywhere; class_name PascalCase; files snake_case; one class per file; public
  rule functions annotated with the GDD § they implement.
- Integer/percent math, round-half-up at the final step; stable-ID iteration order.
- Do not modify addons/ or docs/GAME_DESIGN.md. Do not edit tests except to fix a genuine test
  bug — and if you do, say so explicitly in your summary.
- Stay within the spec's scope (~300 LOC). Resist adjacent improvements.

Work loop: implement → run the task's tests headless → fix → repeat until they pass.
Then run 'bash tools/run_tests.sh' (if it exists) to check you broke nothing else.`,
  { label: `impl:${spec.task_id}`, phase: 'Implement', model: 'sonnet', schema: IMPL_RESULT })

if (!impl) throw new Error('Implementer agent returned no result')
log(`Implemented: ${impl.files_changed.length} file(s) changed, local tests passing=${impl.tests_passing_locally}`)

// ---------- Phase 4: Verify & fix (Opus) ----------

phase('Verify')
const verify = await agent(`${CONTEXT}

ROLE: Verifier & fixer — adversarially verify the iteration and drive the suite to green (§13.6).

TASK SPEC:
${specText}

IMPLEMENTER REPORT (do not trust it — verify):
${JSON.stringify(impl, null, 2)}

TEST AUTHOR REPORT:
${JSON.stringify(tests, null, 2)}

Do, in order:
1. Run every §13.1 command that currently applies (run_tests.sh always; sim_smoke / content_cli
   validate once those tools exist). All headless.
2. Diff-review the changed files (git diff / git status): scope creep beyond the spec, magic
   numbers that belong in data/, typing violations, determinism violations (randi, wall-clock,
   float accumulation, unstable iteration), commands mutating state outside validate/apply,
   missing event emissions, tests weakened by the implementer.
3. Cross-check every constant the tests pin against the GDD tables. On mismatch: fix CODE (or a
   wrong test) to match the GDD table — never the other way. A deliberate rule change requires a
   docs/decisions.md entry and belongs to a separate tuning task, not this one.
4. Fix what you find; re-run until green. Re-record goldens only for a legitimate, explainable
   rules change, and note it (the Land stage will log it in decisions.md).
5. If after serious effort something still fails, stop and report green=false with precise
   failures_remaining (file, test name, error) so the next iteration can resume.`,
  { label: `verify:${spec.task_id}`, phase: 'Verify', model: 'opus', schema: VERIFY_RESULT })

if (!verify) throw new Error('Verifier agent returned no result')
log(verify.green ? 'Suite GREEN' : `Suite RED — ${verify.failures_remaining || 'see summary'}`)

// ---------- Phase 5: Land (Opus) ----------

phase('Land')
const land = await agent(`${CONTEXT}

ROLE: Land — persist the iteration's outcome. The suite is ${verify.green ? 'GREEN' : 'RED (blocked)'}.

TASK SPEC:
${specText}

VERIFY REPORT:
${JSON.stringify(verify, null, 2)}

Do:
1. Update docs/PROGRESS.md: current position, milestone tracker (check the milestone's §14–§16
   acceptance criteria — mark the milestone done ONLY if they all pass headless, and say so),
   append a task-log row (status: ${verify.green ? 'landed' : 'blocked'}), refresh "Notes for the
   next iteration" (what to pick up, known risks).
2. If the iteration deviated from the GDD or re-recorded goldens, add the dated entry to
   docs/decisions.md (what/why/§ affected) — same commit as the change (§13.3).
3. Commit everything: message '${verify.green ? '' : 'WIP(blocked) '}${spec.task_id}: ${spec.title}'
   plus a short body (deliverables, test status). End the body with:
   Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
4. Push to origin main. If push fails (e.g. remote ahead), pull --rebase and push again; report
   honestly if it still fails.
5. Do not modify code or tests in this stage.`,
  { label: `land:${spec.task_id}`, phase: 'Land', model: 'opus', schema: LAND_RESULT })

if (!land) throw new Error('Land agent returned no result')
log(`Landed: committed=${land.committed}, pushed=${land.pushed}`)

return {
  status: verify.green ? 'landed' : 'blocked',
  task: { id: spec.task_id, title: spec.title, milestone: spec.milestone },
  tests: { files: tests.test_files, red_confirmed: tests.red_confirmed },
  implementation: { files_changed: impl.files_changed },
  verify: { green: verify.green, suites_run: verify.suites_run, failures_remaining: verify.failures_remaining || '' },
  land: { committed: land.committed, pushed: land.pushed, commit_message: land.commit_message || '' },
}
