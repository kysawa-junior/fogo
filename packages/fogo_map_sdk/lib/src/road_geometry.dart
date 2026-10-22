import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'data.dart';
import 'camera.dart';
import 'coordinates.dart';

/// Cartographic generalization rules shared by the renderer, the surface
/// cache and the tests (ADR-0006). Presentation widths are screen pixels
/// evaluated on quarter-zoom buckets; road buffers are built in mercator
/// metres per bucket so pan, rotation and pitch reuse geometry.
abstract final class FogoCartography {
  static double zoomBucket(double zoom) => (zoom * 4).round() / 4;

  static double _ramp(double zoom, List<(double, double)> anchors) {
    if (zoom <= anchors.first.$1) return anchors.first.$2;
    for (int i = 1; i < anchors.length; i++) {
      if (zoom <= anchors[i].$1) {
        final (double z0, double w0) = anchors[i - 1];
        final (double z1, double w1) = anchors[i];
        return w0 + (w1 - w0) * ((zoom - z0) / (z1 - z0));
      }
    }
    return anchors.last.$2;
  }

  /// Screen-pixel width of a street class at [zoom]; continuous, no jumps.
  static double widthPx(FogoRoadClass roadClass, double zoom) =>
      switch (roadClass) {
        FogoRoadClass.motorway => _ramp(zoom, [
          (7, 4.5),
          (10, 6),
          (13, 8.5),
          (16, 11),
          (19, 13),
        ]),
        FogoRoadClass.trunk => _ramp(zoom, [
          (7, 4),
          (10, 5.5),
          (13, 8),
          (16, 10),
          (19, 12),
        ]),
        FogoRoadClass.primary => _ramp(zoom, [
          (8, 2.5),
          (11, 4),
          (13, 5.5),
          (16, 8),
          (19, 11),
        ]),
        FogoRoadClass.secondary => _ramp(zoom, [
          (9, 2),
          (12, 3),
          (14, 4.5),
          (16, 6.5),
          (19, 9),
        ]),
        FogoRoadClass.tertiary => _ramp(zoom, [
          (11, 1.5),
          (13, 2.5),
          (15, 4),
          (17, 6),
          (19, 8),
        ]),
        FogoRoadClass.unclassified || FogoRoadClass.residential => _ramp(zoom, [
          (11.5, 1.5),
          (13, 2),
          (15, 3.5),
          (17, 5.5),
          (19, 7),
        ]),
        FogoRoadClass.other => _ramp(zoom, [(14, 1.5), (17, 3), (19, 5)]),
        FogoRoadClass.service => _ramp(zoom, [(14.5, 1.2), (16, 2), (19, 4.5)]),
        FogoRoadClass.track => _ramp(zoom, [(13, 1), (16, 2), (19, 3.5)]),
        FogoRoadClass.path => _ramp(zoom, [(16, 1), (19, 2.5)]),
      };

  /// Casing halo grows with the street instead of a fixed pad.
  static double casingPad(double widthPx) =>
      (0.6 + widthPx * 0.18).clamp(0.8, 2.4).toDouble();

  /// Metre half-width for buffering, derived from the bucket scale.
  static double halfWidthMeters(double widthPx, double zoomBucket) =>
      widthPx /
      (256 *
          math.pow(2, zoomBucket).toDouble() /
          FogoProjection.worldCircumference);
}

abstract final class FogoRoadGeometryMerger {
  static const double _maxDeflection = math.pi * 5 / 6;

  static List<FogoMapRoad> merge(Iterable<FogoMapRoad> source) {
    List<FogoMapRoad> roads = _deduplicate(source);
    while (true) {
      final Map<(double, double), List<_Endpoint>> endpoints = {};
      for (int i = 0; i < roads.length; i++) {
        final FogoMapRoad road = roads[i];
        if (road.pointCount < 2 || _isClosed(road.coordinates)) continue;
        _addEndpoint(endpoints, road, i, true);
        _addEndpoint(endpoints, road, i, false);
      }
      final List<FogoMapRoad> next = [];
      final Set<int> consumed = {};
      bool changed = false;
      for (int i = 0; i < roads.length; i++) {
        if (consumed.contains(i)) continue;
        _Endpoint? partner;
        bool atStart = false;
        for (final bool start in [true, false]) {
          final List<_Endpoint> candidates = _candidates(
            roads,
            endpoints,
            i,
            start,
          );
          if (candidates.length == 1) {
            partner = candidates.single;
            atStart = start;
            break;
          }
        }
        if (partner == null || partner.roadIndex <= i) {
          next.add(roads[i]);
          continue;
        }
        final List<_Endpoint> reverseCandidates = _candidates(
          roads,
          endpoints,
          partner.roadIndex,
          partner.atStart,
        );
        if (reverseCandidates.length != 1 ||
            reverseCandidates.single.roadIndex != i ||
            reverseCandidates.single.atStart != atStart) {
          next.add(roads[i]);
          continue;
        }
        next.add(
          _join(roads[i], atStart, roads[partner.roadIndex], partner.atStart),
        );
        consumed
          ..add(i)
          ..add(partner.roadIndex);
        changed = true;
      }
      roads = next;
      if (!changed) return roads;
    }
  }

