export const meta = {
  name: 'run-phase',
  description: 'Implement one prepared phase (or subphase) of docs/IMPLEMENTATION_PLAN.md unattended: tasks in the prepared order, one commit each, independent verification with suggested repairs, then the comprehensive phase test, review and triage. Pauses cleanly when an agent dies (e.g. a usage limit).',
  whenToUse: 'Args {phase: N}. Optional: {subphase: "2A"} run one subphase (checkpoint, no review); {only: ["T2.3"]} named tasks; {tasks: [{id, slug, spec, smallScale}], mode, notes} skip the Scope agent; {skipReview: true}; {repairRounds: n}.',
  phases: [
    { title: 'Scope', detail: 'read the prepared phase: order, groups, mode, task states' },
    { title: 'Implement' },
    { title: 'Verify' },
    { title: 'Repair' },
    { title: 'Recheck' },
    { title: 'Record' },
    { title: 'Phase test' },
    { title: 'Review' },
    { title: 'Triage' },
  ],
}

// ---------------------------------------------------------------------------
// Part of the phased-dev plugin. The rules the prompts name live in the
// project's CLAUDE.md; skills/method/references/lessons.md says why each exists.
//
// State is in git, never only here: a task is ☐ (not started), ◐ (committed,
// unverified) or ☑ (verified) in the plan. So when an agent dies -- usually a
// usage or rate limit -- this workflow stops and returns `paused` with the next
// step. Resume with Workflow's resumeFromRunId in the same session (completed
// agents replay from cache), or later with the `resume` skill, which reads git.
// ---------------------------------------------------------------------------

const REPO = (args && args.repo) || '.'
const PHASE = (args && args.phase) != null ? String(args.phase) : null
const SUBPHASE = (args && args.subphase) || null
const ONLY = (args && args.only && args.only.length) ? args.only : null
if (PHASE == null) throw new Error('run-phase needs args {phase: N}')

const SCOPE_SCHEMA = {
  type: 'object',
  properties: {
    prepared: { type: 'boolean', description: "the phase has a 'Prepared: <date>' line" },
    mode: { type: 'string', enum: ['prototype', 'harnessing', 'production'] },
    tasks: {
      type: 'array',
      description: 'in the PREPARED order, excluding ☑ tasks',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          slug: { type: 'string' },
          state: { type: 'string', enum: ['todo', 'implemented'], description: '☐ = todo, ◐ = implemented (committed, unverified)' },
          group: { type: 'string', description: 'implementation group from the Preparation table, e.g. G2' },
          spec: { type: 'string', description: 'the requirement quoted verbatim, plus context the implementer needs' },
          smallScale: { type: 'string', description: 'the small test, naming its target' },
        },
        required: ['id', 'slug', 'state', 'spec', 'smallScale'],
      },
    },
    blockingQuestions: { type: 'array', items: { type: 'string' }, description: 'open Q-n affecting this phase that are marked blocking' },
    phaseExit: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['prepared', 'mode', 'tasks', 'blockingQuestions', 'phaseExit'],
}
const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    completed: { type: 'array', items: { type: 'string' }, description: 'task ids committed (◐) with a clean audit' },
    summaries: { type: 'array', items: { type: 'string' }, description: 'one per task: "<id>: what was built; the assertion the claim rests on; assumptions made"' },
    questions: { type: 'array', items: { type: 'string' }, description: 'Q-n ids recorded in docs/QUESTIONS.md' },
    blockingQuestion: { type: 'string', description: 'a Q-n that stopped the work, if any' },
    features: { type: 'array', items: { type: 'string' }, description: 'F-n ids recorded in docs/FEATURES.md' },
    blocker: { type: 'string', description: 'why the work stopped, with the exact failure output' },
  },
  required: ['completed', 'summaries'],
}
const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    problems: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          task: { type: 'string' },
          problem: { type: 'string', description: 'file:line, what is wrong, the reproducing command' },
          suggested_repair: { type: 'string', description: 'the concrete change you would make' },
        },
        required: ['task', 'problem', 'suggested_repair'],
      },
    },
    observations: { type: 'array', items: { type: 'string' } },
    questions: { type: 'array', items: { type: 'string' }, description: 'ambiguities in the requirement' },
    evidence: { type: 'string' },
  },
  required: ['pass', 'problems', 'evidence'],
}
const DONE_SCHEMA = { type: 'object', properties: { ok: { type: 'boolean' }, detail: { type: 'string' } }, required: ['ok'] }
const PHASE_TEST_SCHEMA = {
  type: 'object',
  properties: { pass: { type: 'boolean' }, gate_script: { type: 'string' }, transcript: { type: 'string' }, problems: { type: 'array', items: { type: 'string' } } },
  required: ['pass', 'gate_script', 'transcript', 'problems'],
}
const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: { severity: { type: 'string' }, file: { type: 'string' }, summary: { type: 'string' }, why: { type: 'string' } },
        required: ['severity', 'summary', 'why'],
      },
    },
  },
  required: ['findings'],
}

