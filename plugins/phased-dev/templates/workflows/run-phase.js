export const meta = {
  name: 'run-phase',
  description: 'Implement one phase of docs/IMPLEMENTATION_PLAN.md: tasks or planned batches, each verified before the next, then the full-scale phase test, review and backlog triage',
  whenToUse: 'Run a phase of the plan. Args {phase: N}. Optional: {only: ["T1.3"]}, {groups: [["T2.1","T2.2"],["T2.3"]]}, {profile: "prototype"|"production"}, {repairRounds: n}, {skipReview: true}.',
  phases: [
    { title: 'Scope', detail: 'read the plan and extract this phase\'s tasks and batches' },
    { title: 'Implement' },
    { title: 'Verify' },
    { title: 'Repair' },
    { title: 'Recheck' },
    { title: 'Phase test' },
    { title: 'Review' },
    { title: 'Triage' },
  ],
}

// ---------------------------------------------------------------------------
// Generalised from the maestro-enjoy run-phase workflow. Every rule in the
// prompts below was bought by a measured failure there; see the phased-dev
// plugin's skills/method/references/lessons.md for the numbers.
//
// Profiles
//   production  one agent per task (or per planned group), adversarial
//               verification with mutation proof of every test, up to 3
//               repair rounds, a four-lens review panel plus a critic.
//   prototype   the plan's Batches table drives execution: ONE agent implements
//               a whole batch and commits it once, ONE verifier proves the
//               batch's central claims by mutation, ONE repair round, then a
//               single combined review. Parked features go to OUT_OF_SCOPE.md.
// ---------------------------------------------------------------------------

const REPO = (args && args.repo) || '.'
const PHASE = (args && args.phase) != null ? String(args.phase) : null
const PROFILE = (args && args.profile) || 'production'
const PROTO = PROFILE === 'prototype'
const MAX_REPAIRS = (args && args.repairRounds) || (PROTO ? 1 : 3)
const ONLY = (args && args.only && args.only.length) ? args.only : null
let GROUPS = (args && args.groups && args.groups.length) ? args.groups : null

if (PHASE == null) throw new Error('run-phase needs args {phase: N}')

const SCOPE_SCHEMA = {
  type: 'object',
  properties: {
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          slug: { type: 'string' },
          spec: { type: 'string', description: 'the plan requirement quoted verbatim, plus context the implementer needs' },
          smallScale: { type: 'string', description: 'the small-scale test this task must ship, naming its test target' },
        },
        required: ['id', 'slug', 'spec', 'smallScale'],
      },
    },
    batches: { type: 'array', items: { type: 'array', items: { type: 'string' } }, description: "the plan's Batches table for this phase, as lists of task ids; empty if the plan has none" },
    phaseExit: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['tasks', 'phaseExit'],
}
const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    completed: { type: 'boolean' },
    summary: { type: 'string' },
    small_scale_test: { type: 'string' },
    parked: { type: 'array', items: { type: 'string' }, description: 'OOS ids added to docs/OUT_OF_SCOPE.md' },
    blocker: { type: 'string' },
  },
  required: ['completed', 'summary'],
}
const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' }, description: 'reproduced defects only' },
    observations: { type: 'array', items: { type: 'string' }, description: 'judgement calls; must NOT fail the task' },
    evidence: { type: 'string' },
  },
  required: ['pass', 'problems', 'evidence'],
}
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

// --- Shared prose: name the CLAUDE.md rule, do not restate it ---------------

const READ_ONLY = `## Read-only
The work is committed on \`main\`. Do NOT run git checkout, switch, merge, reset,
commit, stash or rebase. Inspect with git log/show/diff. If you make a scratch
edit to prove a point, REVERT it and confirm \`git status --porcelain\` is empty.`

