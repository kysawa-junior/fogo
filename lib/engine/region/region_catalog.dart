import '../geo/geo_bounds.dart';
import '../spatial/spatial_partitioner.dart' show MapCity;

/// Catálogo regional do F.O.G.O.: Marília-SP, Vera Cruz-SP, Garça-SP e o
/// corredor entre elas. Caixas urbanas generosas (não são limites
/// municipais); arquivos `.osm` são configuráveis por cidade.
///
/// Fontes dos dados empacotados: extratos reais do OpenStreetMap
/// (© OpenStreetMap contributors) gerados a partir do PBF local — ver
/// `tool/map_data/README.md`. Sem arquivo empacotado, o usuário importa
/// qualquer `.osm` via seletor de arquivos.
abstract final class RegionCatalog {
  static const mariliaBounds = GeoBounds(
    west: -49.975,
    south: -22.235,
    east: -49.925,
    north: -22.200,
  );

  static const veraCruzBounds = GeoBounds(
    west: -49.849,
    south: -22.236,
    east: -49.799,
    north: -22.206,
  );

  static const garcaBounds = GeoBounds(
    west: -49.684,
    south: -22.245,
    east: -49.634,
    north: -22.210,
  );

  static const MapCity marilia = MapCity(
    id: 'marilia',
    name: 'Marília-SP',
    bounds: mariliaBounds,
    osmAssetPath: 'assets/map/osm/marilia.osm.gz',
  );

  static const MapCity veraCruz = MapCity(
    id: 'vera-cruz',
    name: 'Vera Cruz-SP',
    bounds: veraCruzBounds,
    osmAssetPath: 'assets/map/osm/vera-cruz.osm.gz',
  );

  static const MapCity garca = MapCity(
    id: 'garca',
    name: 'Garça-SP',
    bounds: garcaBounds,
    osmAssetPath: 'assets/map/osm/garca.osm.gz',
  );

  static const List<MapCity> cities = [marilia, veraCruz, garca];

  static MapCity byId(String id) =>
      cities.firstWhere((c) => c.id == id, orElse: () => marilia);
}
