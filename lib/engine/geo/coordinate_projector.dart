import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'geo_bounds.dart';
import 'geo_coordinate.dart';

export 'package:vector_math/vector_math_64.dart' show Vector3, Aabb3;

/// Coordenada cartesiana local do motor, em metros.
///
/// Convenção de eixos (destro, Y para cima — mesma do Flutter Scene):
/// - X: leste (east) — cresce para leste da origem.
/// - Y: cima (up) — elevação em metros; 0 = solo. Dados OSM sem altitude
///   não inventam elevação; builders usam offsets explícitos de render.
/// - Z: sul (south) — cresce para o sul; norte = −Z.
/// A origem é definida pelo [CoordinateProjector] (centro da região
/// carregada), garantindo magnitudes pequenas e precisão de float.
typedef WorldCoordinate = Vector3;

/// Limites espaciais em coordenadas de mundo (AABB, metros).
typedef WorldBounds = Aabb3;

/// Projetor geográfico ↔ local para a região de Marília/Vera Cruz/Garça.
///
/// Projeção equiretangular local (adequada para regiões de dezenas de km —
/// erro sub-métrico no corredor Marília–Garça de ~40 km):
///   x = (lon − lon0) · k · cos(lat0)
///   z = (lat0 − lat) · k          (sul positivo, ver convenção acima)
///   y = elevação em metros, 0 quando ausente.
/// com k = π/180 · R, R = 6378137 m (WGS84).
class CoordinateProjector {
  CoordinateProjector(this.origin)
    : _metersPerDegLat = math.pi / 180 * _earthRadiusM,
      _metersPerDegLon =
          math.pi / 180 * _earthRadiusM * math.cos(_rad(origin.latitude));

  /// Origem local (lat/lon que mapeiam para (0, 0, 0)).
  final GeoCoordinate origin;

  static const double _earthRadiusM = 6378137;
  final double _metersPerDegLat;
  final double _metersPerDegLon;

  /// Cria um projetor centrado numa bounds (origem = centro da bounds).
  factory CoordinateProjector.forBounds(GeoBounds bounds) =>
      CoordinateProjector(bounds.center);

  /// Projeção geo → mundo. Elevação ausente vira y = 0.
  Vector3 project(GeoCoordinate c) => Vector3(
    (c.longitude - origin.longitude) * _metersPerDegLon,
    c.elevation ?? 0,
    (origin.latitude - c.latitude) * _metersPerDegLat,
  );

  /// Projeção mundo → geo (inversa exata; elevação preservada se não-zero).
  GeoCoordinate unproject(Vector3 p) => GeoCoordinate(
    origin.latitude - p.z / _metersPerDegLat,
    origin.longitude + p.x / _metersPerDegLon,
    elevation: p.y != 0 ? p.y : null,
  );

  static double _rad(double deg) => deg * math.pi / 180;
}
