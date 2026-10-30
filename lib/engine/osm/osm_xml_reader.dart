import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml_events.dart';

import '../load_progress.dart';
import 'osm_elements.dart';

/// Leitor de arquivos OSM XML (`.osm`, `.osm.gz`).
///
/// Streaming de eventos (pull parsing, sem DOM em memória): elementos são
/// absorvidos por um [OsmDataStore] conforme aparecem. Leitura separada da
/// interpretação — este reader não conhece ruas, prédios nem semântica.
///
/// Em OSM XML, `nd`, `tag` e `member` são sempre self-closing; `node`
/// também é quando não carrega tags. Elementos com id/coords inválidas são
/// tolerados (registrados como issue), XML malformado aborta com exceção.
class OsmXmlReader {
  /// Lê bytes (gzip detectado por magic number) e popula `store`.
  static void read(
    Uint8List bytes,
    OsmDataStore store, {
    LoadProgress? progress,
  }) {
    final Uint8List decoded =
        bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B
        ? Uint8List.fromList(gzip.decode(bytes))
        : bytes;
    final source = utf8.decode(decoded, allowMalformed: true);

    progress?.begin('Interpretando OSM');
    // Denominador real do parse: total de elementos do XML.
    final int total = _countElements(source);

    var count = 0;
    OsmNode? openNode;
    OsmWay? openWay;
    OsmRelation? openRelation;

    for (final event in parseEvents(source, validateNesting: true)) {
      if (event is XmlStartElementEvent) {
        final attrs = {for (final a in event.attributes) a.name: a.value};
        switch (event.name) {
          case 'node':
            if (event.isSelfClosing) {
              _commitNode(store, attrs);
              count++;
            } else {
              openNode = _pendingNode(store, attrs);
            }
          case 'way':
            openWay = OsmWay(id: int.tryParse(attrs['id'] ?? '') ?? -1);
          case 'relation':
            openRelation = OsmRelation(
              id: int.tryParse(attrs['id'] ?? '') ?? -1,
            );
          case 'nd':
            final way = openWay;
            final ref = int.tryParse(attrs['ref'] ?? '');
            if (way == null || ref == null) {
              store.issues.add(
                OsmImportIssue(
                  'Referência nd inválida ou fora de contexto.',
                  elementId: way == null ? null : 'way/${way.id}',
                ),
              );
            } else {
              way.nodeRefs.add(ref);
            }
          case 'tag':
            final k = attrs['k'];
            final v = attrs['v'];
            final tags = openNode?.tags ?? openWay?.tags ?? openRelation?.tags;
            if (k != null && v != null && tags != null) tags[k] = v;
          case 'member':
            final rel = openRelation;
            final ref = int.tryParse(attrs['ref'] ?? '');
            if (rel == null || ref == null) {
              store.issues.add(
                OsmImportIssue(
                  'Membro inválido ou fora de contexto.',
                  elementId: rel == null ? null : 'relation/${rel.id}',
                ),
              );
            } else {
              rel.members.add(
                OsmMember(attrs['type'] ?? '', ref, attrs['role'] ?? ''),
              );
            }
          default:
            break; // osm/bounds/meta e elementos desconhecidos: schema OSM
          // fixo; payloads extra não existem no formato. Tags — o canal de
          // extensão real — são preservadas íntegras nas entidades.
        }
      } else if (event is XmlEndElementEvent) {
        switch (event.name) {
          case 'node':
            final node = openNode;
            openNode = null;
            if (node != null) {
              final ele = node.tags['ele'];
              final elevation = ele == null ? null : double.tryParse(ele);
              if (node.id >= 0) {
                store.addNode(
                  OsmNode(
                    id: node.id,
                    lat: node.lat,
                    lon: node.lon,
                    elevation: elevation,
                    tags: node.tags,
                  ),
                );
                count++;
              } else {
                store.issues.add(
                  OsmImportIssue('Nó com id inválido.', elementId: 'node/-'),
                );
              }
            }
          case 'way':
            final way = openWay;
            openWay = null;
            if (way != null) {
              if (way.id >= 0) {
                store.addWay(way);
                count++;
              } else {
                store.issues.add(
                  OsmImportIssue('Via com id inválido.', elementId: 'way/-'),
                );
              }
            }
          case 'relation':
            final rel = openRelation;
            openRelation = null;
            if (rel != null) {
              if (rel.id >= 0) {
                store.addRelation(rel);
                count++;
              } else {
                store.issues.add(
                  OsmImportIssue(
                    'Relation com id inválido.',
                    elementId: 'relation/-',
                  ),
                );
              }
            }
          default:
            break;
        }
        if (count % 5000 == 0 && count > 0) {
          progress?.step(count, total == 0 ? 1 : count / total);
        }
      }
    }
    progress?.step(count, 1);
  }

  /// Total de elementos do XML (nodes + ways + relations) — denominador
  /// real do progresso do parse.
  static int _countElements(String source) {
    int total = 0;
    for (final String tag in const <String>['<node', '<way', '<relation']) {
      int index = source.indexOf(tag);
      while (index >= 0) {
        total++;
        index = source.indexOf(tag, index + tag.length);
      }
    }
    return total;
  }

  /// Nós recebem lat/lon no start event; com tags ficam abertos até o end.
  static OsmNode _pendingNode(OsmDataStore store, Map<String, String> attrs) {
    final lat = double.tryParse(attrs['lat'] ?? '');
    final lon = double.tryParse(attrs['lon'] ?? '');
    final id = int.tryParse(attrs['id'] ?? '') ?? -1;
    if (lat == null || lon == null) {
      store.issues.add(
        OsmImportIssue(
          'Coordenada inválida; nó descartado.',
          elementId: 'node/$id',
        ),
      );
    }
    return OsmNode(id: id, lat: lat ?? 0, lon: lon ?? 0);
  }

  static void _commitNode(OsmDataStore store, Map<String, String> attrs) {
    final node = _pendingNode(store, attrs);
    if (node.id >= 0) {
      store.addNode(node);
    } else {
      store.issues.add(
        OsmImportIssue('Nó com id inválido.', elementId: 'node/-'),
      );
    }
  }
}
