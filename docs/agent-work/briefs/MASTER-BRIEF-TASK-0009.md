# Master Brief — TASK-0009: Road-Surface Names and Direction Arrows

```yaml
master_brief:
  task_id: TASK-0009
  source_request: >-
    You are a subagent spawned by another session. You are Documentation Director for the Instrum organization. Prepare the documentation instruction pack for TASK-0009 using the mandatory org flow. Repo: /home/kysawa/Instrum/fogo. User approved design spec and explicitly said proceed. Approved spec: docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md (commit 1e26dd6). Inspect existing project documentation and architecture as required; use requirements analyst, documentation inspector, and architecture standards reviewer as your process requires; invoke instruction-compiler for all WP file creation (only compiler may write WP files). Do not implement code and do not invoke operational sector leads or Delivery Auditor. Preserve all unrelated pre-existing worktree changes; only create/modify TASK-0009 documentation artifacts. Return the Instruction Pack with paths for Master Brief, Engineering/Design/Integration/Validation WPs as applicable, plus findings and objective acceptance criteria. Respect the spec's approved scope: OSM road-name decals in Flutter Scene (textured per-tile atlas, world-aligned, 2D UI labels only in Map2DView, 2D anchors by path length); repeated road arrows every ~45m, bidirectional in separate lanes, one-way yes/no/-1 and roundabout parsing, world-space batches per tile, 0.04m above road surface, close 3D LOD <=1200m; preserve existing oneway bool behavior, pickability of base roads, no new package, tests/analyze/Linux debug build. Include clarification that one-way directional enums should preserve current callers and 3D annotations must not intercept raycasts.
  consolidated_requirements:
    functional:
      - "Render named OSM roads as tangent-aligned world-space asphalt decals using a per-tile text atlas; use name then ref; keep UI labels in Map2DView and use cumulative path-length midpoint for 2D road anchors."
      - "Render direction arrows every approximately 45 m, with short-way minimum coverage, opposing directions in separate lanes, and local tangent orientation on curves."
      - "Parse yes=forward, -1=reverse, no=both, missing roundabout=forward, explicit roundabout no=both, and other/absent=both. Keep RoadProperties.oneway API and its meaning: true means one permitted direction."
      - "Raise arrows and decals approximately 0.04 m above roads; batch by tile; show annotation batches only within close 3D LOD <=1,200 m."
      - "Both arrow and decal geometry have no entity ID or retained CPU hit geometry and do not intercept raycasts; base roads remain selectable."
      - "Keep annotations out of Map2DScene; forward UVs and use upload-time atlas creation, with atlas failures skipping affected decals without blocking the scene."
    non_functional:
      - "No new package dependency or palette token; use existing crossing/marking palette."
      - "Run dart format, flutter analyze, flutter test, and available Linux debug build; report actual evidence and unavailable prerequisites."
      - "Preserve all unrelated pre-existing modified, deleted, and untracked worktree content."
  doc_audit_summary:
    conflicts:
      - "README.md:78-80 describes cartographic labels as screen overlays; approved design moves named-road labels onto 3D road-surface decals. README updates are not authorized in this task."
      - "Current explicit roundabout one-way mapping returns true even for oneway=no; approved behavior requires explicit no to override the roundabout default to both/false."
    outdated:
      - "lib/engine/scene/lod_policy.dart:18-42 assigns roadMarking LOD 1 with 3,500 m maximum; new annotations require <=1,200 m. Do not change unrelated marking policy without evidence/scope review."
    missing:
      - "No evidence-backed root-cause/correction report exists yet for existing bool callers, scene entity identity/raycast flow, LOD distance basis, or adapter seam; CODE-0009 must provide it before Engineering starts analyzed changes."
      - "FlutterSceneAdapter currently does not forward MeshData UVs to MeshGeometry.fromArrays; per-tile atlas/UV integration and raycast behavior need focused implementation evidence/tests."
    confirmed:
      - "lib/engine/domain/road_properties.dart:6-26 defines RoadProperties.oneway as bool."
      - "lib/engine/osm/osm_feature_mapper.dart:405-412 sets oneway true for yes OR any roundabout, so explicit roundabout no currently remains true."
      - "Existing bool consumers include road join/deduplication, vector cell data, and selection details; inventory exact call sites in CODE-0009."
      - "lib/features/map/presentation/render/label_candidates.dart:28-41 positions road labels at arithmetic vertex mean."
      - "lib/engine/scene/map_scene.dart:9-20 requires MapSceneObject.entityId; lib/engine/fogo_engine.dart creates road-marking objects; adapter maps nodes/picks by entity identity."
      - "lib/features/map/presentation/render/flutter_scene_adapter.dart:147-154 passes positions, normals, colors, and indices but not UVs."
      - "Regional OSM extract contains 5,338 highway ways, 2,699 with name or ref, per approved design spec."
  arch_constraints:
    - "Follow approved spec docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md, commit 1e26dd6."
    - "Code Analysis is report-only and precedes Engineering; Engineering waits for its root-cause/correction/integration handoff before implementing analyzed concerns."
    - "Keep OSM parsing/road geometry in engine; Flutter text rasterization, atlases, UV/material upload in render adapter; use MapScene and existing spatial tiles."
    - "Do not use an invented entityId sentinel; both annotation kinds have no entity identity/CPU hit geometry and raycasts pass through."
    - "Preserve bool API and true=one-permitted-direction meaning; explicit roundabout no=false/both is an intentional input-specific behavior correction."
    - "No new package; preserve separate 2D scene and current area/POI label policy."
    - "Do not edit README/spec or any non-TASK-0009 artifact; preserve unrelated worktree changes."
  risks:
    - "Required MapSceneObject.entityId conflicts with visual-only annotation identity and must be resolved from code evidence."
    - "Roundabout explicit-no behavior changes old bool result; current callers and tests need analysis."
    - "Current roadMarking LOD is 3,500 m; changing it globally could alter existing behavior."
    - "Tile-edge atlas ownership/failure granularity, approximate spacing/elevation tolerances, text fit/straightness threshold, and LOD distance basis are open technical decisions; surface rather than invent."
    - "Existing dirty worktree makes broad formatting, reset, or cleanup unsafe."
  dependencies:
    agents:
      - "code-analysis-lead"
      - "engineering-lead"
      - "quality-performance-engineer"
      - "delivery-auditor"
    work_packages:
      - "CODE-0009"
      - "INT-0009"
      - "ENG-0009"
      - "VAL-0009"
    modules:
      - "RoadProperties, OSM mapping, and all bool callers"
      - "MapScene object identity, tile assignment, LOD, and raycast selection"
      - "MeshData UV and Flutter Scene adapter/material/atlas seam"
      - "2D label candidates and 2D/3D view separation"
  team_assignment:
    engineering: true
    design: false
    code_analysis: true
  execution_order:
    - "Code Analysis (read-only root cause and correction/integration handoff)"
    - "Engineering (gated on returned Code Analysis handoff)"
    - "Validation (after Engineering)"
    - "Delivery Auditor (final verdict after validation evidence)"
  acceptance_criteria:
    - "AC-01: Named roads render as world-aligned atlas-backed decals on asphalt in close 3D, follow tangent/perspective, and are not screen overlays."
    - "AC-02: All UI labels remain in Map2DView; 2D road candidates use cumulative path-length midpoint; area/POI policy and separate 2D road painter remain unchanged."
    - "AC-03: yes=forward/true, -1=reverse/true, no=both/false; missing roundabout=forward/true; explicit roundabout no=both/false despite old blanket-roundabout true; other/absent=both/false."
    - "AC-04: Arrows follow direction and curved tangents, repeat at ~45 m or cover shorter ways, use opposing quarter-width lane offsets for bidirectional roads, and sit ~0.04 m above road."
    - "AC-05: Per-tile batches, upload-time atlas generation, UV/material upload, and <=1,200 m annotation LOD are verified; existing 3,500 m roadMarking behavior is not silently changed."
    - "AC-06: Neither arrow nor decal nodes have entity ID/retained CPU hit geometry or intercept raycasts; base roads remain selectable; Map2DScene receives no arrows."
    - "AC-07: Tests cover parser/caller behavior, 2D anchor, arrows, atlas/UV, LOD, view separation, and raycast selection."
    - "AC-08: Formatter, flutter analyze/test, and available Linux debug build pass or exact unavailable/failure evidence is reported."
  protected_areas:
    - "RoadProperties.oneway API and caller meaning true=one permitted direction; allow only approved -1 and explicit-roundabout-no mapping clarifications."
    - "Base-road entity identity/pickability; annotation geometry stays non-intercepting."
    - "2D area/POI labels and independent 2D road painter."
    - "README.md, approved design spec, and all non-TASK-0009 docs are read-only."
    - "All pre-existing modified, deleted, and untracked worktree content; preserve existing contents/diffs."
  affected_areas:
    - "lib/engine/domain/road_properties.dart and lib/engine/domain/road.dart"
    - "lib/engine/osm/osm_feature_mapper.dart; features/map/vector road joins/deduplication and vector data"
    - "lib/engine/scene/map_scene.dart, lib/engine/fogo_engine.dart, lib/engine/scene/lod_policy.dart"
    - "lib/engine/geometry/mesh_data.dart and lib/features/map/presentation/render/flutter_scene_adapter.dart"
    - "label_candidates.dart, label_overlay.dart, fogo_scene_view.dart and focused tests"
```

