import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'camera.dart';
import 'coordinates.dart';
import 'data.dart';
import 'overlays.dart';
import 'road_geometry.dart';
import 'style.dart';

/// Display-only estimated height in metres for a building without a real OSM
/// `height`: area band + stable FNV-1a jitter (ADR-0005). The renderer
/// delegates here, so this pure function is the single estimate definition.
@visibleForTesting
double fogoEstimatedHeightMeters(List<double> coordinates, double areaM2) {
  final double base;
  if (areaM2 < 90) {
    base = 4.5;
  } else if (areaM2 < 350) {
    base = 7.5;
  } else if (areaM2 < 1500) {
    base = 12;
  } else if (areaM2 < 6000) {
    base = 21;
  } else {
    base = 30;
  }
  return base + fogoHeightJitter(coordinates) * 4;
}

/// Stable FNV-1a jitter for display-only building height estimates.
///
/// `Object.hashAll` is randomized per VM process, which would change a
/// building's estimated height on every app restart; this seed uses only
/// integer arithmetic over the coordinate values, so it is deterministic
/// across sessions and platforms (ADR-0005).
@visibleForTesting
double fogoHeightJitter(List<double> coordinates) {
  int seed = 0x811c9dc5;
  for (final double value in coordinates.take(8)) {
    if (!value.isFinite) continue;
    seed ^= (value * 1e6).round() & 0x7fffffff;
    seed = (seed * 0x01000193) & 0x7fffffff;
  }
  return ((seed & 0xF) / 15).clamp(0, 1).toDouble();
}

@immutable
class FogoMapRenderData {
  FogoMapRenderData({
    List<FogoMapRoad> roads = const [],
    List<FogoMapArea> areas = const [],
    List<FogoMapRail> rails = const [],
    List<FogoMapWaterLine> waterLines = const [],
    List<FogoMapPoi> pois = const [],
    List<FogoMapLabel> labels = const [],
    List<FogoMapArea> buildings = const [],
  }) : roads = List.unmodifiable(roads),
       areas = List.unmodifiable(areas),
       rails = List.unmodifiable(rails),
       waterLines = List.unmodifiable(waterLines),
       pois = List.unmodifiable(pois),
       labels = List.unmodifiable(labels),
       buildings = List.unmodifiable(buildings);

  factory FogoMapRenderData.fromCells(Iterable<FogoMapCellData> cells) {
    final List<FogoMapRoad> roads = [];
    final List<FogoMapArea> areas = [];
    final List<FogoMapRail> rails = [];
    final List<FogoMapWaterLine> waterLines = [];
    final List<FogoMapPoi> pois = [];
    final List<FogoMapLabel> labels = [];
    final List<FogoMapArea> buildings = [];
    for (final FogoMapCellData cell in cells) {
      roads.addAll(cell.roads);
      areas.addAll(cell.areas);
      rails.addAll(cell.rails);
      waterLines.addAll(cell.waterLines);
      pois.addAll(cell.pois);
      labels.addAll(cell.labels);
      buildings.addAll(cell.buildings);
    }
    return FogoMapRenderData(
      roads: FogoRoadGeometryMerger.merge(roads),
      areas: areas,
      rails: rails,
      waterLines: waterLines,
      pois: pois,
      labels: labels,
      buildings: buildings,
    );
  }

  final List<FogoMapRoad> roads;
  final List<FogoMapArea> areas;
  final List<FogoMapRail> rails;
  final List<FogoMapWaterLine> waterLines;
  final List<FogoMapPoi> pois;
  final List<FogoMapLabel> labels;
  final List<FogoMapArea> buildings;

  bool get isEmpty =>
      roads.isEmpty &&
      areas.isEmpty &&
      rails.isEmpty &&
      waterLines.isEmpty &&
      pois.isEmpty &&
      labels.isEmpty &&
      buildings.isEmpty;
}

class FogoMapPainter extends CustomPainter {
  FogoMapPainter({
    required this.camera,
    required this.data,
    required this.manifest,
    required this.style,
    required this.polylines,
    required this.surfaceCache,
    required this.projectionCache,
  });

  final FogoCameraState camera;
  final FogoMapRenderData data;
  final FogoMapManifest manifest;
  final FogoMapStyle style;
  final List<FogoMapPolyline> polylines;
  final FogoRoadSurfaceCache surfaceCache;
  final FogoProjectionCache projectionCache;

  static final LinkedHashMap<String, ui.Paragraph> _labelCache =
      LinkedHashMap();

  late FogoCameraTransform _transform;
  late FogoGeoBounds _visibleBounds;

