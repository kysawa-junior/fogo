import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
// Importer de runtime do flutter_scene (não exposto na face pública;
// resolve .gltf multi-arquivo em Node).
// ignore: implementation_imports
import 'package:flutter_scene/src/runtime_importer/runtime_importer.dart'
    show importGltf;
import 'package:flutter_scene/scene.dart' as fscene;
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../engine/fogo_engine.dart';
import '../../../../engine/mesh/vehicle_mesh_builder.dart';
import '../../../../engine/scene/visual_style.dart';
import '../../../../engine/scene/lod_policy.dart';
import '../../../../engine/geometry/mesh_data.dart';
import 'scene_overlay.dart';

/// Implementação concreta do [RenderBackend] sobre Flutter Scene.
///
/// ÚNICA camada que depende das APIs de renderização: converte [MeshData]
/// do motor (Float32List/Uint32List) em `MeshGeometry.fromArrays` e
/// `UnlitMaterial`, agrupa objetos em nós-pai por tile (particionamento
/// espacial + culling por distância)
/// e resolve o raycast de seleção de volta ao id da ENTIDADE.
///
/// Vertex colors: malhas com `colors` multiplicam a cor base do
/// material (sombreamento de fachadas, degradê das pads de junção) — um
/// único material por objeto, sem custo extra de draw call.
class FlutterSceneAdapter implements RenderBackend {
  FlutterSceneAdapter() : _scene = fscene.Scene();

  fscene.Scene _scene;
  SceneLightingMode _lightingMode = SceneLightingMode.night;
  final Map<String, List<fscene.Node>> _nodesByEntity = {};
  final Map<fscene.Node, String> _entityByNode = {};
  final Map<String, List<fscene.Material>> _materialsByEntity = {};
  final Map<String, vm.Vector4> _baseColorByEntity = {};

  /// Viaturas simuladas: nós dinâmicos (posição/rotação por frame) —
  /// não fazem parte do upload estático da cena.
  final List<fscene.Node> _vehicleNodes = [];
  VehicleFleet? _vehicleFleet;

  /// Viaturas visíveis só com a camada 3D OPACA (SceneOverlayOpacity = 1,
  /// câmera ≤ 1000 m): a opacidade do crossfade 2D↔3D é da camada INTEIRA,
  /// então na banda translúcida (1000–1400 m) o carro ficaria um fantasma
  /// com a base 2D (ruas/setas) misturada por cima. Os ícones 2D assumem.
  bool _vehiclesVisible = true;

  /// Modelos glTF por tipo (template carregado 1×; instâncias clonam
  /// compartilhando GPU). Diretório do asset + alinhamento de frente
  /// (glTF → engine +X): polícia tem frente presumida em +Z, bombeiro
  /// já em +X — inverter o sinal se visto de costas no app.
  static const _kVehicleModelDir = {
    VehicleKind.police: 'assets/vehicles/bmw_police_car',
    VehicleKind.fire: 'assets/vehicles/fire_truck',
  };
  static const _kVehicleModelYaw = {
    VehicleKind.police: math.pi / 2,
    // Sketchfab: frente em −X (andava de ré) → +X com meia-volta.
    VehicleKind.fire: math.pi,
  };

  /// Escala dos modelos (unidades glTF já são metros; 1.35 deixa os
  /// carros bem legíveis em câmera média).
  static const _kVehicleModelScale = 1.35;

  /// Layer de profundidade dos materiais: vias usam 3–5 e o layer
  /// EMPURRA a superfície para a câmera (overlay coplanar, cresce longe
  /// da origem do mundo — cidades a km). Viaturas em 7 vencem qualquer
  /// capa; a separação REAL vem do lift no vehicle_system.
  static const _kVehicleDepthLayer = 7;

  /// Offset MUNDO para a câmera (Material.depthBias): complementa o
  /// layer — vias/pads/marcações só pintam sobre a viatura se estiverem
  /// >1.5 m mais perto da câmera. Invisível (não move pixels, só depth).
  static const _kVehicleDepthBias = 1.5;

  final Map<VehicleKind, fscene.Node> _vehicleTemplates = {};
  final Map<String, fscene.Node> _tileParents = {};
  final Set<fscene.Node> _annotationNodes = {};

  /// TASK-0011: volumes rangeGated por tile + pad plano por tile +
  /// fator de extrusão corrente por tile (smoothstep na banda do gate).
  final Map<String, List<fscene.Node>> _gatedVolumesByTile = {};
  final Map<String, fscene.Node> _footprintNodeByTile = {};
  final Map<String, double> _extrusionByTile = {};

  /// Último estado do LOD global visto pelo gate (detecta flip para
  /// re-aplicar visibilidade mesmo com extrusão inalterada).
  bool _gateLodVisible = true;

  /// Limite de vista: AABB x/z por tile, preparado pelo motor — o
  /// nó-pai some quando o raio de visão não o toca (outras
  /// cidades do bundle deixam de ir à GPU).
  final Map<String, ({double minX, double minZ, double maxX, double maxZ})>
  _tileBounds = {};
  double _lastCullX = double.nan;
  double _lastCullZ = double.nan;
  double _lastCullRadius = double.nan;

  /// Raio base (m): cobre a viewport 3D até o limiar de modo (~3500 m)
  /// sem desenhar cidades vizinhas. Inclinação baixa amplia o raio, mas
  /// o teto mantém a janela local limitada.
  static const double _cullRadiusMeters = 6000;
  static const double _maxCullRadiusMeters = 8000;

