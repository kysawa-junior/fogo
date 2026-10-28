import 'dart:convert';
import 'dart:typed_data';

import 'package:fogo/engine/domain/land_area.dart';
import 'package:fogo/engine/domain/road.dart';
import 'package:fogo/engine/domain/road_type.dart';
import 'package:fogo/engine/domain/road_marking.dart';
import 'package:fogo/engine/domain/vegetation.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('FogoEngine end-to-end (bytes OSM → cena)', () {
    test('semáforo em cruzamento fica no canto da via principal', () {
      final osm = kFixtureOsm
          .replaceFirst(
            '  <!-- Viaduto',
            '''  <node id="110" lat="-22.2160" lon="-49.9455"/>
  <node id="111" lat="-22.2160" lon="-49.9445"/>
  <!-- Viaduto''',
          )
          .replaceFirst('  <way id="10">', '''  <way id="900">
    <nd ref="110"/><nd ref="26"/><nd ref="111"/>
    <tag k="highway" v="service"/>
    <tag k="width" v="4"/>
  </way>
  <way id="10">''');
      final engine = FogoEngine.build(Uint8List.fromList(utf8.encode(osm)))!;
      final signal = engine.scene.objects.singleWhere(
        (object) => object.entityId == 'node/26',
      );
      final mesh = signal.mesh;
      final colors = mesh.colors!;
      final poleVertices = <Vector3>[];
      var bottomY = double.infinity;
      for (var i = 0; i < mesh.vertexCount; i++) {
        final color = i * 4;
        if ((colors[color] - 0.18).abs() > 1e-5 ||
            (colors[color + 1] - 0.20).abs() > 1e-5 ||
            (colors[color + 2] - 0.23).abs() > 1e-5) {
          continue;
        }
        final position = i * 3;
        final y = mesh.positions[position + 1];
        if (y < bottomY) bottomY = y;
        poleVertices.add(
          Vector3(mesh.positions[position], y, mesh.positions[position + 2]),
        );
      }
      final base = poleVertices.where((p) => (p.y - bottomY).abs() < 1e-4);
      expect(base, isNotEmpty, reason: 'base do poste presente na malha');
      final baseCenter = Vector3.zero();
      var count = 0;
      for (final p in base) {
        baseCenter.add(p);
        count++;
      }
      baseCenter.scale(1 / count);

      final signalPosition = engine.projector.project(
        const GeoCoordinate(-22.2160, -49.9450),
      );
      expect(
        (baseCenter.x - signalPosition.x).abs(),
        greaterThan(4),
        reason: 'poste deve sair do eixo da transversal e ficar na lateral',
      );
      expect(
        (baseCenter.z - signalPosition.z).abs(),
        greaterThan(2.8),
        reason: 'poste deve ficar além da faixa da transversal',
      );
    });

    test('constrói motor completo a partir da fixture', () {
      final engine = FogoEngine.build(fixtureBytes());
      expect(engine, isNotNull);
      final stats = engine!.stats;
      // way 15 descartada (refs pendentes); way 42 (duplicata comprovada
      // da way/10) removida pela deduplicação.
      expect(
        stats.roadCount,
        18,
        reason: '''
+ETAPA 04 (55-58) e ETAPA 05: ferrovias ativas (61, 62, 63)''',
      );
      // way/20, way/22 + Complexo Dois Blocos (relation 47, 2 outers =
      // 2 edifícios por ETAPA 03 multipartes).
      expect(stats.buildingCount, 4);
      // Bosque + ilha de tráfego + estacionamento + Parque Côncavo
      // + ESTÁDIO (way/80) + pitch interno (way/81).
      expect(stats.landAreaCount, 6);
      // node/2 (marked), node/98 (unmarked), node/109 (marked).
      expect(stats.crossingCount, 3);
      expect(stats.signalCount, 1);
      final signalObject = engine.scene.objects.singleWhere(
        (object) => object.kind == SceneObjectKind.signal,
      );
      expect(signalObject.entityId, 'node/26');
      expect(signalObject.mesh.colors, isNotNull);
      // 15 malhas de via + 4 edifícios + 3 áreas + travessia + semáforo
      // + 4 pads: nó 2 (way/10×12), nó 51 (anel×acesso) e nós 6/7
      // (way/11 × way/43 ambígua preservada — junções legítimas).
      // Nó 84 (rodovia layer 0 × rampa layer 1): SEM pad conjunta —
      // níveis distintos nunca recebem junção visual.
      // 18 vias + 4 edifícios + 3 áreas + 3 travessias + 1 semáforo +
      // 2 marcações (stop, hump) + 6 pads (nós 2, 51, 6/7 e o
      // CRUZAMENTO FERROVIÁRIO real do nó 101: way/10 × way/61).
      // Base (37) + árvores OSM (2) + água (1) + mobiliário (1) +
      // árvores procedurais (determinísticas por área — ver teste
      // específico) + Parque Côncavo (1 área).
      expect(stats.meshObjectCount, greaterThan(40));
      expect(
        stats.meshObjectCount,
        lessThan(250),
        reason: 'densidade limitada por área',
      );
      expect(stats.junctionPadCount, 6);
      expect(stats.triangleCount, greaterThan(0));
      // Integridade ETAPA 02.
      expect(stats.duplicateRoadsRemoved, 1, reason: 'way/42 × way/10');
      expect(stats.ambiguousDuplicates, 1, reason: 'way/43 × way/11');
      expect(
        stats.crossingsWithoutConnection,
        8,
        reason:
            'way/45 × (way/10, way/44); way/55 × way/12; e os TRILHOS '
            'verticais way/61/62 atravessam way/10 (62), way/44 e '
            'way/55 sem nós compartilhados — nada conectado por '
            'proximidade',
      );
      expect(stats.isolatedNetworkNodes, 0);
      expect(stats.degenerateSegments, 0);
    });

    test('deduplicação segura: comprovada sai, ambígua e paralela ficam', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // Duplicata comprovada (way/42 = mesmos nós/perfil/semântica da
      // way/10): REMOVIDA do modelo, operação registrada.
      expect(engine.model.byId('way/42'), isNull);
      expect(engine.model.byId('way/10'), isNotNull);
      expect(engine.issues.any((i) => i.message.contains('way/42')), isTrue);
      // Coincidente ambígua (way/43: mesmos nós da way/11, semântica
      // diferente): PRESERVADA.
      expect(engine.model.byId('way/43'), isNotNull);
      expect(engine.model.byId('way/11'), isNotNull);
      // Paralela muito próxima (way/44): PRESERVADA — pistas separadas
      // não são duplicatas.
      expect(engine.model.byId('way/44'), isNotNull);
      // E a way/44 NÃO se conecta à way/10 (sem nós compartilhados).
      final connectedTo10 = engine.network.nodes.values
          .where(
            (n) => n.wayIds.contains('way/44') && n.wayIds.contains('way/10'),
          )
          .length;
      expect(connectedTo10, 0, reason: 'paralelas nunca conectam');
    });

    test('nó duplicado (ids distintos, coordenada igual): sem conexão', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // Nó 60 tem as coordenadas do nó 4; way/46 termina nele. A rede
      // NÃO conecta way/46 à way/10 — só nó compartilhado conecta.
      final shared = engine.network.nodes.values
          .where(
            (n) => n.wayIds.contains('way/46') && n.wayIds.contains('way/10'),
          )
          .length;
      expect(shared, 0);
    });

    test('importação repetida: determinística, sem acúmulo', () {
      final a = FogoEngine.build(fixtureBytes())!;
      final b = FogoEngine.build(fixtureBytes())!;
      expect(b.stats.roadCount, a.stats.roadCount);
      expect(b.stats.meshObjectCount, a.stats.meshObjectCount);
      expect(b.stats.triangleCount, a.stats.triangleCount);
      expect(b.stats.duplicateRoadsRemoved, a.stats.duplicateRoadsRemoved);
      // Nada vira duplicado por carregar duas vezes: builds
      // independentes (stores por id), dedup idempotente.
      expect(b.model.byId('way/42'), isNull);
    });

    test('rotatória: anel fechado vira via contínua, sem fenda na emenda', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final ring = engine.scene.objects
          .where((o) => o.entityId == 'way/40')
          .firstWhere((o) => o.mesh.colors == null)
          .mesh;
      expect(ring.isValid, isTrue);
      // O ponto MÉDIO do segmento de fechamento (53→50) precisa estar
      // coberto: no tratamento antigo de polilinha aberta, esse segmento
      // sumia (o dedupe remove o vértice duplicado) e a emenda ficava
      // aberta ao longo de todo o lado.
      final mid = engine.projector.project(
        GeoCoordinate((-22.2270 + -22.2258) / 2, (-49.9400 + -49.9400) / 2),
      );
      var covered = false;
      Vector3 v(int i) => Vector3(
        ring.positions[ring.indices[i] * 3],
        ring.positions[ring.indices[i] * 3 + 1],
        ring.positions[ring.indices[i] * 3 + 2],
      );
      for (var i = 0; i < ring.indices.length && !covered; i += 3) {
        covered = _inTri(mid, v(i), v(i + 1), v(i + 2));
      }
      expect(
        covered,
        isTrue,
        reason: 'emenda do anel contínua (junção cíclica)',
      );
      // O acesso à rotatória conecta no nó compartilhado (pad de junção);
      // a via prioritária do nó é o anel (secundária > residencial).
      expect(
        engine.scene.objects.any(
          (o) =>
              o.kind == SceneObjectKind.junctionPad && o.entityId == 'way/40',
        ),
        isTrue,
        reason: 'pad na boca do acesso, herdando o anel prioritário',
      );
    });

    test('todas as malhas são válidas: índices no range e valores finitos', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      for (final obj in engine.scene.objects) {
        expect(
          obj.mesh.isValid,
          isTrue,
          reason: '${obj.entityId} deve produzir malha válida',
        );
      }
    });

    test('elevação por camada: ponte acima, túnel abaixo do solo', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      double yOf(String id) {
        // A via pode ter pad de junção com o MESMO entityId (ex. way/10
        // é a via prioritária do cruzamento ferroviário nó 101) — pega
        // a malça estrutural, nunca a pad.
        final obj = engine.scene.objects
            .singleWhere(
              (o) => o.entityId == id && o.kind != SceneObjectKind.junctionPad,
            )
            .mesh
            .computeBounds()!;
        return obj.min.y;
      }

      expect(
        yOf('way/13'),
        closeTo(4.10, 1e-6),
        reason: 'layer 1 + primary elev',
      );
      expect(
        yOf('way/14'),
        closeTo(-3.97, 1e-6),
        reason:
            'layer -1 + elevação base de via local (acima dos planos de área)',
      );
      expect(yOf('way/10'), closeTo(0.03, 1e-6));
    });

    test(
      'particionamento: tiles agrupam objetos, dono = tile do centroide',
      () {
        final engine = FogoEngine.build(fixtureBytes())!;
        expect(engine.scene.tileIds, isNotEmpty);
        for (final obj in engine.scene.objects) {
          expect(
            engine.tileManager.ownerTileOf(obj.entityId),
            isNotNull,
            reason: 'todo objeto tem tile dono',
          );
          expect(engine.scene.tileIds, contains(obj.tileId));
        }
        // Via longa (way 10) atravessa múltiplos tiles: registrada em todos
        // os tiles tocados, mas com UM único dono.
        final touched = engine.tileManager.tiles.values
            .where((t) => t.entityIds.contains('way/10'))
            .toList();
        expect(
          touched.length,
          greaterThanOrEqualTo(2),
          reason: 'via atravessa fronteiras de tiles',
        );
      },
    );

    test(
      'junção: pad pertence à via prioritária e cobre o nó compartilhado',
      () {
        final engine = FogoEngine.build(fixtureBytes())!;
        // Nó 2 une way/10 (residential) e way/12 (primary): a pad herda a
        // identidade da via prioritária (primary).
        final ofPrimary = engine.scene.objects
            .where((o) => o.entityId == 'way/12')
            .toList();
        expect(
          ofPrimary.length,
          2,
          reason: 'malha da via + pad da junção, mesma entidade',
        );
        final pad = ofPrimary.firstWhere((o) => o.mesh.colors != null).mesh;
        final padObj = ofPrimary.firstWhere((o) => o.mesh.colors != null);
        expect(
          padObj.kind,
          SceneObjectKind.junctionPad,
          reason: 'kind próprio permite depthLayer no backend',
        );
        final b = pad.computeBounds()!;
        final nodeCenter = engine.projector.project(
          GeoCoordinate(-22.2200, -49.9450),
        );
        expect(
          nodeCenter.x,
          greaterThan(b.min.x),
          reason: 'pad cobre o nó (x)',
        );
        expect(nodeCenter.x, lessThan(b.max.x));
        expect(
          nodeCenter.z,
          greaterThan(b.min.z),
          reason: 'pad cobre o nó (z)',
        );
        expect(nodeCenter.z, lessThan(b.max.z));
      },
    );

    test('junções em níveis distintos não recebem pad conjunta', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // way/13 (viaduto, layer 1) cruza way/10 sem nó compartilhado: só a
      // malha da própria via, sem pad.
      final viaduct = engine.scene.objects
          .where((o) => o.entityId == 'way/13')
          .toList();
      expect(viaduct.length, 1, reason: 'viaduto sem pad de junção');
    });

    test('ETAPA 03: edifício multipartes vira um bloco por anel externo', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // Relation 47 "Complexo Dois Blocos": 2 outers → 2 edifícios com
      // ids derivados estáveis e alturas por categoria (yes → 6,5 m).
      final blocos = engine.model.buildings
          .where((b) => b.id.startsWith('relation/47'))
          .toList();
      expect(blocos.length, 2, reason: 'um bloco por anel externo');
      expect(blocos.map((b) => b.id).toSet(), {
        'relation/47#0',
        'relation/47#1',
      });
      for (final b in blocos) {
        expect(b.height.value, 9, reason: 'categoria yes documentada');
        expect(b.height.isDefaulted, isTrue);
      }
      // Ambos renderizam como malhas válidas.
      for (final o in engine.scene.objects) {
        if (o.entityId.startsWith('relation/47')) {
          expect(o.mesh.isValid, isTrue);
        }
      }
    });

    test('ETAPA 04: calçada explícita ao lado da rua, sem conexão', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // way/55 (highway=footway, footway=sidewalk): via própria,
      // renderizada, NUNCA fundida com a way/10 nem conectada a ela.
      final sidewalk = engine.model.byId('way/55') as Road?;
      expect(sidewalk, isNotNull, reason: 'calçada explícita renderiza');
      final shared = engine.network.nodes.values
          .where(
            (n) => n.wayIds.contains('way/55') && n.wayIds.contains('way/10'),
          )
          .length;
      expect(shared, 0, reason: 'calçada não conecta topologicamente');
      // E fica AO LADO (≈1,7 m ao sul da linha central da Rua Reta).
      final sw = sidewalk!.points.first;
      final rd = (engine.model.byId('way/10') as Road).points.first;
      final dLat = (sw.latitude - rd.latitude).abs() * 111320;
      expect(dLat, lessThan(8), reason: 'paralela e adjacente');
      // Fora da pista (meia-largura 3,5 m) — sem confundir rua com
      // calçada (§ objetivo da etapa).
      expect(dLat, greaterThan(4.5), reason: 'fora da pista da rua');
    });

    test('ETAPA 11: calçada 2 mm ABAIXO da pista — rua cobre a calçada', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      double yOf(String id) => engine.scene.objects
          .firstWhere((o) => o.entityId == id && o.kind == SceneObjectKind.road)
          .mesh
          .computeBounds()!
          .min
          .y;
      // Calçada/caminho nunca é coplanar com a via: onde cruzam, a
      // PISTA cobre a ribbon da calçada (a travessia de pedestre
      // visível é a faixa, não o piso da calçada).
      expect(yOf('way/55'), closeTo(0.028, 1e-6));
      expect(yOf('way/55'), lessThan(yOf('way/10')));
    });

    test('ENG: estádio renderiza VOLUME (tigela) e não área plana', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final objects = engine.scene.objects
          .where((o) => o.entityId == 'way/80')
          .toList();
      expect(objects.length, 1);
      final stadium = objects.single;
      // VOLUME: kind building (doubleSided no adapter) + depthLayer 3.
      expect(stadium.kind, SceneObjectKind.building);
      expect(stadium.depthLayer, 3);
      final b = stadium.mesh.computeBounds()!;
      // Plataforma (0.06) + arquibancada elevada (0.06+8): tigela.
      expect(b.min.y, closeTo(0.01, 1e-6));
      expect(b.max.y, closeTo(8.06, 1e-6));
      // Tigela: mais de plataforma + chão — anel com tampa e saias.
      expect(stadium.mesh.triangleCount, greaterThan(40));
    });

    test('ENG: pitch dentro do estádio fica ACIMA da plataforma', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final pitch = engine.scene.objects.firstWhere(
        (o) => o.entityId == 'way/81',
      );
      final b = pitch.mesh.computeBounds()!;
      // Plataforma do estádio = 0.060; pitch elevado a 0.064: o
      // gramado nunca é coberto pelo lote.
      expect(b.min.y, closeTo(0.064, 1e-6));
    });

    test('ETAPA 04: rodovia com pistas separadas nunca é fundida', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // Duas pistas (way/56, way/57) da mesma rodovia: entidades
      // distintas, ids distintos, zero nós compartilhados.
      expect(engine.model.byId('way/56'), isNotNull);
      expect(engine.model.byId('way/57'), isNotNull);
      final shared = engine.network.nodes.values
          .where(
            (n) => n.wayIds.contains('way/56') && n.wayIds.contains('way/57'),
          )
          .length;
      expect(shared, 0, reason: 'pistas separadas nunca conectam');
    });

    test('ETAPA 04: rampa no nível certo, sem junção visual entre níveis', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // way/58 (motorway_link, layer=1): renderiza em +4 m; conecta
      // TOPOLOGICAMENTE à rodovia (nó 84 compartilhado é conexão real
      // do OSM), mas NÃO recebe pad conjunta com o nível 0.
      double yOf(String id) => engine.scene.objects
          .firstWhere(
            (o) => o.entityId == id && o.kind != SceneObjectKind.junctionPad,
          )
          .mesh
          .computeBounds()!
          .min
          .y;
      expect(
        yOf('way/58'),
        closeTo(4.14, 1e-6),
        reason: 'layer 1 + motorway elev',
      );
      expect(
        yOf('way/56'),
        closeTo(0.14, 0.01),
        reason: 'motorway com elev visual',
      );
      // Pads existem nos nós 2/51/6/7 — nenhuma no nó 84.
      final padsAt84 = engine.scene.objects.where(
        (o) => o.kind == SceneObjectKind.junctionPad && _nearNode84(o.mesh),
      );
      expect(
        padsAt84.isEmpty,
        isTrue,
        reason: 'sem junção visual entre níveis distintos',
      );
      // Conexão topológica real preservada (nó 84 no grafo).
      final n84 = engine.network.nodes['node/84'];
      expect(n84, isNotNull);
      expect(n84!.wayIds, {'way/56', 'way/58'});
    });

    test('ETAPA 04: ilha de tráfego explícita e estacionamento', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // area:highway=traffic_island (way/59): polígono próprio → área.
      final island = engine.model.byId('way/59');
      expect(island, isNotNull, reason: 'ilha explícita recuperada');
      expect(engine.scene.objects.any((o) => o.entityId == 'way/59'), isTrue);
      // amenity=parking (way/60): estacionamento adjacente à rua, sem
      // conexão viária (áreas nunca entram no grafo).
      final parking = engine.model.byId('way/60') as LandArea?;
      expect(parking, isNotNull);
      expect(parking!.kind, LandAreaKind.parking);
      expect(
        engine.network.nodes.values
            .where((n) => n.wayIds.contains('way/60'))
            .length,
        0,
        reason: 'estacionamento não é via — fora do grafo',
      );
    });

    test('ETAPA 05: ferrovia ativa — eixo único, cor própria, lift', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // way/61 (railway=rail): vira Road com RoadType.rail — UM eixo,
      // nunca duplicado em dois trilhos físicos.
      final rail = engine.model.byId('way/61') as Road?;
      expect(rail, isNotNull);
      expect(rail!.type, RoadType.rail);
      expect(rail.points.length, 3, reason: 'eixo do trilho real');
      // way/62 (trilho paralelo): entidade DISTINTA, nunca fundida.
      expect(engine.model.byId('way/62'), isNotNull);
      // way/63 (trilho curvo): segue o traçado de origem.
      final curvo = engine.model.byId('way/63') as Road?;
      expect(curvo!.points.length, 3);
      // disused: NÃO renderiza (padrão cartográfico — 0 trilhos ativos
      // nos extratos reais, todos disused/abandoned).
      // Cor do trilho: FogoPalette.road(RoadType.rail) — paleta.
      final mesh = engine.scene.objects
          .firstWhere((o) => o.entityId == 'way/61')
          .mesh;
      expect(mesh.isValid, isTrue);
    });

    test('ETAPA 05: cruzamento ferroviário de nível com pad real', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // Nó 101 (railway=level_crossing): way/10 e way/61 COMPARTILHAM o
      // nó → pad conjunta no MESMO nível (5ª pad da fixture).
      final n101 = engine.network.nodes['node/101'];
      expect(n101, isNotNull);
      expect(n101!.wayIds, {
        'way/10',
        'way/61',
      }, reason: 'cruzamento de nível = nó compartilhado real');
      // O trilho é RAIL, não highway — mas conecta como infraestrutura.
      final pad = engine.scene.objects.where(
        (o) =>
            o.kind == SceneObjectKind.junctionPad &&
            _nearNode(o.mesh, engine, GeoCoordinate(-22.2200, -49.9470)),
      );
      expect(
        pad.length,
        greaterThan(0),
        reason: 'cruzamento de nível recebe pad conjunta',
      );
    });

    test('ETAPA 05: travessia sem marcação = pavimento, nunca zebra', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // node/98: highway=crossing SEM crossing=marked → pavimento
      // simples (quad da largura da via, cor de passeio).
      final unmarked = engine.model.crossings.singleWhere(
        (c) => c.id == 'node/98',
      );
      expect(unmarked.marked, isFalse);
      final mesh = engine.scene.objects.singleWhere(
        (o) => o.entityId == 'node/98',
      );
      // Cor de footway (passeio), NÃO branca de zebra.
      expect(mesh.color.x, closeTo(FogoPalette.road(RoadType.footway).x, 1e-3));
      expect(mesh.mesh.triangleCount, 2, reason: 'quad simples, não 4 faixas');
    });

    test('ETAPA 05: barra de parada e lombada nas posições reais', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      // node/99 (highway=stop, nó da way/10): barra transversal.
      final stop = engine.model.markings.singleWhere((m) => m.id == 'node/99');
      expect(stop.kind, RoadMarkingKind.stop);
      expect(stop.connectedWayIds, {'way/10'}, reason: 'orientada pela via');
      expect(stop.headingRadians, isNotNull);
      final stopMesh = engine.scene.objects.singleWhere(
        (o) => o.entityId == 'node/99',
      );
      expect(stopMesh.mesh.isValid, isTrue);
      // Cor branca de marcação (FogoPalette.crossing).
      expect(stopMesh.color.x, closeTo(FogoPalette.crossing.x, 1e-3));
      // node/100 (traffic_calming=hump, way/12): plataforma na COR DA
      // PRÓPRIA via (primary) — paleta intocada.
      final hump = engine.model.markings.singleWhere((m) => m.id == 'node/100');
      expect(hump.kind, RoadMarkingKind.trafficCalming);
      final humpMesh = engine.scene.objects.singleWhere(
        (o) => o.entityId == 'node/100',
      );
      expect(
        humpMesh.color.x,
        closeTo(FogoPalette.road(RoadType.primary).x, 1e-3),
        reason: 'lombada na cor do pavimento da própria via',
      );
    });

    test('ETAPA 05: dados de sinalização incompletos não derrubam a cena', () {
      // node/98 é um crossing ISOLADO (não pertence a nenhuma via) —
      // o motor renderiza com orientação padrão e NÃO conecta.
      final engine = FogoEngine.build(fixtureBytes())!;
      final isolated = engine.model.crossings.singleWhere(
        (c) => c.id == 'node/98',
      );
      expect(isolated.connectedWayIds, isEmpty);
      expect(
        isolated.headingRadians,
        isNull,
        reason: 'sem via conectada: heading indefinido, mesh default',
      );
      // E a cena segue válida (nenhuma malha inválida).
      for (final o in engine.scene.objects) {
        expect(o.mesh.isValid, isTrue);
      }
    });

    test('ETAPA 06: árvores OSM reais nas posições mapeadas', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final trees = engine.model.trees.where((t) => !t.estimated).toList();
      expect(trees.length, 2, reason: 'node/140 e node/141');
      expect(trees.every((t) => t.tags['natural'] == 'tree'), isTrue);
      // Posição real do OSM, nunca inventada.
      final t0 = trees.first;
      expect(t0.position.latitude, closeTo(-22.2085, 1e-6));
      expect(t0.position.longitude, closeTo(-49.9485, 1e-6));
      // Estimativa = false (dado real, não procedural).
      expect(t0.estimated, isFalse);
      // Malhas válidas na cena.
      for (final o in engine.scene.objects.where(
        (o) => o.kind == SceneObjectKind.tree,
      )) {
        expect(o.mesh.isValid, isTrue);
      }
    });

    test('ETAPA 06: árvores procedurais determinísticas e restritas', () {
      final a = FogoEngine.build(fixtureBytes())!;
      final b = FogoEngine.build(fixtureBytes())!;
      final procA = a.model.trees.where((t) => t.estimated).toList();
      final procB = b.model.trees.where((t) => t.estimated).toList();
      // 1. Determinismo: mesmos dados → mesmas árvores.
      expect(procA.length, procB.length);
      for (var i = 0; i < procA.length; i++) {
        expect(
          procA[i].position.latitude,
          closeTo(procB[i].position.latitude, 1e-9),
        );
        expect(
          procA[i].position.longitude,
          closeTo(procB[i].position.longitude, 1e-9),
        );
      }
      // 2. Marcadas como estimated (a UI diferencia).
      expect(procA.every((t) => t.estimated), isTrue);
      expect(procA.every((t) => t.tags['generated'] == 'procedural'), isTrue);
      // 3. Restritas a parques/florestas: o id carrega a origem.
      expect(
        procA.every(
          (t) =>
              t.tags['area']!.contains('relation/30') ||
              t.tags['area']!.contains('way/70'),
        ),
        isTrue,
        reason: 'só no Bosque (forest) e no Parque Côncavo (park)',
      );
      // 4. Nenhuma árvore numa via ou edifício (verificação por
      //    distância às vias da fixture).
      for (final t in procA) {
        for (final road in a.model.roads) {
          final d = _minDistToPolyline(t.position, road.points);
          expect(
            d,
            greaterThan(2.5),
            reason:
                'árvore ${t.id} a ${d.toStringAsFixed(1)} m de '
                '${road.id}',
          );
        }
      }
    });

    test('ETAPA 06: rio (waterway=stream) na geometria real', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final water = engine.model.waterways;
      expect(water.length, 1);
      expect(water.first.id, 'way/71');
      expect(water.first.points.length, 3);
      // Largura default de stream = 3 m.
      expect(water.first.widthMeters, 3.0);
      // Cor de água da paleta.
      final mesh = engine.scene.objects.singleWhere(
        (o) => o.kind == SceneObjectKind.water,
      );
      expect(
        mesh.color.x,
        closeTo(FogoPalette.land(LandAreaKind.water).x, 1e-3),
      );
      expect(mesh.mesh.isValid, isTrue);
    });

    test('ETAPA 06: banco (amenity=bench) na posição real', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final bench = engine.model.furniture;
      expect(bench.length, 1);
      expect(bench.first.kind, StreetFurnitureKind.bench);
      expect(bench.first.position.latitude, closeTo(-22.2092, 1e-6));
      final mesh = engine.scene.objects.singleWhere(
        (o) => o.kind == SceneObjectKind.furniture,
      );
      expect(mesh.mesh.isValid, isTrue);
    });

    test('ETAPA 06: parque côncavo preserva contorno e é válido', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final park = engine.model.landAreas.singleWhere((a) => a.id == 'way/70');
      expect(park.kind, LandAreaKind.park);
      // Malha triangulada válida, sem triângulos degenerados.
      final mesh = engine.scene.objects.singleWhere(
        (o) => o.entityId == 'way/70',
      );
      expect(mesh.mesh.isValid, isTrue);
      // Contorno preservado: 6 vértices do L.
      expect(
        park.polygons.first.first.length,
        greaterThanOrEqualTo(6),
        reason: '6 vértices do L + fechamento',
      );
    });

    test('gzip: mesma cena a partir de .osm.gz', () {
      final plain = FogoEngine.build(fixtureBytes())!;
      final gz = FogoEngine.build(fixtureGzipBytes())!;
      expect(gz.stats.meshObjectCount, plain.stats.meshObjectCount);
      expect(gz.stats.triangleCount, plain.stats.triangleCount);
    });

    test('arquivo vazio/não-OSM retorna null sem exceção', () {
      expect(FogoEngine.build(_bytes('nada aqui')), isNull);
    });

    test('cores por tipo: malhas recebem cor da paleta', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final building = engine.scene.objects.firstWhere(
        (o) => o.kind == SceneObjectKind.building,
      );
      final buildingColor = building.color;
      final palette = FogoPalette.building;
      expect(buildingColor.x, palette.x);
      expect(buildingColor.y, palette.y);
      expect(buildingColor.z, palette.z);
      // ETAPA 05: a travessia da fixture (node/2) é `crossing=marked`
      // → zebra branca. Marcação (stop) usa a MESMA branca de paleta.
      final crossing = engine.scene.objects.singleWhere(
        (o) => o.kind == SceneObjectKind.crossing && o.entityId == 'node/2',
      );
      expect(crossing.color.x, closeTo(FogoPalette.crossing.x, 1e-3));
      final stopBar = engine.scene.objects.singleWhere(
        (o) => o.kind == SceneObjectKind.roadMarking && o.entityId == 'node/99',
      );
      expect(
        stopBar.color.x,
        closeTo(FogoPalette.crossing.x, 1e-3),
        reason: 'barra de parada na branca de marcação',
      );
    });

    test('issues de importação ficam expostas (refs ausentes)', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      expect(engine.issues.any((i) => i.message.contains('999')), isTrue);
    });

    test('seleção por id: byId recupera a entidade correta', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final feature = engine.model.byId('way/10')!;
      expect(feature.tags['name'], 'Rua Reta');
      expect(engine.model.byId('way/999'), isNull);
    });
  });
}