  static bool isRoadClassVisible(FogoRoadClass roadClass, double zoom) =>
      switch (roadClass) {
        FogoRoadClass.motorway || FogoRoadClass.trunk => true,
        FogoRoadClass.primary => zoom >= 7.5,
        FogoRoadClass.secondary => zoom >= 9,
        FogoRoadClass.tertiary ||
        FogoRoadClass.unclassified ||
        FogoRoadClass.residential => zoom >= 11.5,
        FogoRoadClass.other => zoom >= 14,
        FogoRoadClass.track => zoom >= 13,
        FogoRoadClass.service => zoom >= 14.5,
        FogoRoadClass.path => zoom >= 16,
      };

  @override
  void paint(Canvas canvas, Size size) {
    _transform = FogoCameraTransform(camera, size);
    _visibleBounds = _transform.visibleBounds;
    projectionCache.clear();
    final bool pitched = camera.pitch > 0.5;
    canvas.drawColor(style.background, BlendMode.src);
    canvas.save();
    try {
      _clipToCoverage(canvas);
      _paintAreas(canvas);
      _paintWaterLines(canvas);
      _paintRails(canvas);
      if (pitched) {
        // Extrusions must paint over the ground, so near walls correctly
        // occlude the streets behind them (ADR-0006); flat views keep roofs
        // under the street surfaces.
        _paintRoads(canvas, size);
        _paintBuildings(canvas);
      } else {
        _paintBuildings(canvas);
        _paintRoads(canvas, size);
      }
      _paintLabels(canvas, size);
    } finally {
      canvas.restore();
    }
    _paintPolylines(canvas);
  }

  // ------------------------------------------------------------------
  // Metre-space helpers: geometry is buffered in absolute Web Mercator
  // metres (pan/rotation stable) and lifted to the screen through the 3D
  // transform, with near-plane clipping built in.
  // ------------------------------------------------------------------

  double get _zoomBucket => FogoCartography.zoomBucket(camera.zoom);

  /// Resample step that keeps ~8 screen pixels between spline samples.
  double get _smoothStep => 8 / _transform.scale;

  Offset _ground(double lat, double lng) => projectionCache.project(
    lat,
    lng,
    (la, ln) => FogoProjection.project(FogoCoordinate(la, ln)),
  );

  List<Offset> _groundPoints(List<double> coordinates) => [
    for (int i = 0; i < coordinates.length; i += 2)
      _ground(coordinates[i], coordinates[i + 1]),
  ];

  Offset? _screen(double lat, double lng) =>
      _transform.project(FogoCoordinate(lat, lng));

  void _fillPolygon(
    Canvas canvas,
    List<Offset> meters,
    Paint paint, [
    double height = 0,
  ]) {
    final List<Offset>? screen = _transform.projectMetersPolygon(
      meters,
      height,
    );
    if (screen == null) return;
    final ui.Path path = _path(screen)..close();
    canvas.drawPath(path, paint);
  }

  void _strokeGround(
    Canvas canvas,
    List<Offset> meters,
    Paint paint, {
    bool smooth = false,
    double height = 0,
  }) {
    final List<Offset> points = smooth
        ? FogoSmooth.polyline(
            meters,
            stepPx: _smoothStep,
            epsilon: 0.05 / _transform.scale,
          )
        : meters;
    if (points.length < 2) return;
    for (final List<Offset> run in _transform.projectMetersPolyline(
      points,
      height,
    )) {
      canvas.drawPath(_path(run), paint);
    }
  }

  double _groundDepth(List<Offset> meters) {
    double x = 0;
    double y = 0;
    for (final Offset point in meters) {
      x += point.dx;
      y += point.dy;
    }
    return _transform.metersDepth(Offset(x / meters.length, y / meters.length));
  }