  /// ETAPA 08: LOD — nodes por entidade, agrupados por nível.
  final Map<fscene.Node, int> _lodByNode = {};
  double _lastLodDistance = double.infinity;

  /// Cena corrente (a view troca quando [sceneVersion] muda).
  fscene.Scene get scene => _scene;
  int sceneVersion = 0;

  /// Nós de anotação (visual-only): testes leem visibilidade/raycastable.
  @visibleForTesting
  Iterable<fscene.Node> get annotationNodes => _annotationNodes;

  /// TASK-0011: nós de volume rangeGated e pads planos (testes de gate).
  @visibleForTesting
  Iterable<fscene.Node> get gatedVolumeNodes =>
      _gatedVolumesByTile.values.expand((nodes) => nodes);

  @visibleForTesting
  Iterable<fscene.Node> get footprintNodes => _footprintNodeByTile.values;

  /// Falha injetada do PRÓXIMO atlas por tile (testes de degradação local).
  @visibleForTesting
  bool failNextRoadNameAtlas = false;

  /// Visibilidade atual dos nós de uma entidade (testes de LOD/seleção).
  @visibleForTesting
  bool isEntityVisible(String entityId) =>
      (_nodesByEntity[entityId] ?? const <fscene.Node>[]).every(
        (node) => node.visible,
      );

  /// ETAPA 07: alterna entre noturno (UnlitMaterial + vertex colors) e
  /// diurno (PhysicallyBasedMaterial + DirectionalLight). Trocar o modo
  /// reconstrói a cena — não há per-frame overhead.
  set lightingMode(SceneLightingMode mode) {
    if (_lightingMode == mode) return;
    _lightingMode = mode;
  }

  SceneLightingMode get lightingMode => _lightingMode;

  /// Contagem de objetos gráficos na cena carregada (uma entidade pode
  /// ter vários nós: via + suas pads de junção).
  int get objectCount => _entityByNode.length;

