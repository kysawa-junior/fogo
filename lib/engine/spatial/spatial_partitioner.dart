import '../geo/coordinate_projector.dart';
import '../geo/geo_bounds.dart';

/// Tile do mapa: setor espacial retangular (meters) agrupando entidades.
/// A política de elementos que atravessam fronteiras: a ENTIDADE não é
/// duplicada — o tile registra o id da entidade cujo AABB o toca, e o
/// objeto gráfico pertence ao tile do CENTROIDE (uma única vez); tiles
/// vizinhos consultam a mesma entidade por id estável.
class MapTile {
  MapTile({required this.id, required this.bounds, this.tileLevel = 0});

  /// Id estável: `tile/col_row`.
  final String id;
  final WorldBounds bounds;

  /// Nível de detalhe (reservado p/ LOD futuro; 0 = base).
  final int tileLevel;

  final Set<String> entityIds = {};

  bool get isEmpty => entityIds.isEmpty;

  bool intersectsAabb(WorldBounds other) =>
      bounds.min.x <= other.max.x &&
      bounds.max.x >= other.min.x &&
      bounds.min.z <= other.max.z &&
      bounds.max.z >= other.min.z;

  bool containsCenter(Vector3 p) =>
      p.x >= bounds.min.x &&
      p.x <= bounds.max.x &&
      p.z >= bounds.min.z &&
      p.z <= bounds.max.z;
}

/// Cidade/área do catálogo regional.
class MapCity {
  const MapCity({
    required this.id,
    required this.name,
    required this.bounds,
    this.osmAssetPath,
  });

  final String id;
  final String name;

  /// Limites urbanos (WGS84) — caixas generosas, não limites municipais.
  final GeoBounds bounds;

  /// Arquivo `.osm`/`.osm.gz` empacotado (asset), se houver; o usuário
  /// também pode importar qualquer arquivo via seletor.
  final String? osmAssetPath;
}

/// Grade espacial: divide a região em tiles de `cellMeters`.
/// Primeira versão: uma única resolução; LOD futuro pode empilhar níveis
/// sem alterar entidades nem tiles existentes.
class SpatialPartitioner {
  static const double defaultCellMeters = 800;

  /// Cria os tiles que cobrem `worldBounds`.
  static List<MapTile> partition(
    WorldBounds worldBounds, {
    double cellMeters = defaultCellMeters,
  }) {
    final tiles = <MapTile>[];
    final minCol = (worldBounds.min.x / cellMeters).floor();
    final maxCol = (worldBounds.max.x / cellMeters).floor();
    final minRow = (worldBounds.min.z / cellMeters).floor();
    final maxRow = (worldBounds.max.z / cellMeters).floor();
    for (var col = minCol; col <= maxCol; col++) {
      for (var row = minRow; row <= maxRow; row++) {
        tiles.add(
          MapTile(
            id: 'tile/${col}_$row',
            bounds: Aabb3.minMax(
              Vector3(col * cellMeters, 0, row * cellMeters),
              Vector3((col + 1) * cellMeters, 0, (row + 1) * cellMeters),
            ),
          ),
        );
      }
    }
    return tiles;
  }
}

/// Gerencia os tiles: atribuição de entidades, cache de geometria por
/// tile e consultas. Pronto para carregar/descarregar por tile quando a
/// região não couber inteira em cena (v1 carrega tudo, agrupado por tile,
/// permitindo toggle e futuras janelas de visibilidade).
class TileManager {
  final Map<String, MapTile> tiles = {};

  /// entityId → tile dono do objeto gráfico (tile do centroide).
  final Map<String, String> ownerTileByEntity = {};

  TileManager(List<MapTile> grid) {
    for (final t in grid) {
      tiles[t.id] = t;
    }
  }

  /// Atribui uma entidade a todos os tiles tocados (registro) e define o
  /// tile dono pelo centroide. `meshBounds` = AABB da geometria projetada.
  void assign(String entityId, WorldBounds meshBounds, Vector3 center) {
    for (final tile in tiles.values) {
      if (tile.intersectsAabb(meshBounds)) {
        tile.entityIds.add(entityId);
      }
    }
    final owner = tileOfPoint(center);
    if (owner != null) {
      ownerTileByEntity[entityId] = owner.id;
    } else {
      // Centroide fora da grade (dados além da bounds da região): cai no
      // tile mais próximo — nunca perde renderização.
      MapTile? nearest;
      var bestDist = double.infinity;
      for (final tile in tiles.values) {
        final cx = (tile.bounds.min.x + tile.bounds.max.x) / 2;
        final cz = (tile.bounds.min.z + tile.bounds.max.z) / 2;
        final d =
            (cx - center.x) * (cx - center.x) +
            (cz - center.z) * (cz - center.z);
        if (d < bestDist) {
          bestDist = d;
          nearest = tile;
        }
      }
      if (nearest != null) ownerTileByEntity[entityId] = nearest.id;
    }
  }

  String? ownerTileOf(String entityId) => ownerTileByEntity[entityId];

  MapTile? tileOfPoint(Vector3 p) {
    for (final tile in tiles.values) {
      if (tile.containsCenter(p)) return tile;
    }
    return null;
  }
}
