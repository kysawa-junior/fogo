import 'dart:math' as math;
import 'dart:typed_data';

import 'geo/coordinate_projector.dart';
import 'geo/geo_bounds.dart';
import 'geo/geo_coordinate.dart';
import 'domain/building.dart';
import 'domain/land_area.dart';
import 'domain/pedestrian_crossing.dart';
import 'domain/poi.dart';
import 'domain/road_marking.dart';
import 'domain/vegetation.dart';
import 'domain/road.dart';
import 'domain/road_network.dart';
import 'domain/road_type.dart' show RoadType;
import 'geometry/polygon_triangulator.dart';
import 'geometry/mesh_data.dart';
import 'mesh/building_mesh_builder.dart';
import 'mesh/amenity_mesh_builder.dart';
import 'mesh/box_builder.dart';
import 'mesh/crossing_mesh_builder.dart';
import 'mesh/junction_mesh_builder.dart';
import 'mesh/road_annotation_builder.dart';
import 'mesh/road_mesh_builder.dart';
import 'mesh/tree_distributor.dart';
import 'mesh/tree_mesh_builder.dart';
import 'mesh/slab_mesh_builder.dart';
import 'osm/map_topology_builder.dart';
import 'osm/osm_elements.dart';
import 'osm/osm_feature_mapper.dart';
import 'osm/road_deduplicator.dart';
import 'osm/osm_xml_reader.dart';
import 'region/region_catalog.dart';
import 'scene/map_scene.dart';
import 'scene/map_2d_scene.dart';
import 'scene/road_annotations.dart';
import 'scene/vehicle_system.dart';
import 'scene/visual_style.dart';
import 'spatial/spatial_partitioner.dart';

export 'geo/coordinate_projector.dart'
    show CoordinateProjector, WorldBounds, WorldCoordinate, Vector3, Aabb3;
export 'geo/geo_bounds.dart' show GeoBounds;
export 'geo/geo_coordinate.dart' show GeoCoordinate, GeoPolyline, GeoPolygon;
export 'region/region_catalog.dart' show RegionCatalog;
export 'osm/osm_elements.dart' show OsmImportIssue;
export 'scene/camera_controller.dart' show OrbitCamera;
export 'scene/vehicle_system.dart'
    show VehicleFleet, Vehicle, VehicleKind, kVehicleSurfaceLift;
export 'scene/map_scene.dart'
    show
        MapScene,
        MapSceneObject,
        SceneObjectKind,
        FogoPalette,
        BuildingFootprintBatch;
export 'scene/road_annotations.dart'
    show RoadAnnotationBatch, RoadNamePlacement;
