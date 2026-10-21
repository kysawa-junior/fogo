/// Seleção atual do workspace cartográfico (estado de UI controlado por
/// provider, nunca dentro de widgets puramente visuais).
sealed class MapSelection {
  const MapSelection();
}

class NoSelection extends MapSelection {
  const NoSelection();
}

class RoadSelection extends MapSelection {
  const RoadSelection(this.roadId);

  final String roadId;
}

class EquipmentSelection extends MapSelection {
  const EquipmentSelection(this.equipmentId);

  final String equipmentId;
}

class PlaceSelection extends MapSelection {
  const PlaceSelection(this.placeId);

  final String placeId;
}

/// Painel flutuante ativo sobre o mapa (um único slot lateral).
/// O painel contextual fica dormente até existirem operações reais
/// selecionáveis (vias/equipamentos aguardam backend).
enum SidePanel { hidden, routing, proposals, proposalForm }
