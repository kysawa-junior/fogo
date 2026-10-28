import '../geo/geo_coordinate.dart';
import 'map_feature.dart';

/// Ponto de interesse com posição real (ENG-0008: camada `poi_label`
/// do MVT Mapbox; futuramente `amenity`/`shop` do OSM).
///
/// `marker == true` recebe um marcador 3D mínimo (disco no chão) para
/// picking; rótulos puros (`place_label`, `transit_stop_label`,
/// `natural_label`) ficam `marker == false` — só aparecem como rótulo.
class Poi extends MapFeature {
  const Poi({
    required super.id,
    required super.tags,
    required this.position,
    this.marker = true,
  });

  final GeoCoordinate position;

  /// Recebe disco 3D no chão (selecionável por raycast)?
  final bool marker;

  String? get name => tags['name'];

  /// Importância do MVT (`filterrank` 0–5 / `symbolrank`); menor = mais
  /// importante. Nulo quando a fonte não fornece.
  int? get rank => int.tryParse(tags['filterrank'] ?? tags['symbolrank'] ?? '');
}
