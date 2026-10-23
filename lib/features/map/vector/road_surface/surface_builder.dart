part of 'road_surface.dart';

/// Builds constant-width road surfaces using local metric offsets.
class RoadSurfaceBuilder {
  static const double _pointEpsilon = 0.01;
  static const double _miterLimit = 2;
  static const int _capSteps = 8;

  /// Returns [null] for a line too short to form a surface.
  static RoadSurface? build(List<double> center, double halfMeters) {
    final int count = center.length ~/ 2;
    if (count < 2 || halfMeters <= 0) return null;

    final double lat0 = center[0];
    final double lng0 = center[1];
    final double cosLat = math.cos(lat0 * math.pi / 180.0);
    const double mLat = 111132.0;
    final double mLng = 111320.0 * cosLat;
    if (mLng.abs() < 1e-6) return null;

    final List<math.Point<double>> points = [
      for (int i = 0; i < count; i++)
        math.Point(
          (center[i * 2 + 1] - lng0) * mLng,
          (center[i * 2] - lat0) * mLat,
        ),
    ];

    // OSM closed ways repeat their first coordinate at the end. Remove that
    // duplicate, then include the closing edge explicitly below.
    final bool closed =
        points.length >= 3 &&
        _distance(points.first, points.last) < _pointEpsilon;
    if (closed) {
      do {
        points.removeLast();
      } while (points.length > 1 &&
          _distance(points.first, points.last) < _pointEpsilon);
    }
    _removeDegeneratePoints(points);
    if (points.length < (closed ? 3 : 2)) return null;

    final int segmentCount = closed ? points.length : points.length - 1;
    final List<math.Point<double>> directions = [];
    for (int i = 0; i < segmentCount; i++) {
      final math.Point<double> a = points[i];
      final math.Point<double> b = points[(i + 1) % points.length];
      final math.Point<double> delta = b - a;
      final double length = delta.magnitude;
      if (length < _pointEpsilon) continue;
      directions.add(math.Point(delta.x / length, delta.y / length));
    }
    if (directions.length != segmentCount) return null;

    final List<math.Point<double>> left = _buildSide(
      points,
      directions,
      halfMeters,
      1,
      closed,
    );
    final List<math.Point<double>> right = _buildSide(
      points,
      directions,
      halfMeters,
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
      return RoadSurface([
        _toFlat(_withWinding(outer, positive: true), lat0, lng0, mLat, mLng),
        _toFlat(_withWinding(inner, positive: false), lat0, lng0, mLat, mLng),
      ]);
    }

    final math.Point<double> first = points.first;
    final math.Point<double> last = points.last;
    final math.Point<double> firstDirection = directions.first;
    final math.Point<double> lastDirection = directions.last;
    final List<math.Point<double>> endCap = _capArc(
      last,
      math.atan2(lastDirection.y, lastDirection.x) + math.pi / 2,
      -math.pi,
      halfMeters,
    );
    final List<math.Point<double>> startCap = _capArc(
      first,
      math.atan2(firstDirection.y, firstDirection.x) - math.pi / 2,
      -math.pi,
      halfMeters,
    );

    final List<math.Point<double>> outline = [
      ...left,
      ...endCap.skip(1).take(endCap.length - 2),
      ...right.reversed,
      ...startCap.skip(1).take(startCap.length - 2),
    ];
    final List<math.Point<double>> compacted = _compact(outline);
    if (compacted.length < 3) return null;
    return RoadSurface([
      _toFlat(_withWinding(compacted, positive: true), lat0, lng0, mLat, mLng),
    ]);
  }

  static List<math.Point<double>> _buildSide(
    List<math.Point<double>> points,
    List<math.Point<double>> directions,
    double halfWidth,
    int side,
    bool closed,
  ) {
    if (closed) {
      final List<math.Point<double>> chain = [];
      for (int i = 0; i < points.length; i++) {
        final math.Point<double> previous =
            directions[(i - 1 + directions.length) % directions.length];
        final math.Point<double> next = directions[i];
        chain.addAll(_join(points[i], previous, next, side, halfWidth));
      }
      return _compact(chain);
    }

    final List<math.Point<double>> chain = [
      points.first + _normal(directions.first, side) * halfWidth,
    ];
    for (int i = 1; i < points.length - 1; i++) {
      chain.addAll(
        _join(points[i], directions[i - 1], directions[i], side, halfWidth),
      );
    }
    chain.add(points.last + _normal(directions.last, side) * halfWidth);
    return _compact(chain);
  }