// --- Shared prose ----------------------------------------------------------

const READ_ONLY = `## Read-only
Do NOT run git checkout, switch, merge, reset, commit, stash or rebase, and edit
nothing except scratch mutations you revert. Confirm \`git status --porcelain\`
is empty before finishing.`

const TESTS = `Run only the tests you are working on or mutating; the full suite once at the end.`

function depth(mode) {
  if (mode === 'prototype') return `Mode **prototype** (CLAUDE.md → Modes): demonstrate the functionality on typical input, quickly and cheaply. One demonstration test per task. No edge cases, no harness, no polish — record each thing you deliberately skip as a \`kind: hardening\` entry in docs/FEATURES.md with \`Disposition: mode: harnessing\`. Unhandled input must be refused or visibly skipped, never turned into a plausible wrong result.`
  return `Mode **${mode}** (CLAUDE.md → Modes): tests for every behaviour the task names, including edge and malformed input${mode === 'production' ? ', plus fuzz targets for untrusted input' : ''}.`
}

function verifyChecks(mode) {
  const common = `- Is the requirement met, or stubbed, partial, quietly narrowed? Quote it, then the code.
- Run the real program on real (sample) data; look for a wrong result.
- Unhandled input is refused or visibly skipped — never a plausible wrong result.
- Prose the work added (help, doc comments, docs) matches the behaviour.`
  if (mode === 'prototype') return `${common}
- The demonstration test really exercises the behaviour: break the behaviour, run that test, watch it fail, revert. One mutation per task.
- Do NOT raise missing edge cases, harness or polish as problems — that is harnessing work; note them in observations.`
  return `${common}
- CLAUDE.md "Tests that cannot fail": EVERY new test can fail. Break the implementation at the exact construct each test names, run that test, watch it fail, revert. Check fixtures for the self-referential shape.
- The edge and malformed inputs the requirement names are handled and tested.${mode === 'production' ? '\n- Find one hostile input the tests do not throw.' : ''}`
}

const OUTPUT = `## Output
pass=false ONLY for a defect you reproduced. Each problem: task id; file:line,
what is wrong and the reproducing command; and a concrete suggested_repair.
Judgement calls go in observations and do NOT fail the work. Ambiguities in the
requirement go in questions.`

// --- Prompts ---------------------------------------------------------------

function implPrompt(group, mode, notes, prior) {
  const ids = group.map(t => t.id)
  return `You are the implementer for ${ids.length === 1 ? `task ${ids[0]}` : `tasks ${ids.join(', ')}, in this order`} in ${REPO}.

Read CLAUDE.md (binding) and the phase in docs/IMPLEMENTATION_PLAN.md first.

${depth(mode)}

## The tasks
${group.map(t => `### ${t.id} — ${t.slug}\n${t.spec}\n\n**Small test:** ${t.smallScale}`).join('\n\n')}

${notes ? `## About this phase\n${notes}\n` : ''}
## Already done in this phase
${prior.length ? prior.map(s => '- ' + s).join('\n') : '- nothing yet'}

## For EACH task, in order
1. Implement it. Real code.
2. Its small tests in the same commit. Fixtures are literal data, never the constant under test; a new table of magic numbers gets a test pinning each value to a literal with its citation. You do not need to mutation-prove them — the verifier does.
3. Mark it ◐ in docs/IMPLEMENTATION_PLAN.md (that line only — a sed on T1.1 also hits T1.10).
4. Commit ONLY this task: subject "<id>: <what>", with the Co-Authored-By trailer. One task, one commit.
5. Run \`scripts/task-audit.sh <id>\`; it must exit 0 (fix with a further "<id>:" commit).

## When something comes up
- A question the documents do not settle: record it in docs/QUESTIONS.md (question skill format). If it is blocking — the answer changes what you build — STOP after the last clean commit and return it in blockingQuestion. Otherwise continue on a stated assumption, written in the entry and the commit message.
- A new feature or idea outside the task: record it in docs/FEATURES.md (feature skill format, Disposition: proposed). Do not build it.
- Libraries: only those in docs/SPEC.md → Allowed libraries. Needing another is a blocking question.

## Hard rules
No push, rebase, amend, or branch. Do not touch the protected paths in scripts/method.conf. If a task cannot be completed: no red commit, no weakened test, no silently narrowed requirement — stop and return the exact failure output in blocker. Return the ids you completed.

${TESTS}`
}

