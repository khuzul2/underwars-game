export const meta = {
  name: 'underwars-iteration',
  description: 'One Underwars agent-loop iteration (GDD §13.3): Opus orients/tests/verifies, Sonnet implements',
  whenToUse: 'Run exactly one task iteration of the Underwars implementation loop. Repeat invocations advance milestones M0…M8, E1…E5, C1…C6.',
  phases: [
    { title: 'Orient', detail: 'read loop state + GDD, pick and spec the next task', model: 'opus' },
    { title: 'Tests', detail: 'write failing tests pinning the GDD rules for the task', model: 'opus' },
    { title: 'Implement', detail: 'make the tests pass within spec scope', model: 'sonnet' },
    { title: 'Verify', detail: 'run applicable suite headless, fix until green', model: 'opus' },
    { title: 'Land', detail: 'update PROGRESS/decisions, commit with task ID, push', model: 'opus' },
  ],
}

// ---------- Schemas ----------

const TASK_SPEC = {
  type: 'object',
  required: ['nothing_to_do'],
  properties: {
    nothing_to_do: { type: 'boolean', description: 'true ONLY if no task can/should run (all milestones done, or hard external blocker). When true, reason is mandatory and task fields must be omitted. When false, ALL task fields below are mandatory.' },
    reason: { type: 'string', description: 'mandatory when nothing_to_do is true: precise explanation of why no task can run' },
    milestone: { type: 'string', description: 'e.g. M0' },
    task_id: { type: 'string', description: 'e.g. M0-T2 — next sequential ID for this milestone per docs/PROGRESS.md. ASCII letters/digits/dash only.' },
    title: { type: 'string', description: 'short imperative title; plain ASCII, no quotes/backticks/newlines' },
    gdd_sections: { type: 'array', items: { type: 'string' }, description: 'GDD sections the task implements, e.g. ["§6.1", "§6.3"]' },
    deliverables: { type: 'array', items: { type: 'string' } },
    test_plan: { type: 'string', description: 'what the failing tests must pin, incl. exact table values from the GDD (as amended by decisions.md overrides)' },
    implementation_notes: { type: 'string', description: 'constraints, files, approach hints for the implementer' },
    files_expected: { type: 'array', items: { type: 'string' } },
    estimated_loc: { type: 'number', maximum: 300, description: 'must be ≤ 300; spec only the first slice otherwise' },
  },
}

const TESTS_RESULT = {
  type: 'object',
  required: ['test_files', 'red_confirmed', 'no_testable_rule', 'summary'],
  properties: {
    test_files: { type: 'array', items: { type: 'string' } },
    red_confirmed: { type: 'boolean', description: 'the new tests were RUN and fail for the intended reason (missing implementation), not for setup/syntax errors' },
    no_testable_rule: { type: 'boolean', description: 'true only for pure-scaffolding tasks with genuinely nothing to pin; red_confirmed must then be false and test_files empty' },
    summary: { type: 'string' },
    notes_for_implementer: { type: 'string' },
  },
}

const IMPL_RESULT = {
  type: 'object',
  required: ['summary', 'files_changed', 'tests_passing_locally', 'deviations'],
  properties: {
    summary: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    tests_passing_locally: { type: 'boolean' },
    deviations: { type: 'array', items: { type: 'string' }, description: 'every ambiguity resolved per GDD §13.4, every test file edited and why, every judgment call a decisions.md entry might need; empty if none' },
    concerns: { type: 'string', description: 'anything the verifier should scrutinize' },
  },
}

const VERIFY_RESULT = {
  type: 'object',
  required: ['green', 'suites_run', 'not_applicable', 'summary'],
  properties: {
    green: { type: 'boolean', description: 'every applicable suite passes headless (a not-yet-due/absent tool is NOT a failure — list it in not_applicable)' },
    suites_run: { type: 'array', items: { type: 'string' } },
    not_applicable: { type: 'array', items: { type: 'string' }, description: '§13.1 commands skipped because their tool is not yet due/built' },
    fixes_made: { type: 'array', items: { type: 'string' } },
    goldens_rerecorded: { type: 'boolean' },
    deviations: { type: 'array', items: { type: 'string' }, description: 'rule interpretations or golden re-records needing a decisions.md entry' },
    failures_remaining: { type: 'string' },
    summary: { type: 'string' },
  },
}