  static List<FogoMapRoad> _deduplicate(Iterable<FogoMapRoad> source) {
    final Map<int, List<FogoMapRoad>> buckets = {};
    final List<FogoMapRoad> unique = [];
    for (final FogoMapRoad road in source) {
      final int fieldsHash = Object.hash(
        road.roadClass,
        road.name,
        road.ref,
        road.oneway,
        road.bridge,
        road.tunnel,
      );
      final int forwardHash = Object.hash(
        fieldsHash,
        Object.hashAll(road.coordinates),
      );
      final int reverseHash = Object.hash(
        fieldsHash,
        Object.hashAll(_reverse(road.coordinates)),
      );
      final Iterable<int> hashes = road.oneway
          ? [forwardHash]
          : {forwardHash, reverseHash};
      bool duplicate = false;
      for (final int hash in hashes) {
        if ((buckets[hash] ?? const <FogoMapRoad>[]).any(
          (other) => _sameRoad(other, road),
        )) {
          duplicate = true;
          break;
        }
      }
      if (duplicate) continue;
      for (final int hash in hashes) {
        buckets.putIfAbsent(hash, () => []).add(road);
      }
      unique.add(road);
    }
    return unique;
  }

  static bool _sameRoad(FogoMapRoad a, FogoMapRoad b) {
    if (a.roadClass != b.roadClass ||
        a.name != b.name ||
        a.ref != b.ref ||
        a.oneway != b.oneway ||
        a.bridge != b.bridge ||
        a.tunnel != b.tunnel ||
        a.coordinates.length != b.coordinates.length) {
      return false;
    }
    bool sameForward = true;
    bool sameReverse = !a.oneway;
    for (int i = 0; i < a.coordinates.length; i += 2) {
      sameForward &=
          a.coordinates[i] == b.coordinates[i] &&
          a.coordinates[i + 1] == b.coordinates[i + 1];
      final int reverseIndex = b.coordinates.length - 2 - i;
      sameReverse &=
          a.coordinates[i] == b.coordinates[reverseIndex] &&
          a.coordinates[i + 1] == b.coordinates[reverseIndex + 1];
    }
    return sameForward || sameReverse;
  }

  static void _addEndpoint(
    Map<(double, double), List<_Endpoint>> index,
    FogoMapRoad road,
    int roadIndex,
    bool atStart,
  ) {
    final int i = atStart ? 0 : road.coordinates.length - 2;
    index
        .putIfAbsent((road.coordinates[i], road.coordinates[i + 1]), () => [])
        .add(_Endpoint(roadIndex, atStart));
  }

  static List<_Endpoint> _candidates(
    List<FogoMapRoad> roads,
    Map<(double, double), List<_Endpoint>> endpoints,
    int roadIndex,
    bool atStart,
  ) {
    final FogoMapRoad road = roads[roadIndex];
    final int i = atStart ? 0 : road.coordinates.length - 2;
    final (double, double) key = (road.coordinates[i], road.coordinates[i + 1]);
    return [
      for (final _Endpoint other in endpoints[key] ?? const <_Endpoint>[])
        if (other.roadIndex != roadIndex &&
            _sameStyle(road, roads[other.roadIndex]) &&
            _directionsContinue(
              road,
              atStart,
              roads[other.roadIndex],
              other.atStart,
            ) &&
            _preservesDirection(
              road,
              atStart,
              roads[other.roadIndex],
              other.atStart,
            ))
          other,
    ];
  }

  static bool _sameStyle(FogoMapRoad a, FogoMapRoad b) =>
      a.roadClass == b.roadClass &&
      a.name == b.name &&
      a.ref == b.ref &&
      a.oneway == b.oneway &&
      a.bridge == b.bridge &&
      a.tunnel == b.tunnel;

