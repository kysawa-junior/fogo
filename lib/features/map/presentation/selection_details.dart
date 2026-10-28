import '../../../engine/domain/building.dart';
import '../../../engine/domain/land_area.dart';
import '../../../engine/domain/map_feature.dart';
import '../../../engine/domain/pedestrian_crossing.dart';
import '../../../engine/domain/poi.dart';
import '../../../engine/domain/road.dart';
import '../../../engine/domain/sourced_value.dart';

/// Dados de exibição da entidade selecionada (título + propriedades).
class EntityDetails {
  const EntityDetails({
    required this.title,
    required this.subtitle,
    required this.properties,
  });

  final String title;
  final String subtitle;
  final List<(String, String)> properties;
}

/// Constrói os dados de exibição a partir da entidade de domínio —
/// apresentação pura, sem parsing nem geometria.
EntityDetails buildEntityDetails(MapFeature feature) {
  switch (feature) {
    case Road road:
      return EntityDetails(
        title: road.name ?? 'Via sem nome',
        subtitle: 'Via — ${_roadTypeLabel(road)}',
        properties: [
          ('ID', road.id),
          ('Tipo', _roadTypeLabel(road)),
          ('Comprimento', '${road.lengthMeters.toStringAsFixed(0)} m'),
          ('Largura', _sourced(road.properties.widthMeters, suffix: ' m')),
          if (road.properties.lanes != null)
            ('Faixas', '${road.properties.lanes}'),
          ('Sentido único', road.properties.oneway ? 'sim' : 'não'),
          if (road.properties.surface != null)
            ('Superfície', road.properties.surface!),
          ('Camada (layer)', '${road.properties.layer}'),
          ('Ponte', road.properties.bridge ? 'sim' : 'não'),
          ('Túnel', road.properties.tunnel ? 'sim' : 'não'),
        ],
      );
    case Building building:
      return EntityDetails(
        title: building.tags['name'] ?? 'Edifício',
        subtitle: 'Edifício — ${building.id}',
        properties: [
          ('ID', building.id),
          ('Altura', _sourcedHeight(building.height)),
          if (building.levels != null)
            ('Pavimentos (tag)', '${building.levels}'),
          if (building.minHeightMeters != null)
            ('Altura mínima', '${building.minHeightMeters} m'),
          if (building.hasHoles) ('Buracos no contorno', 'sim'),
        ],
      );
    case LandArea area:
      return EntityDetails(
        title: area.name ?? 'Área ${area.kind.label}',
        subtitle: 'Área — ${area.kind.label}',
        properties: [
          ('ID', area.id),
          ('Classe', area.kind.label),
          if (area.polygons.length > 1)
            ('Polígonos', '${area.polygons.length}'),
          ...area.polygons.indexed
              .where((e) => e.$2.length > 1)
              .map(
                (e) => ('Buracos (polígono ${e.$1 + 1})', '${e.$2.length - 1}'),
              ),
        ],
      );
    case PedestrianCrossing crossing:
      return EntityDetails(
        title: 'Travessia de pedestres',
        subtitle: 'Cruzamento — ${crossing.id}',
        properties: [
          ('ID', crossing.id),
          (
            'Vias conectadas',
            crossing.connectedWayIds.isEmpty
                ? 'desconhecidas'
                : crossing.connectedWayIds.join(', '),
          ),
        ],
      );
    case TrafficSignal signal:
      return EntityDetails(
        title: 'Semáforo',
        subtitle: 'Sinalização — ${signal.id}',
        properties: [
          ('ID', signal.id),
          (
            'Vias conectadas',
            signal.connectedWayIds.isEmpty
                ? 'desconhecidas'
                : signal.connectedWayIds.join(', '),
          ),
        ],
      );
    case Poi poi:
      return EntityDetails(
        title: poi.name ?? 'Ponto de interesse',
        subtitle: poi.marker
            ? 'POI — ${poi.tags['class'] ?? poi.tags['maki'] ?? '?'}'
            : 'Rótulo — ${poi.tags['class'] ?? '?'}',
        properties: [
          ('ID', poi.id),
          if (poi.tags['class'] != null) ('Classe', poi.tags['class']!),
          if (poi.tags['maki'] != null) ('Maki', poi.tags['maki']!),
          if (poi.rank != null) ('Importância (rank)', '${poi.rank}'),
          ('Origem', '© OpenStreetMap contributors'),
        ],
      );
    default:
      return EntityDetails(
        title: feature.id,
        subtitle: 'Elemento cartográfico',
        properties: [('ID', feature.id)],
      );
  }
}

String _roadTypeLabel(Road road) {
  final raw = road.tags['highway'] ?? road.tags['railway'] ?? '?';
  return raw;
}

String _sourced(SourcedValue<double>? value, {required String suffix}) {
  if (value == null) return '—';
  final num = value.value.toStringAsFixed(1);
  return switch (value.origin) {
    SourcedOrigin.known => '$num$suffix (tag)',
    SourcedOrigin.estimated =>
      '$num$suffix (estimado${value.raw == null ? '' : ' de ${value.raw}'})',
    SourcedOrigin.defaulted => '$num$suffix (padrão)',
  };
}

String _sourcedHeight(SourcedValue<double> value) =>
    _sourced(value, suffix: ' m');
