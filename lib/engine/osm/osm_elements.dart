/// Elementos brutos OSM, pré-interpretação semântica. Preservam ids
/// originais, referências na ordem do arquivo e tags íntegras
/// (inclusive desconhecidas). Um `OsmWay` NÃO é uma rua — pode ser
/// contorno de prédio, trilha, rio etc.; a interpretação vive no
/// [OsmFeatureMapper].
library;

/// `<node id lat lon [ele]>` + tags.
class OsmNode {
  OsmNode({
    required this.id,
    required this.lat,
    required this.lon,
    this.elevation,
    tags,
  }) : tags = tags ?? {};

  final int id;
  final double lat;
  final double lon;

  /// Elevação da tag `ele` (metros); nula quando ausente — nunca inventada.
  final double? elevation;
  final Map<String, String> tags;
}

/// `<way id> <nd ref…/> <tag…/>` — ordem dos nd preservada.
class OsmWay {
  OsmWay({required this.id, List<int>? nodeRefs, tags})
    : nodeRefs = nodeRefs ?? [],
      tags = tags ?? {};

  final int id;

  /// Referências a nós, NA ORDEM do XML.
  final List<int> nodeRefs;
  final Map<String, String> tags;

  bool get isClosed => nodeRefs.length > 1 && nodeRefs.first == nodeRefs.last;
}

/// Membro de relation: `<member type ref role>`.
class OsmMember {
  const OsmMember(this.type, this.ref, this.role);

  final String type; // node | way | relation
  final int ref;
  final String role; // outer | inner | '' | …
}

/// `<relation id> <member…/> <tag…/>`.
class OsmRelation {
  OsmRelation({required this.id, List<OsmMember>? members, tags})
    : members = members ?? [],
      tags = tags ?? {};

  final int id;
  final List<OsmMember> members;
  final Map<String, String> tags;
}

/// Armazenamento em memória do conteúdo de um arquivo `.osm`
/// (primeira versão: memória; organizado para permitir streaming
/// incremental de arquivos grandes — o reader emite elementos e este
/// store os absorve).
class OsmDataStore {
  final Map<int, OsmNode> _nodes = {};
  final Map<int, OsmWay> _ways = {};
  final Map<int, OsmRelation> _relations = {};

  /// Problemas encontrados na importação (referências ausentes, elementos
  /// inválidos) — erros não derrubam a importação, são reportados.
  final List<OsmImportIssue> issues = [];

  void addNode(OsmNode node) => _nodes[node.id] = node;
  void addWay(OsmWay way) => _ways[way.id] = way;
  void addRelation(OsmRelation relation) => _relations[relation.id] = relation;

  OsmNode? nodeById(int id) => _nodes[id];
  OsmWay? wayById(int id) => _ways[id];
  OsmRelation? relationById(int id) => _relations[id];

  Iterable<OsmNode> get nodes => _nodes.values;
  Iterable<OsmWay> get ways => _ways.values;
  Iterable<OsmRelation> get relations => _relations.values;

  int get nodeCount => _nodes.length;
  int get wayCount => _ways.length;
  int get relationCount => _relations.length;

  /// Resolve a geometria de uma via; nós ausentes são registrados como
  /// issue e a via pode retornar null/parcial conforme [tolerateMissing].
  List<OsmNode?> resolveWayNodes(OsmWay way) {
    final resolved = <OsmNode?>[];
    for (final ref in way.nodeRefs) {
      final node = _nodes[ref];
      if (node == null) {
        issues.add(
          OsmImportIssue(
            'Nó $ref referenciado pela via ${way.id} não existe no arquivo.',
            elementId: 'way/${way.id}',
          ),
        );
      }
      resolved.add(node);
    }
    return resolved;
  }
}

/// Problema de importação (não fatal).
class OsmImportIssue {
  OsmImportIssue(this.message, {this.elementId});

  final String message;
  final String? elementId;

  @override
  String toString() => 'OsmImportIssue(${elementId ?? '-'}: $message)';
}