const PASS_FAIL = `## pass/fail
pass=false ONLY for a defect you reproduced: an unmet requirement, a hollow test,
a wrong behaviour, a sentence of prose the code contradicts. Judgement calls go
in \`observations\` and must NOT fail the task; they are triaged into
docs/BACKLOG.md, so write each so it makes sense to someone who never saw this
task. Every problem needs file:line and the exact command that reproduces it.`

const TEST_DISCIPLINE = `## Running tests
Mutation proof needs the one test being mutated, not the suite. Run the whole
suite ONCE at the end. Determinism re-runs happen at the phase gate only.`

const MUTATION = `CLAUDE.md, "Tests that cannot fail", is binding. For every test: could it
still pass if the behaviour it names were broken? Prove the answer — break the
*implementation* at the exact construct the test names, run that one test, watch
it fail, REVERT, confirm a clean tree. Check fixtures for the self-referential
shape: input built from the constant under test cannot fail.`

const MUTATION_PROTO = `CLAUDE.md, "Tests that cannot fail", is binding for every claim the prototype
makes. You do not need to mutation-prove every test. For each task, find the
ONE assertion the task's claim rests on, break the implementation behind it,
run that one test, watch it fail, REVERT. A central claim that survives mutation
is a defect whatever the test count says.`

const SCOPE_RULE = `## Scope (prototype)
CLAUDE.md, *Profile*: features outside the question in docs/CONCEPT.md are
parked, not built and not dropped. If one comes up, add an OOS entry to
docs/OUT_OF_SCOPE.md, make the code refuse or visibly skip it if input can reach
it, and continue. Hardening you deliberately skip (fuzzing, malformed-input
suites, polish) is one line under *Deferred hardening*. Never park something the
task's own requirement asks for — that is reducing scope, and it is a stop.`

const subject = ids => `${ids.join(', ')}: <short description>`

function implPrompt(group, notes, prior) {
  const ids = group.map(t => t.id)
  const one = group.length === 1
  return `You are implementing ${one ? `task ${ids[0]}` : `batch ${ids.join(' + ')} (${group.length} tasks, implemented together and committed once)`} in the repository at ${REPO}.

Read CLAUDE.md and docs/IMPLEMENTATION_PLAN.md first. The working agreement and the prime directive are binding.

## ${one ? 'The task' : 'The tasks'}

${group.map(t => `### ${t.id} — ${t.slug}\n${t.spec}\n\n**Small-scale test:** ${t.smallScale}`).join('\n\n')}

${notes ? `## About this phase\n\n${notes}\n` : ''}
## Already done in this phase

${prior.length ? prior.map(s => '- ' + s).join('\n') : '- nothing yet'}

## Process

1. Confirm \`main\` is clean and green (\`scripts/task-audit.sh\` needs a commit, so run the CHECKS from scripts/method.conf). A red tree you inherited is a stop, not yours to paper over.
2. Implement. Real code, no placeholders.
3. Tests in the same commit. **Fixtures are literal data, never the constant under test.** A new table of magic numbers gets one test pinning each value to a literal with its citation. ${PROTO || !one ? 'You are NOT required to mutation-prove every test here: an independent verifier does that next. Say in your summary which single assertion matters most per task and what would break it.' : MUTATION}
4. Tick ${one ? `the ${ids[0]} checkbox` : `the checkboxes of ${ids.join(', ')}`} (☐ → ☑) in docs/IMPLEMENTATION_PLAN.md — those lines and no other. A sed on T1.1 also rewrites T1.10; check the diff.
5. Commit ONCE on \`main\` with subject "${subject(ids)}" and the Co-Authored-By trailer.
6. Run \`scripts/task-audit.sh <id>\` for ${one ? 'the task' : 'each task'}. It must exit 0. Fix with a further commit carrying the same subject prefix.
7. STOP.

${PROTO ? SCOPE_RULE : ''}

${TEST_DISCIPLINE}

## Hard rules
- Do not push, rebase, amend or force-push. Do not touch the protected paths in scripts/method.conf.
- If you cannot complete the work, STOP: no weakened test, no stubbed requirement, no red commit. Return completed=false with the exact failure output and your diagnosis.`
}

