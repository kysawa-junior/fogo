part of 'vector_data.dart';

/// Dados de uma célula (l0 = vias/áreas/pois/rótulos/ferrovias/água;
/// l1 = edificações).
class MapCellData {
  const MapCellData({
    this.roads = const [],
    this.areas = const [],
    this.rails = const [],
    this.waterLines = const [],
    this.pois = const [],
    this.labels = const [],
    this.buildings = const [],
  });

  final List<MapRoad> roads;
  final List<MapArea> areas;
  final List<MapRail> rails;
  final List<MapWaterLine> waterLines;
  final List<MapPoi> pois;
  final List<MapLabel> labels;
  final List<MapArea> buildings;

  static MapCellData l0FromJson(Map<String, dynamic> json) => MapCellData(
    roads: [
      for (final r in (json['roads'] as List? ?? const []))
        MapRoad(
          cls: roadClassFromCode(r['c'] as int),
          name: r['n'] as String? ?? '',
          ref: (r['r'] as String?)?.isEmpty ?? true ? null : r['r'] as String,
          oneway: (r['o'] as int? ?? 0) == 1,
          bridge: (r['br'] as int? ?? 0) == 1,
          tunnel: (r['tn'] as int? ?? 0) == 1,
          flatCoords: List<double>.from(r['p'] as List),
          bbox: List<double>.from(r['b'] as List),
        ),
    ],
    areas: [
      for (final a in (json['areas'] as List? ?? const []))
        MapArea(
          kind: areaKindFromCode(a['k'] as int),
          flatCoords: List<double>.from(a['p'] as List),
          bbox: List<double>.from(a['b'] as List),
        ),
    ],
    rails: [
      for (final r in (json['rail'] as List? ?? const []))
        MapRail(
          kind: railKindFromCode(r['k'] as int? ?? 0),
          flatCoords: List<double>.from(r['p'] as List),
          bbox: List<double>.from(r['b'] as List),
        ),
    ],
    waterLines: [
      for (final w in (json['wl'] as List? ?? const []))
        MapWaterLine(
          kind: waterLineKindFromCode(w['k'] as int),
          name: w['n'] as String? ?? '',
          flatCoords: List<double>.from(w['p'] as List),
          bbox: List<double>.from(w['b'] as List),
        ),
    ],
    pois: [
      for (final p in (json['pois'] as List? ?? const []))
        MapPoi(
          kind: PoiKind.values[(p['k'] as int).clamp(0, 5)],
          lat: p['x'] as double,
          lng: p['y'] as double,
          name: p['n'] as String? ?? '',
        ),
    ],
    labels: [
      for (final l in (json['labels'] as List? ?? const []))
        MapLabel(
          kind: LabelKind.values[(l['k'] as int).clamp(0, 3)],
          lat: l['x'] as double,
          lng: l['y'] as double,
          text: l['n'] as String? ?? '',
        ),
    ],
  );

  static MapCellData l1FromJson(Map<String, dynamic> json) => MapCellData(
    buildings: [
      for (final b in (json['bld'] as List? ?? const []))
        MapArea(
          kind: AreaKind.green, // não usado; edifícios pintados à parte
          flatCoords: List<double>.from(b['p'] as List),
          bbox: List<double>.from(b['b'] as List),
        ),
    ],
  );
}