function verifyPrompt(unit, mode, summaries) {
  const ids = unit.map(t => t.id)
  return `Verify ${ids.join(', ')} in ${REPO}, committed on main and marked ◐. Assume the work does NOT meet its requirement until the evidence forces the opposite.

${READ_ONLY}

## First, the audit
${ids.map(id => `scripts/task-audit.sh ${id}`).join('\n')}
Every FAIL line is a problem. Do not re-check by hand what it checks.

## The requirements (mode: ${mode})
${unit.map(t => `### ${t.id}\n${t.spec}\n\n**Small test:** ${t.smallScale}`).join('\n\n')}

## What the implementer reported
${summaries.length ? summaries.map(s => '- ' + s).join('\n') : '- (committed before this run; read the commits)'}

## What to check
${verifyChecks(mode)}

${TESTS}

${OUTPUT}`
}

function repairPrompt(ids, problems, round) {
  return `Verification of ${ids.join(', ')} in ${REPO} found reproduced problems. You are the implementer; fix them (repair round ${round}).

${problems.map((p, i) => `${i + 1}. [${p.task}] ${p.problem}\n   Suggested repair: ${p.suggested_repair}`).join('\n')}

For each: apply the suggested repair or a better one, add the test that would have caught it, prove it — break the fix, watch that test fail, revert. Commit per task, subject "<task id>: <what you fixed>" with the trailer; run scripts/task-audit.sh for each id. Never fix a problem by weakening the test that exposes it; prefer fixing behaviour over rewording prose. If a problem is not real, say so with evidence instead of changing code. Return the ids you repaired in completed.

${TESTS}`
}

function recheckPrompt(ids, problems, round) {
  return `${ids.join(', ')} in ${REPO} was repaired (round ${round}). Decide whether the repair worked. Assume it did not.

${READ_ONLY}

## The problems it was supposed to fix
${problems.map((p, i) => `${i + 1}. [${p.task}] ${p.problem}`).join('\n')}

1. scripts/task-audit.sh for each id; every FAIL is a problem.
2. For EACH problem: reproduce the original failure now. It must not reproduce. "Fixed" by rewording, deleting a test or narrowing an assertion is not fixed.
3. For each: break the fix, run the covering test, watch it fail, revert.
4. Read only the repair diff; did it break a neighbour?
Do NOT re-verify the whole task.

${OUTPUT}`
}

// ---------------------------------------------------------------------------

const done = []
const observations = []
const questions = []
const features = []
const prior = []

function paused(stage, detail) {
  log(`PAUSED during ${stage}: ${detail}`)
  return {
    phase: PHASE, paused: true, stage, detail, completed: done, questions, features, observations,
    resume: 'Same session: Workflow resumeFromRunId with this run id. Later: the resume skill (reads scripts/progress.sh). Record the pause in docs/STATUS.md → Current run.',
  }
}
function blocked(stage, detail, extra) {
  log(`BLOCKED during ${stage}: ${detail}`)
  return { phase: PHASE, blocked: { stage, detail, ...(extra || {}) }, completed: done, questions, features, observations }
}

phase('Scope')
let scope
if (args && args.tasks) {
  scope = { prepared: true, mode: args.mode || 'prototype', tasks: args.tasks.map(t => ({ state: 'todo', ...t })), blockingQuestions: [], phaseExit: args.phaseExit || '(supplied by caller)', notes: args.notes || '' }
} else {
  scope = await agent(`Read ${REPO}/docs/IMPLEMENTATION_PLAN.md, ${REPO}/docs/QUESTIONS.md and ${REPO}/CLAUDE.md, and extract what is needed to run **Phase ${PHASE}${SUBPHASE ? `, subphase ${SUBPHASE} only` : ''}**.

- prepared: whether the phase has a "Prepared: <date>" line.
- mode: from the "# Prototype" / "# Harnessing" / "# Production" heading the phase sits under.
- tasks: in the order of the phase's Preparation table (plan order if there is none), EXCLUDING tasks marked ☑. For each: id; slug; state (☐ → todo, ◐ → implemented); group (from the Preparation table); spec — the requirement QUOTED VERBATIM plus the context the implementer needs (the invariant or spec section it touches, the code it extends — read src/ so it extends rather than duplicates); smallScale — the small test, naming its target.
- blockingQuestions: open questions in docs/QUESTIONS.md marked blocking that affect this phase.
- phaseExit: quoted. notes: the Preparation section's findings and traps.
${ONLY ? `Return ONLY these tasks: ${ONLY.join(', ')} — even if marked ☑.` : ''}
You may run \`scripts/progress.sh\` to cross-check the task states.`, { label: `scope:${SUBPHASE ? SUBPHASE : "P" + PHASE}`, phase: 'Scope', schema: SCOPE_SCHEMA, effort: 'medium' })
  if (!scope) return paused('scope', 'the scope agent returned nothing')
}