  @override
  Future<void> uploadScene(
    MapScene mapScene, {
    void Function(double progress)? onProgress,
  }) async {
    _scene = fscene.Scene();
    _vehicleNodes.clear();
    _vehicleFleet = null;
    _vehicleTemplates.clear();
    _nodesByEntity.clear();
    _entityByNode.clear();
    _materialsByEntity.clear();
    _baseColorByEntity.clear();
    _tileParents.clear();
    _tileBounds.clear();
    _tileBounds.addAll(mapScene.tileBounds);
    for (final batch in mapScene.annotations) {
      final bounds = batch.bounds;
      final previous = _tileBounds[batch.tileId];
      _tileBounds[batch.tileId] = previous == null
          ? (
              minX: bounds.min.x,
              minZ: bounds.min.z,
              maxX: bounds.max.x,
              maxZ: bounds.max.z,
            )
          : (
              minX: math.min(previous.minX, bounds.min.x),
              minZ: math.min(previous.minZ, bounds.min.z),
              maxX: math.max(previous.maxX, bounds.max.x),
              maxZ: math.max(previous.maxZ, bounds.max.z),
            );
    }
    _lodByNode.clear();
    _annotationNodes.clear();
    _gatedVolumesByTile.clear();
    _footprintNodeByTile.clear();
    _extrusionByTile.clear();
    _gateLodVisible = true;
    _lastCullX = _lastCullZ = _lastCullRadius = double.nan;
    // Nodes novos nascem visible=true: força o primeiro updateLOD a
    // re-aplicar as gates (senão |Δ|<50 m deixa tudo visível pós-upload).
    _lastLodDistance = double.infinity;
    sceneVersion++;

    for (final tileId in mapScene.tileIds) {
      final parent = fscene.Node()..name = tileId;
      _scene.add(parent);
      _tileParents[tileId] = parent;
    }

    // ETAPA 07: no modo diurno, a luz direcional do Scene (conveniência
    // do flutter_scene) acende os PBR volumes e projeta sombras.
    if (_lightingMode == SceneLightingMode.day) {
      _scene.directionalLight = fscene.DirectionalLight(
        direction: vm.Vector3(0.5, -1.0, 0.85),
        intensity: 2.5,
        castsShadow: true,
      );
    } else {
      _scene.directionalLight = null;
    }

    // Upload fatiado: criar MeshGeometry/nodes na main isolate é a única
    // opção (APIs do renderer não rodam em isolate), mas em LOTES com
    // `await` entre eles — sem isso, 17k objetos congelam a UI.
    const int batch = 400;
    final int total = mapScene.objects.length;
    for (var i = 0; i < total; i++) {
      final obj = mapScene.objects[i];
      final color4 = vm.Vector4(
        obj.color.x.toDouble(),
        obj.color.y.toDouble(),
        obj.color.z.toDouble(),
        1.0,
      );
      // Noturno: Unlit + vertex colors (sombreamento de fachadas).
      // Diurno: PBR — mesmas cores, mas com resposta à luz real.
      final fscene.Material material;
      if (_lightingMode == SceneLightingMode.day) {
        final pbr = fscene.PhysicallyBasedMaterial()
          ..baseColorFactor = color4
          ..metallicFactor = 0.0
          ..roughnessFactor = 0.85;
        // Pads de junção: camada de profundidade acima das vias.
        pbr.depthLayer = obj.depthLayer;
        material = pbr;
      } else {
        final unlit = fscene.UnlitMaterial()
          ..baseColorFactor = color4
          // Paleta em display-referred: a cor autoral chega na tela
          // IGUAL ao canvas 2D — sem a curva de tone/linear→sRGB que
          // clareava a cena (via 0.40 saía ~0.66).
          ..displayReferred = true;
        unlit.depthLayer = obj.depthLayer;
        material = unlit;
      }
      // Edifícios: culling OFF — o volume fechado (paredes+teto+piso)
      // nunca some por convenção de winding/culling do rasterizador;
      // sem faces coincidentes no motor, o custo é só o overdraw das
      // faces internas quando visíveis.
      if (obj.kind == SceneObjectKind.building) {
        material.doubleSided = true;
      }
      final geometry = fscene.MeshGeometry.fromArrays(
        positions: Float32List.fromList(obj.mesh.positions),
        normals: Float32List.fromList(obj.mesh.normals),
        colors: obj.mesh.colors == null
            ? null
            : Float32List.fromList(obj.mesh.colors!),
        texCoords: obj.mesh.texCoords,
        indices: obj.mesh.indices,
      );
      final node = fscene.Node(mesh: fscene.Mesh(geometry, material));
      node.name = obj.entityId;
      final parent = _tileParents[obj.tileId];
      if (parent != null) {
        parent.add(node);
      } else {
        _scene.add(node);
      }
      _nodesByEntity.putIfAbsent(obj.entityId, () => []).add(node);
      if (obj.rangeGated) {
        // TASK-0011: visibilidade do volume é do gate por tile, não do
        // LOD global — nasce oculto até o primeiro updateLOD decidir.
        _gatedVolumesByTile.putIfAbsent(obj.tileId, () => []).add(node);
        node.visible = false;
      } else {
        _lodByNode[node] = LodPolicy.levelOf(obj.kind);
      }
      _entityByNode[node] = obj.entityId;
      _materialsByEntity.putIfAbsent(obj.entityId, () => []).add(material);
      _baseColorByEntity.putIfAbsent(
        obj.entityId,
        () => _baseColorOf(material),
      );

      if (i % batch == batch - 1 || i == total - 1) {
        onProgress?.call(total == 0 ? 1 : (i + 1) / total);
        // Cede o event loop: frames, gestos e o overlay seguem fluindo.
        await Future<void>.delayed(Duration.zero);
      }
    }

    for (final batch in mapScene.annotations) {
      final parent = _tileParents[batch.tileId];
      if (parent == null) continue;

      if (batch.roadNames.isNotEmpty) {
        try {
          final atlas = await _createRoadNameAtlas(batch.roadNames);
          if (atlas != null) {
            final node =
                fscene.Node(
                    mesh: fscene.Mesh(
                      fscene.MeshGeometry.fromArrays(
                        positions: atlas.mesh.positions,
                        normals: atlas.mesh.normals,
                        texCoords: atlas.mesh.texCoords,
                        indices: atlas.mesh.indices,
                        retainCpuData: false,
                      ),
                      fscene.UnlitMaterial(colorTexture: atlas.texture)
                        ..alphaMode = fscene.AlphaMode.blend,
                    ),
                  )
                  ..raycastable = false
                  ..visible = false;
            parent.add(node);
            _annotationNodes.add(node);
          }
        } catch (error, stackTrace) {
          // Atlas failure is tile-local: arrow and base-scene upload continue.
          debugPrint(
            'Road-name atlas failed for ${batch.tileId}: $error\n$stackTrace',
          );
        }
      }

      final arrowMesh = batch.arrowMesh;
      if (arrowMesh != null && arrowMesh.vertexCount > 0) {
        final color = FogoPalette.crossing;
        final node =
            fscene.Node(
                mesh: fscene.Mesh(
                  fscene.MeshGeometry.fromArrays(
                    positions: arrowMesh.positions,
                    normals: arrowMesh.normals,
                    colors: arrowMesh.colors,
                    texCoords: arrowMesh.texCoords,
                    indices: arrowMesh.indices,
                    retainCpuData: false,
                  ),
                  fscene.UnlitMaterial()
                    ..baseColorFactor = vm.Vector4(
                      color.x.toDouble(),
                      color.y.toDouble(),
                      color.z.toDouble(),
                      1,
                    )
                    // Mesma paleta do 2D: display-referred (sem tone curve).
                    ..displayReferred = true,
                ),
              )
              ..raycastable = false
              ..visible = false;
        parent.add(node);
        _annotationNodes.add(node);
      }
      await Future<void>.delayed(Duration.zero);
    }
    for (final batch in mapScene.buildingFootprints) {
      final parent = _tileParents[batch.tileId];
      if (parent == null) continue;
      final color = FogoPalette.building;
      final node =
          fscene.Node(
              mesh: fscene.Mesh(
                fscene.MeshGeometry.fromArrays(
                  positions: batch.mesh.positions,
                  normals: batch.mesh.normals,
                  indices: batch.mesh.indices,
                  retainCpuData: false,
                ),
                fscene.UnlitMaterial()
                  ..baseColorFactor = vm.Vector4(
                    color.x.toDouble(),
                    color.y.toDouble(),
                    color.z.toDouble(),
                    1,
                  )
                  ..depthLayer = 3
                  // Mesma paleta do 2D: display-referred (sem tone curve).
                  ..displayReferred = true,
              ),
            )
            ..raycastable = false
            ..visible = false;
      parent.add(node);
      _footprintNodeByTile[batch.tileId] = node;
    }
  }

