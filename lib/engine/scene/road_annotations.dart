import '../geo/coordinate_projector.dart';
import '../geometry/mesh_data.dart';

/// Engine-computed text placement. Adapter rasterizes [text] and must keep
/// its decal inside [bounds], fitting within the supplied span or omitting it.
class RoadNamePlacement {
  const RoadNamePlacement({
    required this.text,
    required this.center,
    required this.tangent,
    required this.maxLengthMeters,
    required this.maxHeightMeters,
    required this.bounds,
  });

  final String text;
  final Vector3 center;

  /// Unit horizontal tangent in ordered-way direction; decal is visual-only.
  final Vector3 tangent;

  /// Adapter may fit text to this span; it must not exceed either dimension.
  final double maxLengthMeters;
  final double maxHeightMeters;
  final WorldBounds bounds;
}

/// Per-tile visual-only annotations. Deliberately has no cartographic entity
/// identity; adapter must not register these meshes for selection or raycasts.
class RoadAnnotationBatch {
  RoadAnnotationBatch({
    required this.tileId,
    required List<RoadNamePlacement> roadNames,
    required this.arrowMesh,
    required this.bounds,
  }) : roadNames = List.unmodifiable(roadNames);

  static const double maxCameraDistanceMeters = 1200;

  final String tileId;
  final List<RoadNamePlacement> roadNames;
  final MeshData? arrowMesh;

  /// Union of complete decal fit bounds and arrow geometry bounds for culling.
  final WorldBounds bounds;
}
