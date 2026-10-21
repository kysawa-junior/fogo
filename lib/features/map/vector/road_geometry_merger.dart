import 'dart:math' as math;

import 'vector_data.dart';

/// Dissolves unambiguous, continuous OSM ways for rendering only. Source cell
/// records remain untouched; equal r5 coordinates stand in for unavailable
/// OSM node IDs.
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

  static List<MapRoad> _deduplicate(Iterable<MapRoad> source) {
    final Map<int, List<MapRoad>> buckets = {};
    final List<MapRoad> unique = [];
    for (final MapRoad road in source) {
      final int fieldsHash = Object.hash(
        road.cls,
        road.name,
        road.ref,
        road.oneway,
        road.bridge,
        road.tunnel,
      );
      final int forwardHash = Object.hash(
        fieldsHash,
        Object.hashAll(road.flatCoords),
      );
      final int reverseHash = Object.hash(
        fieldsHash,
        Object.hashAll(_reverse(road.flatCoords)),
      );
      final Iterable<int> hashes = road.oneway
          ? [forwardHash]
          : {forwardHash, reverseHash};
      bool duplicate = false;
      for (final int hash in hashes) {
        final List<MapRoad> bucket = buckets[hash] ?? const <MapRoad>[];
        if (bucket.any((MapRoad other) => _sameRoad(other, road))) {
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

  static bool _sameRoad(MapRoad a, MapRoad b) {
    if (a.cls != b.cls ||
        a.name != b.name ||
        a.ref != b.ref ||
        a.oneway != b.oneway ||
        a.bridge != b.bridge ||
        a.tunnel != b.tunnel ||
        a.flatCoords.length != b.flatCoords.length) {
      return false;
    }
    bool sameForward = true;
    bool sameReverse = !a.oneway;
    for (int i = 0; i < a.flatCoords.length; i += 2) {
      sameForward &=
          a.flatCoords[i] == b.flatCoords[i] &&
          a.flatCoords[i + 1] == b.flatCoords[i + 1];
      final int reverseIndex = b.flatCoords.length - 2 - i;
      sameReverse &=
          a.flatCoords[i] == b.flatCoords[reverseIndex] &&
          a.flatCoords[i + 1] == b.flatCoords[reverseIndex + 1];
    }
    return sameForward || sameReverse;
  }

  static void _addEndpoint(
    Map<(double, double), List<_Endpoint>> index,
    MapRoad road,
    int roadIndex,
    bool atStart,
  ) {
    final int i = atStart ? 0 : road.flatCoords.length - 2;
    final (double, double) key = (road.flatCoords[i], road.flatCoords[i + 1]);
    index.putIfAbsent(key, () => []).add(_Endpoint(roadIndex, atStart));
  }

  static List<_Endpoint> _candidates(
    List<MapRoad> roads,
    Map<(double, double), List<_Endpoint>> endpoints,
    int roadIndex,
    bool atStart,
  ) {
    final MapRoad road = roads[roadIndex];
    final int i = atStart ? 0 : road.flatCoords.length - 2;
    final (double, double) key = (road.flatCoords[i], road.flatCoords[i + 1]);
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

  static bool _sameStyle(MapRoad a, MapRoad b) =>
      a.cls == b.cls &&
      a.name == b.name &&
      a.ref == b.ref &&
      a.oneway == b.oneway &&
      a.bridge == b.bridge &&
      a.tunnel == b.tunnel;

  static bool _directionsContinue(
    MapRoad a,
    bool aAtStart,
    MapRoad b,
    bool bAtStart,
  ) {
    final math.Point<double> da = _outwardDirection(a, aAtStart);
    final math.Point<double> db = _outwardDirection(b, bAtStart);
    final double dot = da.x * db.x + da.y * db.y;
    return dot < -math.cos(_maxDeflection);
  }

  static math.Point<double> _outwardDirection(MapRoad road, bool atStart) {
    final List<double> coords = road.flatCoords;
    final int endpoint = atStart ? 0 : coords.length - 2;
    final int adjacent = atStart ? 2 : coords.length - 4;
    final double lat = coords[endpoint];
    final double dx =
        (coords[adjacent + 1] - coords[endpoint + 1]) *
        111320.0 *
        math.cos(lat * math.pi / 180.0);
    final double dy = (coords[adjacent] - lat) * 111132.0;
    final double length = math.sqrt(dx * dx + dy * dy);
    return length == 0
        ? const math.Point(0, 0)
        : math.Point(dx / length, dy / length);
  }

  static bool _preservesDirection(
    MapRoad a,
    bool aAtStart,
    MapRoad b,
    bool bAtStart,
  ) => !a.oneway || aAtStart != bAtStart;

  static MapRoad _join(MapRoad a, bool aAtStart, MapRoad b, bool bAtStart) {
    final List<double> first = a.flatCoords;
    final List<double> second = b.flatCoords;
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
    return MapRoad(
      cls: a.cls,
      name: a.name,
      ref: a.ref,
      oneway: a.oneway,
      bridge: a.bridge,
      tunnel: a.tunnel,
      flatCoords: coords,
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