  /// Anexa a frota à cena: um nó por viatura. Modelos glTF em
  /// `assets/vehicles/` (template por tipo, instâncias clonam e
  /// compartilham GPU); fallback: malha de caixas procedural. Chamar
  /// APÓS o upload da cena — nós vivem na cena corrente.
  Future<void> attachVehicles(VehicleFleet fleet) async {
    _vehicleNodes.clear();
    _vehicleFleet = fleet;
    var viaGltf = 0, viaFallback = 0;
    for (final vehicle in fleet.vehicles) {
      fscene.Node node;
      try {
        node = await _vehicleInstance(vehicle.kind);
        viaGltf++;
      } catch (e) {
        debugPrint(
          'Viatura ${vehicle.kind.name}: glTF falhou ($e) — fallback caixas',
        );
        node = _vehicleBoxNode(vehicle.kind);
        viaFallback++;
      }
      _scene.add(node);
      node.visible = _vehiclesVisible;
      _vehicleNodes.add(node);
    }
    // DIAGNÓSTICO de profundidade: se vias/setas ainda pintarem sobre
    // os carros NESTE build, checar esta linha no console (layer/bias
    // esperados: 7 / 1.5; lift 0.5 m em vehicle_system).
    debugPrint(
      'Viaturas anexadas: $viaGltf glTF, $viaFallback fallback; '
      'depthLayer=$_kVehicleDepthLayer depthBias=$_kVehicleDepthBias '
      'lift=${kVehicleSurfaceLift}m renderOrder=1',
    );
    syncVehicles();
  }

  /// Instância normalizada do modelo glTF: frente = +X local, chão em
  /// y = 0, centrada na origem — o wrapper recebe pos/yaw por frame.
  Future<fscene.Node> _vehicleInstance(VehicleKind kind) async {
    var template = _vehicleTemplates[kind];
    if (template == null) {
      final dir = _kVehicleModelDir[kind]!;
      final gltf = (await rootBundle.load('$dir/scene.gltf')).buffer
          .asUint8List();
      template = await importGltf(
        gltf,
        resolveUri: (uri) async =>
            (await rootBundle.load('$dir/$uri')).buffer.asUint8List(),
      );
      _unlitifyVehicle(template);
      _vehicleTemplates[kind] = template;
    }
    final model = template.clone();
    final yaw = _kVehicleModelYaw[kind]!;
    final bounds = template.combinedLocalBounds;
    if (bounds != null) {
      model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
      // TRS: a escala é aplicada ANTES da rotação/translação — o offset
      // de chão escala junto para o chão continuar em y=0.
      model.scale = vm.Vector3.all(_kVehicleModelScale);
      model.position = vehicleGroundOffset(bounds, yaw)
        ..scale(_kVehicleModelScale);
    }
    _setVehicleRenderOrder(model);
    return fscene.Node()..add(model);
  }

  /// A cena é display-referred INTEIRA (desenha back-to-front SEM depth
  /// write — painter's algorithm): material.depthLayer/depthBias não
  /// ordenam nada nesse bucket, e o PRIMEIRO critério do sort é
  /// Node.renderOrder (default 0 em tudo). Nós de via são ribbons
  /// gigantes — quando o CENTRO do bounds deles fica mais perto da
  /// câmera que a viatura (visto de cima), a via desenha DEPOIS e pinta
  /// por cima. renderOrder=1 garante viatura por último, sempre.
  void _setVehicleRenderOrder(fscene.Node node) {
    node.renderOrder = 1;
    for (final child in node.children) {
      _setVehicleRenderOrder(child);
    }
  }

  /// Importado é PBR (preto na noite, sem luz): troca por Unlit com a
  /// MESMA textura/fator de cor base e display-referred (paleta da cena).
  void _unlitifyVehicle(fscene.Node node) {
    final mesh = node.mesh;
    if (mesh != null) {
      for (final p in mesh.primitives) {
        final m = p.material;
        if (m is fscene.PhysicallyBasedMaterial) {
          p.material = fscene.UnlitMaterial(colorTexture: m.baseColorTexture)
            ..baseColorFactor = m.baseColorFactor
            ..displayReferred = true
            // Vias (layer 3–5) empurram a superfície para a câmera e
            // escondem o carro em ângulo rasante — ver _kVehicleDepthLayer.
            ..depthLayer = _kVehicleDepthLayer
            // Trava final: 1.5 m MUNDO para a câmera — qualquer mobiliário
            // de via (capa, pad de junção, marcação) precisa estar >1.5 m
            // mais perto da câmera para pintar sobre a viatura.
            ..depthBias = _kVehicleDepthBias;
        }
      }
    }
    for (final child in node.children) {
      _unlitifyVehicle(child);
    }
  }

