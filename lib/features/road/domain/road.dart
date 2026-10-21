import 'package:latlong2/latlong.dart';

/// Tipo de via.
enum RoadType { avenue, street, arterial, corridor }

/// Sentido de circulação.
enum FlowDirection { oneWay, twoWay, alternating, closed }

/// Estado operacional da via (semântica compartilhada com legendas e camadas).
enum OperationalStatus { normal, attention, critical, closed }

/// Permissões de uso da via (ausência da classe = restrição).
enum RoadPermission { pedestrian, bicycle, bus, truck, emergency, loading }

/// Entidade de domínio: via urbana.
///
/// Metadados de auditoria de origem (autor da criação, sistema de origem etc.)
/// pertencem ao futuro backend; localmente mantém-se [updatedAt] e o histórico
/// vive nas propostas de alteração.
class Road {
  const Road({
    required this.id,
    required this.name,
    required this.geometry,
    required this.type,
    required this.direction,
    required this.lanes,
    required this.speedLimitKmh,
    required this.status,
    this.permissions = const {},
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// Geometria geográfica (sequência de vértices lat/lng).
  final List<LatLng> geometry;
  final RoadType type;
  final FlowDirection direction;
  final int lanes;
  final int speedLimitKmh;
  final OperationalStatus status;
  final Set<RoadPermission> permissions;
  final DateTime updatedAt;

  Road copyWith({
    String? name,
    List<LatLng>? geometry,
    RoadType? type,
    FlowDirection? direction,
    int? lanes,
    int? speedLimitKmh,
    OperationalStatus? status,
    Set<RoadPermission>? permissions,
    DateTime? updatedAt,
  }) {
    return Road(
      id: id,
      name: name ?? this.name,
      geometry: geometry ?? this.geometry,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      lanes: lanes ?? this.lanes,
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
