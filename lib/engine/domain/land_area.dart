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

  // Reclassificação dos antigos "other": amenity de edifícios de
  // interesse (tags reais do extrato regional) — hierarquia acima de
  // parques e água.
  fuelStation,
  police,
  hospital,
  placeOfWorship,
  stadium,
  other;

  /// Rótulo em português (painel de seleção; o .name era em inglês).
  String get label => switch (this) {
    park => 'Parque',
    water => 'Água',
    forest => 'Floresta',
    farmland => 'Zona agrícola',
    residential => 'Zona residencial',
    industrial => 'Zona industrial',
    commercial => 'Zona comercial',
    education => 'Educação',
    sports => 'Esportes',
    parking => 'Estacionamento',
    fuelStation => 'Posto de gasolina',
    police => 'Delegacia',
    hospital => 'Hospital',
    placeOfWorship => 'Local religioso',
    stadium => 'Estádio',
    other => 'Outros',
  };

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
        // Vegetação baixa/uso verde: parque (223 ocorrências no
        // extrato regional — antes caiam em "other" e z-fightavam
        // com parques coplanares).
        case 'grass':
        case 'village_green':
        case 'recreation_ground':
          return LandAreaKind.park;
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
    if (leisure == 'stadium' || leisure == 'arena') {
      return LandAreaKind.stadium;
    }
    if (leisure == 'pitch' || leisure == 'sports_centre') {
      return LandAreaKind.sports;
    }
    // Amenity em área: edifícios de interesse (posto, delegacia,
    // hospital, templo) — antes caiam no genérico "other".
    if (tags.containsKey('amenity')) {
      switch (tags['amenity']) {
        case 'fuel':
          return LandAreaKind.fuelStation;
        case 'police':
          return LandAreaKind.police;
        case 'hospital':
        case 'clinic':
          return LandAreaKind.hospital;
        case 'place_of_worship':
          return LandAreaKind.placeOfWorship;
        case 'parking':
          return LandAreaKind.parking;
      }
    }
    return LandAreaKind.other;
  }
}
