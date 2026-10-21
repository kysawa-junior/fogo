import 'road.dart';

/// Categoria de alteração proposta para uma via.
enum ChangeKind { speedLimit, lanes, direction, status }

/// Regras de validação das propostas (domínio puro, testável).
abstract final class RoadChangeValidation {
  static const int minSpeedKmh = 5;
  static const int maxSpeedKmh = 160;
  static const int minLanes = 1;
  static const int maxLanes = 8;
  static const int minJustificationLength = 20;

  static String? speedKmh(int? value) {
    if (value == null) return 'Informe o novo limite.';
    if (value < minSpeedKmh || value > maxSpeedKmh) {
      return 'Limite deve estar entre $minSpeedKmh e $maxSpeedKmh km/h.';
    }
    return null;
  }

  static String? lanes(int? value) {
    if (value == null) return 'Informe a nova quantidade de faixas.';
    if (value < minLanes || value > maxLanes) {
      return 'Faixas devem estar entre $minLanes e $maxLanes.';
    }
    return null;
  }

  static String? justification(String value) {
    if (value.trim().length < minJustificationLength) {
      return 'Descreva a justificativa (mín. $minJustificationLength caracteres).';
    }
    return null;
  }
}

/// Alteração tipada sobre uma via (valor antigo → novo valor).
sealed class RoadChange {
  const RoadChange();

  /// Resumo legível da alteração (usado em painéis e histórico).
  String get summary;

  /// Aplica a alteração sobre a via (imutável; retorna cópia).
  Road applyTo(Road road);
}

class SpeedLimitChange extends RoadChange {
  const SpeedLimitChange({required this.fromKmh, required this.toKmh});

  final int fromKmh;
  final int toKmh;

  @override
  String get summary => 'Limite de velocidade: $fromKmh → $toKmh km/h';

  @override
  Road applyTo(Road road) => road.copyWith(speedLimitKmh: toKmh);
}

class LanesChange extends RoadChange {
  const LanesChange({required this.fromLanes, required this.toLanes});

  final int fromLanes;
  final int toLanes;

  @override
  String get summary => 'Faixas: $fromLanes → $toLanes';

  @override
  Road applyTo(Road road) => road.copyWith(lanes: toLanes);
}

class DirectionChange extends RoadChange {
  const DirectionChange({required this.from, required this.to});

  final FlowDirection from;
  final FlowDirection to;

  @override
  String get summary => 'Sentido: alteração de circulação';

  @override
  Road applyTo(Road road) => road.copyWith(direction: to);
}

class StatusChange extends RoadChange {
  const StatusChange({required this.from, required this.to});

  final OperationalStatus from;
  final OperationalStatus to;

  @override
  String get summary => 'Estado operacional: alteração de status';

  @override
  Road applyTo(Road road) => road.copyWith(status: to);
}

/// Constrói a alteração tipada a partir da escolha do formulário.
/// Valores obrigatórios devem ter sido validados antes ([RoadChangeValidation]).
RoadChange buildRoadChange({
  required ChangeKind kind,
  required Road road,
  required int? numericValue,
  required FlowDirection? direction,
  required OperationalStatus? status,
}) {
  return switch (kind) {
    ChangeKind.speedLimit => SpeedLimitChange(
      fromKmh: road.speedLimitKmh,
      toKmh: numericValue!,
    ),
    ChangeKind.lanes => LanesChange(
      fromLanes: road.lanes,
      toLanes: numericValue!,
    ),
    ChangeKind.direction => DirectionChange(
      from: road.direction,
      to: direction!,
    ),
    ChangeKind.status => StatusChange(from: road.status, to: status!),
  };
}
