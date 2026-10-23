part of 'road_geometry_merger.dart';

/// Drops repeated ways (same style and same geometry, forward or reversed).
/// One-way ways only match forward, so opposing carriageways survive.
List<MapRoad> _deduplicate(Iterable<MapRoad> source) {
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

bool _sameRoad(MapRoad a, MapRoad b) {
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

List<double> _reverse(List<double> coords) => [
  for (int i = coords.length - 2; i >= 0; i -= 2) ...[coords[i], coords[i + 1]],
];
