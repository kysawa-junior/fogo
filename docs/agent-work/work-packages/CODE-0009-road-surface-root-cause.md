---
id: CODE-0009
version: "1"
status: approved
source:
  user_request: "TASK-0009"
  orchestrator_task_id: TASK-0009
objective: "Produce evidence-backed root-cause analysis and correction/integration handoff before Engineering implements TASK-0009."
background: "Code analysis is required for existing oneway callers, roundabout explicit-no behavior, scene identity/raycast flow, current annotation LOD, and engine/Flutter Scene seam. Approved spec: docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md (commit 1e26dd6)."
scope:
  included:
    - "Read-only trace RoadProperties.oneway and callers in OSM mapping, road join/deduplication, vector cell data, and selection details."
    - "Read-only OSM mapping analysis for yes/no/-1, absent values, roundabout default, and explicit roundabout oneway=no."
    - "Trace MapSceneObject identity, road/marking creation, tile assignment, adapter nodes, raycast/picking, and retained hit data."
    - "Trace road-marking LOD and camera-distance basis against approved annotation maximum <=1,200 m."
    - "Trace MeshData UV support, FlutterSceneAdapter upload, and engine-to-adapter placement/atlas seam."
    - "Deliver a written root-cause report, minimal correction plan, open decisions, and explicit Engineering handoff."
  excluded:
    - "Any production/test source edits, implementation, refactoring, or edits to approved design spec."
    - "Editing README.md or any non-TASK-0009 document; README findings are report-only."
    - "Inventing tile/atlas failure, spacing/elevation tolerance, fit/straightness, or LOD-basis thresholds."
    - "Final delivery approval; Delivery Auditor remains distinct and runs after Engineering and Validation."
requirements:
  functional:
    - "Inventory each oneway caller and document actual behavior/API reliance with path:line evidence."
    - "Provide tag→direction→bool matrix: true means one permitted direction; yes and -1 are one-way; explicit roundabout no maps to both/false, intentionally overriding old blanket-roundabout true."
    - "Explain how required MapSceneObject.entityId and adapter picking flow interact with no-ID/no-retained-hit-geometry annotation requirement."
    - "Record current road-marking LOD including 3,500 m and trace measured camera-distance basis versus approved <=1,200 m annotation LOD."
    - "Trace engine placement, tile assignment, adapter UV/material upload, current UV omission, and raycast behavior for arrows and decals."
    - "Classify root causes versus symptoms, cite observed behavior and source lines, and return a minimal correction/integration handoff to ENG-0009."
    - "List unresolved atlas edge/failure granularity, ~45 m/~0.04 m tolerances, text fit/straightness threshold, and LOD distance basis without choosing values."
  non_functional:
    - "Report-only and read-only on source; no code changes or worktree cleanup."
    - "Separate observed facts, root causes, correction proposals, and open decisions."
    - "Preserve unrelated modified, deleted, and untracked worktree content."
constraints:
  technical:
    - "Approved design spec is behavior authority; explicit roundabout oneway=no means both and legacy bool false."
    - "Engineering must not implement analyzed concerns until the written root-cause/correction/integration handoff returns."
    - "Read-only focused tests may be run if required to establish a caller; do not modify tests or source."
  architectural:
    - "Engine owns OSM parsing/road geometry/engine-independent placement; adapter owns Flutter text rasterization, atlas textures, and Flutter Scene materials."
    - "Do not prescribe entity identity or retained CPU hit data for annotations; both arrow and decal geometry must pass raycasts through."
    - "Do not invent a sentinel entityId to work around MapSceneObject's required field; report evidence-backed options."
  visual:
    - "No redesign; approved spec is visual source of truth. README's stale overlay statement is not authorized for editing."
  business:
    - "No new dependency or scope expansion."
dependencies:
  agents:
    - "code-analysis-lead"
    - "engineering-lead"
  work_packages: []
  modules:
    - "Road OSM mapping and bool callers"
    - "MapScene identity, tile assignment, LOD, and selection"
    - "Flutter Scene adapter geometry/material upload and raycasts"
assigned_agents:
  - "code-analysis-lead"
affected_areas:
  modules:
    - "oneway API and consumers"
    - "OSM direction mapping including roundabout explicit-no override"
    - "scene identity, tile ownership, LOD, and picking"
    - "MeshData UV and FlutterSceneAdapter integration seam"
  packages: []
  files:
    - "lib/engine/domain/road_properties.dart"
    - "lib/engine/osm/osm_feature_mapper.dart"
    - "lib/features/map/vector/road_geometry_merger/road_join.dart"
    - "lib/features/map/vector/road_geometry_merger/road_deduplication.dart"
    - "lib/features/map/vector/vector_data/features.dart"
    - "lib/features/map/vector/vector_data/cell_data.dart"
    - "lib/features/map/presentation/selection_details.dart"
    - "lib/engine/scene/map_scene.dart"
    - "lib/engine/fogo_engine.dart"
    - "lib/engine/scene/lod_policy.dart"
    - "lib/engine/scene/camera_controller.dart"
    - "lib/features/map/presentation/render/flutter_scene_adapter.dart"
    - "lib/features/map/presentation/render/fogo_scene_view.dart"
    - "lib/engine/geometry/mesh_data.dart"
    - "lib/features/map/presentation/render/label_candidates.dart"
    - "README.md (read-only finding only)"