if (!scope.prepared) return blocked('scope', `phase ${PHASE} is not prepared — run the prepare-phase skill first`)
if (scope.blockingQuestions && scope.blockingQuestions.length) return blocked('scope', `open blocking question(s): ${scope.blockingQuestions.join(', ')} — answer them first (question skill)`)

const MODE = scope.mode
const MAX_REPAIRS = (args && args.repairRounds) || (MODE === 'prototype' ? 1 : 3)
let tasks = scope.tasks
if (ONLY) tasks = tasks.filter(t => ONLY.includes(t.id))
if (!tasks.length) log(`Phase ${PHASE}${SUBPHASE || ''}: no unverified task left.`)

// Implementation groups, in the prepared order of their first task.
const groups = []
for (const t of tasks) {
  const key = t.group || t.id
  let g = groups.find(x => x.key === key)
  if (!g) groups.push(g = { key, tasks: [] })
  g.tasks.push(t)
}
log(`Phase ${PHASE}${SUBPHASE || ''} (${MODE}): ${tasks.length} task(s) in ${groups.length} group(s): ${groups.map(g => g.tasks.map(t => t.id).join('+')).join(' | ')}`)

const total = tasks.length
for (const g of groups) {
  const todo = g.tasks.filter(t => t.state !== 'implemented')
  const summaries = []

  // --- implement: one agent per group, one commit per task ------------------
  if (todo.length) {
    phase('Implement')
    const impl = await agent(implPrompt(todo, MODE, scope.notes, prior), { label: `impl:${todo.map(t => t.id).join('+')}`, phase: 'Implement', schema: IMPL_SCHEMA })
    if (!impl) return paused('implement', `the implementer for ${todo.map(t => t.id).join(', ')} returned nothing; tasks it committed are ◐ and will be verified on resume`)
    ;(impl.questions || []).forEach(q => questions.push(q))
    ;(impl.features || []).forEach(f => features.push(f))
    ;(impl.summaries || []).forEach(s => { summaries.push(s); prior.push(s) })
    if (impl.blockingQuestion) return blocked('implement', `blocking question ${impl.blockingQuestion} — answer it, then resume`, { question: impl.blockingQuestion })
    const missing = todo.filter(t => !(impl.completed || []).includes(t.id)).map(t => t.id)
    if (missing.length) return blocked('implement', impl.blocker || `not completed: ${missing.join(', ')}`)
  }

  // --- verify: prototype per group, otherwise per task ----------------------
  const units = MODE === 'prototype' ? [g.tasks] : g.tasks.map(t => [t])
  for (const unit of units) {
    const ids = unit.map(t => t.id)
    const label = ids.join('+')
    const keep = v => {
      ;(v.observations || []).forEach(o => observations.push(`${label}: ${o}`))
      ;(v.questions || []).forEach(q => questions.push(`${label} (verifier): ${q}`))
    }
    phase('Verify')
    let v = await agent(verifyPrompt(unit, MODE, summaries.filter(s => ids.some(id => s.startsWith(id)))), { label: `verify:${label}`, phase: 'Verify', schema: VERDICT_SCHEMA, effort: 'high' })
    if (!v) return paused('verify', `the verifier for ${label} returned nothing — ${label} is committed (◐) and UNVERIFIED`)
    keep(v)

    let round = 0
    let problems = v.pass ? [] : v.problems
    while (problems.length && round < MAX_REPAIRS) {
      round++
      log(`${label}: ${problems.length} problem(s), repair round ${round}/${MAX_REPAIRS}`)
      const r = await agent(repairPrompt(ids, problems, round), { label: `repair${round}:${label}`, phase: 'Repair', schema: IMPL_SCHEMA })
      if (!r) return paused(`repair ${round}`, `the repair agent for ${label} returned nothing`)
      if (r.blockingQuestion) return blocked(`repair ${round}`, `blocking question ${r.blockingQuestion}`, { question: r.blockingQuestion })
      v = await agent(recheckPrompt(ids, problems, round), { label: `recheck${round}:${label}`, phase: 'Recheck', schema: VERDICT_SCHEMA, effort: 'high' })
      if (!v) return paused(`recheck ${round}`, `the recheck for ${label} returned nothing — repair round ${round} is UNCONFIRMED`)
      keep(v)
      problems = v.pass ? [] : v.problems
    }
    if (problems.length) return blocked('verify', `${label}: problems survived ${round} repair round(s)`, { problems })

    // --- record: ◐ → ☑, one commit per task ---------------------------------
    phase('Record')
    const rec = await agent(`In ${REPO}, verification of ${ids.join(', ')} passed. For each id, in docs/IMPLEMENTATION_PLAN.md change its marker from ◐ to ☑ (that line only) and commit with subject "<id>: verified" and the Co-Authored-By trailer — one commit per id. Then run scripts/task-audit.sh for each id; it must exit 0. Change nothing else. Return ok=true when done.`, { label: `record:${label}`, phase: 'Record', schema: DONE_SCHEMA, effort: 'low' })
    if (!rec || !rec.ok) return paused('record', `${label} passed verification but was not marked ☑ — mark it on resume`)
    ids.forEach(id => done.push({ id, repairRounds: round }))
    log(`${label} ☑ (${round} repair round(s)) — ${done.length}/${total} this run`)
  }
}

