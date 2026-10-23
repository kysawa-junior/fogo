import '../domain/land_area.dart';
import '../domain/road_type.dart';
import '../geometry/mesh_data.dart';
import '../geo/coordinate_projector.dart';

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
  });

  final String entityId;
  final String tileId;
  final MeshData mesh;

  /// Cor linear RGB 0..1 (materiais básicos; legibilidade > realismo).
  final Vector3 color;
  final SceneObjectKind kind;
}

enum SceneObjectKind { road, building, landArea, crossing, signal }

/// Cena pronta para upload: objetos particionados + enquadramento.
class MapScene {
  const MapScene({
    required this.objects,
    required this.worldBounds,
    required this.tileIds,
  });

  final List<MapSceneObject> objects;

  /// Bounds de mundo de toda a região carregada (meters).
  final WorldBounds worldBounds;

  final Set<String> tileIds;
}

/// Paleta noturna do F.O.G.O. 3D — legibilidade e coerência geométrica,
/// não realismo fotográfico.
abstract final class FogoPalette {
  static final Vector3 ground = Vector3(0.05, 0.06, 0.08);

  static Vector3 road(RoadType type) => switch (type) {
    RoadType.motorway => Vector3(0.85, 0.55, 0.30),
    RoadType.trunk => Vector3(0.82, 0.52, 0.32),
    RoadType.primary => Vector3(0.86, 0.62, 0.40),
    RoadType.secondary => Vector3(0.72, 0.62, 0.48),
    RoadType.tertiary => Vector3(0.60, 0.58, 0.52),
    RoadType.unclassified => Vector3(0.42, 0.44, 0.47),
    RoadType.residential => Vector3(0.40, 0.42, 0.46),
    RoadType.livingStreet => Vector3(0.38, 0.40, 0.44),
    RoadType.service => Vector3(0.30, 0.31, 0.34),
    RoadType.pedestrian => Vector3(0.26, 0.27, 0.30),
    RoadType.footway => Vector3(0.24, 0.25, 0.28),
    RoadType.cycleway => Vector3(0.20, 0.34, 0.28),
    RoadType.path => Vector3(0.22, 0.23, 0.25),
    RoadType.track => Vector3(0.30, 0.26, 0.20),
    RoadType.rail => Vector3(0.22, 0.20, 0.22),
    RoadType.other => Vector3(0.35, 0.36, 0.39),
  };

  static Vector3 get building => Vector3(0.16, 0.18, 0.22);
  static Vector3 get crossing => Vector3(0.92, 0.92, 0.95);
  static Vector3 get signal => Vector3(0.95, 0.75, 0.20);
  static Vector3 get selection => Vector3(0.20, 0.62, 1.00);

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
    LandAreaKind.other => Vector3(0.065, 0.07, 0.085),
  };
}
