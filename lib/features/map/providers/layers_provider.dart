import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/road_filter.dart';

/// Camadas do workspace cartográfico.
/// `buildings`/`labels` operam sobre a base real (OSM). Camadas sem fonte
/// de dados ficam desativadas até integração (estado documentado, não
/// decorativo). Os módulos de vias/equipamentos continuam dormentes.
enum MapLayerId { buildings, labels, agentsVehicles, alerts, riskAreas }

class LayerSpec {
  const LayerSpec({
    required this.id,
    required this.label,
    required this.available,
  });

  final MapLayerId id;
  final String label;
  final bool available;

  String get unavailableReason => 'Fonte de dados não integrada nesta etapa.';
}

const List<LayerSpec> kLayerSpecs = [
  LayerSpec(id: MapLayerId.buildings, label: 'Edificações', available: true),
  LayerSpec(id: MapLayerId.labels, label: 'Nomes e rótulos', available: true),
  LayerSpec(
    id: MapLayerId.agentsVehicles,
    label: 'Agentes e veículos',
    available: false,
  ),
  LayerSpec(
    id: MapLayerId.alerts,
    label: 'Alertas e ocorrências',
    available: false,
  ),
  LayerSpec(
    id: MapLayerId.riskAreas,
    label: 'Áreas de risco',
    available: false,
  ),
];

LayerSpec layerSpec(MapLayerId id) => kLayerSpecs.firstWhere((s) => s.id == id);

/// Camadas ativas (consumido pela camada vetorial).
final layersProvider = NotifierProvider<LayersNotifier, Set<MapLayerId>>(
  LayersNotifier.new,
);

class LayersNotifier extends Notifier<Set<MapLayerId>> {
  @override
  Set<MapLayerId> build() => const {MapLayerId.buildings, MapLayerId.labels};

  void toggle(MapLayerId id) {
    if (!layerSpec(id).available) return;
    final Set<MapLayerId> next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void enable(MapLayerId id) {
    if (!layerSpec(id).available || state.contains(id)) return;
    state = {...state, id};
  }
}

/// Filtro de vias por grupo (vazio = todas).
final roadFilterProvider =
    NotifierProvider<RoadFilterNotifier, Set<RoadFilterGroup>>(
      RoadFilterNotifier.new,
    );

class RoadFilterNotifier extends Notifier<Set<RoadFilterGroup>> {
  @override
  Set<RoadFilterGroup> build() => const {};

  void toggle(RoadFilterGroup group) {
    final Set<RoadFilterGroup> next = {...state};
    if (!next.remove(group)) next.add(group);
    state = next;
  }

  void clear() => state = const {};
}
