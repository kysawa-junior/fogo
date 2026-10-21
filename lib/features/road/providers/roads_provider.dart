import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../road/domain/road.dart';
import '../../road/domain/road_change.dart';

/// Catálogo operacional de vias.
/// shortcut: sem fonte de dados nesta etapa (lista vazia); trocar por
/// repositório HTTP quando houver backend. Testes injetam dados via [seed].
final roadsProvider = NotifierProvider<RoadsNotifier, List<Road>>(
  RoadsNotifier.new,
);

class RoadsNotifier extends Notifier<List<Road>> {
  RoadsNotifier({this.seed});

  final List<Road>? seed;

  @override
  List<Road> build() => seed ?? const [];

  /// Aplica uma alteração aprovada à representação operacional da via.
  void applyChange(String roadId, RoadChange change) {
    state = [
      for (final road in state)
        if (road.id == roadId)
          change.applyTo(road).copyWith(updatedAt: DateTime.now())
        else
          road,
    ];
  }
}

/// Busca uma via por id na lista fornecida.
Road? findRoad(List<Road> roads, String id) {
  for (final road in roads) {
    if (road.id == id) return road;
  }
  return null;
}
