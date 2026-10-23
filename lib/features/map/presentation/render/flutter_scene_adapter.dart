import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_scene/scene.dart' as fscene;
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../engine/fogo_engine.dart';
import '../../../../engine/geometry/mesh_data.dart';

/// Implementação concreta do [RenderBackend] sobre Flutter Scene.
///
/// ÚNICA camada que depende das APIs de renderização: converte [MeshData]
/// do motor (Float32List/Uint32List) em `MeshGeometry.fromArrays` e
/// `UnlitMaterial`, agrupa objetos em nós-pai por tile (particionamento
/// espacial; culling por nó + futuras janelas de visibilidade por tile)
/// e resolve o raycast de seleção de volta ao id da ENTIDADE.
class FlutterSceneAdapter implements RenderBackend {
  FlutterSceneAdapter() : _scene = fscene.Scene();

  fscene.Scene _scene;
  final Map<String, fscene.Node> _nodesByEntity = {};
  final Map<fscene.Node, String> _entityByNode = {};
  final Map<String, fscene.Node> _tileParents = {};
  final Map<String, vm.Vector4> _baseColorByEntity = {};
  final Map<String, fscene.UnlitMaterial> _materialByEntity = {};

  /// Cena corrente (a view troca quando [sceneVersion] muda).
  fscene.Scene get scene => _scene;
  int sceneVersion = 0;

  /// Contagem de objetos na cena carregada.
  int get objectCount => _nodesByEntity.length;

  @override
  Future<void> uploadScene(MapScene mapScene) async {
    _scene = fscene.Scene();
    _nodesByEntity.clear();
    _entityByNode.clear();
    _tileParents.clear();
    _baseColorByEntity.clear();
    _materialByEntity.clear();
    sceneVersion++;

    for (final tileId in mapScene.tileIds) {
      final parent = fscene.Node()..name = tileId;
      _scene.add(parent);
      _tileParents[tileId] = parent;
    }

    for (final obj in mapScene.objects) {
      final geometry = fscene.MeshGeometry.fromArrays(
        positions: Float32List.fromList(obj.mesh.positions),
        normals: Float32List.fromList(obj.mesh.normals),
        indices: obj.mesh.indices,
      );
      final material = fscene.UnlitMaterial()
        ..baseColorFactor = vm.Vector4(
          obj.color.x.toDouble(),
          obj.color.y.toDouble(),
          obj.color.z.toDouble(),
          1.0,
        );
      final node = fscene.Node(mesh: fscene.Mesh(geometry, material));
      node.name = obj.entityId;
      final parent = _tileParents[obj.tileId];
      if (parent != null) {
        parent.add(node);
      } else {
        _scene.add(node);
      }
      _nodesByEntity[obj.entityId] = node;
      _entityByNode[node] = obj.entityId;
      _materialByEntity[obj.entityId] = material;
      _baseColorByEntity[obj.entityId] = material.baseColorFactor;
    }
  }

  @override
  Future<void> clear() async {
    _scene = fscene.Scene();
    _nodesByEntity.clear();
    _entityByNode.clear();
    _tileParents.clear();
    _baseColorByEntity.clear();
    _materialByEntity.clear();
    sceneVersion++;
  }

  @override
  void setEntityColor(String entityId, Vector3? color) {
    final material = _materialByEntity[entityId];
    if (material == null) return;
    if (color == null) {
      final base = _baseColorByEntity[entityId];
      if (base != null) material.baseColorFactor = base;
    } else {
      material.baseColorFactor = vm.Vector4(color.x, color.y, color.z, 1.0);
    }
  }

  /// Seleção por raycast: ponto de tela → entidade cartográfica.
  /// A identidade retornada é a da entidade (`way/…`), nunca a do nó
  /// gráfico.
  String? pickEntity(
    Offset localPosition,
    Size viewSize,
    fscene.PerspectiveCamera camera,
  ) {
    final ray = camera.screenPointToRay(localPosition, viewSize);
    final hit = _scene.raycast(ray);
    if (hit == null) return null;
    return _entityByNode[hit.node];
  }
}