  static bool _directionsContinue(
    FogoMapRoad a,
    bool aAtStart,
    FogoMapRoad b,
    bool bAtStart,
  ) {
    final math.Point<double> da = _outwardDirection(a, aAtStart);
    final math.Point<double> db = _outwardDirection(b, bAtStart);
    return da.x * db.x + da.y * db.y < -math.cos(_maxDeflection);
  }

  static math.Point<double> _outwardDirection(FogoMapRoad road, bool atStart) {
    final List<double> coords = road.coordinates;
    final int endpoint = atStart ? 0 : coords.length - 2;
    final int adjacent = atStart ? 2 : coords.length - 4;
    final double lat = coords[endpoint];
    final double dx =
        (coords[adjacent + 1] - coords[endpoint + 1]) *
        111320.0 *
        math.cos(lat * math.pi / 180);
    final double dy = (coords[adjacent] - lat) * 111132.0;
    final double length = math.sqrt(dx * dx + dy * dy);
    return length == 0
        ? const math.Point(0, 0)
        : math.Point(dx / length, dy / length);
  }

  static bool _preservesDirection(
    FogoMapRoad a,
    bool aAtStart,
    FogoMapRoad b,
    bool bAtStart,
  ) => !a.oneway || aAtStart != bAtStart;

  static FogoMapRoad _join(
    FogoMapRoad a,
    bool aAtStart,
    FogoMapRoad b,
    bool bAtStart,
  ) {
    final List<double> first = a.coordinates;
    final List<double> second = b.coordinates;
    final List<double> coords;
    if (!aAtStart && bAtStart) {
      coords = [...first, ...second.skip(2)];
    } else if (!aAtStart && !bAtStart) {
      coords = [...first, ..._reverse(second).skip(2)];
    } else if (aAtStart && !bAtStart) {
      coords = [...second, ...first.skip(2)];
    } else {
      coords = [..._reverse(first), ...second.skip(2)];
    }
    final List<double> latitudes = [
      for (int i = 0; i < coords.length; i += 2) coords[i],
    ];
    final List<double> longitudes = [
      for (int i = 1; i < coords.length; i += 2) coords[i],
    ];
    return FogoMapRoad(
      roadClass: a.roadClass,
      name: a.name,
      ref: a.ref,
      oneway: a.oneway,
      bridge: a.bridge,
      tunnel: a.tunnel,
      coordinates: coords,
      bbox: [
        latitudes.reduce(math.min),
        longitudes.reduce(math.min),
        latitudes.reduce(math.max),
        longitudes.reduce(math.max),
      ],
    );
  }

  static List<double> _reverse(List<double> coords) => [
    for (int i = coords.length - 2; i >= 0; i -= 2) ...[
      coords[i],
      coords[i + 1],
    ],
  ];

  static bool _isClosed(List<double> coords) =>
      coords.length >= 6 &&
      coords[0] == coords[coords.length - 2] &&
      coords[1] == coords[coords.length - 1];
}

class _Endpoint {
  const _Endpoint(this.roadIndex, this.atStart);
  final int roadIndex;
  final bool atStart;
}

/// Shared absolute Web Mercator coordinates (metres) within one paint pass.
/// Absolute values are stable across pan and zoom, so one frame's cache
/// serves every consumer consistently.
class FogoProjectionCache {
  final Map<(double, double), Offset> _points = {};

  Offset project(double lat, double lng, Offset Function(double, double) fn) =>
      _points.putIfAbsent((lat, lng), () => fn(lat, lng));

  void clear() => _points.clear();
}

class FogoRoadSurface {
  const FogoRoadSurface(this.contours);
  static const FogoRoadSurface empty = FogoRoadSurface(<List<Offset>>[]);
  final List<List<Offset>> contours;
}

/// Pixel-space buffered road geometry preserves widths at all zooms and
/// camera angles while retaining casing, rounded joins and roundabouts.
abstract final class FogoRoadSurfaceBuilder {
  static const double _epsilon = 0.01;
  static const double _miterLimit = 2;
  static const int _capSteps = 8;

