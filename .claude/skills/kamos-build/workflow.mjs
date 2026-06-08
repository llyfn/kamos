// kamos-build — Workflow-script form.
//
// Deterministic phase gating + parallel per-layer QA + schema-validated
// outputs. Equivalent in shape to SKILL.md's TeamCreate/Agent prose but
// runs through the Workflow tool: resumable, journaled, typed outputs.
//
// Invocation:
//   Workflow({
//     scriptPath: ".claude/skills/kamos-build/workflow.mjs",
//     args: {
//       feature: "tasting-flight",
//       sequenceNumber: "021",
//       layers: { design: true, schema: true, api: true, admin: false,
//                 flutter: true, i18n: true }
//     }
//   })
//
// On resume: same args → cached agent results; phase gating still
// deterministic.

export const meta = {
  name: 'kamos-build',
  description: 'Drive one KAMOS feature through every layer it touches',
  phases: [
    { title: 'Design',        detail: 'designer extends design/ + HANDOFF.md addendum' },
    { title: 'Schema + API',  detail: 'db-architect, backend-engineer (+ admin slice) in parallel; QA fires per slice' },
    { title: 'Frontend',      detail: 'flutter-engineer; QA fires on slice completion' },
    { title: 'Final QA',      detail: 'qa-inspector final mode + test-runner gates' },
    { title: 'Doc sync',      detail: 'doc-keeper syncs CLAUDE.md / SPEC.md / runbooks' },
  ],
}

// ---------------------------------------------------------------------------
// Schemas for typed agent outputs. Workflow validates these at tool-call
// time and retries the agent on mismatch.
// ---------------------------------------------------------------------------

const QA_FINDING_SCHEMA = {
  type: 'object',
  required: ['status', 'findings', 'invariants'],
  properties: {
    status: { enum: ['PASS', 'PASS WITH MINOR', 'FAIL'] },
    reportPath: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'severity', 'title'],
        properties: {
          id: { type: 'string' },                      // e.g. QA-014
          severity: { enum: ['BLOCKER', 'MAJOR', 'MINOR'] },
          invariant: { type: 'string' },               // e.g. invariant:jwt-storage
          boundary: { type: 'string' },                // file:line ↔ file:line
          title: { type: 'string' },
          problem: { type: 'string' },
          fix: { type: 'string' },                     // owner-prefixed instruction
          ownerAgent: { enum: [
            'designer', 'db-architect', 'backend-engineer',
            'flutter-engineer', 'i18n-curator', 'orchestrator',
          ] },
        },
      },
    },
    invariants: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'status'],
        properties: {
          id: { type: 'string' },                      // invariant:jwt-storage
          status: { enum: ['PASS', 'FAIL', 'N/A'] },
          notes: { type: 'string' },
        },
      },
    },
  },
}

const IMPL_DONE_SCHEMA = {
  type: 'object',
  required: ['layer', 'changedPaths'],
  properties: {
    layer: { enum: ['design', 'db', 'api', 'admin', 'flutter'] },
    changedPaths: { type: 'array', items: { type: 'string' } },
    openApiDelta: { type: 'string' },                  // backend-engineer only
    migrationsAdded: { type: 'array', items: { type: 'string' } }, // db only
    arbKeysAdded: { type: 'array', items: { type: 'string' } },    // flutter only
    notes: { type: 'string' },
  },
}

const VERIFY_REPORT_SCHEMA = {
  type: 'object',
  required: ['result', 'gates'],
  properties: {
    result: { enum: ['PASS', 'FAIL', 'BLOCKED'] },
    gates: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'status'],
        properties: {
          name: { type: 'string' },
          status: { enum: ['PASS', 'FAIL', 'SKIPPED', 'BLOCKED'] },
          durationSeconds: { type: 'number' },
          excerpt: { type: 'string' },
        },
      },
    },
    reportPath: { type: 'string' },
  },
}

// ---------------------------------------------------------------------------
// Inputs (validated up front; the orchestrator agent is responsible for
// confirming scope with the user before calling Workflow).
// ---------------------------------------------------------------------------

const {
  feature,
  sequenceNumber,
  layers = { design: true, schema: true, api: true, admin: false, flutter: true, i18n: true },
} = args || {}

if (!feature || !sequenceNumber) {
  throw new Error('kamos-build workflow requires args.feature and args.sequenceNumber')
}

const featureDir = `docs/history/${sequenceNumber}_${feature}`
const briefPath = `${featureDir}/00_brief.md`
const qaDir = `${featureDir}/qa`

const promptFor = (templatePath) => `Follow the spawn template at ${templatePath}. Feature: ${feature}. Brief: ${briefPath}. QA dir: ${qaDir}.`

// ---------------------------------------------------------------------------
// PHASE 1 — Design
// ---------------------------------------------------------------------------
phase('Design')

if (layers.design) {
  const designerImpl = await agent(
    promptFor('.claude/skills/kamos-build/prompts/designer.md'),
    { label: 'design:implement', agentType: 'designer', schema: IMPL_DONE_SCHEMA },
  )
  if (!designerImpl) {
    throw new Error('designer returned null — user skipped or agent failed')
  }
  log(`design: ${designerImpl.changedPaths.length} paths changed`)

  const designQA = await agent(
    `${promptFor('.claude/skills/kamos-build/prompts/qa-inspector.md')} mode=incremental-design — verify HANDOFF.md addendum internal consistency, category-strings invariant, rating widget where shown.`,
    { label: 'design:qa', agentType: 'qa-inspector', schema: QA_FINDING_SCHEMA },
  )
  if (designQA?.status === 'FAIL') {
    log(`design QA FAIL — ${designQA.findings.filter(f => f.severity !== 'MINOR').length} non-MINOR findings`)
    // Fix round-trip is handled inline by the designer + qa-inspector via
    // SendMessage; we do not retry the whole agent here. If status is still
    // FAIL after their round-trip, the orchestrator halts and escalates.
    throw new Error('Phase 1 halted: design QA FAIL with unresolved BLOCKER/MAJOR')
  }
}

