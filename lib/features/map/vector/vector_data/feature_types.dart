part of 'vector_data.dart';

/// Classe de via (índice = código no JSON das células).
enum RoadClass {
  motorway,
  trunk,
  primary,
  secondary,
  tertiary,
  unclassified,
  residential,
  service,
  track,
  path,
  other,
}

RoadClass roadClassFromCode(int code) =>
    RoadClass.values[code.clamp(0, RoadClass.values.length - 1)];

enum AreaKind { water, green, farmland, boundary }

AreaKind areaKindFromCode(int code) =>
    AreaKind.values[code.clamp(0, AreaKind.values.length - 1)];

/// Curso d'água linear (rio, canal, córrego, dreno).
enum WaterLineKind { river, canal, stream, drain }

WaterLineKind waterLineKindFromCode(int code) =>
    WaterLineKind.values[code.clamp(0, WaterLineKind.values.length - 1)];

enum PoiKind { amenity, shop, tourism, leisure, healthcare, craftOffice }

enum LabelKind { city, town, village, suburb }

enum RailKind { rail, tram, disused }

RailKind railKindFromCode(int code) =>
    RailKind.values[code.clamp(0, RailKind.values.length - 1)];
