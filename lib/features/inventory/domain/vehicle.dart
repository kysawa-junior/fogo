import '../../../engine/scene/vehicle_system.dart' show VehicleKind;

export '../../../engine/scene/vehicle_system.dart' show VehicleKind;

/// Estado de funcionamento da viatura (mesmos nomes do fogo-server).
// ignore: constant_identifier_names — os nomes batem com o enum do server.
enum VehicleStatus { ativa, disponivel, em_manutencao }

/// Entidade de domínio: viatura registrada no backend (inventário).
///
/// Diferente da viatura SIMULADA no mapa (do engine, sem placa): aqui
/// fica o registro da frota — identificação civil e estado de serviço.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.kind,
    required this.status,
  });

  /// Id público do servidor ("VT-001").
  final String id;
  final String plate;
  final VehicleKind kind;
  final VehicleStatus status;
}