  /// Fallback procedural (caixas coloridas, frente = +X).
  fscene.Node _vehicleBoxNode(VehicleKind kind) {
    final (body, cabin, bar) = switch (kind) {
      VehicleKind.police => (
        vm.Vector3(0.92, 0.92, 0.95),
        vm.Vector3(0.16, 0.20, 0.28),
        vm.Vector3(0.25, 0.50, 1.00),
      ),
      VehicleKind.fire => (
        vm.Vector3(0.80, 0.12, 0.10),
        vm.Vector3(0.16, 0.20, 0.28),
        vm.Vector3(0.95, 0.30, 0.20),
      ),
    };
    final mesh = buildVehicleMesh(body: body, cabin: cabin, bar: bar);
    return fscene.Node(
        mesh: fscene.Mesh(
          fscene.MeshGeometry.fromArrays(
            positions: mesh.positions,
            normals: mesh.normals,
            indices: mesh.indices,
            colors: mesh.colors,
            retainCpuData: false,
          ),
          fscene.UnlitMaterial()
            ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
            // Cores por vértice AUTORAIS: display-referred (paleta
            // igual à do 2D — mesma regra dos objetos estáticos).
            ..displayReferred = true
            ..depthLayer = _kVehicleDepthLayer
            ..depthBias = _kVehicleDepthBias,
        ),
      )
      ..raycastable = false
      // Mesmo motivo do _setVehicleRenderOrder (painter's algorithm).
      ..renderOrder = 1
      ..visible = true;
  }