## Discovery findings

- `README.md:78-80` describes screen-space overlays. This is a stale-doc conflict only; this compilation does not authorize README edits.
- `RoadProperties.oneway` is declared as bool (`lib/engine/domain/road_properties.dart:6-26`). The mapper currently sets it to `tags['oneway'] == 'yes' || tags['junction'] == 'roundabout'` (`lib/engine/osm/osm_feature_mapper.dart:405-412`). Therefore explicit `oneway=no` on a roundabout currently remains true.
- Bool consumers include road joining/deduplication (`lib/features/map/vector/road_geometry_merger/road_join.dart`, `road_deduplication.dart`), vector cells (`features/map/vector/vector_data/features.dart`, `cell_data.dart`), and selection details (`lib/features/map/presentation/selection_details.dart`). CODE-0009 must inventory exact calls and meaning.
- Current 2D road label candidates use arithmetic mean (`lib/features/map/presentation/render/label_candidates.dart:28-41`); approved behavior is cumulative path-length midpoint.
- `MapSceneObject.entityId` is required (`lib/engine/scene/map_scene.dart:9-20`). Engine creates road marking objects and adapter names/maps nodes by entity ID; `flutter_scene_adapter.dart:147-154` currently uploads no UV array.
- Current road markings are classified LOD 1, capped at 3,500 m (`lib/engine/scene/lod_policy.dart:18-42`); approved annotation LOD is <=1,200 m. Report must distinguish annotation policy from existing road markings.

## Open decisions

CODE-0009 must report rather than silently invent: (1) tile-edge atlas ownership and atlas failure granularity; (2) test tolerances for approximately 45 m spacing and 0.04 m surface offset; (3) minimum straightness, fit, and legibility threshold for road text; (4) distance origin/basis and hysteresis treatment for 1,200 m annotation LOD; (5) whether the existing 3,500 m roadMarking policy is deliberately unchanged while annotation LOD is scoped separately. These do not reopen the approved visual spec; any needed product/scope change routes through Director/Orchestrator.

## Package index

- Code Analysis: `docs/agent-work/work-packages/CODE-0009-road-surface-root-cause.md`
- Shared Integration Contract: `docs/agent-work/work-packages/INT-0009-road-surface-analysis-engine-contract.md`
- Engineering: `docs/agent-work/work-packages/ENG-0009-road-surface-annotations.md`
- Validation: `docs/agent-work/work-packages/VAL-0009-road-surface-annotations-validation.md`
- Handoff: `docs/agent-work/handoffs/HANDOFF-TASK-0009.md`
