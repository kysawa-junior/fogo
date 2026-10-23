/// Classificação de vias a partir do valor da tag `highway` do OSM.
enum RoadType {
  motorway,
  trunk,
  primary,
  secondary,
  tertiary,
  unclassified,
  residential,
  livingStreet,
  service,
  pedestrian,
  footway,
  cycleway,
  path,
  track,
  rail,
  other;

  /// Mapeamento explícito OSM → tipo. Valores desconhecidos → [other]
  /// (tags preservadas na entidade; nada é descartado).
  static RoadType fromHighwayTag(String? highway, {String? railway}) {
    if (railway == 'rail' && highway == null) return RoadType.rail;
    switch (highway) {
      case 'motorway':
      case 'motorway_link':
        return RoadType.motorway;
      case 'trunk':
      case 'trunk_link':
        return RoadType.trunk;
      case 'primary':
      case 'primary_link':
        return RoadType.primary;
      case 'secondary':
      case 'secondary_link':
        return RoadType.secondary;
      case 'tertiary':
      case 'tertiary_link':
        return RoadType.tertiary;
      case 'unclassified':
        return RoadType.unclassified;
      case 'residential':
        return RoadType.residential;
      case 'living_street':
        return RoadType.livingStreet;
      case 'service':
        return RoadType.service;
      case 'pedestrian':
        return RoadType.pedestrian;
      case 'footway':
      case 'steps':
        return RoadType.footway;
      case 'cycleway':
        return RoadType.cycleway;
      case 'path':
        return RoadType.path;
      case 'track':
        return RoadType.track;
      default:
        return RoadType.other;
    }
  }
}
