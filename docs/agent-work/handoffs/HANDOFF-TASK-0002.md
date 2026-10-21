# Handoff — TASK-0002 Road width zoom stability

## Work packages

- `docs/agent-work/work-packages/ENG-0002-road-width-zoom-stability.md` — implement fixed per-class polygon widths at each class's z16 target and fixed 2.4px casing delta at every zoom; preserve adaptive railway `RoadWidths.width`, same-bucket cache behavior, and existing map invariants.
- `docs/agent-work/work-packages/VAL-0002-road-width-zoom-stability-validation.md` — independently verify all-class pixel conversions at z7/12/14/15/16/18/20, fixed casing, adaptive railway width, cache semantics, project checks, and representative rendering.

## Sequence

1. Engineering implements ENG-0002 in existing vector-road pipeline: at every zoom polygon widths equal per-class z16 targets and casing delta is 2.4px. Keep `RoadWidths.width` adaptive only for railway styling. Preserve class thresholds, hierarchy, filters, camera behavior, polygon geometry, assets/schema, colors, and other layers. Denser overview is explicitly approved. Add specified tests, update architecture documentation, and report changed paths and actual check results.
2. Validation executes VAL-0002 against completed changes. Record exact commands, outcomes, visual evidence, and limitations; return failures or gaps to engineering.

Use `docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md` as the approved source of truth. Engineering and validation only; no design package or design/engineering integration contract is required. Do not invoke operational sectors or the Delivery Auditor from this handoff.
