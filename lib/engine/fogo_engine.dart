import 'dart:typed_data';

import 'geo/coordinate_projector.dart';
import 'geo/geo_bounds.dart';
import 'domain/road.dart';
import 'domain/road_network.dart';
import 'geometry/polygon_triangulator.dart';
import 'mesh/building_mesh_builder.dart';
import 'mesh/crossing_mesh_builder.dart';
import 'mesh/road_mesh_builder.dart';
import 'osm/map_topology_builder.dart';
import 'osm/osm_elements.dart';
import 'osm/osm_feature_mapper.dart';
import 'osm/osm_xml_reader.dart';
import 'scene/map_scene.dart';
import 'spatial/spatial_partitioner.dart';

export 'geo/coordinate_projector.dart'
    show CoordinateProjector, WorldBounds, WorldCoordinate, Vector3, Aabb3;
export 'geo/geo_bounds.dart' show GeoBounds;
export 'geo/geo_coordinate.dart' show GeoCoordinate, GeoPolyline, GeoPolygon;
export 'region/region_catalog.dart' show RegionCatalog;
export 'osm/osm_elements.dart' show OsmImportIssue;
export 'scene/camera_controller.dart' show OrbitCamera;
export 'scene/map_scene.dart'
    show MapScene, MapSceneObject, SceneObjectKind, FogoPalette;
export 'scene/render_backend.dart' show RenderBackend;
export 'spatial/spatial_partitioner.dart' show MapTile, TileManager, MapCity;

/// F.O.G.O. 3D Engine — fachada do motor cartográfico.
///
/// Pipeline completo, puro Dart (executável em isolate):
///   OSM XML → [OsmDataStore] → [MapModel] (entidades)
///   → [RoadNetwork] (topologia) → projeção local → malhas 3D
///   → tiles (particionamento) → [MapScene] (upload ao backend).
///
/// O motor não conhece Flutter nem a biblioteca gráfica; a integração
/// com o backend é feita pela camada de aplicação via [RenderBackend].
class FogoEngine {
  FogoEngine._({
    required this.store,
    required this.model,
    required this.network,
    required this.scene,
    required this.projector,
    required this.tileManager,
    required this.geoBounds,
    required this.stats,
  });

  final OsmDataStore store;
  final MapModel model;
  final RoadNetwork network;
  final MapScene scene;
  final CoordinateProjector projector;
  final TileManager tileManager;

  /// Bounds geográficos reais do conteúdo carregado.
  final GeoBounds geoBounds;

  final FogoEngineStats stats;

  /// Problemas não fatais da importação (refs ausentes, geometria
  /// inválida etc.) — também disponível em store.issues.
  List<OsmImportIssue> get issues => store.issues;

