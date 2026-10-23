part of 'road_geometry_merger.dart';

/// Endpoint index and the rules deciding whether two way ends may be joined:
/// same style, compatible directions, and one-way direction preserved.
void _addEndpoint(
  Map<(double, double), List<_Endpoint>> index,
  MapRoad road,
  int roadIndex,
  bool atStart,
) {
  final int i = atStart ? 0 : road.flatCoords.length - 2;
  final (double, double) key = (road.flatCoords[i], road.flatCoords[i + 1]);
  index.putIfAbsent(key, () => []).add(_Endpoint(roadIndex, atStart));
}

List<_Endpoint> _candidates(
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

bool _sameStyle(MapRoad a, MapRoad b) =>
    a.cls == b.cls &&
    a.name == b.name &&
    a.ref == b.ref &&
    a.oneway == b.oneway &&
    a.bridge == b.bridge &&
    a.tunnel == b.tunnel;

bool _directionsContinue(MapRoad a, bool aAtStart, MapRoad b, bool bAtStart) {
  final math.Point<double> da = _outwardDirection(a, aAtStart);
  final math.Point<double> db = _outwardDirection(b, bAtStart);
  final double dot = da.x * db.x + da.y * db.y;
  return dot < -math.cos(RoadGeometryMerger._maxDeflection);
}

math.Point<double> _outwardDirection(MapRoad road, bool atStart) {
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

bool _preservesDirection(MapRoad a, bool aAtStart, MapRoad b, bool bAtStart) =>
    !a.oneway || aAtStart != bAtStart;

MapRoad _join(MapRoad a, bool aAtStart, MapRoad b, bool bAtStart) {
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

bool _isClosed(List<double> coords) =>
    coords.length >= 6 &&
    coords[0] == coords[coords.length - 2] &&
    coords[1] == coords[coords.length - 1];

class _Endpoint {
  const _Endpoint(this.roadIndex, this.atStart);

  final int roadIndex;
  final bool atStart;
}