protected_areas:
  modules:
    - "All repository source/tests/spec/README/existing docs read-only during Code Analysis."
    - "All pre-existing modified, deleted, and untracked worktree content."
  files:
    - "docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md"
    - "README.md and all non-TASK-0009 documents"
    - "All pre-task modified/deleted/untracked files; no edit, reset, removal, or overwrite."
deliverables:
  - "Report at docs/agent-work/reviews/CODE-0009-road-surface-root-cause.md with finding ID, severity/impact, root cause versus symptom, observed behavior, and path:line evidence."
  - "Complete one-way tag/direction/bool matrix and explicit roundabout-no caller impact."
  - "Scene identity/raycast trace for arrow/decal nodes, including required MapSceneObject.entityId and adapter node maps."
  - "Current LOD/distance trace and exact engine/adapter UV/tile/atlas seam."
  - "Minimal correction plan and integration handoff to Engineering, mapped to ENG-0009 criteria."
  - "Open-decision list; do not invent thresholds or edit README/spec."
acceptance_criteria:
  - "Every in-scope behavior has source path:line evidence and root-cause/symptom classification."
  - "Every root-cause finding carries severity/impact and maps to a minimal correction recommendation."
  - "Every oneway caller is listed; true means one permitted direction; yes=true/forward, -1=true/reverse, explicit roundabout no=false/both despite old blanket-roundabout true."
  - "Report explains required entityId, adapter node identity, retained hit geometry, and raycast implications for visual-only annotations."
  - "Report documents current roadMarking 3,500 m LOD and approved <=1,200 m annotation LOD without changing unrelated marking policy."
  - "Report traces 2D midpoint/UV omission and recommends minimum engine/adapter correction."
  - "Atlas failure, tile edge, approximate tolerances, fit/straightness, and LOD basis are surfaced as unresolved."
  - "No source edits; Engineering is explicitly gated on returned handoff."
testing_requirements:
  - "Use direct reads/search for source evidence and cite exact paths/lines."
  - "Run existing focused tests read-only only when needed; record actual commands/results."
  - "No source-mutating formatter/build and no new tests in this report-only stage."
documentation_requirements:
  - "Write only docs/agent-work/reviews/CODE-0009-road-surface-root-cause.md as the analysis report."
  - "Return report and correction/integration handoff to Orchestrator; do not edit README, design spec, or other non-TASK-0009 docs."
risks:
  - "MapSceneObject requires entityId while annotations must have none; a sentinel may corrupt selection or violate design."
  - "Explicit roundabout no intentionally changes current bool result; caller effects require evidence and tests."
  - "Changing 3,500 m roadMarking LOD globally may affect unrelated markings."
  - "Atlas, approximate tolerances, fit, and LOD-basis choices can cause incompatible implementations if hidden."
  - "Dirty worktree increases accidental source mutation risk."
completion_report:
  required: true
---
# Work Package CODE-0009 — Road-Surface Annotation Root-Cause Analysis

## Purpose and execution gate

Perform read-only analysis before ENG-0009 implementation. Return the report and concrete correction/integration handoff to the Orchestrator. Engineering must wait for that handoff before changing analyzed concerns. Do not implement fixes, edit source/tests, change README/spec, or issue a delivery verdict.

## Investigation checklist

1. Trace `RoadProperties.oneway` from `lib/engine/domain/road_properties.dart` through OSM mapping, road joining/deduplication, vector-cell decoding, selection details, and all other callers. Record each caller's actual bool meaning and proposed compatibility matrix.
2. Trace OSM `yes`, `no`, `-1`, absent values, roundabout default, and explicit roundabout `oneway=no`. Current mapper `lib/engine/osm/osm_feature_mapper.dart:405-412` assigns true for any roundabout; record explicit-no false as an intentional approved behavior change, not preservation of the old result.
3. Trace road/marking `MapSceneObject` creation, tile ownership, required `entityId`, adapter node/entity maps, hit data, and raycast/pick selection. Both annotation kinds have no identity/hit geometry and must not intercept.
4. Trace `LodPolicy` and camera/renderer distance updates. Current road markings are LOD 1 with 3,500 m max; approved annotation LOD is <=1,200 m. Identify measured distance and whether a new cutoff can be scoped to annotations.
5. Trace engine placement data, `MapScene`, `MeshData` UV support, FlutterSceneAdapter `MeshGeometry.fromArrays`, texture/material ownership, tile batches, and atlas failure handling.
6. Return minimal correction plan that separates engine direction/placement from adapter atlas/UV/material work. Identify the required-entityId conflict and provide evidence-backed options, not a sentinel.
7. Surface open decisions: tile-edge atlas ownership/failure granularity; tolerances for approximate 45 m spacing and 0.04 m elevation; minimum fit/straightness/legibility; and LOD distance basis. Do not fabricate values.

The report at `docs/agent-work/reviews/CODE-0009-road-surface-root-cause.md` is the gate input to ENG-0009 and INT-0009. Include source evidence, root-cause/symptom classification, callers, correction plan, required regressions, integration seam, unresolved decisions, and explicit handoff. Route unresolved architecture conflicts through Orchestrator/Documentation Director.
