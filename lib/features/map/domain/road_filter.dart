import '../vector/vector_data.dart' show RoadClass;

/// Filtro de vias por grupo (vazio = todas visíveis).
enum RoadFilterGroup {
  main('Rodovias'),
  primary('Primárias'),
  secondary('Secundárias'),
  tertiary('Terciárias'),
  local('Locais'),
  service('Serviços'),
  rural('Rurais/Trilhas');

  const RoadFilterGroup(this.label);
  final String label;
}

/// Um grupo de filtro controla a visibilidade das classes correspondentes.
bool roadFilterApplies(RoadClass cls, Set<RoadFilterGroup> filter) {
  if (filter.isEmpty) return true;
  if (filter.contains(RoadFilterGroup.main) &&
      (cls == RoadClass.motorway || cls == RoadClass.trunk)) {
    return true;
  }
  if (filter.contains(RoadFilterGroup.primary) && cls == RoadClass.primary) {
    return true;
  }
  if (filter.contains(RoadFilterGroup.secondary) &&
      cls == RoadClass.secondary) {
    return true;
  }
  if (filter.contains(RoadFilterGroup.tertiary) && cls == RoadClass.tertiary) {
    return true;
  }
  if (filter.contains(RoadFilterGroup.local) &&
      (cls == RoadClass.unclassified || cls == RoadClass.residential)) {
    return true;
  }
  if (filter.contains(RoadFilterGroup.service) &&
      (cls == RoadClass.service || cls == RoadClass.other)) {
    return true;
  }
  if (filter.contains(RoadFilterGroup.rural) &&
      (cls == RoadClass.track || cls == RoadClass.path)) {
    return true;
  }
  return false;
}
