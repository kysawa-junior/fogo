part of 'vector_data.dart';

class MapRoad {
  const MapRoad({
    required this.cls,
    required this.name,
    required this.oneway,
    required this.bridge,
    required this.tunnel,
    this.ref,
    required this.flatCoords,
    required this.bbox,
  });

  final RoadClass cls;
  final String name;

  /// Sentido único (setas no zoom de rua).
  final bool oneway;
  final bool bridge;
  final bool tunnel;

  /// Referência (SP-333, BR-…) para shields.
  final String? ref;

  /// Pares lat,lng encadeados: [lat0, lng0, lat1, lng1, ...].
  final List<double> flatCoords;

  /// minLat, minLng, maxLat, maxLng (culling).
  final List<double> bbox;

  int get pointCount => flatCoords.length ~/ 2;
}

class MapArea {
  const MapArea({
    required this.kind,
    required this.flatCoords,
    required this.bbox,
  });

  final AreaKind kind;
  final List<double> flatCoords;
  final List<double> bbox;
}

class MapRail {
  const MapRail({
    required this.kind,
    required this.flatCoords,
    required this.bbox,
  });

  final RailKind kind;
  final List<double> flatCoords;
  final List<double> bbox;

  int get pointCount => flatCoords.length ~/ 2;
}

class MapWaterLine {
  const MapWaterLine({
    required this.kind,
    required this.name,
    required this.flatCoords,
    required this.bbox,
  });

  final WaterLineKind kind;
  final String name;
  final List<double> flatCoords;
  final List<double> bbox;

  int get pointCount => flatCoords.length ~/ 2;
}

class MapPoi {
  const MapPoi({
    required this.kind,
    required this.lat,
    required this.lng,
    required this.name,
  });

  final PoiKind kind;
  final double lat;
  final double lng;
  final String name;
}

class MapLabel {
  const MapLabel({
    required this.kind,
    required this.lat,
    required this.lng,
    required this.text,
  });

  final LabelKind kind;
  final double lat;
  final double lng;
  final String text;
}
