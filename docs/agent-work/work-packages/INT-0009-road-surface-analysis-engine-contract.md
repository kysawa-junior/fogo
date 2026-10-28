---
id: INT-0009
version: "1"
status: approved
source:
  user_request: "TASK-0009"
  orchestrator_task_id: TASK-0009
objective: "Bind the CODE-0009 root-cause handoff to gated ENG-0009 implementation across OSM direction, MapScene identity/LOD, and Flutter Scene annotations."
background: "Code analysis is required for existing bool parsing/callers, roundabout explicit-no behavior, entity identity/raycasts, road-marking LOD, and adapter UV handling. Approved spec: docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md (commit 1e26dd6)."
scope:
  included:
    - "Define CODE-0009 report as required input and start gate for Engineering on analyzed concerns."
    - "Bind the legacy RoadProperties.oneway bool contract to both/forward/reverse direction semantics."
    - "Define engine-to-adapter responsibilities for placement, tile batches, atlas/UV/material upload, LOD, and picking."
    - "Record open implementation decisions without selecting unstated thresholds."
    - "Keep Validation after Engineering and Delivery Auditor as a distinct final verdict role."
  excluded:
    - "Design work or visual changes beyond the approved spec."
    - "Implementation or source edits in this contract."
    - "README/spec edits and unrelated worktree cleanup."
requirements:
  functional:
    - "CODE-0009 returns root-cause findings and correction/integration handoff; no analyzed implementation begins before handoff returns."
    - "Preserve RoadProperties.oneway API and meaning: true means one permitted direction; yes=forward/true; -1=reverse/true; no=both/false."
    - "Missing roundabout oneway defaults to forward/true; explicit roundabout no overrides default to both/false, intentionally changing old blanket-roundabout true for this input."
    - "Engine owns OSM parsing, road geometry, and engine-independent placement; adapter owns text rasterization, per-tile atlas, UV/material creation, and Flutter Scene upload."
    - "Both arrow and decal geometry have no entity ID and no retained CPU hit geometry, do not intercept raycasts, and leave base roads selectable."
    - "Batch annotation geometry by existing spatial tile, keep <=1,200 m close-3D LOD, and keep arrows out of Map2DScene."
    - "Validation verifies implementation after Engineering; Delivery Auditor alone issues final delivery verdict after validation evidence."
  non_functional:
    - "Preserve unrelated pre-existing modified, deleted, and untracked worktree content."
    - "No new dependency; leave README/spec/non-TASK-0009 documents unchanged."
constraints:
  technical:
    - "Do not solve required MapSceneObject.entityId with an invented sentinel; CODE-0009 documents evidence-backed integration options."
    - "Current roadMarking LOD reaches 3,500 m; do not silently change unrelated existing markings to annotation LOD."
    - "Tile-edge atlas ownership/failure granularity, ~45 m/~0.04 m tolerances, fit/straightness threshold, and LOD-distance basis remain open until surfaced."
  architectural:
    - "Keep OSM parsing/road geometry in engine and Flutter text/atlas/material work in adapter."
    - "Code Analysis is report-only; Engineering implements after handoff; Validation reports evidence; Delivery Auditor issues final verdict."
  visual:
    - "Approved TASK-0009 spec is the visual source of truth."
  business:
    - "No new dependency or scope expansion."
dependencies:
  agents:
    - "code-analysis-lead"
    - "engineering-lead"
    - "quality-performance-engineer"
    - "delivery-auditor"
  work_packages: []
  modules:
    - "Road OSM mapping and bool callers"
    - "MapScene entity/tile data, LOD, and road selection"
    - "Flutter Scene adapter UV/material/raycast seam"
assigned_agents:
  - "engineering-lead"
affected_areas:
  modules:
    - "Code Analysis-to-Engineering handoff gate"
    - "RoadProperties.oneway and OSM direction parsing"
    - "MapScene identity, annotation batches, LOD, and road selection"
    - "Flutter Scene texture atlas/UV upload and picking"
  packages: []
  files:
    - "docs/agent-work/work-packages/CODE-0009-road-surface-root-cause.md"
    - "docs/agent-work/work-packages/ENG-0009-road-surface-annotations.md"
    - "docs/agent-work/work-packages/VAL-0009-road-surface-annotations-validation.md"
    - "lib/engine/domain/road_properties.dart"
    - "lib/engine/osm/osm_feature_mapper.dart"
    - "lib/engine/scene/map_scene.dart"
    - "lib/engine/scene/lod_policy.dart"
    - "lib/features/map/presentation/render/flutter_scene_adapter.dart"
protected_areas:
  modules:
    - "Existing oneway bool API/caller meaning except approved -1 and explicit-no input mapping clarifications."
    - "Base-road identity/pickability; both annotation kinds pass raycasts through."
    - "Existing 2D label/area/POI policy and unrelated map behavior."
    - "All pre-existing worktree modifications, deletions, and untracked content not required by TASK-0009."
  files:
    - "README.md, approved design spec, and all non-TASK-0009 docs."
    - "Every pre-existing modified/deleted/untracked path and prior content; preserve without reset or cleanup."
deliverables:
  - "Evidence-backed CODE-0009 to ENG-0009 handoff and explicit implementation gate."
  - "Shared legacy bool/directional contract including explicit roundabout no override."
  - "Engine-to-adapter contract for tile batches, atlas/UVs, LOD, and visual-only raycast behavior."
  - "Open-decision list without invented thresholds."
  - "Separate ENG → VAL → Delivery Auditor sequence; no conflated verdicts."
