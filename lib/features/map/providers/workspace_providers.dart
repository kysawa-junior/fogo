import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_selection.dart';

/// Seleção atual de objetos do mapa.
final selectionProvider = NotifierProvider<SelectionNotifier, MapSelection>(
  SelectionNotifier.new,
);

class SelectionNotifier extends Notifier<MapSelection> {
  @override
  MapSelection build() => const NoSelection();

  void selectRoad(String roadId) => state = RoadSelection(roadId);

  void selectEquipment(String equipmentId) =>
      state = EquipmentSelection(equipmentId);

  void selectPlace(String placeId) => state = PlaceSelection(placeId);

  void clear() => state = const NoSelection();
}

/// Painel flutuante ativo sobre o mapa.
final sidePanelProvider = NotifierProvider<SidePanelNotifier, SidePanel>(
  SidePanelNotifier.new,
);

class SidePanelNotifier extends Notifier<SidePanel> {
  @override
  SidePanel build() => SidePanel.hidden;

  void openRouting() => state = SidePanel.routing;

  void openProposals() => state = SidePanel.proposals;

  void openProposalForm() => state = SidePanel.proposalForm;

  void hide() => state = SidePanel.hidden;
}
