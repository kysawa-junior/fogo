import '../domain/land_area.dart';
import '../domain/road_type.dart';
import '../geometry/mesh_data.dart';
import '../geo/coordinate_projector.dart';
import 'road_annotations.dart';

/// Objeto de cena do motor, independente da biblioteca gráfica.
/// `entityId` é a identidade da ENTIDADE cartográfica (`way/123`), nunca
/// a identidade do objeto gráfico no backend.
class MapSceneObject {
  const MapSceneObject({
    required this.entityId,
    required this.tileId,
    required this.mesh,
    required this.color,
    required this.kind,
    this.depthLayer = 0,
    this.rangeGated = false,
  });

  final String entityId;
  final String tileId;
  final MeshData mesh;

  /// Cor linear RGB 0..1 (materiais básicos; legibilidade > realismo).
  final Vector3 color;
  final SceneObjectKind kind;

  /// Hierarquia visual (ETAPA 09 ajuste): vias maiores ficam ACIMA das
  /// menores quando coplanares — z-fight de pistas paralelas resolve
  /// com a via mais importante cobrindo a menor.
  final int depthLayer;

  /// TASK-0011: volume visível só dentro do raio da câmera; fora dele o
  /// pad plano do tile (MapScene.buildingFootprints) assume. Landmarks
  /// (amenidades) ficam de fora do gate.
  final bool rangeGated;
}

enum SceneObjectKind {
  road,
  building,
  landArea,
  crossing,
  signal,
  roadMarking,
  tree,
  water,
  furniture,
  junctionPad,

  /// ENG-0008: marcador de ponto de interesse (disco no chão).
  poi,
}

/// Pads planos de edifícios de UM tile (TASK-0011): fallback 2D dos
/// volumes fora do raio da câmera. Visual-only — o adapter não deve
/// registrar seleção nem raycast.
class BuildingFootprintBatch {
  const BuildingFootprintBatch({required this.tileId, required this.mesh});

  final String tileId;
  final MeshData mesh;
}

/// Cena pronta para upload: objetos particionados + enquadramento.
class MapScene {
  const MapScene({
    required this.objects,
    required this.worldBounds,
    required this.tileIds,
    this.tileBounds = const {},
    this.annotations = const [],
    this.buildingFootprints = const [],
  });

  final List<MapSceneObject> objects;

  /// Bounds de mundo de toda a região carregada (meters).
  final WorldBounds worldBounds;

  final Set<String> tileIds;

  /// Bounds x/z do conteúdo de cada tile, usadas pelo renderer para
  /// cortar tiles distantes sem recalcular bounds de cada mesh no upload.
  final Map<String, ({double minX, double minZ, double maxX, double maxZ})>
  tileBounds;

  /// Engine-independent, non-selectable road annotations grouped by tile.
  final List<RoadAnnotationBatch> annotations;

  /// Pads planos por tile: substituem os volumes `rangeGated` fora do raio.
  final List<BuildingFootprintBatch> buildingFootprints;
}

/// Paleta noturna do F.O.G.O. 3D — legibilidade e coerência geométrica,
/// não realismo fotográfico.
abstract final class FogoPalette {
  static final Vector3 ground = Vector3(0.05, 0.06, 0.08);

  /// Pavimento uniforme: tipo continua disponível para largura, LOD e
  /// hierarquia, mas não altera a cor da via.
  static Vector3 road(RoadType _) => Vector3(0.40, 0.42, 0.46);

  static Vector3 get building => Vector3(0.16, 0.18, 0.22);
  static Vector3 get crossing => Vector3(0.92, 0.92, 0.95);

  /// Semáforo usa cores por vértice (metal + lentes); branco evita tingir
  /// as peças ao multiplicar o material base pelas cores da malha.
  static Vector3 get signal => Vector3(1, 1, 1);
  static Vector3 get selection => Vector3(0.20, 0.62, 1.00);

  /// ENG-0008: disco de POI — derivado do token de sinal (âmbar
  /// neutro, legível sobre vias e áreas sem cor nova no sistema).
  static Vector3 get poi => Vector3(0.80, 0.65, 0.35);

  static Vector3 land(LandAreaKind kind) => switch (kind) {
    LandAreaKind.park => Vector3(0.10, 0.16, 0.10),
    LandAreaKind.water => Vector3(0.06, 0.10, 0.18),
    LandAreaKind.forest => Vector3(0.08, 0.13, 0.09),
    LandAreaKind.farmland => Vector3(0.13, 0.12, 0.08),
    LandAreaKind.residential => Vector3(0.07, 0.075, 0.09),
    LandAreaKind.industrial => Vector3(0.09, 0.08, 0.10),
    LandAreaKind.commercial => Vector3(0.09, 0.09, 0.11),
    LandAreaKind.education => Vector3(0.10, 0.10, 0.13),
    LandAreaKind.sports => Vector3(0.09, 0.14, 0.09),
    LandAreaKind.parking => Vector3(0.10, 0.10, 0.12),
    // Edifícios de interesse (ex-"other"): tinta sutil por categoria.
    LandAreaKind.fuelStation => Vector3(0.15, 0.13, 0.07),
    LandAreaKind.police => Vector3(0.07, 0.10, 0.15),
    LandAreaKind.hospital => Vector3(0.13, 0.08, 0.09),
    LandAreaKind.placeOfWorship => Vector3(0.10, 0.09, 0.14),
    // Estádio: concreto claro das arquibancadas (o modelo domina a
    // leitura; o gramado é o pitch interno, tinta própria).
    LandAreaKind.stadium => Vector3(0.17, 0.18, 0.16),
    LandAreaKind.other => Vector3(0.065, 0.07, 0.085),
  };
}
