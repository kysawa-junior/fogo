import '../geo/geo_coordinate.dart';
import 'map_feature.dart';

/// Área territorial: parques, quadras, água, agricultura etc.
/// Suporta múltiplos anéis por polígono (buracos) e múltiplos polígonos
/// (relações multipolygon), todos em coordenadas geográficas.
class LandArea extends MapFeature {
  const LandArea({
    required super.id,
    required super.tags,
    required this.polygons,
    required this.kind,
  });

  /// Cada polígono: [0] anel externo, demais anéis são buracos.
  final List<List<GeoPolyline>> polygons;

  final LandAreaKind kind;

  String? get name => tags['name'];
}

/// Classificação de áreas para estilo visual e semântica.
enum LandAreaKind {
  park,
  water,
  forest,
  farmland,
  residential,
  industrial,
  commercial,
  education,
  sports,
  parking,
  other;

  static LandAreaKind fromTags(Map<String, String> tags) {
    final leisure = tags['leisure'];
    if (leisure == 'park' || leisure == 'garden' || leisure == 'playground') {
      return LandAreaKind.park;
    }
    if (tags.containsKey('natural')) {
      switch (tags['natural']) {
        case 'water':
        case 'wetland':
          return LandAreaKind.water;
        case 'wood':
          return LandAreaKind.forest;
      }
    }
    if (tags.containsKey('landuse')) {
      switch (tags['landuse']) {
        case 'forest':
          return LandAreaKind.forest;
        case 'farmland':
        case 'orchard':
        case 'meadow':
          return LandAreaKind.farmland;
        case 'residential':
          return LandAreaKind.residential;
        case 'industrial':
          return LandAreaKind.industrial;
        case 'commercial':
          return LandAreaKind.commercial;
        case 'education':
        case 'school':
          return LandAreaKind.education;
        case 'sports':
          return LandAreaKind.sports;
        case 'parking':
          return LandAreaKind.parking;
      }
    }
    if (leisure == 'pitch' || leisure == 'sports_centre') {
      return LandAreaKind.sports;
    }
    if (tags.containsKey('amenity') && tags['amenity'] == 'parking') {
      return LandAreaKind.parking;
    }
    return LandAreaKind.other;
  }
}
