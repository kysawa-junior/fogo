import 'package:flutter/foundation.dart';

import 'vector_data/vector_data.dart';

/// Preserves zoom visibility thresholds used by the legacy geometry tests.
abstract final class FogoVectorPainter {
  @visibleForTesting
  static bool isRoadClassVisible(RoadClass cls, double zoom) => switch (cls) {
    RoadClass.motorway || RoadClass.trunk => true,
    RoadClass.primary => zoom >= 7.5,
    RoadClass.secondary => zoom >= 9,
    RoadClass.tertiary ||
    RoadClass.unclassified ||
    RoadClass.residential => zoom >= 11.5,
    RoadClass.other => zoom >= 14,
    RoadClass.track => zoom >= 13,
    RoadClass.service => zoom >= 14.5,
    RoadClass.path => zoom >= 16,
  };
}