  static FogoRoadSurface? build(List<Offset> center, double halfWidth) {
    final List<math.Point<double>> points = [
      for (final Offset point in center) math.Point(point.dx, point.dy),
    ];
    if (points.length < 2 || halfWidth <= 0) return null;
    final bool closed =
        points.length >= 3 && _distance(points.first, points.last) < _epsilon;
    if (closed) {
      do {
        points.removeLast();
      } while (points.length > 1 &&
          _distance(points.first, points.last) < _epsilon);
    }
    _removeDegenerate(points);
    if (points.length < (closed ? 3 : 2)) return null;
    final int segmentCount = closed ? points.length : points.length - 1;
    final List<math.Point<double>> directions = [];
    for (int i = 0; i < segmentCount; i++) {
      final math.Point<double> delta =
          points[(i + 1) % points.length] - points[i];
      final double length = delta.magnitude;
      if (length < _epsilon) continue;
      directions.add(math.Point(delta.x / length, delta.y / length));
    }
    if (directions.length != segmentCount) return null;
    final List<math.Point<double>> left = _buildSide(
      points,
      directions,
      halfWidth,
      1,
      closed,
    );
    final List<math.Point<double>> right = _buildSide(
      points,
      directions,
      halfWidth,
      -1,
      closed,
    );
    if (closed) {
      final double leftArea = _signedArea(left);
      final double rightArea = _signedArea(right);
      if (leftArea.abs() < 1e-6 || rightArea.abs() < 1e-6) return null;
      final List<math.Point<double>> outer = leftArea.abs() > rightArea.abs()
          ? left
          : right;
      final List<math.Point<double>> inner = identical(outer, left)
          ? right
          : left;
      return FogoRoadSurface([
        _offsets(_withWinding(outer, positive: true)),
        _offsets(_withWinding(inner, positive: false)),
      ]);
    }
    final math.Point<double> first = points.first;
    final math.Point<double> last = points.last;
    final List<math.Point<double>> endCap = _capArc(
      last,
      math.atan2(directions.last.y, directions.last.x) + math.pi / 2,
      -math.pi,
      halfWidth,
    );
    final List<math.Point<double>> startCap = _capArc(
      first,
      math.atan2(directions.first.y, directions.first.x) - math.pi / 2,
      -math.pi,
      halfWidth,
    );
    final List<math.Point<double>> outline = _compact([
      ...left,
      ...endCap.skip(1).take(endCap.length - 2),
      ...right.reversed,
      ...startCap.skip(1).take(startCap.length - 2),
    ]);
    return outline.length < 3
        ? null
        : FogoRoadSurface([_offsets(_withWinding(outline, positive: true))]);
  }

  static List<math.Point<double>> _buildSide(
    List<math.Point<double>> points,
    List<math.Point<double>> directions,
    double width,
    int side,
    bool closed,
  ) {
    if (closed) {
      final List<math.Point<double>> chain = [];
      for (int i = 0; i < points.length; i++) {
        chain.addAll(
          _join(
            points[i],
            directions[(i - 1 + directions.length) % directions.length],
            directions[i],
            side,
            width,
          ),
        );
      }
      return _compact(chain);
    }
    final List<math.Point<double>> chain = [
      points.first + _normal(directions.first, side) * width,
    ];
    for (int i = 1; i < points.length - 1; i++) {
      chain.addAll(
        _join(points[i], directions[i - 1], directions[i], side, width),
      );
    }
    chain.add(points.last + _normal(directions.last, side) * width);
    return _compact(chain);
  }

  static List<math.Point<double>> _join(
    math.Point<double> vertex,
    math.Point<double> before,
    math.Point<double> after,
    int side,
    double width,
  ) {
    final double cross = before.x * after.y - before.y * after.x;
    final double delta = math.atan2(
      cross,
      before.x * after.x + before.y * after.y,
    );
    final math.Point<double> start = vertex + _normal(before, side) * width;
    final math.Point<double> end = vertex + _normal(after, side) * width;
    if (delta.abs() < 1e-6) return [end];
    if ((math.pi - delta.abs()).abs() < 1e-5) return [start, end];
    if (delta * side < 0) {
      final double startAngle = math.atan2(
        start.y - vertex.y,
        start.x - vertex.x,
      );
      final int steps = (delta.abs() / (math.pi / 12)).ceil().clamp(1, 24);
      return [
        start,
        for (int i = 1; i <= steps; i++)
          vertex +
              math.Point(
                math.cos(startAngle + delta * i / steps) * width,
                math.sin(startAngle + delta * i / steps) * width,
              ),
      ];
    }
    if (cross.abs() < 1e-8) return [start, end];
    final math.Point<double> between = end - start;
    final double t = (between.x * after.y - between.y * after.x) / cross;
    final math.Point<double> intersection = start + before * t;
    if (!intersection.x.isFinite ||
        !intersection.y.isFinite ||
        _distance(intersection, vertex) > width * _miterLimit) {
      return [start, end];
    }
    return [intersection];
  }

