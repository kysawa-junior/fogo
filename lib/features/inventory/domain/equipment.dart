import 'package:latlong2/latlong.dart';

/// Categoria do ativo urbano.
enum EquipmentCategory { camera, radar, scale, gate, kiosk, scooter, sensor }

/// Estado de disponibilidade do equipamento.
enum EquipmentStatus { online, attention, offline, maintenance }

/// Entidade de domínio: equipamento urbano conectado.
class Equipment {
  const Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.status,
    this.lastSeenAt,
    this.telemetry = const {},
    this.roadId,
  });

  final String id;
  final String name;
  final EquipmentCategory category;

  /// Localização geográfica (lat/lng).
  final LatLng location;
  final EquipmentStatus status;

  /// Última atualização conhecida (null = desconhecida).
  final DateTime? lastSeenAt;

  /// Telemetria disponível como pares chave/valor já formatados.
  final Map<String, String> telemetry;

  /// Via associada, quando houver.
  final String? roadId;
}
