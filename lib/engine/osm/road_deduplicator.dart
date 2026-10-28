import 'osm_elements.dart';

import '../domain/road.dart';

/// Deduplicação SEGURA de vias: remove apenas duplicatas COMPROVADAS —
/// mesma sequência de nós OSM (frente ou ré), mesmo perfil vertical
/// (layer/bridge/tunnel) e mesma semântica (tipo + nome + direção). Esse
/// critério não confunde:
/// - pistas separadas de uma avenida (nodeRefs distintos),
/// - vias paralelas (nodeRefs distintos),
/// - níveis distintos (layer/bridge/tunnel diferem),
/// - atributos semânticos divergentes (preservadas como ambíguas).
///
/// Duplicatas assim surgem de edições OSM mal resolvidas (a mesma via
/// traçada duas vezes sobre os mesmos nós). Ambíguas e preservadas são
/// registradas como issues informativas — nunca removidas às cegas.
abstract final class RoadDeduplicator {
  /// Remove duplicatas comprovadas; retorna vias restantes e contadores
  /// (`removed` = duplicatas descartadas, `ambiguous` = casos coincidentes
  /// preservados por atributos divergentes).
  static ({List<Road> roads, int removed, int ambiguous}) dedupe(
    List<Road> roads,
    OsmDataStore store,
  ) {
    // Índice pela sequência de nós (frente e ré compartilham a chave).
    final byGeometry = <String, Road>{};
    final out = <Road>[];
    var removed = 0;
    var ambiguous = 0;

    void register(Road road) {
      byGeometry[_geometryKey(road)] = road;
      out.add(road);
    }

    for (final road in roads) {
      final existing = byGeometry[_geometryKey(road)];
      if (existing == null) {
        register(road);
        continue;
      }
      final duplicate =
          _sameVerticalProfile(existing, road) &&
          existing.type == road.type &&
          (existing.name ?? '') == (road.name ?? '') &&
          existing.properties.direction == road.properties.direction;
      if (duplicate) {
        // Duplicata comprovada: mantém a com mais tags (desempate por
        // id — determinístico); a outra sai do modelo.
        final keep = _better(existing, road);
        final drop = identical(keep, existing) ? road : existing;
        if (!identical(keep, existing)) {
          out.remove(existing);
          register(road);
        }
        removed++;
        store.issues.add(
          OsmImportIssue(
            'Via duplicada (mesmos nós OSM, mesmo perfil e semântica): '
            '${drop.id} descartada em favor de ${keep.id}.',
            elementId: drop.id,
          ),
        );
      } else {
        // Ambígua: geometria coincidente, mas atributos divergentes —
        // preserva ambas e registra para análise.
        ambiguous++;
        store.issues.add(
          OsmImportIssue(
            'Geometria coincidente com atributos divergentes: '
            '${road.id} × ${existing.id} — ambas preservadas.',
            elementId: road.id,
          ),
        );
        register(road);
      }
    }
    return (roads: out, removed: removed, ambiguous: ambiguous);
  }

  static String _geometryKey(Road road) {
    final refs = road.nodeRefs;
    final forward = refs.join(',');
    final reversed = refs.reversed.join(',');
    // Menor chave canônica: frente e ré colidem no mesmo bucket.
    return forward.compareTo(reversed) <= 0 ? forward : reversed;
  }

  static bool _sameVerticalProfile(Road a, Road b) =>
      a.properties.layer == b.properties.layer &&
      a.properties.bridge == b.properties.bridge &&
      a.properties.tunnel == b.properties.tunnel;

  static Road _better(Road a, Road b) {
    if (a.tags.length != b.tags.length) {
      return a.tags.length > b.tags.length ? a : b;
    }
    // Desempate determinístico: id menor (numérico) vence.
    final ai = int.tryParse(a.id.split('/').last) ?? 0;
    final bi = int.tryParse(b.id.split('/').last) ?? 0;
    return ai <= bi ? a : b;
  }
}