if (SUBPHASE) {
  // A subphase ends in a checkpoint, not a review or a push.
  phase('Phase test')
  const cp = await agent(`In ${REPO}, run \`scripts/gate.sh ${SUBPHASE}\` and return its last 30 lines in gate_script verbatim; pass = exit status 0; problems = its FAIL lines; transcript = the command and output. Fix nothing.`, { label: `checkpoint:${SUBPHASE}`, phase: 'Phase test', schema: PHASE_TEST_SCHEMA, effort: 'low' })
  if (!cp) return paused('checkpoint', `the checkpoint for ${SUBPHASE} returned nothing`)
  return { phase: PHASE, subphase: SUBPHASE, mode: MODE, completed: done, questions, features, observations, checkpoint: cp }
}
if (args && args.skipReview) return { phase: PHASE, mode: MODE, completed: done, questions, features, observations, note: 'gate skipped' }

// --- The comprehensive phase test -------------------------------------------

phase('Phase test')
const phaseTest = await agent(`Run the COMPREHENSIVE test for Phase ${PHASE} (mode: ${MODE}) in ${REPO}. It gates the phase's push; be hard to satisfy.

Run \`scripts/gate.sh ${PHASE}\`; put its last 30 lines in gate_script verbatim. Every FAIL is a problem; do not re-check by hand what it checked.

Then judge:
1. The exit criterion: ${scope.phaseExit}
   On the REAL data, all of it. ${MODE === 'prototype' ? 'The demonstration runs end to end and shows what it claims.' : 'Compare with the authority the way CLAUDE.md says it can be compared.'}${MODE === 'production' ? ' Measure the quality targets.' : ''}
2. docs/DIVERGENCES.md: run every claim; each must still be literally true.
3. docs/FEATURES.md: input that reaches an unbuilt feature behaves as its "If reached" line says.
Also report any check scripts/gate.sh could make and does not.

pass=false if anything fails. Actual commands and real output in transcript. Fix nothing.`, { label: `phase-test:P${PHASE}`, phase: 'Phase test', schema: PHASE_TEST_SCHEMA, effort: 'high' })
if (!phaseTest) return paused('phase test', 'the comprehensive test returned nothing — re-run it on resume')

