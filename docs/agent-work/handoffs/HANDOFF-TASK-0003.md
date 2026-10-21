# Handoff — TASK-0003 Offline dark map tiles

## Work packages

- `docs/agent-work/work-packages/ENG-0003-offline-dark-map-tiles.md` — generate deterministic local z7–18 XYZ tiles from existing OSM cells, wire bundled tiles as an offline dark basemap, preserve the transparent dynamic vector overlay and map invariants, update documentation/ADR, and report tests plus artifact/build measurements.
- `docs/agent-work/work-packages/VAL-0003-offline-dark-map-tiles-validation.md` — independently verify tile pixels/omissions/determinism/coverage, local-only tile behavior, viewport overlap and layer controls/order, protected behaviors, project checks, visual captures, and measured tile/bundle/build values.

## Sequence

1. Engineering implements ENG-0003 using `docs/superpowers/specs/2026-10-19-offline-dark-map-tiles-design.md` as approved source of truth. Reuse existing cells and source only; do not obtain public raster tiles or download the source PBF again. Rasterize non-toggleable non-road features only. Keep roads/buildings/labels live in a transparent vector layer and preserve the specified toggles, road widths/order/filters, routes, markers, camera behavior, attribution, and approved palette. Use local `AssetTileProvider`, manifest `tileBounds`, a local dark error image, and no `fallbackUrl` or tile network. Implement viewport-intersection coverage; document the hybrid behavior in README and `docs/ARCHITECTURE.md`, add the ADR, and leave TASK-0001/2 reports unchanged. Run engineering checks and report exact results, captures, tile count/bytes, debug bundle size, and build time.
2. After ENG-0003 is complete, validation executes VAL-0003 independently. Record evidence criterion by criterion, exact commands/results, actual measurements and visual captures; return failures or gaps to engineering without implementing fixes.
3. After engineering and validation evidence are returned, the orchestrator coordinates the Delivery Auditor per workflow. This handoff does not authorize the compiler to invoke operational sectors or auditor.

Engineering and Validation only. No Design Work Package or Shared Integration Contract is required by the Master Brief. The estimate of about 63,114 tile positions is a measurement risk, not a substitute for reporting actual generated size/build time. Preserve all protected areas in both work packages.
