/// Entidade cartográfica base do F.O.G.O.
///
/// O `id` preserva a identidade OSM original no formato `tipo/id`
/// (ex.: `way/123456`, `node/987`, `relation/42`) — nunca confundir com a
/// identidade de objetos gráficos na cena.
///
/// Todas as tags OSM são preservadas (inclusive desconhecidas) para
/// extensões futuras.
abstract class MapFeature {
  const MapFeature({required this.id, required this.tags});

  final String id;

  /// Tags OSM originais, íntegras.
  final Map<String, String> tags;

  String? tag(String key) => tags[key];
}