  void _clipToCoverage(Canvas canvas) {
    final FogoGeoBounds bounds = manifest.bounds;
    final List<Offset> ring = [
      _ground(bounds.south, bounds.west),
      _ground(bounds.south, bounds.east),
      _ground(bounds.north, bounds.east),
      _ground(bounds.north, bounds.west),
      _ground(bounds.south, bounds.west),
    ];
    final List<List<Offset>> runs = _transform.projectMetersPolyline(ring);
    if (runs.isEmpty) return;
    // Concatenate all visible runs into ONE subpath: at pitch the far side
    // of the ring is clipped away and close() must bridge the near side in
    // a single polygon, not leave degenerate per-run subpaths.
    final ui.Path path = ui.Path();
    bool started = false;
    for (final List<Offset> run in runs) {
      for (final Offset point in run) {
        if (!started) {
          path.moveTo(point.dx, point.dy);
          started = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
    }
    path.close();
    canvas.clipPath(path);
  }

  // ------------------------------------------------------------------
  // Layers
  // ------------------------------------------------------------------

  void _paintAreas(Canvas canvas) {
    if (!style.showAreas) return;
    final Paint fill = Paint()..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = style.boundary;
    // Same-colour hairline on fills closes the antialiasing seams between
    // adjacent parcels (ADR-0006).
    final Paint seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final FogoMapArea area in data.areas) {
      if (!_visible(area.bbox)) continue;
      final List<Offset> ground = _groundPoints(area.coordinates);
      if (ground.length < 3) continue;
      if (area.kind == FogoAreaKind.boundary) {
        _strokeGround(canvas, [...ground, ground.first], stroke);
      } else {
        fill.color = switch (area.kind) {
          FogoAreaKind.water => style.water,
          FogoAreaKind.green => style.green,
          FogoAreaKind.farmland => style.farmland,
          FogoAreaKind.boundary => style.boundary,
        };
        seam.color = fill.color;
        _fillPolygon(canvas, ground, fill);
        _fillPolygon(canvas, ground, seam);
      }
    }
  }

  void _paintWaterLines(Canvas canvas) {
    if (!style.showWaterLines) return;
    final double scale = _lineScale(camera.zoom);
    for (final FogoMapWaterLine line in data.waterLines) {
      if (!_visible(line.bbox) ||
          (line.kind == FogoWaterLineKind.drain && camera.zoom < 15)) {
        continue;
      }
      final double width = switch (line.kind) {
        FogoWaterLineKind.river => 3.6 * scale,
        FogoWaterLineKind.canal => 2.4 * scale,
        FogoWaterLineKind.stream => 1.5 * scale,
        FogoWaterLineKind.drain => 0.8 * scale,
      };
      _strokeGround(
        canvas,
        _groundPoints(line.coordinates),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.5, width)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = style.waterLine,
        smooth: true,
      );
    }
  }

  void _paintRails(Canvas canvas) {
    if (!style.showRail) return;
    final double railScale = _railScale(camera.zoom);
    for (final FogoMapRail rail in data.rails) {
      if (!_visible(rail.bbox)) continue;
      final List<Offset> ground = FogoSmooth.polyline(
        _groundPoints(rail.coordinates),
        stepPx: _smoothStep,
        epsilon: 0.05 / _transform.scale,
      );
      if (ground.length < 2) continue;
      if (rail.kind == FogoRailKind.disused) {
        for (final List<Offset> run in _transform.projectMetersPolyline(
          ground,
        )) {
          _drawDashed(
            canvas,
            run,
            Paint()
              ..color = style.railDisused
              ..strokeWidth = math.max(1, 1.1 * railScale)
              ..strokeCap = StrokeCap.square,
            6,
            5,
          );
        }
      } else if (camera.zoom >= 13) {
        _strokeGround(
          canvas,
          ground,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = style.railBed
            ..strokeWidth = math.max(1, 2.6 * railScale)
            ..strokeCap = StrokeCap.square
            ..strokeJoin = StrokeJoin.round,
        );
        for (final List<Offset> run in _transform.projectMetersPolyline(
          ground,
        )) {
          _drawDashed(
            canvas,
            run,
            Paint()
              ..color = style.railTie
              ..strokeWidth = math.max(1, 1.1 * railScale)
              ..strokeCap = StrokeCap.square,
            7,
            6,
          );
        }
      }
    }
  }

  void _paintBuildings(Canvas canvas) {
    if (!style.showBuildings || camera.zoom < 15) return;
    final bool pitched = camera.pitch > 0.5;
    final List<({List<Offset> ground, double heightPx, double depth})> items =
        [];
    for (final FogoMapArea building in data.buildings) {
      if (!_visible(building.bbox)) continue;
      List<Offset> ground = _groundPoints(building.coordinates);
      if (ground.length < 3) continue;
      if ((ground.first - ground.last).distance > 0.05) {
        ground = [...ground, ground.first];
      }
      double heightPx = 0;
      if (pitched) {
        final double? real = building.heightMeters;
        if (real != null && real > 0) {
          heightPx = _transform.heightToPixels(real);
        } else if (style.estimateBuildingHeights) {
          heightPx = _estimatedHeightPx(building, ground);
        }
      }
      items.add((
        ground: ground,
        heightPx: heightPx,
        depth: _groundDepth(ground),
      ));
    }
    // Far first: painter's algorithm keeps nearer extrusions on top.
    items.sort((a, b) => b.depth.compareTo(a.depth));
    final Paint roof = Paint()..color = style.building;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = style.buildingStroke;
    for (final item in items) {
      _drawBuilding(canvas, item.ground, item.heightPx, roof, stroke);
    }
  }