bool _inTri(Vector3 p, Vector3 a, Vector3 b, Vector3 c) {
  double sign(Vector3 p1, Vector3 v1, Vector3 v2) =>
      (p1.x - v2.x) * (v1.z - v2.z) - (v1.x - v2.x) * (p1.z - v2.z);
  final d1 = sign(p, a, b);
  final d2 = sign(p, b, c);
  final d3 = sign(p, c, a);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

/// A malha cobre o nó 84 (rampa×rodovia) no plano x/z?
bool _nearNode84(dynamic mesh) {
  final engine = fogoEngineOfTest;
  final node = engine!.projector.project(GeoCoordinate(-22.2300, -49.9470));
  final b = mesh.computeBounds();
  return b != null &&
      node.x >= b.min.x &&
      node.x <= b.max.x &&
      node.z >= b.min.z &&
      node.z <= b.max.z;
}

/// Pad cobre a coordenada dada no plano x/z?
bool _nearNode(dynamic mesh, FogoEngine engine, GeoCoordinate coord) {
  final node = engine.projector.project(coord);
  final b = mesh.computeBounds();
  return b != null &&
      node.x >= b.min.x &&
      node.x <= b.max.x &&
      node.z >= b.min.z &&
      node.z <= b.max.z;
}

double _minDistToPolyline(dynamic point, List<dynamic> polyline) {
  var best = double.infinity;
  for (var i = 0; i < polyline.length - 1; i++) {
    final a = polyline[i];
    final b = polyline[i + 1];
    const mLat = 111320.0;
    const mLon = 90000.0; // cos(-22°)
    final ax = a.longitude * mLon, az = a.latitude * mLat;
    final bx = b.longitude * mLon, bz = b.latitude * mLat;
    final px = point.longitude * mLon, pz = point.latitude * mLat;
    final abx = bx - ax, abz = bz - az;
    final lenSq = abx * abx + abz * abz;
    if (lenSq == 0) continue;
    var t = ((px - ax) * abx + (pz - az) * abz) / lenSq;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * abx, cz = az + t * abz;
    final d = (px - cx) * (px - cx) + (pz - cz) * (pz - cz);
    if (d < best) best = d;
  }
  return best == double.infinity ? 0 : best;
}

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));