  static List<math.Point<double>> _capArc(
    math.Point<double> center,
    double angle,
    double sweep,
    double radius,
  ) => [
    for (int i = 0; i <= _capSteps; i++)
      center +
          math.Point(
            math.cos(angle + sweep * i / _capSteps) * radius,
            math.sin(angle + sweep * i / _capSteps) * radius,
          ),
  ];

  static void _removeDegenerate(List<math.Point<double>> points) {
    for (int i = points.length - 1; i > 0; i--) {
      if (_distance(points[i], points[i - 1]) < _epsilon) points.removeAt(i);
    }
  }

  static List<math.Point<double>> _compact(List<math.Point<double>> points) {
    final List<math.Point<double>> result = [];
    for (final math.Point<double> point in points) {
      if (result.isEmpty || _distance(result.last, point) >= _epsilon) {
        result.add(point);
      }
    }
    if (result.length > 1 && _distance(result.first, result.last) < _epsilon) {
      result.removeLast();
    }
    return result;
  }

  static List<math.Point<double>> _withWinding(
    List<math.Point<double>> points, {
    required bool positive,
  }) {
    final bool isPositive = _signedArea(points) >= 0;
    return isPositive == positive ? points : points.reversed.toList();
  }

  static double _signedArea(List<math.Point<double>> points) {
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final math.Point<double> a = points[i];
      final math.Point<double> b = points[(i + 1) % points.length];
      area += a.x * b.y - b.x * a.y;
    }
    return area / 2;
  }

  static List<Offset> _offsets(List<math.Point<double>> points) => [
    for (final math.Point<double> point in points) Offset(point.x, point.y),
  ];

  static double _distance(math.Point<double> a, math.Point<double> b) =>
      (a - b).magnitude;
  static math.Point<double> _normal(math.Point<double> direction, int side) =>
      math.Point(-direction.y * side, direction.x * side);
}

class FogoRoadSurfaceCache {
  final Expando<_CachedSurface> _fill = Expando('road fill');
  final Expando<_CachedSurface> _casing = Expando('road casing');

  FogoRoadSurface fillSurface(
    FogoMapRoad road,
    double halfWidth,
    FogoCameraTransform transform,
    FogoProjectionCache projectionCache,
  ) => _surface(_fill, road, halfWidth, transform, projectionCache);

  FogoRoadSurface casingSurface(
    FogoMapRoad road,
    double halfWidth,
    FogoCameraTransform transform,
    FogoProjectionCache projectionCache,
  ) => _surface(_casing, road, halfWidth, transform, projectionCache);

  FogoRoadSurface _surface(
    Expando<_CachedSurface> cache,
    FogoMapRoad road,
    double halfWidthPx,
    FogoCameraTransform transform,
    FogoProjectionCache projectionCache,
  ) {
    // Buffers live in absolute mercator metres keyed by zoom bucket and
    // metre half-width, so pan, rotation and pitch reuse geometry; only a
    // bucket crossing rebuilds (ADR-0006).
    final double zoomBucket = FogoCartography.zoomBucket(transform.camera.zoom);
    final double bucketScale =
        256 *
        math.pow(2, zoomBucket).toDouble() /
        FogoProjection.worldCircumference;
    final double halfWidth = halfWidthPx / bucketScale;
    final _CachedSurface? old = cache[road];
    if (old != null &&
        old.zoomBucket == zoomBucket &&
        old.halfWidth == halfWidth) {
      return old.surface;
    }
    final List<Offset> meters = [
      for (int i = 0; i < road.coordinates.length; i += 2)
        projectionCache.project(
          road.coordinates[i],
          road.coordinates[i + 1],
          (lat, lng) => FogoProjection.project(FogoCoordinate(lat, lng)),
        ),
    ];
    final double step = 8 / bucketScale;
    final double epsilon = 0.05 / bucketScale;
    final FogoRoadSurface surface =
        FogoRoadSurfaceBuilder.build(
          FogoSmooth.polyline(meters, stepPx: step, epsilon: epsilon),
          halfWidth,
        ) ??
        FogoRoadSurface.empty;
    cache[road] = _CachedSurface(zoomBucket, halfWidth, surface);
    return surface;
  }
}

class _CachedSurface {
  const _CachedSurface(this.zoomBucket, this.halfWidth, this.surface);
  final double zoomBucket;
  final double halfWidth;
  final FogoRoadSurface surface;
}

