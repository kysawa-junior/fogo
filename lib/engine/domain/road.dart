import 'linear_feature.dart';
import 'road_properties.dart';
import 'road_type.dart';

/// Via cartográfica com geometria (polilinha ordenada) e propriedades.
/// Não confundir `way` OSM com rua: um way também pode ser contorno de
/// prédio, trilha, rio etc. — o mapper decide o que vira [Road].
class Road extends LinearFeature {
  Road({
    required super.id,
    required super.tags,
    required super.points,
    required this.type,
    required this.properties,
    this.nodeRefs = const [],
  });

  final RoadType type;
  final RoadProperties properties;

  /// Referências estáveis aos nós OSM da polilinha (mesmos índices de
  /// [points] quando não há nós ausentes; ver issues do importador).
  /// Base da conectividade em [RoadNetwork].
  final List<int> nodeRefs;

  String? get name {
    final name = tags['name'];
    if (name != null && name.trim().isNotEmpty) return name;
    final ref = tags['ref'];
    return ref != null && ref.trim().isNotEmpty ? ref : null;
  }

  bool get isElevated => properties.bridge;
  bool get isUnderground => properties.tunnel;
}