acceptance_criteria:
  - "Engineering begins analyzed changes only after CODE-0009 report/handoff returns and blockers are routed."
  - "Contract states true means exactly one permitted direction; -1 is reverse/true; explicit roundabout no is both/false and intentionally overrides old mapping."
  - "No entityId/picking conflict is bypassed with a sentinel; arrows and decals remain non-pickable and base road remains selectable."
  - "Engine/adapter responsibilities and per-tile scene-upload/UV contract are explicit."
  - "Current 3,500 m roadMarking LOD is distinguished from new annotation maximum 1,200 m."
  - "Atlas/tile failure policy, approximate tolerances, fit/straightness, and LOD basis remain explicit open decisions."
  - "Validation is a distinct post-implementation package; Delivery Auditor remains final verdict owner."
testing_requirements:
  - "No tests run by Integration Contract; bind checks from CODE-0009, ENG-0009, and VAL-0009."
  - "ENG-0009 covers parser/caller, label, arrow, atlas/UV, LOD, view separation, and raycast regressions."
  - "VAL-0009 runs formatter, flutter analyze/test, and available Linux debug build after implementation."
documentation_requirements:
  - "Reference the returned CODE-0009 report before Engineering starts."
  - "Do not alter README/spec or non-TASK-0009 documentation."
risks:
  - "A sentinel entityId could corrupt selection or violate approved no-ID behavior; wait for evidence-backed seam recommendation."
  - "Explicit roundabout no intentionally changes current bool result; tests must distinguish input-specific correction from API breakage."
  - "Changing roadMarking LOD globally could alter unrelated behavior; keep annotation LOD scoped."
completion_report:
  required: true
feature_id: "TASK-0009-road-surface-annotations"
shared_models:
  - "RoadProperties.oneway bool: true means one permitted direction; extend with both/forward/reverse without removing the API."
  - "Tag matrix: yes=forward/true; -1=reverse/true; no=both/false; absent roundabout=forward/true; explicit roundabout no=both/false."
  - "MapScene annotation placement/batch metadata associated with existing spatial tiles; exact representation follows CODE-0009 handoff."
  - "Flutter Scene decal/arrow geometry and texture UV/material data with no entity identity or retained CPU hit geometry."
shared_states:
  - "analysis_handoff: pending → returned; report includes root causes and correction/integration handoff."
  - "engineering_gate: blocked until CODE-0009 handoff returns; open only after blockers are routed."
  - "annotation_visibility: close 3D only, maximum 1,200 m; Map2DScene receives no arrows."
  - "selection: visual annotations do not hit; base road remains selectable."
responsibilities:
  design: []
  code_analysis:
    - "Read-only trace of bool callers, OSM tags, scene identity/raycast, current LOD, and engine/adapter seam."
    - "Return root-cause findings, minimal correction plan, open decisions, and direct Engineering handoff; no source edits."
  engineering:
    - "Wait for CODE-0009 handoff before implementing analyzed concerns."
    - "Implement approved annotation contract across engine and Flutter Scene adapter while preserving bool API and raycast behavior."
    - "Do not invent unresolved thresholds or use a sentinel entityId; escalate conflicts through Orchestrator/Director."
approval_required_from:
  - "engineering-lead"
  - "delivery-auditor"
---
# Work Package INT-0009 — Code Analysis to Engineering Integration Contract

## Purpose and gate

This contract binds CODE-0009's read-only root-cause report to ENG-0009 implementation across OSM direction, MapScene identity/tile ownership, annotation LOD, and Flutter Scene atlas/UV/material upload. Engineering must not implement analyzed concerns until the report and correction/integration handoff have been returned. This execution gate is not a delivery verdict.

## One-way compatibility

Keep `RoadProperties.oneway` API and meaning: `true` means one permitted direction. `yes` is forward/true; `-1` is reverse/true; `no` is both/false. Missing `oneway` on a roundabout defaults to forward/true. Explicit roundabout `oneway=no` overrides that default and is both/false, intentionally changing the current mapper's blanket-roundabout true result for this input. CODE-0009 traces actual callers; ENG-0009 tests this matrix.

## Engine and adapter boundary

Engine owns OSM parsing, road geometry, and engine-independent decal/arrow placement. Adapter owns Flutter text rasterization, per-tile atlas generation, UV/material creation, and Flutter Scene upload. Batches use existing spatial tile ownership and upload-time work. Both decal and arrow geometry have no entity ID and no retained CPU hit geometry; neither intercepts raycasts. The base road remains selectable. `Map2DScene` receives no arrows. Annotation LOD is no farther than 1,200 m; current roadMarking LOD is 3,500 m and must not change globally without evidence and scope review.

`MapSceneObject.entityId` is currently required. This contract does not select a sentinel or silently weaken the approved no-ID requirement. CODE-0009 returns the exact seam and evidence-backed correction option before Engineering implementation.

## Open decisions

The approved spec gives approximate targets but no numeric tolerances or policy for tile-edge atlas ownership/failure granularity, 45 m spacing tolerance, 0.04 m elevation tolerance, minimum straightness/fit/legibility, or LOD distance origin/basis. CODE-0009 must surface these; Engineering documents any implementation choice or routes a scope clarification rather than presenting an invented threshold as approved.

## Sequence and ownership

1. CODE-0009 inspects and returns its report/handoff; no source code changes in that stage.
2. Engineering starts analyzed work only after that handoff returns and blockers are routed; it implements approved scope and preserves compatibility/picking contracts.
3. VAL-0009 validates implementation independently and reports exact evidence.
4. Delivery Auditor reviews completed evidence and alone issues the final verdict.
