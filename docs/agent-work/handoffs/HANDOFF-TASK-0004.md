# Handoff — TASK-0004 F.O.G.O. Map SDK

## Work package

- Canonical package: `docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md` — ENG-0004 v2, compiler-prepared and ready for orchestration dispatch; no approval verdict issued.
- `docs/agent-work/work-packages/ENG-0004-owned-offline-map-sdk.md` is a superseded, non-authoritative, non-dispatchable duplicate; do not dispatch it.
- Status: Pending orchestration dispatch. No engineering/design/code-analysis sector has been dispatched and no implementation has occurred. No Delivery Auditor verdict exists.
- Source spec `docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md` says `Reviewed and approved by the user on 2026-10-19`; this is user approval, not an auditor verdict.

## Assignment and sequence

Engineering only. No Design WP, Code Analysis WP, or Shared Integration Contract is required: this is an approved feature replacement with specified visual direction, not an audit/defect task. After orchestration dispatch, engineering lead owns execution and specialist routing. After engineering delivery, the Orchestrator may dispatch Delivery Auditor to validate implementation and parity/cleanup evidence.

## Required execution order

Follow phases in ENG-0004 v2: discovery/safety baseline → SDK boundary/camera → local data/generator → renderer/integration → parity validation/evidence → gated cleanup last → post-parity ADR/docs and auditor handoff. Use only the already-local `tool/map_data/raw/sudeste-latest.osm.pbf`; no download, replacement, rewrite, or other PBF modification. Record SHA-256 immediately before and after generation and require equality plus a matching manifest `sourceSha256`.

Cell/manifest protections are narrow but explicit: preserve all existing OSM geometry, records, membership, coverage, non-height cell content, and non-height manifest fields/counts. Permit only additive validated positive numeric `height` on existing building records, approved height-related schema/count changes, generated cell/manifest regeneration, and metadata strictly required by the existing contract. Stage candidates and promote only after semantic diff confirms no other change. Fail closed if PBF is missing, checksum differs, or an unrelated semantic delta appears. Do not guess height grammar, units, or counter semantics.

Keep the existing renderer, flutter_map, and all 21,829 raster files until every parity gate passes and evidence is recorded. If a gate fails, retain them and report cleanup blocked.

## Auditor evidence packet

Include test/build/analyze commands and results; native evidence for Marília-SP, Vera Cruz-SP, Garça-SP, corridor, coverage edge and outside coverage; available/unavailable targets; bundle/map-data sizes and limitations; source-PBF before/after checksum evidence; exact raster path/checksum inventory; and exact deletion list/count, or explicit proof cleanup remained blocked. Auditor must also verify protected assets/history remain intact and docs/ADR updates follow parity. Do not claim auditor approval in implementation docs or alter historical TASK-0003 unresolved AC-03/AC-07.
