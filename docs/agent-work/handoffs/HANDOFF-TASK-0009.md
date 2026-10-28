# Handoff — TASK-0009 Road-Surface Names and Direction Arrows

## Package index

- Master Brief: `docs/agent-work/briefs/MASTER-BRIEF-TASK-0009.md`
- Code Analysis: `docs/agent-work/work-packages/CODE-0009-road-surface-root-cause.md`
- Shared Integration Contract: `docs/agent-work/work-packages/INT-0009-road-surface-analysis-engine-contract.md`
- Engineering: `docs/agent-work/work-packages/ENG-0009-road-surface-annotations.md`
- Validation: `docs/agent-work/work-packages/VAL-0009-road-surface-annotations-validation.md`
- Design: not assigned; approved spec fully specifies visual behavior.
- Integration is required for the Code Analysis → Engineering gate and engine/Flutter Scene seam; see INT-0009.

## Handoff sequence

1. Documentation Director returns this instruction pack and paths to the Orchestrator. Do not send raw user request to operational teams.
2. Orchestrator dispatches `CODE-0009` to Code Analysis Lead for read-only root-cause work and written correction/integration handoff. No source edits, README edits, or spec edits in this stage.
3. Engineering Lead may start `ENG-0009` only after the CODE-0009 report/handoff is returned. Follow INT-0009; preserve pre-existing worktree content. Route unresolved architecture/scope questions through Director/Orchestrator.
4. After implementation evidence, run `VAL-0009` through Quality/Performance validation. It validates only, returns failures to Engineering, and reruns affected checks after fixes.
5. Orchestrator dispatches Delivery Auditor after Engineering and Validation reports are complete. Auditor alone issues final delivery verdict.

## Shared acceptance and boundary reminders

- Preserve `RoadProperties.oneway` API and meaning: true means one permitted direction. `-1` is reverse/true; explicit roundabout `oneway=no` is both/false and intentionally overrides current blanket-roundabout true.
- Keep labels in 2D only; anchor 2D road candidates by cumulative path length.
- Use per-tile text atlases/annotation batches, upload-time generation, approximately 45 m arrows, 0.04 m surface offset, and 1,200 m maximum 3D LOD.
- Arrow and decal geometry both have no entity ID/retained CPU hit geometry and must not intercept raycasts or make base roads unselectable.
- No new package dependency. Do not reset, remove, or overwrite unrelated modified/deleted/untracked worktree content.
- Surface atlas/tile failure granularity, approximate tolerances, text fit/straightness, and LOD-distance basis; do not invent hidden thresholds.
- Evidence must include focused tests, formatter, `flutter analyze`, `flutter test`, available Linux debug build, and explicit unavailable checks. Validation is separate from final Delivery Auditor verdict.
- Work Package `status: approved` is compilation state required by the compiler contract, not a delivery verdict. Workflow remains in progress until the Orchestrator routes execution and the Delivery Auditor reports.
