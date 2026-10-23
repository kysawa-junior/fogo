import 'dart:math' as math;

import '../vector_data/vector_data.dart';

part 'road_deduplication.dart';
part 'road_join.dart';

/// Dissolves unambiguous, continuous OSM ways for rendering only. Source cell
/// records remain untouched; equal r5 coordinates stand in for unavailable
/// OSM node IDs.
///
/// The merge loop lives here; dedup and the join rules live in the sibling
/// parts (`road_deduplication.dart`, `road_join.dart`).
abstract final class RoadGeometryMerger {
  static const double _maxDeflection = math.pi * 5 / 6;

  static List<MapRoad> merge(Iterable<MapRoad> source) {
    List<MapRoad> roads = _deduplicate(source);
    while (true) {
      final Map<(double, double), List<_Endpoint>> endpoints = {};
      for (int i = 0; i < roads.length; i++) {
        final MapRoad road = roads[i];
        if (road.pointCount < 2 || _isClosed(road.flatCoords)) continue;
        _addEndpoint(endpoints, road, i, true);
        _addEndpoint(endpoints, road, i, false);
      }

      final List<MapRoad> next = [];
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
}