  /// Deterministic display-only height, banded by footprint area with a
  /// stable jitter. Cell data stays untouched; see ADR-0005. The height
  /// definition itself lives in the shared pure function
  /// [fogoEstimatedHeightMeters]; this wrapper only measures the footprint
  /// (absolute mercator metres) and converts metres to pixels.
  double _estimatedHeightPx(FogoMapArea building, List<Offset> groundMeters) {
    final double cosLat = math.cos(camera.center.latitude * math.pi / 180);
    double sum = 0;
    for (int i = 0; i < groundMeters.length - 1; i++) {
      sum +=
          groundMeters[i].dx * groundMeters[i + 1].dy -
          groundMeters[i + 1].dx * groundMeters[i].dy;
    }
    final double areaM2 = (sum.abs() * 0.5) * cosLat * cosLat;
    return _transform.heightToPixels(
      fogoEstimatedHeightMeters(building.coordinates, areaM2),
    );
  }

  void _drawBuilding(
    Canvas canvas,
    List<Offset> ground,
    double heightPx,
    Paint roof,
    Paint stroke,
  ) {
    final bool pitched = camera.pitch > 0.5 && heightPx > 0.5;
    if (pitched) {
      final Offset light = const Offset(
        -0.7071067811865476,
        -0.7071067811865476,
      );
      for (int i = 0; i < ground.length - 1; i++) {
        final Offset a = ground[i];
        final Offset b = ground[i + 1];
        final Offset edge = b - a;
        if (edge.distance < 0.01) continue;
        final Offset normal = Offset(-edge.dy, edge.dx);
        final double shade =
            0.5 +
            0.5 *
                ((normal.dx * light.dx + normal.dy * light.dy) /
                    normal.distance);
        final Offset? s0 = _transform.projectMeters(a, 0);
        final Offset? s1 = _transform.projectMeters(b, 0);
        final Offset? s2 = _transform.projectMeters(b, heightPx);
        final Offset? s3 = _transform.projectMeters(a, heightPx);
        if (s0 == null || s1 == null || s2 == null || s3 == null) continue;
        final ui.Path wall = ui.Path()
          ..moveTo(s0.dx, s0.dy)
          ..lineTo(s1.dx, s1.dy)
          ..lineTo(s2.dx, s2.dy)
          ..lineTo(s3.dx, s3.dy)
          ..close();
        canvas.drawPath(
          wall,
          Paint()
            ..color = Color.lerp(
              style.buildingWallDark,
              style.buildingWallLit,
              shade.clamp(0, 1),
            )!,
        );
      }
      final List<Offset>? top = _transform.projectMetersPolygon(
        ground,
        heightPx,
      );
      if (top == null) return;
      final ui.Path roofPath = _path(top)..close();
      canvas.drawPath(roofPath, roof);
      if (camera.zoom >= 16) canvas.drawPath(roofPath, stroke);
      return;
    }
    final List<Offset>? top = _transform.projectMetersPolygon(ground, 0);
    if (top == null) return;
    final ui.Path roofPath = _path(top)..close();
    canvas.drawPath(roofPath, roof);
    if (camera.zoom >= 16) canvas.drawPath(roofPath, stroke);
  }

