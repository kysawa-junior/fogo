import 'package:fogo_map_sdk/fogo_map_sdk.dart';

/// Região de cobertura do F.O.G.O. — Marília-SP e Garça-SP + corredor.
/// Centros verificados via Nominatim (2026-10). Cobertura efetiva = bbox
/// do manifesto da base (assets/map/manifest.json), extraído do OSM.
abstract final class FogoRegion {
  static const FogoCoordinate mariliaCenter = FogoCoordinate(
    -22.21720,
    -49.95000,
  );
  static const FogoCoordinate garcaCenter = FogoCoordinate(
    -22.22800,
    -49.65881,
  );

  /// Ponto médio do corredor entre as duas cidades (vista inicial).
  static const FogoCoordinate corridorMidpoint = FogoCoordinate(
    -22.2225,
    -49.8044,
  );

  /// Caixas urbanas generosas (incluem bairros e periferia; não são os
  /// limites municipais). min/max em lat,lng.
  static const List<double> mariliaUrbanBox = [-22.31, -50.04, -22.12, -49.85];
  static const List<double> garcaUrbanBox = [-22.32, -49.74, -22.12, -49.58];

  static FogoGeoBounds boxBounds(List<double> b) =>
      FogoGeoBounds(west: b[1], south: b[0], east: b[3], north: b[2]);

  static FogoGeoBounds mariliaBounds() => boxBounds(mariliaUrbanBox);
  static FogoGeoBounds garcaBounds() => boxBounds(garcaUrbanBox);

  /// Região completa carregada na base (Marília + Garça + corredor).
  static const FogoGeoBounds regionBounds = FogoGeoBounds(
    west: -50.04,
    south: -22.31,
    east: -49.59,
    north: -22.13,
  );
}
