# Handoff — TASK-0001 Road surface continuity

## Work packages

- `docs/agent-work/work-packages/ENG-0001-road-surface-continuity.md` — deduplicate cell copies and dissolve eligible runtime render geometry; remediate road surfaces, per-frame projection reuse, label halo, and regression tests.
- `docs/agent-work/work-packages/VAL-0001-road-surface-continuity-validation.md` — independently validate geometry merging, tests, analysis, build, and painter invariants.

## Sequence

1. Engineering inspects map data loading, geometry merger, builder, painter, and tests; implements runtime-only deduplication/dissolve plus approved continuity changes and adds specified regression cases. Merge only uniquely connected ways with matching style/name and normalized endpoints plus compatible tangents/directions; preserve oneway and leave ambiguous branches untouched. Include two one-way named roundabout arcs closing despite a differently named access branch.
2. Engineering reports changed files and command evidence to validation.
3. Validation runs VAL-0001 recipe against completed remediation and reports results and environment limitations.

Use `docs/superpowers/specs/2026-10-19-road-surface-continuity-design.md` as shared source of truth. Runtime dissolve must affect derived render geometry only. Preserve approved polygon-buffer scope, existing class batching and painter order, source cell records, OSM schema/assets, road widths, colors, bridge/tunnel treatment, layer order, navigation, and unrelated behavior. Design is already approved; no design package or design/engineering integration contract is required. Do not regenerate assets.