  void _paintRoads(Canvas canvas, Size size) {
    if (!style.showRoads) return;
    final Map<FogoRoadClass, List<FogoMapRoad>> byClass = {
      for (final FogoRoadClass roadClass in FogoRoadClass.values) roadClass: [],
    };
    final List<FogoMapRoad> bridges = [];
    final List<FogoMapRoad> tunnels = [];
    for (final FogoMapRoad road in data.roads) {
      if (!_visible(road.bbox) ||
          !style.roadClassVisible(road.roadClass) ||
          !isRoadClassVisible(road.roadClass, camera.zoom)) {
        continue;
      }
      if (road.tunnel) {
        tunnels.add(road);
      } else if (road.bridge) {
        bridges.add(road);
      } else {
        byClass[road.roadClass]!.add(road);
      }
    }
    final List<FogoRoadClass> order = FogoRoadClass.values.reversed.toList();
    final Paint fill = Paint()..style = PaintingStyle.fill;

    // Presentation widths come from the zoom-bucket ramp; the casing halo
    // grows with the street instead of a fixed pad (ADR-0006).
    for (final FogoRoadClass roadClass in order) {
      final List<FogoMapRoad> roads = byClass[roadClass]!;
      if (roads.isEmpty) continue;
      final double width = FogoCartography.widthPx(roadClass, _zoomBucket);
      final double pad = FogoCartography.casingPad(width);
      for (final FogoMapRoad road in roads) {
        _drawSurface(
          canvas,
          surfaceCache.casingSurface(
            road,
            width / 2 + pad,
            _transform,
            projectionCache,
          ),
          fill..color = style.roadCasing,
        );
      }
    }
    for (final FogoRoadClass roadClass in order) {
      for (final FogoMapRoad road in bridges) {
        if (road.roadClass != roadClass) continue;
        final double width = FogoCartography.widthPx(roadClass, _zoomBucket);
        final double pad = FogoCartography.casingPad(width) + 0.4;
        _drawSurface(
          canvas,
          surfaceCache.casingSurface(
            road,
            width / 2 + pad,
            _transform,
            projectionCache,
          ),
          fill..color = style.roadCasingBridge,
        );
      }
    }
    for (final FogoRoadClass roadClass in order) {
      final List<FogoMapRoad> roads = byClass[roadClass]!;
      if (roads.isEmpty) continue;
      final double width = FogoCartography.widthPx(roadClass, _zoomBucket);
      for (final FogoMapRoad road in roads) {
        _drawSurface(
          canvas,
          surfaceCache.fillSurface(
            road,
            width / 2,
            _transform,
            projectionCache,
          ),
          fill..color = style.roadColor(roadClass),
        );
      }
    }
    for (final FogoRoadClass roadClass in order) {
      for (final FogoMapRoad road in bridges) {
        if (road.roadClass != roadClass) continue;
        final double width = FogoCartography.widthPx(roadClass, _zoomBucket);
        _drawSurface(
          canvas,
          surfaceCache.fillSurface(
            road,
            width / 2,
            _transform,
            projectionCache,
          ),
          fill..color = style.roadColor(roadClass),
        );
      }
    }
    for (final FogoRoadClass roadClass in order) {
      for (final FogoMapRoad road in tunnels) {
        if (road.roadClass != roadClass) continue;
        final double width = FogoCartography.widthPx(roadClass, _zoomBucket);
        _drawSurface(
          canvas,
          surfaceCache.fillSurface(
            road,
            width / 2,
            _transform,
            projectionCache,
          ),
          fill..color = style.roadColor(roadClass).withValues(alpha: 0.45),
        );
      }
    }
    _paintOneway(canvas, Offset.zero & size, byClass, bridges);
  }

  void _drawSurface(Canvas canvas, FogoRoadSurface surface, Paint paint) {
    for (final List<Offset> contour in surface.contours) {
      _fillPolygon(canvas, contour, paint);
    }
  }

  void _paintOneway(
    Canvas canvas,
    Rect view,
    Map<FogoRoadClass, List<FogoMapRoad>> byClass,
    List<FogoMapRoad> bridges,
  ) {
    if (camera.zoom < 15) return;
    final Paint arrowPaint = Paint()..color = style.onewayArrow;
    int drawn = 0;
    for (final FogoMapRoad road in [
      ...byClass.values.expand((roads) => roads),
      ...bridges,
    ]) {
      if (drawn >= 250) break;
      if (!road.oneway ||
          road.roadClass == FogoRoadClass.path ||
          road.roadClass == FogoRoadClass.track) {
        continue;
      }
      final double width = FogoCartography.widthPx(road.roadClass, _zoomBucket);
      drawn += _drawOnewayArrows(
        canvas,
        view,
        road,
        arrowPaint,
        // Density scales with the street; the 120px floor keeps dense
        // residential grids from turning into arrow wallpaper (ADR-0006).
        spacing: math.max(120, width * 18),
        edge: width * 1.6,
        scale: math.max(1, width * 0.22),
      );
    }
  }