  /// Aplica posição/yaw das viaturas aos nós — roda por frame no tick
  /// do viewport 3D (a frota em si é tickada pelo dono da câmera).
  void syncVehicles() {
    final fleet = _vehicleFleet;
    if (fleet == null) return;
    for (
      var i = 0;
      i < fleet.vehicles.length && i < _vehicleNodes.length;
      i++
    ) {
      final v = fleet.vehicles[i];
      final node = _vehicleNodes[i];
      node.visible = _vehiclesVisible;
      node.position = vm.Vector3(v.x, v.y, v.z);
      node.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), v.heading);
    }
  }

  /// Liga/desliga as viaturas 3D (crossfade 2D↔3D — ver _vehiclesVisible).
  set vehiclesVisible(bool visible) {
    if (visible == _vehiclesVisible) return;
    _vehiclesVisible = visible;
    for (final node in _vehicleNodes) {
      node.visible = visible;
    }
  }

  @override
  Future<void> clear() async {
    _scene = fscene.Scene();
    _vehicleNodes.clear();
    _vehicleFleet = null;
    _vehicleTemplates.clear();
    _nodesByEntity.clear();
    _entityByNode.clear();
    _materialsByEntity.clear();
    _baseColorByEntity.clear();
    _tileParents.clear();
    _tileBounds.clear();
    _lodByNode.clear();
    _annotationNodes.clear();
    _gatedVolumesByTile.clear();
    _footprintNodeByTile.clear();
    _extrusionByTile.clear();
    _gateLodVisible = true;
    _lastCullX = _lastCullZ = _lastCullRadius = double.nan;
    sceneVersion++;
  }

  /// ETAPA 08: atualiza visibilidade por LOD (gates por entidade, com
  /// histerese — só trabalho quando a distância CRUZOU um threshold).
  ///
  /// Com [cullCenter], aplica também o LIMITE DE VISTA: nó-pai do tile
  /// some quando a esfera de visão (raio cresce com a câmera baixa —
  /// horizonte) não toca a AABB do tile. Roda por frame: iteração
  /// barata (esfera vs AABB), sem custo em comparação ao que corta.
  ///
  /// TASK-0011: [cameraPosition] aciona o gate de volumes — só tiles
  /// dentro de [LodPolicy.buildingVolumeRadiusMeters] da CÂMERA mostram
  /// volumes; o resto mostra o pad plano do tile.
  void updateLOD(
    double cameraDistance, {
    vm.Vector3? cullCenter,
    double elevationRadians = math.pi / 2,
    vm.Vector3? cameraPosition,
  }) {
    final previousLodDistance = _lastLodDistance;
    if ((cameraDistance - _lastLodDistance).abs() >= 50) {
      final prev = _lastLodDistance;
      _lastLodDistance = cameraDistance;
      _lodByNode.forEach((node, level) {
        node.visible = LodPolicy.isLevelVisible(
          level,
          cameraDistance,
          previousDistance: prev,
        );
      });
    }
    _updateBuildingRangeGate(
      cameraDistance,
      cameraPosition,
      previousLodDistance: previousLodDistance,
    );
    final annotationsVisible =
        cameraDistance <= RoadAnnotationBatch.maxCameraDistanceMeters;
    for (final node in _annotationNodes) {
      node.visible = annotationsVisible;
    }
    if (cullCenter == null || _tileBounds.isEmpty) return;
    final radius = math.min(
      _maxCullRadiusMeters,
      _cullRadiusMeters / elevationRadians.clamp(0.35, 1.0),
    );
    if ((cullCenter.x - _lastCullX).abs() < 50 &&
        (cullCenter.z - _lastCullZ).abs() < 50 &&
        (radius - _lastCullRadius).abs() < 50) {
      return;
    }
    _lastCullX = cullCenter.x;
    _lastCullZ = cullCenter.z;
    _lastCullRadius = radius;
    _tileParents.forEach((tileId, parent) {
      final b = _tileBounds[tileId];
      if (b == null) return;
      final visible =
          distanceSqToBox(
            minX: b.minX,
            minZ: b.minZ,
            maxX: b.maxX,
            maxZ: b.maxZ,
            x: cullCenter.x,
            z: cullCenter.z,
          ) <=
          radius * radius;
      if (parent.visible != visible) parent.visible = visible;
    });
  }

  /// Extrusão progressiva estilo Mapbox: volumes de edifício crescem do
  /// chão conforme a câmera se aproxima (smoothstep na banda do gate,
  /// 700→600 m); pads planos (footprints 2D) permanecem por baixo até a
  /// altura completa. Roda TODO frame — a escala acompanha o ZOOM, que
  /// muda sem deslocar a câmera no plano. O LOD global (3.500 m) esconde
  /// ambos, como hoje.
  void _updateBuildingRangeGate(
    double cameraDistance,
    vm.Vector3? cameraPosition, {
    required double previousLodDistance,
  }) {
    if (cameraPosition == null) return;
    if (_gatedVolumesByTile.isEmpty && _footprintNodeByTile.isEmpty) return;

    final radiusIn = LodPolicy.buildingVolumeRadiusMeters;
    final radiusOut = radiusIn + LodPolicy.buildingVolumeHysteresisMeters;
    final tileIds = {..._gatedVolumesByTile.keys, ..._footprintNodeByTile.keys};
    // Pads e volumes compartilham o LOD das vias de nível 1 (3.500 m):
    // além disso a cidade inteira esconde, como hoje.
    final lodVisible = LodPolicy.isLevelVisible(
      1,
      cameraDistance,
      previousDistance: previousLodDistance,
    );
    // LOD cruzou um threshold: re-aplica visibilidade mesmo com a
    // extrusão inalterada (o skip por epsilon pularia o flip).
    final bool lodChanged = lodVisible != _gateLodVisible;
    _gateLodVisible = lodVisible;
    for (final tileId in tileIds) {
      final bounds = _tileBounds[tileId];
      final double k = bounds == null
          ? 1.0
          : extrusionFactor(
              distanceMeters: math.sqrt(
                distanceSqToBox(
                  minX: bounds.minX,
                  minZ: bounds.minZ,
                  maxX: bounds.maxX,
                  maxZ: bounds.maxZ,
                  x: cameraPosition.x,
                  z: cameraPosition.z,
                ),
              ),
              radiusIn: radiusIn,
              radiusOut: radiusOut,
            );
      final volumes = _gatedVolumesByTile[tileId];
      if (volumes != null) {
        final lastK = _extrusionByTile[tileId] ?? -1.0;
        if (lodChanged ||
            (k - lastK).abs() >= 0.01 ||
            (k == 0) != (lastK == 0)) {
          _extrusionByTile[tileId] = k;
          for (final node in volumes) {
            node.visible = lodVisible && k > 0;
            node.scale = vm.Vector3(1, k, 1);
          }
        }
      }
      final pad = _footprintNodeByTile[tileId];
      if (pad != null) {
        final visible = lodVisible && k < 1;
        if (pad.visible != visible) pad.visible = visible;
      }
    }
  }

  /// Fator de extrusão 0..1 (smoothstep) pela distância da câmera ao
  /// tile: 0 em [radiusOut] (só footprint), 1 em [radiusIn] (altura
  /// real). Substitui o flip binário com histerese — contínuo não flappa.
  @visibleForTesting
  static double extrusionFactor({
    required double distanceMeters,
    required double radiusIn,
    required double radiusOut,
  }) {
    return SceneOverlayOpacity.smoothstep(
      (radiusOut - distanceMeters) / (radiusOut - radiusIn),
    );
  }

  /// Distância² do ponto (x,z) à AABB x/z — 0 quando dentro.
  @visibleForTesting
  static double distanceSqToBox({
    required double minX,
    required double minZ,
    required double maxX,
    required double maxZ,
    required double x,
    required double z,
  }) {
    final dx = math.max(math.max(minX - x, x - maxX), 0.0);
    final dz = math.max(math.max(minZ - z, z - maxZ), 0.0);
    return dx * dx + dz * dz;
  }

  Future<_RoadNameAtlas?> _createRoadNameAtlas(
    List<RoadNamePlacement> placements,
  ) async {
    if (failNextRoadNameAtlas) {
      failNextRoadNameAtlas = false;
      throw StateError('Injected road-name atlas failure');
    }
    final packed = packRoadNameAtlas(placements);
    if (packed == null) return null;
    ui.Image? image;
    try {
      image = await packed.picture.toImage(packed.width, packed.height);
      final texture = await fscene.Texture2D.fromImage(
        image,
        sampling: const fscene.TextureSampling(maxMipmapLevels: 4),
      );
      return _RoadNameAtlas(texture, packed.mesh);
    } finally {
      image?.dispose();
      packed.picture.dispose();
    }
  }

  /// CPU-only packing seam (no GPU context required): lays out each road
  /// name that fits its span, packs the per-tile atlas, assigns UVs, and
  /// builds the decal quad mesh. Returns null when no name fits.
  @visibleForTesting
  static ({ui.Picture picture, int width, int height, MeshData mesh})?
  packRoadNameAtlas(List<RoadNamePlacement> placements) {
    final glyphs = <_RoadNameGlyph>[];
    try {
      for (final placement in placements) {
        final glyph = _RoadNameGlyph.create(placement);
        if (glyph != null) glyphs.add(glyph);
      }
      if (glyphs.isEmpty) return null;

      glyphs.sort((a, b) => b.cellHeight.compareTo(a.cellHeight));
      final area = glyphs.fold<int>(
        0,
        (sum, glyph) => sum + glyph.cellWidth * glyph.cellHeight,
      );
      final widestCell = glyphs.fold<int>(
        0,
        (width, glyph) => math.max(width, glyph.cellWidth).toInt(),
      );
      final atlasWidth = _nextPowerOfTwo(
        math.max(widestCell, math.sqrt(area).ceil()).toInt(),
      );
      var x = 0;
      var y = 0;
      var rowHeight = 0;
      for (final glyph in glyphs) {
        if (x + glyph.cellWidth > atlasWidth) {
          y += rowHeight;
          x = 0;
          rowHeight = 0;
        }
        glyph.x = x;
        glyph.y = y;
        x += glyph.cellWidth;
        rowHeight = math.max(rowHeight, glyph.cellHeight).toInt();
      }
      final atlasHeight = _nextPowerOfTwo(y + rowHeight);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      for (final glyph in glyphs) {
        final contentWidth = glyph.contentWidth;
        final contentHeight = glyph.contentHeight;
        final contentX =
            glyph.x +
            _roadNameAtlasPadding +
            (glyph.cellWidth - 2 * _roadNameAtlasPadding - contentWidth) / 2;
        final contentY =
            glyph.y +
            _roadNameAtlasPadding +
            (glyph.cellHeight - 2 * _roadNameAtlasPadding - contentHeight) / 2;
        final textOffset = ui.Offset(
          contentX + _roadNameOutlineWidth / 2,
          contentY + _roadNameOutlineWidth / 2,
        );
        glyph.outlinePainter.paint(canvas, textOffset);
        glyph.fillPainter.paint(canvas, textOffset);
        glyph.uMin = contentX / atlasWidth;
        glyph.uMax = (contentX + contentWidth) / atlasWidth;
        glyph.vMin = contentY / atlasHeight;
        glyph.vMax = (contentY + contentHeight) / atlasHeight;
      }
      final picture = recorder.endRecording();
      final mesh = _roadNameMesh(glyphs);
      if (mesh == null) {
        picture.dispose();
        return null;
      }
      return (
        picture: picture,
        width: atlasWidth,
        height: atlasHeight,
        mesh: mesh,
      );
    } finally {
      for (final glyph in glyphs) {
        glyph.outlinePainter.dispose();
        glyph.fillPainter.dispose();
      }
    }
  }

  static MeshData? _roadNameMesh(List<_RoadNameGlyph> glyphs) {
    final positions = <double>[];
    final normals = <double>[];
    final texCoords = <double>[];
    final indices = <int>[];
    for (final glyph in glyphs) {
      final placement = glyph.placement;
      final tangentLength = math.sqrt(
        placement.tangent.x * placement.tangent.x +
            placement.tangent.z * placement.tangent.z,
      );
      if (!tangentLength.isFinite || tangentLength == 0) continue;
      final tx = placement.tangent.x / tangentLength;
      final tz = placement.tangent.z / tangentLength;
      final nx = -tz;
      final nz = tx;
      final halfLength = glyph.worldWidth / 2;
      final halfHeight = placement.maxHeightMeters / 2;
      final center = placement.center;
      final vertices = <(double, double, double)>[
        (
          center.x - tx * halfLength - nx * halfHeight,
          center.y,
          center.z - tz * halfLength - nz * halfHeight,
        ),
        (
          center.x + tx * halfLength - nx * halfHeight,
          center.y,
          center.z + tz * halfLength - nz * halfHeight,
        ),
        (
          center.x + tx * halfLength + nx * halfHeight,
          center.y,
          center.z + tz * halfLength + nz * halfHeight,
        ),
        (
          center.x - tx * halfLength + nx * halfHeight,
          center.y,
          center.z - tz * halfLength + nz * halfHeight,
        ),
      ];
      final vertexOffset = positions.length ~/ 3;
      for (final (px, py, pz) in vertices) {
        positions.addAll([px, py, pz]);
        normals.addAll([0, 1, 0]);
      }
      texCoords.addAll([
        glyph.uMin,
        glyph.vMax,
        glyph.uMax,
        glyph.vMax,
        glyph.uMax,
        glyph.vMin,
        glyph.uMin,
        glyph.vMin,
      ]);
      indices.addAll([
        vertexOffset,
        vertexOffset + 2,
        vertexOffset + 1,
        vertexOffset,
        vertexOffset + 3,
        vertexOffset + 2,
      ]);
    }
    if (positions.isEmpty) return null;
    return MeshData(
      positions: Float32List.fromList(positions),
      normals: Float32List.fromList(normals),
      texCoords: Float32List.fromList(texCoords),
      indices: Uint32List.fromList(indices),
    );
  }

  static int _nextPowerOfTwo(int value) {
    var size = 1;
    while (size < value) {
      size <<= 1;
    }
    return size;
  }

  static const double _roadNameFontSize = 64;
  static const double _roadNameOutlineWidth = 5;
  static const int _roadNameAtlasPadding = 8;

  static ui.Color _paletteColor(Vector3 color) => ui.Color.fromARGB(
    255,
    (color.x * 255).round().clamp(0, 255).toInt(),
    (color.y * 255).round().clamp(0, 255).toInt(),
    (color.z * 255).round().clamp(0, 255).toInt(),
  );

  /// baseColorFactor em Unlit OU PBR (sem interface comum no flutter_scene).
  static vm.Vector4 _baseColorOf(fscene.Material m) {
    if (m case fscene.UnlitMaterial unlit) {
      return unlit.baseColorFactor;
    } else if (m case fscene.PhysicallyBasedMaterial pbr) {
      return pbr.baseColorFactor;
    }
    return vm.Vector4(1, 1, 1, 1);
  }

  static void _setBaseColor(fscene.Material m, vm.Vector4 color) {
    if (m case fscene.UnlitMaterial unlit) {
      unlit.baseColorFactor = color;
    } else if (m case fscene.PhysicallyBasedMaterial pbr) {
      pbr.baseColorFactor = color;
    }
  }

  @override
  void setEntityColor(String entityId, Vector3? color) {
    final materials = _materialsByEntity[entityId];
    if (materials == null) return;
    final highlight = color == null
        ? null
        : vm.Vector4(
            color.x.toDouble(),
            color.y.toDouble(),
            color.z.toDouble(),
            1.0,
          );
    for (final m in materials) {
      if (color == null) {
        // Restauração: cor base original.
        _setBaseColor(
          m,
          _baseColorByEntity[entityId] ?? vm.Vector4(1, 1, 1, 1),
        );
        // Restaura a paleta por vertex colors após remover o destaque.
        if (m case fscene.UnlitMaterial unlit) {
          unlit.vertexColorWeight = 1.0;
        } else if (m case fscene.PhysicallyBasedMaterial pbr) {
          pbr.vertexColorWeight = 1.0;
        }
      } else {
        // Destaque: cor sólida legível de qualquer ângulo.
        _setBaseColor(m, highlight!);
        if (m case fscene.UnlitMaterial unlit) {
          unlit.vertexColorWeight = 0.0;
        } else if (m case fscene.PhysicallyBasedMaterial pbr) {
          pbr.vertexColorWeight = 0.0;
        }
      }
    }
  }

  /// Seleção por raycast: ponto de tela → entidade cartográfica.
  /// A identidade retornada é a da entidade (`way/…`), nunca a do nó
  /// gráfico.
  String? pickEntity(
    ui.Offset localPosition,
    ui.Size viewSize,
    fscene.PerspectiveCamera camera,
  ) {
    final ray = camera.screenPointToRay(localPosition, viewSize);
    final hit = _scene.raycast(ray);
    if (hit == null) return null;
    return _entityByNode[hit.node];
  }
}