  /// Outer side receives a circular arc. Inner side receives the intersection
  /// of the two offset lines, with a bevel fallback when the miter exceeds 2h.
  static List<math.Point<double>> _join(
    math.Point<double> vertex,
    math.Point<double> before,
    math.Point<double> after,
    int side,
    double halfWidth,
  ) {
    final double cross = before.x * after.y - before.y * after.x;
    final double dot = before.x * after.x + before.y * after.y;
    final double delta = math.atan2(cross, dot);
    final math.Point<double> start = vertex + _normal(before, side) * halfWidth;
    final math.Point<double> end = vertex + _normal(after, side) * halfWidth;

    if (delta.abs() < 1e-6) return [end];
    // A near reversal has no stable offset-line intersection or unique outer
    // side. Bevel both offsets instead of producing an unbounded spike.
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
                math.cos(startAngle + delta * i / steps) * halfWidth,
                math.sin(startAngle + delta * i / steps) * halfWidth,
              ),
      ];
    }

    final double denominator = cross;
    if (denominator.abs() < 1e-8) return [start, end];
    final math.Point<double> between = end - start;
    final double t = (between.x * after.y - between.y * after.x) / denominator;
    final math.Point<double> intersection = start + before * t;
    if (!intersection.x.isFinite ||
        !intersection.y.isFinite ||
        _distance(intersection, vertex) > halfWidth * _miterLimit) {
      return [start, end];
    }
    return [intersection];
  }

  static List<math.Point<double>> _capArc(
    math.Point<double> center,
    double startAngle,
    double sweep,
    double radius,
  ) => [
    for (int i = 0; i <= _capSteps; i++)
      center +
          math.Point(
            math.cos(startAngle + sweep * i / _capSteps) * radius,
            math.sin(startAngle + sweep * i / _capSteps) * radius,
          ),
  ];

  static void _removeDegeneratePoints(List<math.Point<double>> points) {
    for (int i = points.length - 1; i > 0; i--) {
      if (_distance(points[i], points[i - 1]) < _pointEpsilon) {
        points.removeAt(i);
      }
    }
  }

  static List<math.Point<double>> _compact(List<math.Point<double>> points) {
    final List<math.Point<double>> out = [];
    for (final math.Point<double> point in points) {
      if (out.isEmpty || _distance(out.last, point) >= _pointEpsilon) {
        out.add(point);
      }
    }
    if (out.length > 1 && _distance(out.first, out.last) < _pointEpsilon) {
      out.removeLast();
    }
    return out;
  }

  static List<math.Point<double>> _withWinding(
    List<math.Point<double>> points, {
    required bool positive,
  }) {
    final bool hasPositiveArea = _signedArea(points) >= 0;
    return hasPositiveArea == positive ? points : points.reversed.toList();
  }

  static double _signedArea(List<math.Point<double>> points) {
    if (points.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final math.Point<double> a = points[i];
      final math.Point<double> b = points[(i + 1) % points.length];
      area += a.x * b.y - b.x * a.y;
    }
    return area / 2;
  }

  static List<double> _toFlat(
    List<math.Point<double>> points,
    double lat0,
    double lng0,
    double mLat,
    double mLng,
  ) => [
    for (final math.Point<double> point in points) ...[
      lat0 + point.y / mLat,
      lng0 + point.x / mLng,
    ],
  ];

  static double _distance(math.Point<double> a, math.Point<double> b) =>
      (a - b).magnitude;

  static math.Point<double> _normal(math.Point<double> direction, int side) =>
      math.Point(-direction.y * side, direction.x * side);
}
