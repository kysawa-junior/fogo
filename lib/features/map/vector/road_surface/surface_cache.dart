part of 'road_surface.dart';

/// Cache of derived polygon contours per zoom bucket and requested meter
/// width. Expando releases entries when their MapRoad keys are no longer used.
class RoadSurfaceCache {
  RoadSurfaceCache(this.bucket);

  final double bucket;
  final Expando<_CachedRoadSurface> _fill = Expando('fill');
  final Expando<_CachedRoadSurface> _casing = Expando('casing');

  static double bucketFor(double zoom) => (zoom * 4).round() / 4.0;

  RoadSurface fillSurface(MapRoad road, double halfMeters) =>
      _surface(_fill, road, halfMeters);

  RoadSurface casingSurface(MapRoad road, double halfMeters) =>
      _surface(_casing, road, halfMeters);

  RoadSurface _surface(
    Expando<_CachedRoadSurface> cache,
    MapRoad road,
    double halfMeters,
  ) {
    final _CachedRoadSurface? cached = cache[road];
    if (cached != null && cached.halfMeters == halfMeters) {
      return cached.surface;
    }
    final RoadSurface surface =
        RoadSurfaceBuilder.build(road.flatCoords, halfMeters) ??
        RoadSurface.empty;
    cache[road] = _CachedRoadSurface(halfMeters, surface);
    return surface;
  }
}

class _CachedRoadSurface {
  const _CachedRoadSurface(this.halfMeters, this.surface);

  final double halfMeters;
  final RoadSurface surface;
}