  /// Constrói o motor a partir de bytes de um arquivo `.osm`/`.osm.gz`.
  /// Retorna null se o arquivo não produzir conteúdo utilizável (o
  /// chamador decide como reportar).
  static FogoEngine? build(
    Uint8List osmBytes, {
    void Function(String phase, int count)? onProgress,
    OsmFeatureMapper? mapper,
  }) {
    final store = OsmDataStore();
    OsmXmlReader.read(osmBytes, store, onProgress: onProgress);
    if (store.nodeCount == 0) return null;

    onProgress?.call('Interpretando elementos', store.wayCount);
    final m = mapper ?? OsmFeatureMapper();
    final model = m.map(store);

    onProgress?.call('Construindo topologia', model.roads.length);
    final network = MapTopologyBuilder().build(model, store);

    // Bounds geográfico real do carregado (para projeção e enquadramento).
    var west = double.infinity, south = double.infinity;
    var east = -double.infinity, north = -double.infinity;
    for (final node in store.nodes) {
      if (node.lon < west) west = node.lon;
      if (node.lon > east) east = node.lon;
      if (node.lat < south) south = node.lat;
      if (node.lat > north) north = node.lat;
    }
    final geoBounds = GeoBounds(
      west: west,
      south: south,
      east: east,
      north: north,
    );
    final projector = CoordinateProjector.forBounds(geoBounds);

    onProgress?.call('Gerando geometria 3D', model.roads.length);
    final objects = <MapSceneObject>[];

    // Ruas: superfície por polilinha, elevação por camada vertical.
    var triangles = 0;
    for (final road in model.roads) {
      final pts = [for (final p in road.points) projector.project(p)];
      final width = road.properties.widthMeters?.value ?? 5;
      final mesh = RoadMeshBuilder.build(
        pts,
        width,
        yLift: _layerLift(road.properties.layer),
      );
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: road.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.road(road.type),
          kind: SceneObjectKind.road,
        ),
      );
    }

    // Edifícios extrudados.
    for (final building in model.buildings) {
      final rings = [
        for (final ring in building.footprint)
          [for (final p in ring) projector.project(p)],
      ];
      final mesh = BuildingMeshBuilder.build(
        rings,
        heightMeters: building.height.value,
        minHeightMeters: building.minHeightMeters,
      );
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: building.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.building,
          kind: SceneObjectKind.building,
        ),
      );
    }

    // Áreas: superfícies planas com buracos.
    for (final area in model.landAreas) {
      final mesh = merge([
        for (final polygon in area.polygons)
          PolygonTriangulator.triangulateFlat(
            [for (final p in polygon[0]) projector.project(p)],
            [
              for (final hole in polygon.skip(1))
                [for (final p in hole) projector.project(p)],
            ],
            0.02,
          ),
      ]);
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: area.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.land(area.kind),
          kind: SceneObjectKind.landArea,
        ),
      );
    }

    // Travessias e semáforos nas posições reais.
    for (final crossing in model.crossings) {
      final pos = projector.project(crossing.position);
      final mesh = CrossingMeshBuilder.build(
        pos,
        crossing.headingRadians,
        roadWidthMeters: _connectedRoadWidth(crossing.connectedWayIds, model),
        y: _layerLift(0) + 0.08,
      );
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: crossing.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.crossing,
          kind: SceneObjectKind.crossing,
        ),
      );
    }
    for (final signal in model.signals) {
      final pos = projector.project(signal.position);
      final mesh = TrafficSignalMeshBuilder.build(pos, signal.headingRadians);
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: signal.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.signal,
          kind: SceneObjectKind.signal,
        ),
      );
    }

    // Particionamento: tiles reais pela bounds projetada do conteúdo.
    onProgress?.call('Particionando espacialmente', objects.length);
    final worldBounds = _unionBounds(objects);
    final grid = SpatialPartitioner.partition(worldBounds);
    final tiles = TileManager(grid);
    for (final obj in objects) {
      final b = obj.mesh.computeBounds();
      if (b == null) continue;
      final center = Vector3(
        (b.min.x + b.max.x) / 2,
        0,
        (b.min.z + b.max.z) / 2,
      );
      tiles.assign(obj.entityId, b, center);
    }
    for (var i = 0; i < objects.length; i++) {
      final obj = objects[i];
      objects[i] = MapSceneObject(
        entityId: obj.entityId,
        tileId: tiles.ownerTileOf(obj.entityId) ?? 'tile/0_0',
        mesh: obj.mesh,
        color: obj.color,
        kind: obj.kind,
      );
    }

    final scene = MapScene(
      objects: objects,
      worldBounds: worldBounds,
      tileIds: {for (final t in grid) t.id},
    );

    return FogoEngine._(
      store: store,
      model: model,
      network: network,
      scene: scene,
      projector: projector,
      tileManager: tiles,
      geoBounds: geoBounds,
      stats: FogoEngineStats(
        nodeCount: store.nodeCount,
        roadCount: model.roads.length,
        buildingCount: model.buildings.length,
        landAreaCount: model.landAreas.length,
        crossingCount: model.crossings.length,
        signalCount: model.signals.length,
        meshObjectCount: objects.length,
        triangleCount: triangles,
        issueCount: store.issues.length,
      ),
    );
  }

  /// Elevação render por camada vertical OSM (`layer`): aproximação
  /// documentada de 4 m por nível (dica de ordenação, não medida real).
  static double _layerLift(int layer) => (layer.clamp(-2, 3)) * 4.0;

  static double _connectedRoadWidth(Set<String> wayIds, MapModel model) {
    for (final id in wayIds) {
      final feature = model.byId(id);
      if (feature is Road) {
        return feature.properties.widthMeters?.value ?? 6;
      }
    }
    return 6;
  }

  static WorldBounds _unionBounds(List<MapSceneObject> objects) {
    var minX = double.maxFinite, minZ = double.maxFinite;
    var maxX = -double.maxFinite, maxZ = -double.maxFinite;
    for (final obj in objects) {
      final b = obj.mesh.computeBounds();
      if (b == null) continue;
      if (b.min.x < minX) minX = b.min.x;
      if (b.min.z < minZ) minZ = b.min.z;
      if (b.max.x > maxX) maxX = b.max.x;
      if (b.max.z > maxZ) maxZ = b.max.z;
    }
    if (minX == double.maxFinite) {
      return Aabb3.minMax(Vector3(-100, 0, -100), Vector3(100, 0, 100));
    }
    return Aabb3.minMax(Vector3(minX, 0, minZ), Vector3(maxX, 0, maxZ));
  }
}

class FogoEngineStats {
  const FogoEngineStats({
    required this.nodeCount,
    required this.roadCount,
    required this.buildingCount,
    required this.landAreaCount,
    required this.crossingCount,
    required this.signalCount,
    required this.meshObjectCount,
    required this.triangleCount,
    required this.issueCount,
  });

  final int nodeCount;
  final int roadCount;
  final int buildingCount;
  final int landAreaCount;
  final int crossingCount;
  final int signalCount;
  final int meshObjectCount;
  final int triangleCount;
  final int issueCount;
}