function verifyPrompt(group, summaries) {
  const ids = group.map(t => t.id)
  return `Adversarially verify ${ids.join(', ')} in ${REPO}, committed on \`main\`. Assume the work does NOT meet its specification until the evidence forces the opposite.

${READ_ONLY}

## First, the mechanical audit
\`\`\`
${ids.map(id => `scripts/task-audit.sh ${id}`).join('\n')}
\`\`\`
Every FAIL line is a problem, copied verbatim with its task id. Do not re-check by hand what the script checks.

## The specifications
${group.map(t => `### ${t.id}\n${t.spec}\n\n**Small-scale test:** ${t.smallScale}`).join('\n\n')}

## What the implementer reported
${summaries.map(s => `- ${s}`).join('\n')}

## What to check
- Is every requirement genuinely implemented, or stubbed, partial, or quietly narrowed? Quote the requirement, then the code.
- ${PROTO ? MUTATION_PROTO : MUTATION}
- Run the real program on the real data. Hunt for an input that produces a wrong result; report the invocation.
- Does any prose the work added (help, doc comments, docs/*.md) claim something the code does not do?
${group.length > 1 ? '- Between the tasks: a helper one added and another works around; a requirement each assumed the other covered.' : ''}
${PROTO ? '- Was anything parked in docs/OUT_OF_SCOPE.md that the requirement itself asks for? That is scope reduction, and it is a problem. Does input that reaches a parked feature get refused or visibly skipped, rather than a plausible wrong result?' : ''}

${TEST_DISCIPLINE}

${PASS_FAIL}
Attribute every problem to a task id.`
}

function repairPrompt(ids, problems, round) {
  return `${ids.join(', ')} in ${REPO} is committed on \`main\` and verification found real problems. Fix them with a further commit (repair round ${round}).

${problems.map((p, i) => `${i + 1}. ${p}`).join('\n')}

For each: fix it, then prove the fix — break the behaviour again, watch the specific test fail, revert. If no test would have caught it, add one in the same commit.
Run scripts/task-audit.sh for each id, and commit with subject exactly "${subject(ids)}" plus the trailer — the id list is how the audit knows which tasks a commit belongs to.
Never fix a problem by weakening the test that exposes it, and prefer fixing behaviour over rewording the prose that describes it. If a problem is not real, say so with evidence instead of changing code to appease it.

${TEST_DISCIPLINE}`
}

function recheckPrompt(ids, problems, round) {
  return `${ids.join(', ')} in ${REPO} was repaired (round ${round}). Decide whether the repair worked. Assume it did not.

${READ_ONLY}

## The problems it was supposed to fix
${problems.map((p, i) => `${i + 1}. ${p}`).join('\n')}

1. Run scripts/task-audit.sh for each id; every FAIL line is a problem.
2. For EACH problem: reproduce the original failure against the code as it stands. It must no longer reproduce. A problem "fixed" by rewording, deleting a test or narrowing an assertion is not fixed.
3. For each: break the fix, run the covering test, watch it fail, revert.
4. Read the repair diff only and judge whether it broke a neighbour.
Do NOT re-derive the whole task.

${PASS_FAIL}`
}

// ---------------------------------------------------------------------------

log(`Phase ${PHASE} (${PROFILE}): reading the plan.`)
phase('Scope')

let scope
if (args && args.tasks) {
  scope = { tasks: args.tasks, batches: [], phaseExit: args.phaseExit || '(supplied by caller)', notes: args.notes || '' }
} else {
  const skipRule = ONLY
    ? `Return EXACTLY these tasks: ${ONLY.join(', ')}, even if already ticked ☑ — the caller named them.`
    : 'Skip tasks already marked ☑.'
  scope = await agent(`Read ${REPO}/docs/IMPLEMENTATION_PLAN.md and extract what is needed to execute **Phase ${PHASE}**.

For each task, in plan order: id; slug; spec — the requirement QUOTED VERBATIM plus any context the implementer needs from elsewhere (a CLAUDE.md invariant, a settled decision, the state of the code it extends — read src/ so it extends rather than duplicates); smallScale — the test that would FAIL if the behaviour were broken, naming its test target.

Also: phaseExit (quoted); notes — the phase's Readiness section, shared traps, dependencies it adds; batches — the phase's Batches table as lists of task ids (empty if none).

${skipRule}`, { label: `scope:P${PHASE}`, phase: 'Scope', schema: SCOPE_SCHEMA, effort: 'high' })
  if (!scope || !scope.tasks || !scope.tasks.length) {
    return { phase: PHASE, blocked: { stage: 'scope', detail: 'no tasks extracted — wrong phase, or all done?' } }
  }
}

let tasks = scope.tasks
if (ONLY) {
  tasks = tasks.filter(t => ONLY.includes(t.id))
  const missing = ONLY.filter(id => !tasks.some(t => t.id === id))
  if (missing.length) return { phase: PHASE, blocked: { stage: 'scope', detail: `only named tasks the scope agent did not return: ${missing.join(', ')}` } }
}

if (!GROUPS && scope.batches && scope.batches.length) GROUPS = scope.batches
// Tasks the caller supplied by hand were chosen together, so under prototype
// they are one batch unless the caller grouped them otherwise.
if (!GROUPS && PROTO && args && args.tasks) GROUPS = [tasks.map(t => t.id)]
if (PROTO && !GROUPS) {
  // Batching is planned, not improvised: a prototype phase without a Batches
  // table is a planning gap, and running it per task is the expensive default.
  return { phase: PHASE, blocked: { stage: 'scope', detail: 'prototype profile but the plan has no Batches table for this phase — run the plan skill first, or pass args.groups' } }
}
const runGroups = GROUPS
  ? GROUPS.map(ids => tasks.filter(t => ids.includes(t.id))).filter(g => g.length)
  : tasks.map(t => [t])
if (GROUPS) {
  const placed = new Set(runGroups.flat().map(t => t.id))
  const orphans = tasks.filter(t => !placed.has(t.id)).map(t => t.id)
  if (orphans.length) return { phase: PHASE, blocked: { stage: 'scope', detail: `tasks in no batch would be silently skipped: ${orphans.join(', ')}` } }
}
log(`${runGroups.length} unit(s): ${runGroups.map(g => g.map(t => t.id).join('+')).join(' | ')}`)

const done = []
const prior = []
const observations = []
const parked = []
let blocked = null

for (const group of runGroups) {
  const ids = group.map(t => t.id)
  const label = ids.join('+')

  // Production with groups keeps one implementer per task (a verifier then takes
  // the group); prototype hands the whole batch to one implementer, because the
  // context read is the cost being amortised.
  const implUnits = PROTO ? [group] : group.map(t => [t])
  const summaries = []
  for (const unit of implUnits) {
    phase('Implement')
    const impl = await agent(implPrompt(unit, scope.notes, prior), { label: `impl:${unit.map(t => t.id).join('+')}`, phase: 'Implement', schema: IMPL_SCHEMA })
    if (!impl || !impl.completed) {
      blocked = { task: unit.map(t => t.id).join(', '), stage: 'implement', detail: (impl && (impl.blocker || impl.summary)) || 'implementer returned nothing' }
      break
    }
    summaries.push(`${unit.map(t => t.id).join(', ')}: ${impl.summary}`)
    prior.push(`${unit.map(t => t.id).join(', ')}: ${impl.summary}`)
    ;(impl.parked || []).forEach(p => parked.push(p))
  }
  if (blocked) break

  // A null verdict is a dead verifier, and a dead verifier is not a pass.
  const record = v => v && (v.observations || []).forEach(o => observations.push(`${label}: ${o}`))
  let verdict = await agent(verifyPrompt(group, summaries), { label: `verify:${label}`, phase: 'Verify', schema: VERDICT_SCHEMA, effort: 'high' })
  record(verdict)
  if (!verdict) { blocked = { task: label, stage: 'verify', detail: `verifier died: ${label} is committed and UNVERIFIED. Re-run with only: [${ids.map(i => `"${i}"`).join(', ')}]` }; break }

  let round = 0
  let problems = verdict.pass ? [] : verdict.problems
  while (problems.length && round < MAX_REPAIRS) {
    round++
    const repair = await agent(repairPrompt(ids, problems, round), { label: `repair${round}:${label}`, phase: 'Repair', schema: IMPL_SCHEMA })
    if (!repair || !repair.completed) { blocked = { task: label, stage: `repair ${round}`, detail: (repair && repair.blocker) || 'repair returned nothing', problems }; break }
    verdict = await agent(recheckPrompt(ids, problems, round), { label: `recheck${round}:${label}`, phase: 'Recheck', schema: VERDICT_SCHEMA, effort: 'high' })
    record(verdict)
    if (!verdict) { blocked = { task: label, stage: `recheck ${round}`, detail: 'recheck died; repair UNCONFIRMED', problems }; break }
    problems = verdict.pass ? [] : verdict.problems
  }
  if (blocked) break
  if (problems.length) { blocked = { task: label, stage: 'verify', detail: `problems survived ${round} repair round(s)`, problems }; break }
  ids.forEach(id => done.push({ id, repairRounds: round }))
  log(`${label} committed and verified (${round} repair round(s))`)
}

if (blocked) {
  log(`BLOCKED at ${blocked.task} during ${blocked.stage} — stopping, as the working agreement requires`)
  return { phase: PHASE, profile: PROFILE, blocked, completed: done, observations, parked }
}
if (args && args.skipReview) return { phase: PHASE, profile: PROFILE, blocked: null, completed: done, observations, parked, note: 'gate skipped' }

// --- The phase gate --------------------------------------------------------

phase('Phase test')
const phaseTest = await agent(`You are running the FULL-SCALE phase test for Phase ${PHASE} in ${REPO}. This is the gate before the phase is pushed; be hard to satisfy.

Run \`scripts/gate.sh ${PHASE}\`. Put its last 30 lines in gate_script verbatim. Every FAIL line is a problem. A missing phase gate script is itself a problem. Do not re-check by hand what it checked.

Spend your judgement on:
1. **The exit criterion**: ${scope.phaseExit}
   Test it against the REAL data, not a subset. Measure any performance claim. Compare with the authority the way CLAUDE.md says it can be compared.
2. **docs/DIVERGENCES.md is literally true**: run each claim.${PROTO ? '\n3. **docs/OUT_OF_SCOPE.md is honest**: for each parked entry, the program behaves as its "If reached" line says.' : ''}
Also report any check scripts/gate.sh could make and does not.

pass=false if anything fails. Put actual commands and real output in transcript. Fix nothing.`, { label: `phase-test:P${PHASE}`, phase: 'Phase test', schema: PHASE_TEST_SCHEMA, effort: 'high' })

const LENSES = PROTO
  ? [{ key: 'combined', prompt: `Review Phase ${PHASE} of ${REPO} (main) in one pass, proportionate to a prototype (CLAUDE.md, *Profile*). Change no files.
1. **Claims**: for each task, quote the requirement and say met / partially / unmet with evidence.
2. **Tests**: ${MUTATION_PROTO}
3. **Lies**: any path where the output could be a plausible wrong result instead of a refusal or visible skip — the one robustness property a prototype keeps.
4. **Scope**: anything built that is out of the question in docs/CONCEPT.md (should have been parked), and anything parked that the question needs.
5. **Seams**: anything that would force a rewrite, not an extension, at graduation.
Severity blocker/major/minor.` }]
  : [
      { key: 'seams', prompt: `Review Phase ${PHASE} of ${REPO} (main) against CLAUDE.md "Architecture seams": anything forcing a refactor when a later seam arrives, types leaking across a seam, platform code outside its seam. Severity blocker/major/minor. Change no files.` },
      { key: 'tests', prompt: `Review the QUALITY of every test added in Phase ${PHASE} of ${REPO} (main). ${MUTATION} Assume there is a hollow one you have not found. Look for tests that drive a neighbouring function rather than the one they name, and positional tables where one row is exercised. ${TEST_DISCIPLINE} Severity blocker/major/minor.` },
      { key: 'robustness', prompt: `Review Phase ${PHASE} of ${REPO} (main) for the no-crash rule, unchecked indexing and casts, unbounded growth, unactionable errors, and any path where a diagnostic reaches the output channel. scripts/gate.sh already threw its inputs; find the one it does not. file:line each. Severity blocker/major/minor. Change no files.` },
      { key: 'conformance', prompt: `Audit Phase ${PHASE} of ${REPO} (main) against the prime directive and invariants in CLAUDE.md and the plan. For EACH task quote the requirement and state met / partially / unmet with evidence. Where code or prose disagrees with the authority, the authority wins. Severity blocker/major/minor. Change no files.` },
    ]

phase('Review')
const reviewed = await parallel(LENSES.map(l => () => agent(l.prompt, { label: `review:${l.key}`, phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high' })))
const lensesLost = LENSES.filter((_, i) => !reviewed[i]).map(l => l.key)
let findings = reviewed.filter(Boolean).flatMap(r => r.findings || [])

if (!PROTO) {
  const critic = await agent(`You are the completeness critic for Phase ${PHASE} of ${REPO}. Findings so far:\n${JSON.stringify(findings, null, 2)}\nPhase test passed: ${phaseTest ? phaseTest.pass : 'unknown'}; its problems: ${JSON.stringify(phaseTest ? phaseTest.problems : [])}\n\nFind what they all MISSED: a requirement nobody verified, a file nobody read, a decision that will bite later, a claim above that is wrong, a check scripts/gate.sh or scripts/task-audit.sh should now make. Check the repository yourself. Report only NEW findings. Severity blocker/major/minor. Change no files.`, { label: 'review:completeness', phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high' })
  if (!critic) lensesLost.push('completeness')
  findings = findings.concat((critic && critic.findings) || [])
}
const blockers = findings.filter(f => String(f.severity).toLowerCase() === 'blocker')

phase('Triage')
let backlog = null
if (observations.length || findings.length) {
  backlog = await agent(`Triage what Phase ${PHASE} of ${REPO} turned up but did not act on.

Observations (${observations.length}):\n${JSON.stringify(observations, null, 2)}
Review findings (${findings.length}):\n${JSON.stringify(findings, null, 2)}

1. Check each against the repository NOW; drop what a later task already fixed, and count them.
2. Drop duplicates, merge near-duplicates.
3. Survivors that are defects or improvements in what was built: one line each in docs/BACKLOG.md under "## Phase ${PHASE}" — severity, file/symbol, what is wrong, the later task that should settle it.${PROTO ? '\n4. Survivors that are features or hardening outside the prototype\'s question: an entry in docs/OUT_OF_SCOPE.md instead, not the backlog.' : ''}
Commit once with subject "P${PHASE}: triage the phase review" and the trailer. Fix nothing; change no other file. Return counts: in, dropped as fixed, dropped as duplicate, landed.`, { label: 'triage', phase: 'Triage', effort: 'medium' })
}

return {
  phase: PHASE,
  profile: PROFILE,
  blocked: null,
  completed: done,
  parked,
  observations,
  phaseTest,
  findings,
  blockers,
  backlog,
  lensesLost,
  // A panel with a missing lens has unknown findings, not absent ones.
  gatePassed: !!(phaseTest && phaseTest.pass) && blockers.length === 0 && lensesLost.length === 0,
}
