import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/providers/equipment_provider.dart';
import '../../map/presentation/render/map_icons.dart';
import '../domain/risk_area.dart';

/// Modo de visão do mapa: false = Normal (ícones), true = Cidade
/// Preditiva (heatmap de risco sobre a base 2D). Alternado pelo botão
/// da nav rail — a câmera não é afetada.
final predictiveModeProvider = NotifierProvider<PredictiveModeNotifier, bool>(
  PredictiveModeNotifier.new,
);

class PredictiveModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Filtro de ícones do Modo Normal: tipos visíveis. Completo = todos os
/// tipos (comportamento atual); vazio = nenhum ícone no mapa.
final mapIconFilterProvider =
    NotifierProvider<MapIconFilterNotifier, Set<MapIconKind>>(
      MapIconFilterNotifier.new,
    );

class MapIconFilterNotifier extends Notifier<Set<MapIconKind>> {
  @override
  Set<MapIconKind> build() => MapIconKind.values.toSet();

  void toggle(MapIconKind kind) {
    final Set<MapIconKind> next = {...state};
    if (!next.remove(kind)) next.add(kind);
    state = next;
  }

  void all() => state = MapIconKind.values.toSet();
}

/// Áreas de risco do fogo-server (GET /risk/areas) — carregadas sob
/// demanda ao entrar no modo Cidade Preditiva. Sem retry automático
/// (mesma razão dos providers de Inventário: backoff trava em
/// AsyncLoading sob FakeAsync nos testes).
final riskAreasProvider = FutureProvider<List<RiskArea>>(
  (ref) => ref.watch(fogoApiClientProvider).riskAreas(),
);