export 'domain/road_properties.dart' show RoadDirection;
export 'scene/map_2d_scene.dart' show Map2DScene, Map2DStroke, Map2DFill;
export 'scene/render_backend.dart' show RenderBackend;
export 'scene/visual_style.dart' show Fogo3DStyle;
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
    required this.map2d,
    required this.projector,
    required this.tileManager,
    required this.vehicles,
    required this.geoBounds,
    required this.stats,
  });

  final OsmDataStore store;
  final MapModel model;
  final RoadNetwork network;
  final MapScene scene;

  /// Cena 2D independente (modo mapa): vias + áreas + footprints como
  /// primitivas leves, sem mesh 3D — visão geral desenhada em canvas.
  final Map2DScene map2d;
  final CoordinateProjector projector;
  final TileManager tileManager;

  /// Frota simulada (viaturas de polícia e bombeiro circulando pela
  /// malha viária). Tick pelo dono único da câmera (Map2DView).
  final VehicleFleet vehicles;

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
    Fogo3DStyle style = Fogo3DStyle.standard,
  }) {
    final store = OsmDataStore();
    OsmXmlReader.read(osmBytes, store, onProgress: onProgress);
    if (store.nodeCount == 0) return null;

    onProgress?.call('Interpretando elementos', store.wayCount);
    final m = mapper ?? OsmFeatureMapper();
    final model = m.map(store);

    // Deduplicação SEGURA (mesmos nós OSM + mesmo perfil vertical +
    // mesma semântica). Ambíguas são preservadas e registradas.
    onProgress?.call('Deduplicando vias', model.roads.length);
    final dedup = RoadDeduplicator.dedupe(model.roads, store);
    model.roads
      ..clear()
      ..addAll(dedup.roads);
    model.indexAll();

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

    // Viaturas simuladas: grafo dirigível da rede (oneway do OSM
    // respeitado) — circulam nas 3 cidades da região.
    onProgress?.call('Simulando viaturas', network.segments.length);
    final vehicles = VehicleFleet(
      edges: _vehicleEdges(network, model, projector),
      vehicleCount: 10,
    );

    onProgress?.call('Gerando geometria 3D', model.roads.length);
    final objects = <MapSceneObject>[];
    final roadAnnotationGeometry = <RoadAnnotationGeometry>[];
    // Primitivas 2D (modo mapa): coletadas NOS MESMOS loops — mesmos
    // filtros, sem reprojeção.
    final strokes2d = <Map2DStroke>[];
    final fills2d = <Map2DFill>[];

    // Ruas: superfície por polilinha, elevação por camada vertical.
    var triangles = 0;
    for (final road in model.roads) {
      final pts = [for (final p in road.points) projector.project(p)];
      final width = road.properties.widthMeters?.value ?? 5;
      final roadSurfaceY = _roadLift(
        layer: road.properties.layer,
        bridge: road.properties.bridge,
        tunnel: road.properties.tunnel,
        type: road.type,
      );
      final mesh = RoadMeshBuilder.build(pts, width, yLift: roadSurfaceY);
      if (mesh == null) continue;
      final annotations = RoadAnnotationBuilder.build(
        road: road,
        centerline: pts,
        roadSurfaceY: roadSurfaceY,
      );
      roadAnnotationGeometry.add(annotations);
      triangles += annotations.arrows.fold(
        0,
        (count, arrow) => count + arrow.mesh.triangleCount,
      );
      triangles += mesh.triangleCount;
      strokes2d.add(
        Map2DStroke(
          points: _flattenXZ(pts),
          widthMeters: width,
          color: FogoPalette.road(road.type),
          type: road.type,
        ),
      );
      objects.add(
        MapSceneObject(
          entityId: road.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.road(road.type),
          kind: SceneObjectKind.road,
          depthLayer: _roadDepthLayer(road.type),
        ),
      );
    }

    // Edifícios extrudados.
    final flatByBuilding = <String, MeshData>{};
    for (final building in model.buildings) {
      final rings = [
        for (final ring in building.footprint)
          [for (final p in ring) projector.project(p)],
      ];
      final meshes = BuildingMeshBuilder.build(
        rings,
        heightMeters: building.height.value,
        minHeightMeters: building.minHeightMeters,
      );
      if (meshes == null) continue;
      triangles += meshes.volume.triangleCount;
      flatByBuilding[building.id] = meshes.flat;
      // Modo 2D: footprint FLATO (sem extrusão) — silhueta do mapa
      // escuro; volume é exclusivo do modo 3D.
      fills2d.add(
        Map2DFill(
          rings: [for (final ring in rings) _flattenXZ(ring)],
          color: FogoPalette.building,
          footprint: true,
        ),
      );
      objects.add(
        MapSceneObject(
          entityId: building.id,
          tileId: '',
          mesh: meshes.volume,
          color: FogoPalette.building,
          kind: SceneObjectKind.building,
          // Edifícios acima de parques (0) e água (2).
          depthLayer: 3,
          // TASK-0011: volume só perto da câmera; longe, pad do tile.
          rangeGated: true,
        ),
      );
    }

    // ÁGUA: placa 3D (slab) — topo no offset de água, base no plano do
    // parque: espessura REAL elimina qualquer conflito com o parque.
    // Bboxes projetadas dos estádios: o pitch (campo interno) precisa
    // renderizar ACIMA da plataforma do lote — arquibancada elevada +
    // gramado visível, sem isso a plataforma do estádio o cobre.
    final stadiumBboxes = <(double, double, double, double)>[];
    for (final area in model.landAreas) {
      if (area.kind != LandAreaKind.stadium) continue;
      var minX = double.infinity, maxX = -double.infinity;
      var minZ = double.infinity, maxZ = -double.infinity;
      for (final polygon in area.polygons) {
        for (final ring in polygon) {
          for (final p in ring) {
            final q = projector.project(p);
            if (q.x < minX) minX = q.x;
            if (q.x > maxX) maxX = q.x;
            if (q.z < minZ) minZ = q.z;
            if (q.z > maxZ) maxZ = q.z;
          }
        }
      }
      if (minX <= maxX) stadiumBboxes.add((minX, maxX, minZ, maxZ));
    }
    for (final area in model.landAreas) {
      // Mato/lavoura RURAIS no entorno (fora do perímetro urbano):
      // forest 76 km² / grass rural 21 km² no extrato regional —
      // triangulam centenas de milhares de triângulos sem valor
      // visual. Gap natural dos dados: rural ≥ 3,2 km², parques
      // urbanos ≤ 0,75 km². Limiar 1 km².
      if (_isRuralNature(area)) continue;
      var yLift = _landYOffset(area.kind);
      // Campo interno de estádio: pitch cujo centro cai no bbox de um
      // estádio renderiza ACIMA da plataforma do lote (0.060 + 4 mm)
      // — arquibancada alta, gramado baixo e visível.
      if (area.kind == LandAreaKind.sports &&
          _insideAnyStadium(
            _ringCenterMeters(area, projector),
            stadiumBboxes,
          )) {
        yLift = _landYOffset(LandAreaKind.stadium) + 0.004;
      }
      // Placa 3D (slab) para tudo que tem depthLayer próprio: água
      // (topo 0,050) e plataformas dos edifícios de interesse (topo
      // 0,060) — base no plano do parque: espessura REAL elimina
      // qualquer conflito com o plano por baixo. Posto e delegacia
      // ganham MODELOS 3D próprios ([AmenityMeshBuilder]) sobre o
      // pátio — reconhecíveis, acima de parque e água.
      final isSlab = _landDepthLayer(area.kind) != 0;
      final parts = <MeshData>[];
      for (final polygon in area.polygons) {
        final rings = [
          for (final ring in polygon)
            [for (final p in ring) projector.project(p)],
        ];
        // Modo 2D: área flat com a mesma tinta da cena (parques,
        // água, estacionamentos...) — o volume, se houver, é do 3D.
        if (rings.first.length >= 3) {
          fills2d.add(
            Map2DFill(
              rings: [for (final ring in rings) _flattenXZ(ring)],
              color: FogoPalette.land(area.kind),
            ),
          );
        }
        final MeshData? part;
        if (area.kind == LandAreaKind.fuelStation) {
          part = AmenityMeshBuilder.fuelStation(rings);
        } else if (area.kind == LandAreaKind.police) {
          part = AmenityMeshBuilder.police(rings);
        } else if (area.kind == LandAreaKind.stadium) {
          part = AmenityMeshBuilder.stadium(rings);
        } else if (area.kind == LandAreaKind.hospital) {
          part = AmenityMeshBuilder.hospital(rings);
        } else if (area.kind == LandAreaKind.placeOfWorship) {
          part = AmenityMeshBuilder.placeOfWorship(rings);
        } else if (isSlab) {
          part = SlabMeshBuilder.build(
            rings,
            top: yLift,
            bottom: _landYOffset(LandAreaKind.park),
          );
        } else {
          // triangulateFlat SOBRESCREVE o Y pelo 3º argumento — a
          // hierarquia por tipo de área ([_landYOffset]) precisa ser
          // ELE mesmo, não um 0.02 fixo.
          part = PolygonTriangulator.triangulateFlat(
            [for (final p in polygon[0]) projector.project(p)],
            [
              for (final hole in polygon.skip(1))
                [for (final p in hole) projector.project(p)],
            ],
            yLift,
          );
        }
        if (part != null) parts.add(part);
      }
      if (parts.isEmpty) continue;
      final mesh = merge(parts);
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      // Posto/delegacia/estádio/hospital/templo: VOLUME (kind
      // building → doubleSided no adapter); resto: superfície de área.
      final isVolume =
          area.kind == LandAreaKind.fuelStation ||
          area.kind == LandAreaKind.police ||
          area.kind == LandAreaKind.stadium ||
          area.kind == LandAreaKind.hospital ||
          area.kind == LandAreaKind.placeOfWorship;
      objects.add(
        MapSceneObject(
          entityId: area.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.land(area.kind),
          kind: isVolume ? SceneObjectKind.building : SceneObjectKind.landArea,
          depthLayer: _landDepthLayer(area.kind),
        ),
      );
    }

    // Travessias e semáforos nas posições reais.
    for (final crossing in model.crossings) {
      final road = _connectedRoad(crossing.connectedWayIds, model);
      final pos = projector.project(crossing.position);
      final roadY = _roadY(road);
      final width = road == null
          ? 6.0
          : road.properties.widthMeters?.value ?? 6.0;
      final mesh = crossing.marked
          ? CrossingMeshBuilder.build(
              pos,
              crossing.headingRadians,
              roadWidthMeters: width,
              y: roadY + 0.04,
            )
          : CrossingMeshBuilder.build(
              pos,
              crossing.headingRadians,
              roadWidthMeters: width,
              y: roadY + 0.04,
              stripes: 1,
              // Pad discreta do nó de travessia (cor da via).
              stripeW: 1.2,
              gap: 0,
            );
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: crossing.id,
          tileId: '',
          mesh: mesh,
          color: crossing.marked
              ? FogoPalette.crossing
              : FogoPalette.road(RoadType.footway),
          kind: SceneObjectKind.crossing,
          depthLayer: 8,
        ),
      );
    }
    for (final signal in model.signals) {
      final connectedRoads = _connectedRoads(signal.connectedWayIds, model);
      final road = _signalRoad(connectedRoads);
      final roadDirection = _roadDirectionAtSignal(signal, road, projector);
      final signalPosition = projector.project(signal.position);
      final pos = _signalApproachPosition(
        signalPosition,
        signal,
        road,
        roadDirection,
        connectedRoads,
        projector,
      );
      final mesh = TrafficSignalMeshBuilder.build(
        pos,
        roadDirection: roadDirection ?? Vector3(1, 0, 0),
        roadWidthMeters: road?.properties.widthMeters?.value ?? 5.0,
        y: _roadY(road),
      );
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: signal.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.signal,
          kind: SceneObjectKind.signal,
          depthLayer: 8,
        ),
      );
    }

    // Marcações de pavimento (ETAPA 05): barra de retenção ou
    // plataforma redutora, na posição real do nó, na cor da via.
    for (final marking in model.markings) {
      final road = _connectedRoad(marking.connectedWayIds, model);
      final width = road == null
          ? 6.0
          : road.properties.widthMeters?.value ?? 6.0;
      final pos = projector.project(marking.position);
      final y = _roadY(road);
      final MeshData? mesh;
      final Vector3 color;
      switch (marking.kind) {
        case RoadMarkingKind.stop:
        case RoadMarkingKind.giveWay:
          mesh = CrossingMeshBuilder.build(
            pos,
            (marking.headingRadians ?? 0) + math.pi / 2,
            roadWidthMeters: width,
            y: y + 0.09,
            stripes: 1,
            stripeW: 0.45,
            gap: 0,
          );
          color = FogoPalette.crossing;
        case RoadMarkingKind.trafficCalming:
          mesh = buildBox(
            Vector3(pos.x, y + 0.06, pos.z),
            Vector3(width / 2, 0.06, 1.2),
            headingRadians: marking.headingRadians ?? 0,
          );
          color = road == null
              ? FogoPalette.road(RoadType.residential)
              : FogoPalette.road(road.type);
      }
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: marking.id,
          tileId: '',
          mesh: mesh,
          color: color,
          kind: SceneObjectKind.roadMarking,
          depthLayer: 9,
        ),
      );
    }

    // ETAPA 06: água linear (rios/córregos) — faixa da largura real,
    // cor de água da paleta. Hierarquia: ACIMA de parques (rio dentro
    // de parque precisa aparecer; antes ficava 5 cm abaixo e o parque
    // o cortava) e abaixo das vias de ponte (lift 4+).
    for (final waterway in model.waterways) {
      final pts = [for (final p in waterway.points) projector.project(p)];
      if (pts.length < 2) continue;
      final mesh = RoadMeshBuilder.build(
        pts,
        waterway.widthMeters,
        yLift: 0.050, // mesmo plano das áreas de água (polígonos).
      );
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: waterway.id,
          tileId: '',
          mesh: mesh,
          color: FogoPalette.land(LandAreaKind.water),
          kind: SceneObjectKind.water,
          depthLayer: 2,
        ),
      );
    }

    // ETAPA 06: árvores INDIVIDUAIS do OSM (natural=tree) — posição
    // real, altura determinística pelo id (dados sem height/espécie
    // usam o modelo genérico discreto; nunca apresentado como real).
    for (final tree in model.trees.where((t) => !t.estimated)) {
      final pos = projector.project(tree.position);
      final mesh = TreeMeshBuilder.build(pos, tree.id);
      if (mesh == null) continue;
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: tree.id,
          tileId: '',
          mesh: mesh,
          color: _treeColor(),
          kind: SceneObjectKind.tree,
        ),
      );
    }

    // ETAPA 06: mobiliário urbano com posição real (bench/shelter) —
    // modelos mínimos reutilizáveis.
    for (final item in model.furniture) {
      final road = _connectedRoad(item.connectedWayIds, model);
      final pos = projector.project(item.position);
      final y = _roadY(road);
      final MeshData? mesh;
      final Vector3 color;
      switch (item.kind) {
        case StreetFurnitureKind.bench:
          mesh = buildBox(
            Vector3(pos.x, y + 0.45, pos.z),
            Vector3(0.9, 0.45, 0.35),
            headingRadians: item.headingRadians ?? 0,
          );
          color = FogoPalette.building;
        case StreetFurnitureKind.shelter:
          mesh = buildBox(
            Vector3(pos.x, y + 1.2, pos.z),
            Vector3(1.8, 1.2, 0.5),
            headingRadians: item.headingRadians ?? 0,
          );
          color = FogoPalette.building;
      }
      triangles += mesh.triangleCount;
      objects.add(
        MapSceneObject(
          entityId: item.id,
          tileId: '',
          mesh: mesh,
          color: color,
          kind: SceneObjectKind.furniture,
        ),
      );
    }

    // ETAPA 06: árvores PROCEDURAIS — determinísticas (seed fixa),
    // restritas a parques/florestas, fora de edifícios e vias. Marcadas
    // estimated=true: a UI as diferencia dos dados reais do OSM.
    final proceduralSeed = 42;
    for (final area in model.landAreas) {
      if (area.kind != LandAreaKind.park && area.kind != LandAreaKind.forest) {
        continue;
      }
      // Mato rural removido da cena: sem árvores proporcionais.
      if (_isRuralNature(area)) continue;
      final roadPolylines = [for (final road in model.roads) road.points];
      final buildingFootprints = [for (final b in model.buildings) b.footprint];
      // Densidade por área: ~1 árvore/1500 m², mínimo 2, máximo 80.
      // A mesma área sempre gera as mesmas árvores (seed fixa).
      final areaM2 = _polygonAreaM2(area);
      final maxTrees = (areaM2 / 1500).round().clamp(2, 80);
      final positions = TreeDistributor.distribute(
        area: area,
        buildingFootprints: buildingFootprints,
        roadPolylines: roadPolylines,
        maxTrees: maxTrees,
        seed: proceduralSeed,
      );
      for (var i = 0; i < positions.length; i++) {
        final p = positions[i];
        final tree = Tree(
          id: '${area.id}/tree/$i',
          tags: {'generated': 'procedural', 'area': area.id},
          position: GeoCoordinate(p.lat, p.lon),
          estimated: true,
        );
        final pos = projector.project(tree.position);
        final mesh = TreeMeshBuilder.build(pos, tree.id);
        if (mesh == null) continue;
        model.trees.add(tree);
        triangles += mesh.triangleCount;
        objects.add(
          MapSceneObject(
            entityId: tree.id,
            tileId: '',
            mesh: mesh,
            color: _treeColor(),
            kind: SceneObjectKind.tree,
          ),
        );
      }
    }

    // Junções viárias: região de interseção sobre cada nó compartilhado,
    // agrupando apenas segmentos NO MESMO nível vertical (interseção
    // visual entre pontes/túneis e o solo nunca vira pad conjunta).
    var padCount = 0;
    if (style.buildJunctionPads) {
      for (final node in network.junctions) {
        var segments = network.segmentsAtNode(node.id).toList();
        if (segments.length < 2) continue;
        // Calçadas/caminhos (foot-class) NUNCA formam pad conjunta com
        // via de carro: a ribbon da calçada passa por BAIXO (elevação
        // própria) e é coberta pela pista — sem "calçada atravessando
        // a rua" nem invadindo a faixa de pedestres. Node só de
        // calçadas (encontro de caminhos) mantém a pad.
        final streetSegments = segments.where((s) {
          final road = model.byId(s.roadId);
          return road is Road && !_isFootClass(road);
        }).toList();
        if (streetSegments.isNotEmpty) segments = streetSegments;
        if (segments.length < 2) continue;
        final groups = <double, List<({Road road, JunctionArm arm})>>{};
        for (final seg in segments) {
          final road = model.byId(seg.roadId);
          if (road is! Road) continue;
          final dir = _segmentDirectionAt(road, seg, node.id, projector);
          if (dir == null) continue;
          final lift = _roadLevel(
            layer: road.properties.layer,
            bridge: road.properties.bridge,
            tunnel: road.properties.tunnel,
          );
          groups.putIfAbsent(lift, () => []).add((
            road: road,
            arm: JunctionArm(
              direction: dir,
              halfWidthMeters: (road.properties.widthMeters?.value ?? 5) / 2,
              color: FogoPalette.road(road.type),
            ),
          ));
        }
        for (final group in groups.values) {
          if (group.length < 2) continue;
          // Prioridade = tipo de via mais importante (enum order).
          var priority = group.first;
          for (final entry in group) {
            if (entry.road.type.index < priority.road.type.index) {
              priority = entry;
            }
          }
          final center = projector.project(node.position)
            ..y = _roadLift(
              layer: priority.road.properties.layer,
              bridge: priority.road.properties.bridge,
              tunnel: priority.road.properties.tunnel,
              type: priority.road.type,
            );
          final pad = JunctionMeshBuilder.build(
            center,
            [for (final g in group) g.arm],
            priorityColor: FogoPalette.road(priority.road.type),
            style: style,
          );
          if (pad == null) continue;
          padCount++;
          triangles += pad.triangleCount;
          objects.add(
            MapSceneObject(
              // A pad pertence à junção da via prioritária: selecioná-la
              // seleciona a via; destacar a via destaca a junção.
              entityId: priority.road.id,
              tileId: '',
              mesh: pad,
              // Base branca: as cores reais vêm dos VÉRTICES da pad
              // (degradê entre as vias conectadas) — sem dupla
              // multiplicação.
              color: Vector3(1, 1, 1),
              kind: SceneObjectKind.junctionPad,
              depthLayer: 7,
            ),
          );
        }
      }
    }

    // Particionamento: tiles reais pela bounds projetada do conteúdo.
    onProgress?.call('Particionando espacialmente', objects.length);
    final annotationBounds = <WorldBounds>[
      for (final annotations in roadAnnotationGeometry) ...[
        if (annotations.roadName != null) annotations.roadName!.bounds,
        for (final arrow in annotations.arrows) arrow.bounds,
      ],
    ];
    final worldBounds = _unionBounds(objects, extraBounds: annotationBounds);
    final grid = SpatialPartitioner.partition(worldBounds);
    final tiles = TileManager(grid);
    final annotationNamesByTile = <String, List<RoadNamePlacement>>{};
    final annotationArrowsByTile = <String, List<MeshData>>{};
    final annotationBoundsByTile = <String, WorldBounds>{};
    void addAnnotationBounds(String tileId, WorldBounds bounds) {
      final previous = annotationBoundsByTile[tileId];
      annotationBoundsByTile[tileId] = previous == null
          ? bounds
          : _mergeWorldBounds(previous, bounds);
    }

    for (final annotations in roadAnnotationGeometry) {
      final name = annotations.roadName;
      if (name != null) {
        final tile = tiles.tileOfPoint(name.center);
        if (tile != null) {
          annotationNamesByTile.putIfAbsent(tile.id, () => []).add(name);
          addAnnotationBounds(tile.id, name.bounds);
        }
      }
      for (final arrow in annotations.arrows) {
        final tile = tiles.tileOfPoint(arrow.center);
        if (tile != null) {
          annotationArrowsByTile.putIfAbsent(tile.id, () => []).add(arrow.mesh);
          addAnnotationBounds(tile.id, arrow.bounds);
        }
      }
    }
    final annotationTileIds = <String>{
      ...annotationNamesByTile.keys,
      ...annotationArrowsByTile.keys,
    };
    final annotationBatches = [
      for (final tileId in annotationTileIds)
        RoadAnnotationBatch(
          tileId: tileId,
          roadNames: annotationNamesByTile[tileId] ?? const [],
          arrowMesh: RoadAnnotationBuilder.mergeArrowMeshes(
            annotationArrowsByTile[tileId] ?? const [],
          ),
          bounds: annotationBoundsByTile[tileId]!,
        ),
    ];
    final objectBounds = List<WorldBounds?>.filled(objects.length, null);
    for (var i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final b = obj.mesh.computeBounds();
      if (b == null) continue;
      objectBounds[i] = b;
      final center = Vector3(
        (b.min.x + b.max.x) / 2,
        0,
        (b.min.z + b.max.z) / 2,
      );
      tiles.assign(obj.entityId, b, center);
    }
    final tileBounds =
        <String, ({double minX, double minZ, double maxX, double maxZ})>{};
    for (var i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final tileId = tiles.ownerTileOf(obj.entityId) ?? 'tile/0_0';
      final b = objectBounds[i];
      if (b != null) {
        final previous = tileBounds[tileId];
        tileBounds[tileId] = previous == null
            ? (minX: b.min.x, minZ: b.min.z, maxX: b.max.x, maxZ: b.max.z)
            : (
                minX: math.min(previous.minX, b.min.x),
                minZ: math.min(previous.minZ, b.min.z),
                maxX: math.max(previous.maxX, b.max.x),
                maxZ: math.max(previous.maxZ, b.max.z),
              );
      }
      objects[i] = MapSceneObject(
        entityId: obj.entityId,
        tileId: tileId,
        mesh: obj.mesh,
        color: obj.color,
        kind: obj.kind,
        // Particionamento reembala o objeto: depthLayer PRECISA
        // sobreviver (água 2 / interesse 3 / pads 7 / crossings 8) —
        // sem isso o bias de profundidade nunca chegava ao material.
        depthLayer: obj.depthLayer,
        // TASK-0011: o gate de range precisa sobreviver ao reembalo.
        rangeGated: obj.rangeGated,
      );
    }
    for (final batch in annotationBatches) {
      final b = batch.bounds;
      final previous = tileBounds[batch.tileId];
      tileBounds[batch.tileId] = previous == null
          ? (minX: b.min.x, minZ: b.min.z, maxX: b.max.x, maxZ: b.max.z)
          : (
              minX: math.min(previous.minX, b.min.x),
              minZ: math.min(previous.minZ, b.min.z),
              maxX: math.max(previous.maxX, b.max.x),
              maxZ: math.max(previous.maxZ, b.max.z),
            );
    }

    // TASK-0011: pads planos por tile — o fallback 2D dos volumes
    // `rangeGated` fora do raio da câmera. Um mesh por tile, não por
    // prédio: ~300 draws no lugar de 75k.
    final flatsByTile = <String, List<MeshData>>{};
    for (final entry in flatByBuilding.entries) {
      final tileId = tiles.ownerTileOf(entry.key);
      if (tileId == null) continue;
      flatsByTile.putIfAbsent(tileId, () => []).add(entry.value);
    }
    final buildingFootprints = <BuildingFootprintBatch>[
      for (final entry in flatsByTile.entries)
        if (MeshData.merge(entry.value) case final merged?)
          BuildingFootprintBatch(tileId: entry.key, mesh: merged),
    ];

    final scene = MapScene(
      objects: objects,
      worldBounds: worldBounds,
      tileIds: {for (final t in grid) t.id},
      tileBounds: tileBounds,
      annotations: annotationBatches,
      buildingFootprints: buildingFootprints,
    );

    return FogoEngine._(
      store: store,
      model: model,
      network: network,
      scene: scene,
      map2d: Map2DScene(strokes: strokes2d, fills: fills2d),
      projector: projector,
      tileManager: tiles,
      vehicles: vehicles,
      geoBounds: geoBounds,
      stats: FogoEngineStats(
        nodeCount: store.nodeCount,
        roadCount: model.roads.length,
        duplicateRoadsRemoved: dedup.removed,
        ambiguousDuplicates: dedup.ambiguous,
        crossingsWithoutConnection: _countUnconnectedCrossings(model, store),
        // Loops de anel (rotatória) têm start==end COM pontos
        // intermediários — legítimos. Degenerado é o loop sem substância.
        degenerateSegments: network.segments.values
            .where((s) => s.connectsSameNode && s.pointEnd - s.pointStart < 2)
            .length,
        isolatedNetworkNodes: network.nodes.values
            .where((n) => network.segmentsAtNode(n.id).isEmpty)
            .length,
        buildingCount: model.buildings.length,
        landAreaCount: model.landAreas.length,
        crossingCount: model.crossings.length,
        signalCount: model.signals.length,
        meshObjectCount: objects.length,
        junctionPadCount: padCount,
        triangleCount: triangles,
        issueCount: store.issues.length,
      ),
    );
  }

  /// Área aproximada da entidade de área (m²) — para densidade de
  /// vegetação procedural.
  static double _polygonAreaM2(dynamic area) {
    var total = 0.0;
    for (final polygon in area.polygons) {
      if (polygon.isEmpty) continue;
      final outer = polygon.first;
      var sum = 0.0;
      for (var i = 0; i < outer.length; i++) {
        final a = outer[i];
        final b = outer[(i + 1) % outer.length];
        sum += a.longitude * b.latitude - b.longitude * a.latitude;
      }
      total += (sum.abs() / 2) * 111320 * 111320;
    }
    return total;
  }

  /// Limiar de mato rural (m²): natureza acima disso é o entorno da
  /// cidade — fora do perímetro urbano, sem valor visual.
  static const double _ruralNatureMaxM2 = 1e6; // 1 km²

  /// Mato/lavoura rural: park/forest/farmland FORA do perímetro
  /// urbano (caixas curadas do [RegionCatalog] — "generosas, não são
  /// limites municipais") OU acima de 1 km² mesmo dentro. Extrato
  /// real: forest 76 km², grass rural 21,9 km², lavoura 12,9 km² no
  /// entorno; parques urbanos ≤ 0,75 km². Corte performance: essas
  /// áreas triangulavam dezenas de milhares de polígonos.
  static bool _isRuralNature(LandArea area) {
    switch (area.kind) {
      case LandAreaKind.park:
      case LandAreaKind.forest:
      case LandAreaKind.farmland:
        break;
      default:
        return false;
    }
    if (_polygonAreaM2(area) > _ruralNatureMaxM2) return true;
    // Centro da área (bbox do anel externo principal).
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLon = double.infinity, maxLon = -double.infinity;
    for (final polygon in area.polygons) {
      if (polygon.isEmpty) continue;
      for (final p in polygon.first) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
    }
    if (minLat.isInfinite) return false;
    final lat = (minLat + maxLat) / 2;
    final lon = (minLon + maxLon) / 2;
    for (final city in RegionCatalog.cities) {
      final b = city.bounds;
      if (lat >= b.south && lat <= b.north && lon >= b.west && lon <= b.east) {
        return false; // dentro do perímetro urbano
      }
    }
    return true;
  }

  /// Elevação VISUAL por tipo de via (ETAPA 09 ajuste): rodovias
  /// ficam fisicamente acima de ruas locais na cena 3D — hierarquia
  /// cartográfica visível, como no Mapbox Standard. Os valores são
  /// pequenos (não afetam topologia — conectividade continua por nós
  /// compartilhados), mas perceptíveis em vista oblíqua.
  static double _roadRenderElevation(RoadType type) => switch (type) {
    RoadType.motorway => 0.14,
    RoadType.trunk => 0.12,
    RoadType.primary => 0.10,
    RoadType.secondary => 0.07,
    RoadType.tertiary => 0.04,
    RoadType.rail => 0.03,
    // Calçadas/caminhos ABAIXO de toda via de carro: onde a calçada
    // cruza a pista (nó compartilhado), a PISTA cobre a ribbon — a
    // calçada é interrompida pela via como na realidade; a travessia
    // de pedestre visível é a faixa (crossing), nunca o piso da
    // calçada. 2 mm de diferença: invisível fora dos cruzamentos.
    RoadType.footway ||
    RoadType.path ||
    RoadType.cycleway ||
    RoadType.pedestrian => 0.028,
    // Base acima de TODOS os planos de área (máx 0.026): ruas locais
    // nunca são cobertas por parques/grass/estacionamento.
    _ => 0.03,
  };

  /// Hierarquia visual (ETAPA 09 ajuste): maior = renderiza ACIMA
  /// quando coplanar. Rodovias cobrem ruas locais nas pistas paralelas.
  static int _roadDepthLayer(RoadType type) => switch (type) {
    RoadType.motorway => 5,
    RoadType.trunk => 5,
    RoadType.primary => 4,
    RoadType.secondary => 3,
    RoadType.tertiary => 2,
    RoadType.rail => 1,
    _ => 0,
  };

  /// Hierarquia de áreas (maior = por cima): base 0; água 2 — sobre
  /// parques/forest coplanares; edifícios de interesse 3.
  static int _landDepthLayer(LandAreaKind kind) => switch (kind) {
    LandAreaKind.water => 2,
    LandAreaKind.fuelStation ||
    LandAreaKind.police ||
    LandAreaKind.hospital ||
    LandAreaKind.placeOfWorship ||
    LandAreaKind.stadium => 3,
    _ => 0,
  };

  /// Elevação (m) de cada tipo de área — TODOS distintos: áreas de
  /// tipos diferentes nunca ficam coplanares (fim do z-fighting); a
  /// diferença de 2 mm é invisível na escala cartográfica. Máx 0.026
  /// fica abaixo da elevação base das vias (0.03).
  static double _landYOffset(LandAreaKind kind) => switch (kind) {
    LandAreaKind.other => 0.008,
    LandAreaKind.park => 0.010,
    LandAreaKind.forest => 0.012,
    LandAreaKind.farmland => 0.014,
    LandAreaKind.residential => 0.016,
    LandAreaKind.industrial => 0.018,
    LandAreaKind.commercial => 0.020,
    LandAreaKind.education => 0.022,
    LandAreaKind.sports => 0.024,
    LandAreaKind.parking => 0.026,
    LandAreaKind.fuelStation ||
    LandAreaKind.police ||
    LandAreaKind.hospital ||
    LandAreaKind.placeOfWorship ||
    LandAreaKind.stadium => 0.060,
    LandAreaKind.water => 0.050,
  };

  /// Cor de árvore: deriva do token de floresta da paleta (levemente
  /// clareado para leitura de volume — multiplicador, sem cor nova).
  static Vector3 _treeColor() {
    final base = FogoPalette.land(LandAreaKind.forest);
    return Vector3(
      (base.x * 1.6).clamp(0, 1),
      (base.y * 1.5).clamp(0, 1),
      (base.z * 1.4).clamp(0, 1),
    );
  }

  /// Nível FÍSICO da via (§ETAPA 04): 4 m por `layer` OSM (dica de
  /// ordenação, não medida real — sem modelo de terreno). Ponte/túnel
  /// SEM `layer` recebem ±1 nível. Chave de agrupamento de pads de
  /// junção: interseção no mesmo nível é pad conjunta — a elevação
  /// cosmética por tipo de via ([_roadRenderElevation]) nunca separa
  /// nem funde junções (primary×local, rail×local = mesma pad).
  static double _roadLevel({
    required int layer,
    required bool bridge,
    required bool tunnel,
  }) {
    var effective = layer.clamp(-2, 3);
    if (effective == 0) {
      if (bridge) effective = 1;
      if (tunnel) effective = -1;
    }
    return effective * 4.0;
  }

  /// Lift de renderização = nível físico + elevação cosmética por
  /// hierarquia de via (rodovias visivelmente acima de ruas locais).
  static double _roadLift({
    required int layer,
    required bool bridge,
    required bool tunnel,
    RoadType? type,
  }) =>
      _roadLevel(layer: layer, bridge: bridge, tunnel: tunnel) +
      (type == null ? 0.0 : _roadRenderElevation(type));

  /// Arestas dirigíveis para as viaturas: vias de carro (sem calçada,
  /// trilho, túnel), geometria projetada no sentido OSM do segmento.
  static List<FleetEdge> _vehicleEdges(
    RoadNetwork network,
    MapModel model,
    CoordinateProjector projector,
  ) {
    const skip = {
      RoadType.footway,
      RoadType.path,
      RoadType.cycleway,
      RoadType.pedestrian,
      RoadType.rail,
      RoadType.track,
    };
    final edges = <FleetEdge>[];
    for (final segment in network.segments.values) {
      final road = model.byId(segment.roadId);
      if (road is! Road) continue;
      if (skip.contains(road.type) || road.properties.tunnel) continue;
      if (segment.connectsSameNode) continue;
      if (segment.pointEnd - segment.pointStart < 1) continue;
      final pts = <Vector3>[
        for (
          var i = segment.pointStart;
          i <= segment.pointEnd && i < road.points.length;
          i++
        )
          projector.project(road.points[i]),
      ];
      if (pts.length < 2) continue;
      edges.add(
        FleetEdge(
          points: pts,
          surfaceY: roadLiftMeters(road),
          oneway: road.properties.oneway,
          startNodeId: segment.startNodeId,
          endNodeId: segment.endNodeId,
        ),
      );
    }
    return edges;
  }

  /// Elevação da superfície da via (m) — pontes elevam, túneis afundam.
  /// Pública para o sistema de viaturas (rodam SOBRE a superfície).
  static double roadLiftMeters(Road road) => _roadLift(
    layer: road.properties.layer,
    bridge: road.properties.bridge,
    tunnel: road.properties.tunnel,
    type: road.type,
  );

  /// Direção unitária horizontal da via no nó de junção, apontando DA
  /// junção PARA o trecho (usa o range de pontos do segmento — a via é
  /// articulada em nós compartilhados, ver RoadSegment).
  static Vector3? _segmentDirectionAt(
    Road road,
    RoadSegment segment,
    String nodeId,
    CoordinateProjector projector,
  ) {
    final atStart = segment.startNodeId == nodeId;
    final i = atStart ? segment.pointStart : segment.pointEnd;
    final j = atStart ? i + 1 : i - 1;
    if (i < 0 || i >= road.points.length) return null;
    if (j < 0 || j >= road.points.length) return null;
    final a = projector.project(road.points[i]);
    final b = projector.project(road.points[j]);
    final dir = Vector3(b.x - a.x, 0, b.z - a.z);
    if (dir.length2 < 1e-9) return null;
    dir.normalize();
    return dir;
  }

  /// Bounds de mundo da entidade (projetada), para enquadramento de
  /// câmera na seleção. Null quando a entidade não existe.
  WorldBounds? boundsOf(String entityId) {
    final feature = model.byId(entityId);
    if (feature == null) return null;
    final out = Aabb3.minMax(
      Vector3(double.maxFinite, 0, double.maxFinite),
      Vector3(-double.maxFinite, 0, -double.maxFinite),
    );
    var any = false;

    void add(Vector3 p) {
      any = true;
      if (p.x < out.min.x) out.min.x = p.x;
      if (p.z < out.min.z) out.min.z = p.z;
      if (p.x > out.max.x) out.max.x = p.x;
      if (p.z > out.max.z) out.max.z = p.z;
    }

    switch (feature) {
      case Road road:
        for (final p in road.points) {
          add(projector.project(p));
        }
      case Building building:
        for (final ring in building.footprint) {
          for (final p in ring) {
            add(projector.project(p));
          }
        }
      case LandArea area:
        for (final polygon in area.polygons) {
          for (final ring in polygon) {
            for (final p in ring) {
              add(projector.project(p));
            }
          }
        }
      case PedestrianCrossing crossing:
        final p = projector.project(crossing.position);
        add(p + Vector3(-6, 0, -6));
        add(p + Vector3(6, 0, 6));
      case TrafficSignal signal:
        final p = projector.project(signal.position);
        add(p + Vector3(-6, 0, -6));
        add(p + Vector3(6, 0, 6));
      case Poi poi:
        // ENG-0008: rótulos puros (marker == false) também são
        // enquadráveis quando selecionados por busca — nunca null.
        final p = projector.project(poi.position);
        add(p + Vector3(-6, 0, -6));
        add(p + Vector3(6, 0, 6));
      default:
        return null;
    }
    return any ? out : null;
  }

  /// Via conectada mais importante (primeira por ordem de id) — fonte
  /// de largura, cor e lift para entidades de nó (travessia, sinal,
  /// marcação).
  static Road? _connectedRoad(Set<String> wayIds, MapModel model) {
    Road? first;
    Road? street;
    for (final id in wayIds) {
      final feature = model.byId(id);
      if (feature is! Road) continue;
      first ??= feature;
      // Faixa de pedestre/marcação pertence à VIA (não à calçada):
      // elevação e largura da via de carro — nunca da footway
      // (calçada 2 mm abaixo da pista não pode levantar a faixa).
      street ??= _isFootClass(feature) ? null : feature;
    }
    return street ?? first;
  }

  /// Um semáforo em nó compartilhado não pertence necessariamente à
  /// primeira via OSM. Usa a via de maior hierarquia para definir lado e
  /// orientação (RoadType segue a hierarquia viária).
  static Road? _signalRoad(List<Road> roads) {
    Road? first;
    Road? best;
    for (final road in roads) {
      first ??= road;
      if (_isFootClass(road)) continue;
      if (best == null || road.type.index < best.type.index) best = road;
    }
    return best ?? first;
  }

  static List<Road> _connectedRoads(Set<String> wayIds, MapModel model) => [
    for (final id in wayIds)
      if (model.byId(id) case final Road road) road,
  ];

  /// Move semáforos colocados no centro topológico do cruzamento para a
  /// aproximação da via escolhida. Sem esse recuo, offset lateral cai no
  /// eixo da transversal e o poste parece plantado no meio da rua.
  static Vector3 _signalApproachPosition(
    Vector3 position,
    TrafficSignal signal,
    Road? road,
    Vector3? direction,
    List<Road> connectedRoads,
    CoordinateProjector projector,
  ) {
    if (road == null || direction == null) return position;
    var clearance = 0.0;
    for (final crossing in connectedRoads) {
      if (crossing.id == road.id ||
          _isFootClass(crossing) ||
          crossing.properties.layer != road.properties.layer) {
        continue;
      }
      final crossingDirection = _roadDirectionAtSignal(
        signal,
        crossing,
        projector,
      );
      if (crossingDirection == null) continue;
      final sinAngle =
          (direction.x * crossingDirection.z -
                  direction.z * crossingDirection.x)
              .abs();
      // Ways nearly parallel here are usually divided carriageways.
      if (sinAngle < 0.25) continue;
      final width = crossing.properties.widthMeters?.value ?? 5.0;
      clearance = math.max(clearance, width * sinAngle / 2 + 0.9);
    }
    return position + direction * clearance;
  }

  /// Vetor de mundo do nó semafórico para o próximo ponto da via. A
  /// projeção direta evita misturar o bearing geográfico com heading x/z.
  static Vector3? _roadDirectionAtSignal(
    TrafficSignal signal,
    Road? road,
    CoordinateProjector projector,
  ) {
    if (road == null || road.points.length < 2) return null;
    final parts = signal.id.split('/');
    if (parts.length != 2 || parts.first != 'node') return null;
    final nodeRef = int.tryParse(parts.last);
    if (nodeRef == null) return null;
    final index = road.nodeRefs.indexOf(nodeRef);
    if (index < 0 || index >= road.points.length) return null;
    final origin = projector.project(signal.position);
    for (final neighborIndex in [index + 1, index - 1]) {
      if (neighborIndex < 0 || neighborIndex >= road.points.length) continue;
      final neighbor = projector.project(road.points[neighborIndex]);
      final direction = Vector3(
        neighbor.x - origin.x,
        0,
        neighbor.z - origin.z,
      );
      if (direction.length2 > 1e-9) return direction..normalize();
    }
    return null;
  }

  static double _roadY(Road? road) => road == null
      ? 0
      : _roadLift(
          layer: road.properties.layer,
          bridge: road.properties.bridge,
          tunnel: road.properties.tunnel,
          type: road.type,
        );

  /// Calçadas/caminhos de pedestre: footway, path, cycleway e
  /// pedestrian (linha). Regra de hierarquia com vias de carro —
  /// elevação abaixo da pista e sem pad conjunta ([_roadRenderElevation]).
  static bool _isFootClass(Road? road) => switch (road?.type) {
    RoadType.footway ||
    RoadType.path ||
    RoadType.cycleway ||
    RoadType.pedestrian => true,
    _ => false,
  };

  /// Centro (bbox) do anel externo principal da área, em metros
  /// projetados — teste de "pitch dentro de estádio".
  static Vector3 _ringCenterMeters(
    LandArea area,
    CoordinateProjector projector,
  ) {
    final ring = area.polygons.first.first;
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final p in ring) {
      final q = projector.project(p);
      if (q.x < minX) minX = q.x;
      if (q.x > maxX) maxX = q.x;
      if (q.z < minZ) minZ = q.z;
      if (q.z > maxZ) maxZ = q.z;
    }
    return Vector3((minX + maxX) / 2, 0, (minZ + maxZ) / 2);
  }

  /// Converte pontos projetados em x/z intercalados (primitiva 2D).
  static Float32List _flattenXZ(List<Vector3> pts) {
    final out = Float32List(pts.length * 2);
    for (var i = 0; i < pts.length; i++) {
      out[i * 2] = pts[i].x;
      out[i * 2 + 1] = pts[i].z;
    }
    return out;
  }

  static bool _insideAnyStadium(
    Vector3 center,
    List<(double, double, double, double)> bboxes,
  ) => bboxes.any(
    (b) =>
        center.x >= b.$1 &&
        center.x <= b.$2 &&
        center.z >= b.$3 &&
        center.z <= b.$4,
  );

  /// Conta pares de vias cujas GEOMETRIAS se cruzam em projeção sem nó
  /// compartilhado e sem separação de nível. Teste de segmento real
  /// (AABB é só o filtro de candidatos) — pistas paralelas não contam.
  /// Diagnóstico de dados: a conectividade continua sendo só por nós.
  static int _countUnconnectedCrossings(MapModel model, OsmDataStore store) {
    final roads = model.roads;
    final entries =
        <
          ({
            List<double> xs,
            List<double> zs,
            double minX,
            double maxX,
            double minZ,
            double maxZ,
            Set<int> refs,
            bool bridge,
            bool tunnel,
            int layer,
          })
        >[];
    for (final road in roads) {
      if (road.points.length < 2) continue;
      var minX = double.infinity, maxX = -double.infinity;
      var minZ = double.infinity, maxZ = -double.infinity;
      final xs = <double>[], zs = <double>[];
      for (final p in road.points) {
        xs.add(p.longitude);
        zs.add(p.latitude);
        if (p.longitude < minX) minX = p.longitude;
        if (p.longitude > maxX) maxX = p.longitude;
        if (p.latitude < minZ) minZ = p.latitude;
        if (p.latitude > maxZ) maxZ = p.latitude;
      }
      entries.add((
        xs: xs,
        zs: zs,
        minX: minX,
        maxX: maxX,
        minZ: minZ,
        maxZ: maxZ,
        refs: road.nodeRefs.toSet(),
        bridge: road.properties.bridge,
        tunnel: road.properties.tunnel,
        layer: road.properties.layer,
      ));
    }
    // Ordena por AABB para o sweep; pré-agrupa níveis.
    entries.sort((a, b) => a.minX.compareTo(b.minX));

    var count = 0;
    for (var i = 0; i < entries.length; i++) {
      final a = entries[i];
      for (var j = i + 1; j < entries.length; j++) {
        final b = entries[j];
        if (b.minX > a.maxX) break; // sweep encerra
        if (b.minZ > a.maxZ || a.minZ > b.maxZ) continue;
        // Níveis distintos (bridge/tunnel/layer): não-conexão legítima.
        final separated =
            a.bridge != b.bridge || a.tunnel != b.tunnel || a.layer != b.layer;
        if (separated) continue;
        if (a.refs.intersection(b.refs).isNotEmpty) continue;
        if (_polylinesCross(a.xs, a.zs, b.xs, b.zs)) {
          count++;
        }
      }
    }
    return count;
  }

  /// Interseção real entre polilinhas (latitude/longitude como plano
  /// aproximado — serve para diagnóstico booleano).
  static bool _polylinesCross(
    List<double> ax,
    List<double> az,
    List<double> bx,
    List<double> bz,
  ) {
    double orient(
      double px,
      double pz,
      double qx,
      double qz,
      double rx,
      double rz,
    ) => (qx - px) * (rz - pz) - (qz - pz) * (rx - px);

    bool segsCross(
      double a1x,
      double a1z,
      double a2x,
      double a2z,
      double b1x,
      double b1z,
      double b2x,
      double b2z,
    ) {
      final d1 = orient(b1x, b1z, b2x, b2z, a1x, a1z);
      final d2 = orient(b1x, b1z, b2x, b2z, a2x, a2z);
      final d3 = orient(a1x, a1z, a2x, a2z, b1x, b1z);
      final d4 = orient(a1x, a1z, a2x, a2z, b2x, b2z);
      return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
          ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
    }

    for (var i = 0; i < ax.length - 1; i++) {
      for (var j = 0; j < bx.length - 1; j++) {
        if (segsCross(
          ax[i],
          az[i],
          ax[i + 1],
          az[i + 1],
          bx[j],
          bz[j],
          bx[j + 1],
          bz[j + 1],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static WorldBounds _unionBounds(
    List<MapSceneObject> objects, {
    Iterable<WorldBounds> extraBounds = const [],
  }) {
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
    for (final b in extraBounds) {
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

  static WorldBounds _mergeWorldBounds(WorldBounds a, WorldBounds b) =>
      Aabb3.minMax(
        Vector3(
          math.min(a.min.x, b.min.x),
          math.min(a.min.y, b.min.y),
          math.min(a.min.z, b.min.z),
        ),
        Vector3(
          math.max(a.max.x, b.max.x),
          math.max(a.max.y, b.max.y),
          math.max(a.max.z, b.max.z),
        ),
      );
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
    required this.junctionPadCount,
    required this.triangleCount,
    required this.issueCount,
    this.duplicateRoadsRemoved = 0,
    this.ambiguousDuplicates = 0,
    this.crossingsWithoutConnection = 0,
    this.degenerateSegments = 0,
    this.isolatedNetworkNodes = 0,
  });

  final int nodeCount;
  final int roadCount;
  final int buildingCount;
  final int landAreaCount;
  final int crossingCount;
  final int signalCount;
  final int meshObjectCount;
  final int junctionPadCount;
  final int triangleCount;
  final int issueCount;

  /// Integridade (ETAPA 02): duplicatas comprovadas descartadas.
  final int duplicateRoadsRemoved;

  /// Coincidentes com atributos divergentes — preservadas, registradas.
  final int ambiguousDuplicates;

  /// Pares de vias que se cruzam em projeção SEM nó compartilhado e SEM
  /// separação de nível (bridge/tunnel/layer) — dado OSM sem conexão
  /// topológica; o motor NÃO conecta por proximidade.
  final int crossingsWithoutConnection;

  /// Segmentos que começam e terminam no mesmo nó (loop degenerado).
  final int degenerateSegments;

  /// Nós da rede sem nenhum segmento (referência quebrada).
  final int isolatedNetworkNodes;
}