  int _drawOnewayArrows(
    Canvas canvas,
    Rect view,
    FogoMapRoad road,
    Paint paint, {
    required double spacing,
    required double edge,
    required double scale,
  }) {
    if (road.coordinates.length < 4) return 0;
    final List<Offset> meters = FogoSmooth.polyline(
      _groundPoints(road.coordinates),
      stepPx: _smoothStep,
      epsilon: 0.05 / _transform.scale,
    );
    final List<List<Offset>> runs = _transform.projectMetersPolyline(meters);
    int drawn = 0;
    for (final List<Offset> run in runs) {
      if (run.length < 2) continue;
      // Junction exclusion: cumulative screen distance from each run end;
      // arrows stay clear of the [edge] band where ways actually meet.
      final List<double> cumulative = [0.0];
      for (int i = 0; i < run.length - 1; i++) {
        cumulative.add(cumulative.last + (run[i + 1] - run[i]).distance);
      }
      final double total = cumulative.last;
      if (total < edge * 2) continue;
      // Per-run spacing continuity, phase-shifted so arrows do not hug
      // the junction edge.
      double carried = spacing * 0.5;
      for (int i = 0; i < run.length - 1; i++) {
        final Offset a = run[i];
        final Offset b = run[i + 1];
        final Offset segment = b - a;
        final double length = segment.distance;
        if (length == 0) continue;
        carried += length;
        final double middle = cumulative[i] + length / 2;
        if (middle < edge || total - middle < edge) continue;
        if (carried < spacing) continue;
        carried = 0;
        final Offset center = a + segment / 2;
        if (!view.inflate(20).contains(center)) continue;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.atan2(segment.dy, segment.dx));
        final double s = 3.2 * scale;
        final ui.Path arrow = ui.Path()
          ..moveTo(-s, -s * 0.8)
          ..lineTo(s, 0)
          ..lineTo(-s, s * 0.8)
          ..close();
        canvas.drawPath(arrow, paint);
        canvas.restore();
        drawn++;
      }
    }
    return drawn;
  }

  /// Per-kind visible zoom ranges plus a priority budget for place labels
  /// (ADR-0006). Pure so tests can pin the generalization rules.
  @visibleForTesting
  static List<FogoMapLabel> selectPlaceLabels(
    List<FogoMapLabel> labels,
    double zoom, {
    int? budget,
  }) {
    final List<FogoMapLabel> visible = [
      for (final FogoMapLabel label in labels)
        if (_placeLabelInRange(label.kind, zoom)) label,
    ];
    visible.sort((a, b) {
      final int priority = _placePriority(a.kind)
          .compareTo(_placePriority(b.kind));
      return priority != 0 ? priority : a.text.compareTo(b.text);
    });
    final int limit =
        budget ??
        (zoom < 12
            ? 8
            : zoom < 14
            ? 12
            : 18);
    return visible.length <= limit ? visible : visible.sublist(0, limit);
  }

  static bool _placeLabelInRange(FogoLabelKind kind, double zoom) =>
      switch (kind) {
        FogoLabelKind.city => zoom <= 14,
        FogoLabelKind.town => zoom >= 10 && zoom <= 15,
        FogoLabelKind.village => zoom >= 12 && zoom <= 15,
        FogoLabelKind.suburb => zoom >= 13 && zoom <= 16.5,
      };

  static int _placePriority(FogoLabelKind kind) => switch (kind) {
    FogoLabelKind.city => 0,
    FogoLabelKind.town => 1,
    FogoLabelKind.village => 2,
    FogoLabelKind.suburb => 3,
  };

  void _paintLabels(Canvas canvas, Size size) {
    if (!style.showLabels) return;
    final FogoLabelLayout layout = FogoLabelLayout(sameLabelDistance: 350);
    final Rect view = Offset.zero & size;
    for (final FogoMapLabel label in selectPlaceLabels(
      data.labels,
      camera.zoom,
    )) {
      final double fontSize;
      final Color color;
      switch (label.kind) {
        case FogoLabelKind.city:
          fontSize = 14;
          color = style.labelCity;
        case FogoLabelKind.town:
          fontSize = 11.5;
          color = style.labelSuburb;
        case FogoLabelKind.village:
          fontSize = 10;
          color = style.labelSuburb;
        case FogoLabelKind.suburb:
          fontSize = 10;
          color = style.labelSuburb;
      }
      final Offset? position = _screen(
        label.coordinate.latitude,
        label.coordinate.longitude,
      );
      if (position == null || !view.inflate(30).contains(position)) continue;
      final ui.Paragraph paragraph = _label(label.text, fontSize, color);
      if (!layout.tryPlace(
        key: 'place:${label.text}',
        anchor: position,
        aabb: Rect.fromCenter(
          center: position,
          width: paragraph.longestLine,
          height: paragraph.height,
        ),
      )) {
        continue;
      }
      _paintParagraph(canvas, paragraph, position);
    }
    if (camera.zoom >= 15.2) _drawRoadNames(canvas, view, layout);
    if (camera.zoom >= 11 && camera.zoom <= 15.5) {
      _drawRefShields(canvas, view, layout);
    }
    if (style.showLabels && style.showPois && camera.zoom >= 15.5) {
      final Paint poiPaint = Paint()..color = style.poiDot;
      for (final FogoMapPoi poi in data.pois) {
        final Offset? position = _screen(
          poi.coordinate.latitude,
          poi.coordinate.longitude,
        );
        if (position == null || !view.inflate(10).contains(position)) continue;
        canvas.drawCircle(position, 2.2, poiPaint);
        if (camera.zoom < 16.5 || poi.name.isEmpty) continue;
        final ui.Paragraph paragraph = _label(poi.name, 9, style.labelPoi);
        if (layout.tryPlace(
          key: 'poi:${poi.name}',
          anchor: position,
          aabb: Rect.fromCenter(
            center: position.translate(0, -8),
            width: paragraph.longestLine,
            height: paragraph.height,
          ),
        )) {
          _paintParagraph(canvas, paragraph, position.translate(0, -16));
        }
      }
    }
  }

  void _drawRoadNames(Canvas canvas, Rect view, FogoLabelLayout layout) {
    final List<FogoMapRoad> named = [
      for (final FogoMapRoad road in data.roads)
        if (road.name.isNotEmpty &&
            _visible(road.bbox) &&
            style.roadClassVisible(road.roadClass) &&
            isRoadClassVisible(road.roadClass, camera.zoom))
          road,
    ];
    named.sort((a, b) {
      final int priority = a.roadClass.index.compareTo(b.roadClass.index);
      return priority != 0 ? priority : b.pointCount.compareTo(a.pointCount);
    });
    const double spacing = 420;
    final double fontSize = camera.zoom >= 16.5 ? 9.5 : 9;
    int drawn = 0;
    for (final FogoMapRoad road in named) {
      if (drawn >= 200) break;
      final List<List<Offset>> runs = _transform.projectMetersPolyline(
        FogoSmooth.polyline(
          _groundPoints(road.coordinates),
          stepPx: _smoothStep,
          epsilon: 0.05 / _transform.scale,
        ),
      );
      double carry = spacing * 0.35;
      int labelsOnRoad = 0;
      for (final List<Offset> run in runs) {
        for (int i = 0; i < run.length - 1 && labelsOnRoad < 3; i++) {
          final Offset a = run[i];
          final Offset b = run[i + 1];
          final Offset segment = b - a;
          final double length = segment.distance;
          if (length < 24) continue;
          final Offset middle = a + segment / 2;
          if (!view.inflate(20).contains(middle)) continue;
          final double accumulated = carry + length;
          if (accumulated < spacing) {
            carry = accumulated;
            continue;
          }
          carry = 0;
          double angle = math.atan2(segment.dy, segment.dx);
          if (angle > math.pi / 2) {
            angle -= math.pi;
          } else if (angle < -math.pi / 2) {
            angle += math.pi;
          }
          final ui.Paragraph paragraph = _label(
            road.name,
            fontSize,
            style.labelRoad,
          );
          if (!layout.tryPlace(
            key: 'road:${road.name}',
            anchor: middle,
            aabb: FogoLabelLayout.rotatedAabb(
              middle,
              paragraph.longestLine,
              paragraph.height,
              angle,
            ),
          )) {
            continue;
          }
          canvas.save();
          canvas.translate(middle.dx, middle.dy);
          canvas.rotate(angle);
          canvas.drawParagraph(
            paragraph,
            Offset(-paragraph.longestLine / 2, -paragraph.height / 2),
          );
          canvas.restore();
          drawn++;
          labelsOnRoad++;
        }
      }
    }
  }

  void _drawRefShields(Canvas canvas, Rect view, FogoLabelLayout layout) {
    final Paint background = Paint()..color = style.shieldBg;
    final Paint border = Paint()
      ..color = style.shieldBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final FogoMapRoad road in data.roads) {
      if (road.roadClass != FogoRoadClass.motorway &&
          road.roadClass != FogoRoadClass.trunk &&
          road.roadClass != FogoRoadClass.primary) {
        continue;
      }
      if (!_visible(road.bbox) || !style.roadClassVisible(road.roadClass)) {
        continue;
      }
      if (!isRoadClassVisible(road.roadClass, camera.zoom)) continue;
      final String? ref = road.ref;
      if (ref == null || ref.isEmpty || road.pointCount < 2) continue;
      final int middle = road.pointCount ~/ 2;
      final Offset? position = _screen(
        road.coordinates[middle * 2],
        road.coordinates[middle * 2 + 1],
      );
      if (position == null || !view.inflate(40).contains(position)) continue;
      final ui.Paragraph label = _label(ref, 9, style.shieldText);
      final double width = label.longestLine + 10;
      const double height = 16;
      final Rect rect = Rect.fromCenter(
        center: position,
        width: width,
        height: height,
      );
      if (!layout.tryPlace(
        key: 'ref:$ref',
        anchor: position,
        aabb: rect.inflate(3),
      )) {
        continue;
      }
      final RRect rounded = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(4),
      );
      canvas.drawRRect(rounded, background);
      canvas.drawRRect(rounded, border);
      canvas.drawParagraph(
        label,
        position - Offset(label.longestLine / 2, height / 2 - 7),
      );
    }
  }

  void _paintPolylines(Canvas canvas) {
    for (final FogoMapPolyline polyline in polylines) {
      final List<Offset> ground = FogoSmooth.polyline(
        [
          for (final FogoCoordinate coordinate in polyline.points)
            FogoProjection.project(coordinate),
        ],
        stepPx: _smoothStep,
        epsilon: 0.05 / _transform.scale,
      );
      if (polyline.borderColor != null && polyline.borderWidth > 0) {
        _strokeScreen(
          canvas,
          ground,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = polyline.width + polyline.borderWidth * 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = polyline.borderColor!,
          polyline.dashPattern,
        );
      }
      _strokeScreen(
        canvas,
        ground,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = polyline.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = polyline.color,
        polyline.dashPattern,
      );
    }
  }

  void _strokeScreen(
    Canvas canvas,
    List<Offset> meters,
    Paint paint,
    List<double> dash,
  ) {
    for (final List<Offset> run in _transform.projectMetersPolyline(meters)) {
      if (dash.isEmpty) {
        canvas.drawPath(_path(run), paint);
      } else {
        _drawDashed(
          canvas,
          run,
          paint,
          dash[0],
          dash.length > 1 ? dash[1] : dash[0],
        );
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    double dash,
    double gap,
  ) {
    if (points.length < 2) return;
    bool drawing = true;
    double progress = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final Offset start = points[i];
      final Offset end = points[i + 1];
      final Offset delta = end - start;
      final double length = delta.distance;
      if (length == 0) continue;
      double offset = 0;
      while (offset < length) {
        final double run = drawing ? dash : gap;
        final double step = math.min(length - offset, run - progress);
        if (drawing && step > 0) {
          canvas.drawLine(
            start + delta * (offset / length),
            start + delta * ((offset + step) / length),
            paint,
          );
        }
        offset += step;
        progress += step;
        if (progress >= run - 1e-9) {
          progress = 0;
          drawing = !drawing;
        }
      }
    }
  }

  ui.Paragraph _label(String text, double fontSize, Color color) {
    final String key =
        '$text|$fontSize|${color.toARGB32()}|${style.labelHalo.toARGB32()}';
    final ui.Paragraph? cached = _labelCache.remove(key);
    if (cached != null) {
      _labelCache[key] = cached;
      return cached;
    }
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.left, maxLines: 1),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              shadows: [
                for (int i = 0; i < 8; i++)
                  ui.Shadow(
                    color: style.labelHalo,
                    blurRadius: 0.5,
                    offset: Offset(
                      2 * math.cos(i * math.pi / 4),
                      2 * math.sin(i * math.pi / 4),
                    ),
                  ),
              ],
            ),
          )
          ..addText(text);
    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 400));
    _labelCache[key] = paragraph;
    if (_labelCache.length > 500) _labelCache.remove(_labelCache.keys.first);
    return paragraph;
  }

  void _paintParagraph(Canvas canvas, ui.Paragraph paragraph, Offset position) {
    canvas.drawParagraph(
      paragraph,
      position - Offset(paragraph.longestLine / 2, paragraph.height / 2),
    );
  }

  ui.Path _path(List<Offset> points) {
    final ui.Path path = ui.Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  bool _visible(List<double> bbox) =>
      bbox[0] <= _visibleBounds.north &&
      bbox[2] >= _visibleBounds.south &&
      bbox[1] <= _visibleBounds.east &&
      bbox[3] >= _visibleBounds.west;

  static double _lineScale(double zoom) =>
      zoom <= 12 ? 0.7 : math.min(3.2, 1 + (zoom - 12) * 0.26).toDouble();

  static double _railScale(double zoom) {
    const List<(double, double)> anchors = [
      (7, 0.3),
      (10, 0.7),
      (12, 0.9),
      (13, 0.95),
      (14, 1),
      (15, 2.5),
      (16, 5),
      (17, 10),
      (18, 13),
    ];
    for (int i = 1; i < anchors.length; i++) {
      if (zoom <= anchors[i].$1) {
        final (double z0, double w0) = anchors[i - 1];
        final (double z1, double w1) = anchors[i];
        final double width = w0 + (w1 - w0) * (zoom - z0) / (z1 - z0);
        return math.max(1, math.min(14, width * 1.15) * 0.45).toDouble();
      }
    }
    return math.max(1, math.min(14, anchors.last.$2 * 1.15) * 0.45).toDouble();
  }

  @override
  bool shouldRepaint(covariant FogoMapPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.data != data ||
      oldDelegate.manifest != manifest ||
      oldDelegate.style != style ||
      oldDelegate.polylines != polylines;
}