class _RoadNameGlyph {
  _RoadNameGlyph._({
    required this.placement,
    required this.fillPainter,
    required this.outlinePainter,
    required this.contentWidth,
    required this.contentHeight,
  }) : cellWidth =
           contentWidth.ceil() + 2 * FlutterSceneAdapter._roadNameAtlasPadding,
       cellHeight =
           contentHeight.ceil() + 2 * FlutterSceneAdapter._roadNameAtlasPadding,
       worldWidth = placement.maxHeightMeters * contentWidth / contentHeight;

  static _RoadNameGlyph? create(RoadNamePlacement placement) {
    final tangentLength = math.sqrt(
      placement.tangent.x * placement.tangent.x +
          placement.tangent.z * placement.tangent.z,
    );
    if (placement.text.trim().isEmpty ||
        !placement.maxLengthMeters.isFinite ||
        !placement.maxHeightMeters.isFinite ||
        placement.maxLengthMeters <= 0 ||
        placement.maxHeightMeters <= 0 ||
        !placement.center.x.isFinite ||
        !placement.center.y.isFinite ||
        !placement.center.z.isFinite ||
        !tangentLength.isFinite ||
        tangentLength == 0) {
      return null;
    }

    final fillPainter = TextPainter(
      text: TextSpan(
        text: placement.text,
        style: TextStyle(
          color: FlutterSceneAdapter._paletteColor(FogoPalette.crossing),
          fontSize: FlutterSceneAdapter._roadNameFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    final outlinePainter = TextPainter(
      text: TextSpan(
        text: placement.text,
        style: TextStyle(
          foreground: ui.Paint()
            ..color = FlutterSceneAdapter._paletteColor(FogoPalette.ground)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = FlutterSceneAdapter._roadNameOutlineWidth
            ..strokeJoin = ui.StrokeJoin.round,
          fontSize: FlutterSceneAdapter._roadNameFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    try {
      fillPainter.layout();
      outlinePainter.layout();
      final contentWidth =
          math.max(fillPainter.width, outlinePainter.width) +
          FlutterSceneAdapter._roadNameOutlineWidth;
      final contentHeight =
          math.max(fillPainter.height, outlinePainter.height) +
          FlutterSceneAdapter._roadNameOutlineWidth;
      final worldWidth =
          placement.maxHeightMeters * contentWidth / contentHeight;
      // Keep text at the supplied road-width height; omit rather than shrink
      // below that legible size when the available straight span is too short.
      if (!contentWidth.isFinite ||
          !contentHeight.isFinite ||
          contentWidth <= 0 ||
          contentHeight <= 0 ||
          worldWidth > placement.maxLengthMeters) {
        fillPainter.dispose();
        outlinePainter.dispose();
        return null;
      }
      return _RoadNameGlyph._(
        placement: placement,
        fillPainter: fillPainter,
        outlinePainter: outlinePainter,
        contentWidth: contentWidth,
        contentHeight: contentHeight,
      );
    } catch (_) {
      fillPainter.dispose();
      outlinePainter.dispose();
      rethrow;
    }
  }

  final RoadNamePlacement placement;
  final TextPainter fillPainter;
  final TextPainter outlinePainter;
  final double contentWidth;
  final double contentHeight;
  final int cellWidth;
  final int cellHeight;
  final double worldWidth;
  int x = 0;
  int y = 0;
  double uMin = 0;
  double uMax = 0;
  double vMin = 0;
  double vMax = 0;
}

class _RoadNameAtlas {
  const _RoadNameAtlas(this.texture, this.mesh);

  final fscene.Texture2D texture;
  final MeshData mesh;
}
