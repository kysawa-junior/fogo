import 'dart:math' as math;

import '../vector_data/vector_data.dart';

part 'surface_builder.dart';
part 'surface_cache.dart';

/// Buffer polygon(s) derived from an OSM centerline. Closed ways contain an
/// outer contour and a reverse-winding inner contour, leaving their center
/// transparent under nonzero fill.
class RoadSurface {
  const RoadSurface(this.contours);

  static const RoadSurface empty = RoadSurface(<List<double>>[]);

  /// Each contour is a flat sequence of latitude/longitude pairs.
  final List<List<double>> contours;
}