const LENSES = {
  prototype: [
    { key: 'combined', prompt: `Review Phase ${PHASE} (prototype) of ${REPO} briefly. Change no files. (1) Does it demonstrate what the phase set out to, end to end? (2) Can any output be a plausible wrong answer instead of a refusal or visible skip? (3) Was harness, edge-case or polish work done that belongs to harnessing (cost)? (4) Is a seam missing that harnessing will need (rewrite risk)? Severity blocker/major/minor.` },
  ],
  harnessing: [
    { key: 'tests', prompt: `Review the tests added in Phase ${PHASE} (harnessing) of ${REPO}. CLAUDE.md "Tests that cannot fail": assume one cannot fail and find it — break the behaviour each important test names and see whether it fails. Look for self-referential fixtures, tests of a neighbouring function, tables where one row is exercised. Is every behaviour rule the phase touches covered? ${TESTS} Severity blocker/major/minor. Change no files.` },
    { key: 'conformance', prompt: `Audit Phase ${PHASE} (harnessing) of ${REPO} against CLAUDE.md's prime directive and invariants and the plan. For EACH task: quote the requirement, say met / partly / unmet with evidence. Where code or prose disagrees with the authority, the authority wins. Severity blocker/major/minor. Change no files.` },
  ],
  production: [
    { key: 'seams', prompt: `Review Phase ${PHASE} of ${REPO} against CLAUDE.md "Architecture seams": anything forcing a refactor later, types leaking across a seam, platform code outside its seam. Severity blocker/major/minor. Change no files.` },
    { key: 'tests', prompt: `Review the tests added in Phase ${PHASE} of ${REPO}: assume one cannot fail and find it by mutation. ${TESTS} Severity blocker/major/minor. Change no files.` },
    { key: 'robustness', prompt: `Review Phase ${PHASE} of ${REPO} for crash paths, unchecked indexing and casts, unbounded growth, unactionable errors, diagnostics reaching the output channel, secrets in logs. file:line each. Severity blocker/major/minor. Change no files.` },
    { key: 'conformance', prompt: `Audit Phase ${PHASE} of ${REPO} against the prime directive, invariants and plan: each task met / partly / unmet with evidence. Severity blocker/major/minor. Change no files.` },
  ],
}[MODE]

phase('Review')
const reviewed = await parallel(LENSES.map(l => () => agent(l.prompt, { label: `review:${l.key}`, phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high' })))
const lensesLost = LENSES.filter((_, i) => !reviewed[i]).map(l => l.key)
let findings = reviewed.filter(Boolean).flatMap(r => r.findings || [])
if (MODE === 'production') {
  const critic = await agent(`You are the completeness critic for Phase ${PHASE} of ${REPO}. Findings so far:\n${JSON.stringify(findings, null, 2)}\nComprehensive test passed: ${phaseTest.pass}; problems: ${JSON.stringify(phaseTest.problems)}\nFind what everyone MISSED — a requirement nobody verified, a file nobody read, a decision that will bite, a wrong claim above, a check the scripts should now make. Only NEW findings. Severity blocker/major/minor. Change no files.`, { label: 'review:completeness', phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high' })
  if (!critic) lensesLost.push('completeness')
  findings = findings.concat((critic && critic.findings) || [])
}
if (lensesLost.length) return paused('review', `review lens(es) did not report: ${lensesLost.join(', ')} — their findings are unknown, not absent. Re-run them on resume.`)
const blockers = findings.filter(f => String(f.severity).toLowerCase() === 'blocker')

phase('Triage')
let triage = null
if (observations.length || findings.length) {
  triage = await agent(`Triage what Phase ${PHASE} of ${REPO} turned up but did not act on.

Observations (${observations.length}):\n${JSON.stringify(observations, null, 2)}
Review findings (${findings.length}):\n${JSON.stringify(findings, null, 2)}

1. Check each against the repository NOW; drop what is already fixed, and count them. Merge duplicates.
2. Defects or improvements in what was built → one line each in docs/BACKLOG.md under "## Phase ${PHASE}": severity, file/symbol, what is wrong, the later task that should settle it.
3. Features or hardening not built → docs/FEATURES.md entries (Disposition: proposed, or mode: harnessing/production for skipped hardening).
4. Blockers are NOT triaged — list them in your summary; they become remediation tasks.
Commit once: "P${PHASE}: triage the phase review" with the trailer. Fix nothing else. Return counts: in, dropped as fixed, merged, landed in each file.`, { label: 'triage', phase: 'Triage', effort: 'medium' })
  if (!triage) return paused('triage', 'the triage agent returned nothing — re-run it on resume')
}

return {
  phase: PHASE,
  mode: MODE,
  completed: done,
  questions,
  features,
  phaseTest,
  findings,
  blockers,
  triage,
  gatePassed: !!phaseTest.pass && blockers.length === 0,
  next: phaseTest.pass && blockers.length === 0
    ? 'Owner: answer open questions and dispose of proposed features (gate skill, step 4), then push.'
    : 'Blockers become remediation tasks in this phase; prepare and implement them, then re-run the gate.',
}