// ---------------------------------------------------------------------------
// PHASE 2 — Schema + API (+ admin)
//
// db-architect and backend-engineer run in parallel; backend stubs the
// repository until db-architect signals DB-ready via SendMessage. QA fires
// per slice the moment that slice's implementer returns.
// ---------------------------------------------------------------------------
phase('Schema + API')

const phase2Tasks = []

if (layers.schema) {
  phase2Tasks.push({
    label: 'db',
    promptPath: '.claude/skills/kamos-build/prompts/db-architect.md',
    agentType: 'db-architect',
    qaMode: null,        // schema QA folds into incremental-be
  })
}
if (layers.api) {
  phase2Tasks.push({
    label: 'api',
    promptPath: '.claude/skills/kamos-build/prompts/backend-engineer.md',
    agentType: 'backend-engineer',
    qaMode: 'incremental-be',
  })
}
if (layers.admin) {
  phase2Tasks.push({
    label: 'admin',
    promptPath: '.claude/skills/kamos-build/prompts/backend-engineer.md',
    agentType: 'backend-engineer',
    qaMode: 'incremental-admin',
  })
}

// pipeline() returns the last stage's result per item. For slices with no
// qaMode (db-architect — its QA folds into incremental-be), stage2 returns
// a synthetic PASS object so phase2Results uniformly carries QA-shape
// values. This keeps the FAIL filter and the MINOR count below safe.
const SYNTHETIC_QA_PASS = { status: 'PASS', findings: [], invariants: [] }

const phase2Results = await pipeline(
  phase2Tasks,
  (task) => agent(promptFor(task.promptPath), {
    label: task.label,
    phase: 'Schema + API',
    agentType: task.agentType,
    schema: IMPL_DONE_SCHEMA,
  }),
  (impl, task) => {
    if (!impl) return Promise.resolve(SYNTHETIC_QA_PASS)        // implementer was skipped/failed
    if (!task.qaMode) return Promise.resolve(SYNTHETIC_QA_PASS) // db slice — QA folds into incremental-be
    return agent(
      `${promptFor('.claude/skills/kamos-build/prompts/qa-inspector.md')} mode=${task.qaMode}`,
      { label: `qa:${task.label}`, phase: 'Schema + API', agentType: 'qa-inspector', schema: QA_FINDING_SCHEMA },
    )
  },
)

const phase2QAFailures = phase2Results
  .filter(Boolean)
  .filter((qa) => qa.status === 'FAIL')

if (phase2QAFailures.length) {
  throw new Error(`Phase 2 halted: ${phase2QAFailures.length} slice(s) QA FAIL with unresolved BLOCKER/MAJOR`)
}

// ---------------------------------------------------------------------------
// PHASE 3 — Frontend
// ---------------------------------------------------------------------------
phase('Frontend')

if (layers.flutter) {
  const flutterImpl = await agent(
    promptFor('.claude/skills/kamos-build/prompts/flutter-engineer.md'),
    { label: 'flutter:implement', agentType: 'flutter-engineer', schema: IMPL_DONE_SCHEMA },
  )
  if (!flutterImpl) throw new Error('flutter-engineer returned null')

  const flutterQA = await agent(
    `${promptFor('.claude/skills/kamos-build/prompts/qa-inspector.md')} mode=incremental-fe`,
    { label: 'flutter:qa', agentType: 'qa-inspector', schema: QA_FINDING_SCHEMA },
  )
  if (flutterQA?.status === 'FAIL') {
    throw new Error('Phase 3 halted: Flutter QA FAIL with unresolved BLOCKER/MAJOR')
  }
}

// ---------------------------------------------------------------------------
// PHASE 4 — Final QA + verification gates (parallel)
// ---------------------------------------------------------------------------
phase('Final QA')

const [finalQA, gates] = await Promise.all([
  agent(
    `${promptFor('.claude/skills/kamos-build/prompts/qa-inspector.md')} mode=final`,
    { label: 'qa:final', agentType: 'qa-inspector', schema: QA_FINDING_SCHEMA },
  ),
  agent(
    promptFor('.claude/skills/kamos-build/prompts/test-runner.md'),
    { label: 'verify:gates', agentType: 'test-runner', schema: VERIFY_REPORT_SCHEMA },
  ),
])

if (finalQA?.status === 'FAIL' || gates?.result === 'FAIL') {
  throw new Error('Phase 4 halted: final QA or verification gates FAIL')
}

// ---------------------------------------------------------------------------
// PHASE 5 — Doc sync
//
// doc-sync produces prose edits, not a structured object, so no schema is
// passed. The phase still gates final return: a thrown error here halts.
// ---------------------------------------------------------------------------
phase('Doc sync')

const docSync = await agent(
  `Use the doc-sync skill. Sync CLAUDE.md, SPEC.md, README, and any affected runbook against changes in feature ${feature}. Brief at ${briefPath}. Final QA report at ${qaDir}/qa_report_final.md.`,
  { label: 'doc-sync', agentType: 'doc-keeper' },
)

// ---------------------------------------------------------------------------
// Return summary
// ---------------------------------------------------------------------------
return {
  feature,
  sequenceNumber,
  featureDir,
  finalQAStatus: finalQA?.status,
  gatesResult: gates?.result,
  docsSynced: !!docSync,
  minorCount: [...(finalQA?.findings || []), ...phase2Results.filter(Boolean).flatMap(qa => qa.findings || [])]
    .filter(f => f.severity === 'MINOR').length,
}