const LAND_RESULT = {
  type: 'object',
  required: ['committed', 'pushed', 'summary'],
  properties: {
    committed: { type: 'boolean' },
    commit_subject: { type: 'string' },
    pushed: { type: 'boolean' },
    summary: { type: 'string' },
  },
}

// ---------- Shared prompt fragments & helpers ----------

const CONTEXT = `You are one stage of the Underwars agent loop, working in the current repository
checkout (the repo root — where CLAUDE.md lives). Read CLAUDE.md first — it is the operating
manual and its rules are binding. The source of truth for all game rules is docs/GAME_DESIGN.md
(GDD); where prose and a numeric table disagree, the table wins, and a dated override logged in
docs/decisions.md supersedes the printed table value. Loop state lives in docs/PROGRESS.md.
Never invent systems/resources/stats not in the GDD.
Your final text is consumed by an orchestration script, not a human — return exactly what the
task asks for, no pleasantries.`

// Sanitize model-authored strings before interpolating them into prompts/labels.
const clean = (s, max) => String(s == null ? '' : s).replace(/[`'"\r\n]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max || 80)

const specIncomplete = (s) => !s.nothing_to_do && ['milestone', 'task_id', 'title', 'gdd_sections', 'deliverables', 'test_plan', 'implementation_notes', 'estimated_loc']
  .some((k) => s[k] == null || (Array.isArray(s[k]) && s[k].length === 0 && k !== 'files_expected'))

const hint = (args && args.taskHint) ? `\nOPERATOR HINT for this iteration (respect unless it contradicts the GDD): ${clean(args.taskHint, 500)}` : ''

// ---------- Phase 1: Orient (Opus) ----------

phase('Orient')
log('Orienting: reading loop state and GDD to pick the next task')

const ORIENT_PROMPT = `${CONTEXT}

ROLE: Orient — pick and spec the SINGLE next task of the loop (GDD §13.3).${hint}

Do, in order:
1. Read docs/PROGRESS.md, docs/decisions.md, and run: git log --oneline -15, git status --short.
   If the working tree is dirty or PROGRESS disagrees with reality (e.g. last iteration landed as
   WIP(blocked) or aborted mid-flight), your task is to finish/unblock/land that work —
   continuity beats novelty.
2. Read the GDD milestone tables (§14–§16) and the sections relevant to the current milestone in
   docs/PROGRESS.md. Work strictly in milestone order; a milestone is only done when its
   acceptance criteria pass headless.
3. Sanity-run the harness: bash tools/run_tests.sh (exit 2 = harness not available yet, which is
   expected before M0 completes and is NOT a blocker; exit 1 with tests collected = real reds).
4. Choose the single next task: ≤ 300 estimated LOC of change (spec only the first slice of
   anything bigger), directly advancing the current milestone's deliverables/acceptance criteria.
5. Spec it precisely. In test_plan, transcribe the exact GDD table values the tests must pin
   (dig times, yields, formulas, thresholds...) with their § citations — checking decisions.md
   for logged overrides first — so later stages need no guessing. In implementation_notes, name
   target files per the §11.2 layout and any binding constraints (§11.1 determinism, §11.3
   conventions, data-driven constants). task_id and title must be plain ASCII without quotes,
   backticks, or newlines.

Set nothing_to_do=true only if every remaining milestone is complete or a hard external blocker
exists — then reason is mandatory and precise. Otherwise every task field is mandatory.`

let spec = await agent(ORIENT_PROMPT, { label: 'orient', phase: 'Orient', model: 'opus', schema: TASK_SPEC })
if (!spec) throw new Error('Orient agent returned no result; nothing was mutated — safe to rerun the workflow')

if (spec.nothing_to_do !== true && (specIncomplete(spec) || spec.estimated_loc > 300)) {
  log('Orient spec incomplete or oversized — re-running once with feedback')
  spec = await agent(`${ORIENT_PROMPT}

PREVIOUS ATTEMPT REJECTED by the orchestrator: it was ${spec.estimated_loc > 300 ? 'over the 300-LOC ceiling — spec only the first slice' : 'missing mandatory task fields'}.
Previous attempt: ${JSON.stringify(spec)}
Fix that and return a complete, compliant spec.`,
    { label: 'orient:retry', phase: 'Orient', model: 'opus', schema: TASK_SPEC })
  if (!spec) throw new Error('Orient retry returned no result; nothing was mutated — safe to rerun the workflow')
  if (spec.nothing_to_do !== true && (specIncomplete(spec) || spec.estimated_loc > 300)) {
    throw new Error('Orient produced an invalid spec twice; nothing was mutated — inspect docs/PROGRESS.md and rerun')
  }
}

if (spec.nothing_to_do) {
  log(`Nothing to do: ${clean(spec.reason, 200) || 'no reason given'}`)
  const record = await agent(`${CONTEXT}

ROLE: Record-blocker — the Orient stage concluded no task can run. Its reason:
${JSON.stringify(spec.reason || '(none given — say so)')}

Do: update docs/PROGRESS.md ("Blockers" and "Notes for the next iteration") so the next
iteration starts from this conclusion instead of rediscovering it; commit ONLY that file with
subject 'LOOP: no runnable task' and a body quoting the reason, ending the body with:
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Then push (on failure: git pull --rebase and retry once; report honestly).
Do not modify anything else.`,
    { label: 'record-blocker', phase: 'Land', model: 'opus', schema: LAND_RESULT })
  return { status: 'nothing_to_do', reason: spec.reason || '', recorded: !!(record && record.committed), task: null }
}

const taskRef = `${clean(spec.task_id, 24)}`
log(`Task: ${taskRef} — ${clean(spec.title)} (${clean(spec.milestone, 12)}, ~${spec.estimated_loc} LOC, GDD ${spec.gdd_sections.join(' ')})`)
const specText = JSON.stringify(spec, null, 2)

// A stage that dies or hard-fails sets this; the iteration then degrades to a blocked Land
// instead of aborting with work stranded in the tree.
let blockedNote = ''
let tests = null
let impl = null
let verify = null

// ---------- Phase 2: Tests first (Opus) ----------

phase('Tests')
const TESTS_PROMPT = `${CONTEXT}

ROLE: Test author — write the tests for this task BEFORE implementation (GDD §13.2, §13.3).

TASK SPEC (from Orient):
${specText}

Do:
1. Re-read the GDD sections cited in the spec AND docs/decisions.md. Tests pin GDD table values
   EXACTLY — transcribe numbers from the tables (a dated decisions.md override supersedes the
   printed value), never from memory or from existing code.
2. Write/extend GUT tests under tests/ (unit/ for core functions & command validate/apply,
   sim/ for scripted mini-scenarios, golden/ for seed+command-log hashes). Static typing; each
   test file/case cites the GDD § it pins. If the harness itself isn't wired yet (early M0),
   wiring GUT so 'bash tools/run_tests.sh' passes IS the deliverable — the script already exists
   as the hardened harness contract (read it; never weaken it; addons/gut is read-only).
3. Run the new tests headless and set red_confirmed honestly: true ONLY if they fail because the
   implementation is missing — not for setup/syntax/path errors (fix those first).
4. Pure-scaffolding task with genuinely nothing to pin: set no_testable_rule=true,
   red_confirmed=false, test_files=[] and explain in summary. Never write vacuous tests.
5. Do NOT implement production code beyond minimal stubs strictly needed for tests to load.`

tests = await agent(TESTS_PROMPT, { label: `tests:${taskRef}`, phase: 'Tests', model: 'opus', schema: TESTS_RESULT })

if (tests && !tests.red_confirmed && !tests.no_testable_rule) {
  log('Tests not confirmed red — re-running test author once with its own failure report')
  tests = await agent(`${TESTS_PROMPT}

PREVIOUS ATTEMPT did not confirm red. Its report:
${JSON.stringify(tests, null, 2)}
Diagnose why (setup error? wrong paths? tests accidentally passing against existing code?),
fix the tests, run them again, and return an honest result.`,
    { label: `tests-retry:${taskRef}`, phase: 'Tests', model: 'opus', schema: TESTS_RESULT })
}

if (!tests) {
  blockedNote = 'Tests stage returned no result (agent died/skipped); tree may hold partial test files'
} else if (!tests.red_confirmed && !tests.no_testable_rule) {
  blockedNote = `Tests never went red for the intended reason after retry: ${clean(tests.summary, 300)}`
} else {
  log(`Tests: ${tests.test_files.length} file(s), red_confirmed=${tests.red_confirmed}, no_testable_rule=${tests.no_testable_rule}`)
}

// ---------- Phase 3: Implement (Sonnet) ----------

if (!blockedNote) {
  phase('Implement')
  impl = await agent(`${CONTEXT}

ROLE: Implementer — make the task's tests pass. Heavy lifting only; the spec fixes your scope —
resist adjacent improvements.

TASK SPEC:
${specText}

TEST AUTHOR REPORT (make these tests pass; do not weaken them):
${JSON.stringify(tests, null, 2)}
${tests.no_testable_rule ? 'NOTE: scaffolding task — no pinned tests; the deliverables list above is your contract.' : `NOTE: red_confirmed=${tests.red_confirmed} — the tests were run and fail because the implementation is missing. Your job is to make them pass legitimately.`}

Binding constraints (CLAUDE.md / GDD §11):
- Sim core = pure RefCounted, no Node/SceneTree/singletons/randi(); only state.rng for rolls.
- Every GameState mutation goes through a Command (validate/apply); apply() emits typed events.
- No magic numbers: constants come from data/*.json via RulesLoader.
- Static typing everywhere; class_name PascalCase; files snake_case; one class per file; public
  rule functions annotated with the GDD § they implement.
- Integer/percent math, round-half-up at the final step; stable-ID iteration order.
- Do not modify addons/ or docs/GAME_DESIGN.md. Never WEAKEN tools/run_tests.sh (its guards,
  refusal strings and exit codes are the harness contract); strengthening-only edits are allowed
  when the task spec explicitly requires them. Do not edit tests except to
  fix a genuine test bug — and every such edit MUST be listed in deviations with the reason.
- Every ambiguity you resolve per GDD §13.4 (simplest interpretation consistent with §1.1
  pillars) goes in deviations so the Land stage can log it in docs/decisions.md.

Work loop: implement → run the task's tests headless → fix → repeat until they pass.
Then run 'bash tools/run_tests.sh' to check you broke nothing else (exit 2 = harness not
available yet, acceptable only before M0 completes).`,
    { label: `impl:${taskRef}`, phase: 'Implement', model: 'sonnet', schema: IMPL_RESULT })

  if (!impl) {
    blockedNote = 'Implement stage returned no result (agent died/skipped); tree may hold partial implementation'
  } else {
    log(`Implemented: ${impl.files_changed.length} file(s) changed, local tests passing=${impl.tests_passing_locally}, deviations=${impl.deviations.length}`)
  }
}

// ---------- Phase 4: Verify & fix (Opus) ----------

if (!blockedNote) {
  phase('Verify')
  verify = await agent(`${CONTEXT}

ROLE: Verifier & fixer — adversarially verify the iteration and drive the suite to green (§13.6).

TASK SPEC:
${specText}

IMPLEMENTER REPORT (do not trust it — verify; it self-reported tests_passing_locally=${impl.tests_passing_locally}):
${JSON.stringify(impl, null, 2)}

TEST AUTHOR REPORT (red_confirmed=${tests.red_confirmed}, no_testable_rule=${tests.no_testable_rule}):
${JSON.stringify(tests, null, 2)}

Do, in order:
1. Run 'bash tools/run_tests.sh' (never weaken/modify it) plus every other §13.1 command that
   applies to the current milestone per CLAUDE.md's Applicability rule. A command whose tool is
   not yet due or not yet built is NOT a failure — list it under not_applicable instead.
2. Diff-review the changed files (git diff / git status): scope creep beyond the spec, magic
   numbers that belong in data/, typing violations, determinism violations (randi, wall-clock,
   float accumulation, unstable iteration), commands mutating state outside validate/apply,
   missing event emissions, weakened tests (compare against the test author's files).
3. Cross-check every constant the tests pin against the GDD tables, honoring dated decisions.md
   overrides. On mismatch: fix CODE (or a wrong test) to match the governing value — never the
   other way. A NEW rule change requires a decisions.md entry and belongs to a separate tuning
   task, not this one.
4. Fix what you find; re-run until green. Re-record goldens only for a legitimate, explainable
   rules change, and list it in deviations (the Land stage logs it in decisions.md).
5. If after serious effort something still fails, report green=false with precise
   failures_remaining (file, test name, error) so the next iteration can resume.`,
    { label: `verify:${taskRef}`, phase: 'Verify', model: 'opus', schema: VERIFY_RESULT })

  if (!verify) {
    blockedNote = 'Verify stage returned no result (agent died/skipped) — treat the suite state as unknown'
  } else {
    log(verify.green ? 'Suite GREEN' : `Suite RED — ${clean(verify.failures_remaining, 200) || 'see summary'}`)
  }
}

if (!verify) {
  verify = {
    green: false,
    suites_run: [],
    not_applicable: [],
    fixes_made: [],
    goldens_rerecorded: false,
    deviations: [],
    failures_remaining: blockedNote,
    summary: `Iteration degraded before/at Verify: ${blockedNote}`,
  }
}

// ---------- Phase 5: Land (Opus) — always runs, so no work is ever stranded ----------

phase('Land')
const land = await agent(`${CONTEXT}

ROLE: Land — persist the iteration's outcome. The suite state is ${verify.green ? 'GREEN' : 'RED/UNKNOWN (blocked)'}.

TASK SPEC:
${specText}

TEST AUTHOR REPORT:
${JSON.stringify(tests, null, 2)}

IMPLEMENTER REPORT:
${JSON.stringify(impl, null, 2)}

VERIFY REPORT:
${JSON.stringify(verify, null, 2)}

Do:
1. Update docs/PROGRESS.md: current position, milestone tracker (check the milestone's §14–§16
   acceptance criteria — mark the milestone done ONLY if they all pass headless, and say so),
   append a task-log row (status: ${verify.green ? 'landed' : 'blocked'}; the Commit column holds
   the commit SUBJECT, not a SHA), refresh "Notes for the next iteration" (what to pick up, known
   risks, and — if blocked — the exact failures_remaining above).
2. Deviations: collect every entry from the implementer's and verifier's deviations arrays (plus
   goldens_rerecorded). For each, add a dated entry to docs/decisions.md (what/why/§ affected).
   If a logged deviation changes a GDD table value, update that specific table cell in
   docs/GAME_DESIGN.md in this same commit — Land is the only stage permitted to edit the GDD.
3. Commit everything in one commit. Build the subject EXACTLY from the spec fields:
   '${verify.green ? '' : 'WIP(blocked) '}' + task_id + ': ' + title (use the task_id and title
   values from the TASK SPEC above). Write subject and body to a temp file and use
   'git commit -F <file>' so quoting cannot mangle it. Body: deliverables, test status,
   deviations logged. End the body with:
   Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
4. Push to origin main. If push fails (e.g. remote ahead), git pull --rebase and push again;
   report honestly if it still fails.
5. Do not modify code or tests in this stage.`,
  { label: `land:${taskRef}`, phase: 'Land', model: 'opus', schema: LAND_RESULT })

if (!land) {
  return {
    status: 'blocked',
    task: { id: spec.task_id, title: spec.title, milestone: spec.milestone },
    tests: tests ? { files: tests.test_files, red_confirmed: tests.red_confirmed, no_testable_rule: tests.no_testable_rule } : null,
    implementation: impl ? { files_changed: impl.files_changed, deviations: impl.deviations } : null,
    verify: { green: verify.green, suites_run: verify.suites_run, not_applicable: verify.not_applicable, failures_remaining: verify.failures_remaining || '' },
    land: { committed: false, pushed: false, commit_subject: '' },
    note: 'Land stage returned no result — the working tree may hold uncommitted work; next Orient must reconcile via git status',
  }
}
log(`Landed: committed=${land.committed}, pushed=${land.pushed}`)

return {
  status: verify.green ? 'landed' : 'blocked',
  task: { id: spec.task_id, title: spec.title, milestone: spec.milestone },
  tests: tests ? { files: tests.test_files, red_confirmed: tests.red_confirmed, no_testable_rule: tests.no_testable_rule } : null,
  implementation: impl ? { files_changed: impl.files_changed, deviations: impl.deviations } : null,
  verify: { green: verify.green, suites_run: verify.suites_run, not_applicable: verify.not_applicable, failures_remaining: verify.failures_remaining || '' },
  land: { committed: land.committed, pushed: land.pushed, commit_subject: land.commit_subject || '' },
}
