import 'dart:math' as math;

import '../domain/land_area.dart';
import '../geo/geo_coordinate.dart';

/// Distribuição PROCEDURAL de árvores em áreas verdes — determinística
/// (mesmos dados/parâmetros → mesmas árvores), configurável e restrita:
/// - SÓ dentro do polígono da área (parque/floresta);
/// - NUNCA dentro de edifícios (ponto-em-polígono contra footprints);
/// - NUNCA sobre vias (distância mínima da polilinha projetada);
/// - distância mínima entre árvores (grid hashing);
/// - desativável (buildProceduralTrees = false no Fogo3DStyle).
///
/// As árvores geradas são marcadas `estimated = true` — a UI as
/// diferencia dos dados reais (`natural=tree` do OSM).
abstract final class TreeDistributor {
  static const double _minDistanceMeters = 6.0;
  static const double _roadClearanceMeters = 3.0;

  /// Gera posições determinísticas dentro de [area], evitando
  /// [buildingFootprints] (lat/lon) e [roadPolylines] (lat/lon).
  static List<({double lat, double lon})> distribute({
    required LandArea area,
    required List<List<GeoPolyline>> buildingFootprints,
    required List<GeoPolyline> roadPolylines,
    int maxTrees = 80,
    int seed = 42,
    double minDistance = _minDistanceMeters,
  }) {
    // Só áreas verdes recebem vegetação procedural — parques e
    // florestas, nunca estacionamentos ou quadras.
    if (area.kind != LandAreaKind.park && area.kind != LandAreaKind.forest) {
      return const [];
    }

    final rng = math.Random(seed);
    final results = <({double lat, double lon})>[];
    final placed = <({double lat, double lon})>[];

    // Amostra o primeiro polígono (outer ring) da área.
    for (final polygon in area.polygons) {
      if (polygon.isEmpty) continue;
      final outer = polygon.first;
      if (outer.length < 3) continue;

      // Bounds para amostragem rápida.
      var minLat = double.infinity, maxLat = -double.infinity;
      var minLon = double.infinity, maxLon = -double.infinity;
      for (final p in outer) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
      if (minLat.isInfinite) continue;

      var attempts = 0;
      while (results.length < maxTrees && attempts < maxTrees * 12) {
        attempts++;
        // Determinístico: rng seeded + desvio pelo id da área.
        final lat = minLat + rng.nextDouble() * (maxLat - minLat);
        final lon = minLon + rng.nextDouble() * (maxLon - minLon);

        // 1. Dentro do polígono (outer, ignorando anéis internos — a
        // densidade baixa torna o risco de cair num pátio mínimo, e a
        // verificação de edifícios cobre o caso).
        if (!_pointInPolygon(lat, lon, outer)) continue;

        // 2. Fora de todos os edifícios.
        var inBuilding = false;
        for (final footprint in buildingFootprints) {
          for (final ring in footprint) {
            if (_pointInPolygon(lat, lon, ring)) {
              inBuilding = true;
              break;
            }
          }
          if (inBuilding) break;
        }
        if (inBuilding) continue;

        // 3. Longe das vias (clearance em graus aprox.).
        final minRoadDist = _minRoadDistance(lat, lon, roadPolylines);
        if (minRoadDist < _roadClearanceMeters) continue;

        // 4. Distância mínima entre árvores.
        var tooClose = false;
        for (final p in placed) {
          if (_haversine(lat, lon, p.lat, p.lon) < minDistance) {
            tooClose = true;
            break;
          }
        }
        if (tooClose) continue;

        placed.add((lat: lat, lon: lon));
        results.add((lat: lat, lon: lon));
      }
    }
    return results;
  }

  static bool _pointInPolygon(
    double lat,
    double lon,
    List<GeoCoordinate> ring,
  ) {
    var inside = false;
    var j = ring.length - 1;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[j];
      if ((a.latitude > lat) != (b.latitude > lat) &&
          lon <
              (b.longitude - a.longitude) *
                      (lat - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  static double _minRoadDistance(
    double lat,
    double lon,
    List<List<GeoCoordinate>> polylines,
  ) {
    var best = double.infinity;
    for (final line in polylines) {
      for (var i = 0; i < line.length - 1; i++) {
        final d = _pointToSegment(lat, lon, line[i], line[i + 1]);
        if (d < best) best = d;
      }
    }
    return best;
  }

  static double _pointToSegment(
    double lat,
    double lon,
    GeoCoordinate a,
    GeoCoordinate b,
  ) {
    const mLat = 111320.0;
    final ax = a.longitude * mLat, az = a.latitude * mLat;
    final bx = b.longitude * mLat, bz = b.latitude * mLat;
    final px = lon * mLat, pz = lat * mLat;
    final abx = bx - ax, abz = bz - az;
    final lenSq = abx * abx + abz * abz;
    if (lenSq == 0) {
      return math.sqrt((px - ax) * (px - ax) + (pz - az) * (pz - az));
    }
    var t = ((px - ax) * abx + (pz - az) * abz) / lenSq;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * abx, cz = az + t * abz;
    return math.sqrt((px - cx) * (px - cx) + (pz - cz) * (pz - cz));
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final s1 = math.sin(dLat / 2), s2 = math.sin(dLon / 2);
    final h =
        s1 * s1 +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            s2 *
            s2;
    return 2 * r * math.asin(math.sqrt(h));
  }
}
