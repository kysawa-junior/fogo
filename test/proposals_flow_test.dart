import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fogo/features/road/domain/road.dart';
import 'package:fogo/features/road/domain/road_change.dart';
import 'package:fogo/features/road/domain/road_change_proposal.dart';
import 'package:fogo/features/road/providers/proposals_provider.dart';
import 'package:fogo/features/road/providers/roads_provider.dart';

/// Via de fixture para os testes (fonte de dados real é backend).
final List<Road> _seedRoads = [
  Road(
    id: 'r-001',
    name: 'Via de teste',
    geometry: [LatLng(-22.2126, -49.6548), LatLng(-22.2140, -49.6530)],
    type: RoadType.avenue,
    direction: FlowDirection.twoWay,
    lanes: 4,
    speedLimitKmh: 60,
    status: OperationalStatus.normal,
    permissions: {RoadPermission.bus, RoadPermission.pedestrian},
    updatedAt: DateTime(2026, 10, 17),
  ),
];

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        roadsProvider.overrideWith(() => RoadsNotifier(seed: _seedRoads)),
      ],
    );
    addTearDown(container.dispose);
  });

  Road firstRoad() => container.read(roadsProvider).first;

  test(
    'fluxo completo: rascunho → revisão → aprovação → aplicação com auditoria',
    () {
      final Road road = firstRoad();
      final notifier = container.read(proposalsProvider.notifier);

      final String id = notifier.createDraft(
        roadId: road.id,
        change: SpeedLimitChange(fromKmh: road.speedLimitKmh, toKmh: 50),
        justification: 'Redução por alta sinistralidade registrada',
      );
      RoadChangeProposal proposal = container.read(proposalsProvider).single;
      expect(proposal.status, ProposalStatus.draft);
      expect(proposal.history, hasLength(1));

      expect(notifier.sendToReview(id), isTrue);
      proposal = container.read(proposalsProvider).single;
      expect(proposal.status, ProposalStatus.pendingReview);

      expect(notifier.approve(id), isTrue);
      expect(notifier.apply(id), isTrue);
      proposal = container.read(proposalsProvider).single;
      expect(proposal.status, ProposalStatus.applied);
      expect(
        proposal.history,
        hasLength(4),
      ); // criada + enviada + aprovada + aplicada

      // Representação operacional da via foi alterada.
      final Road updated = firstRoad();
      expect(updated.speedLimitKmh, 50);
      expect(updated.updatedAt.isAfter(road.updatedAt), isTrue);
    },
  );

  test('transições inválidas retornam false e não alteram a via', () {
    final Road road = firstRoad();
    final notifier = container.read(proposalsProvider.notifier);
    final String id = notifier.createDraft(
      roadId: road.id,
      change: const LanesChange(fromLanes: 4, toLanes: 5),
      justification: 'Ampliação por demanda crescente do corredor',
    );

    expect(notifier.apply(id), isFalse, reason: 'aplicar rascunho direto');
    expect(notifier.approve(id), isFalse, reason: 'aprovar sem revisão');
    expect(container.read(roadsProvider).first.lanes, road.lanes);

    expect(notifier.sendToReview(id), isTrue);
    expect(notifier.sendToReview(id), isFalse, reason: 'reenviar já pendente');
  });

  test('descarte só é permitido em rascunhos', () {
    final Road road = firstRoad();
    final notifier = container.read(proposalsProvider.notifier);
    final String id = notifier.createDraft(
      roadId: road.id,
      change: StatusChange(from: road.status, to: OperationalStatus.attention),
      justification: 'Sinalização temporária para evento previsto',
    );
    expect(notifier.discard(id), isTrue);
    expect(container.read(proposalsProvider), isEmpty);

    final String id2 = notifier.createDraft(
      roadId: road.id,
      change: StatusChange(from: road.status, to: OperationalStatus.attention),
      justification: 'Sinalização temporária para evento previsto',
    );
    notifier.sendToReview(id2);
    expect(notifier.discard(id2), isFalse, reason: 'descartar pendente');
    expect(container.read(proposalsProvider), hasLength(1));
  });

  test('rejeitada não pode ser aplicada', () {
    final Road road = firstRoad();
    final notifier = container.read(proposalsProvider.notifier);
    final String id = notifier.createDraft(
      roadId: road.id,
      change: const SpeedLimitChange(fromKmh: 60, toKmh: 80),
      justification: 'Aumento pretendido pela operação local',
    );
    notifier.sendToReview(id);
    expect(notifier.reject(id), isTrue);
    expect(notifier.apply(id), isFalse);
    expect(
      container.read(roadsProvider).first.speedLimitKmh,
      road.speedLimitKmh,
    );
  });
}