class FogoLabelLayout {
  FogoLabelLayout({this.sameLabelDistance = 350});
  final double sameLabelDistance;
  final List<Rect> _boxes = [];
  final Map<String, List<Offset>> _anchorsByKey = {};

  bool tryPlace({
    required String key,
    required Offset anchor,
    required Rect aabb,
  }) {
    for (final Offset other in _anchorsByKey[key] ?? const <Offset>[]) {
      if ((other - anchor).distance < sameLabelDistance) return false;
    }
    final Rect padded = aabb.inflate(2);
    if (_boxes.any((box) => box.overlaps(padded))) return false;
    _boxes.add(aabb);
    _anchorsByKey.putIfAbsent(key, () => []).add(anchor);
    return true;
  }

  static Rect rotatedAabb(
    Offset center,
    double width,
    double height,
    double angle,
  ) {
    final double cosAngle = math.cos(angle).abs();
    final double sinAngle = math.sin(angle).abs();
    return Rect.fromCenter(
      center: center,
      width: width * cosAngle + height * sinAngle,
      height: width * sinAngle + height * cosAngle,
    );
  }
}

/// Endpoint-preserving curve smoothing for road-class geometry.
///
/// Dense OSM polylines read as flowing ribbons after a Catmull-Rom
/// resample, while turns sharper than [_cornerDegrees] stay crisp. Junction
/// nodes are exact shared endpoints and are never moved, so connected ways
/// stay connected.
abstract final class FogoSmooth {
  static const double _cornerDegrees = 32;

  /// Endpoint-preserving curve smoothing. [stepPx] is the resample step and
  /// [epsilon] the dedupe distance, both in the caller's coordinate space
  /// (screen pixels for strokes, metres for cached road buffers).
  static List<Offset> polyline(
    List<Offset> points, {
    double stepPx = 8,
    double epsilon = 0.05,
  }) {
    if (points.length < 3) return points;
    final List<Offset> clean = <Offset>[points.first];
    for (final Offset point in points.skip(1)) {
      if ((clean.last - point).distance > epsilon) clean.add(point);
    }
    if (clean.length < 3) return clean;
    final double corner = _cornerDegrees * math.pi / 180;
    final List<List<Offset>> runs = [];
    int runStart = 0;
    for (int i = 1; i < clean.length - 1; i++) {
      if (_turn(clean[i - 1], clean[i], clean[i + 1]) > corner) {
        runs.add(_spline(clean, runStart, i, stepPx));
        runStart = i;
      }
    }
    runs.add(_spline(clean, runStart, clean.length - 1, stepPx));
    final List<Offset> out = <Offset>[];
    for (final List<Offset> run in runs) {
      for (final Offset point in run) {
        if (out.isEmpty || (out.last - point).distance > epsilon) {
          out.add(point);
        }
      }
    }
    return out;
  }

  /// Exterior angle between the segments at [mid], in radians.
  static double _turn(Offset a, Offset mid, Offset b) {
    final Offset u = mid - a;
    final Offset v = b - mid;
    final double lengths = u.distance * v.distance;
    if (lengths == 0) return 0;
    return math.acos(((u.dx * v.dx + u.dy * v.dy) / lengths).clamp(-1, 1));
  }

  /// Catmull-Rom resample of clean[from..to]; both ends are exact.
  static List<Offset> _spline(
    List<Offset> clean,
    int from,
    int to,
    double stepPx,
  ) {
    if (to - from < 2) return clean.sublist(from, to + 1);
    final List<Offset> out = <Offset>[];
    for (int i = from; i < to; i++) {
      final Offset p0 = i == from ? clean[from] : clean[i - 1];
      final Offset p1 = clean[i];
      final Offset p2 = clean[i + 1];
      final Offset p3 = i + 2 > to ? clean[to] : clean[i + 2];
      final int steps = math.max(1, ((p2 - p1).distance / stepPx).ceil());
      for (int s = 0; s < steps; s++) {
        out.add(_rom(p0, p1, p2, p3, s / steps));
      }
    }
    out.add(clean[to]);
    return out;
  }

  static Offset _rom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final double t2 = t * t;
    final double t3 = t2 * t;
    return Offset(
      0.5 *
          ((2 * p1.dx) +
              (-p0.dx + p2.dx) * t +
              (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
              (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
      0.5 *
          ((2 * p1.dy) +
              (-p0.dy + p2.dy) * t +
              (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
              (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
    );
  }
}
