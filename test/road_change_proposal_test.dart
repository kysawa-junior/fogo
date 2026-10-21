import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/road/domain/road_change.dart';
import 'package:fogo/features/road/domain/road_change_proposal.dart';

RoadChangeProposal _proposal(ProposalStatus status) => RoadChangeProposal(
  id: 'PR-001',
  roadId: 'r-001',
  change: const SpeedLimitChange(fromKmh: 60, toKmh: 50),
  justification: 'Redução por sinistralidade registrada',
  status: status,
  createdAt: DateTime(2026, 10, 17),
  history: const [],
);

void main() {
  group('transições de estado', () {
    test('fluxo válido completo', () {
      expect(
        RoadChangeProposal.canTransition(
          ProposalStatus.draft,
          ProposalStatus.pendingReview,
        ),
        isTrue,
      );
      expect(
        RoadChangeProposal.canTransition(
          ProposalStatus.pendingReview,
          ProposalStatus.approved,
        ),
        isTrue,
      );
      expect(
        RoadChangeProposal.canTransition(
          ProposalStatus.pendingReview,
          ProposalStatus.rejected,
        ),
        isTrue,
      );
      expect(
        RoadChangeProposal.canTransition(
          ProposalStatus.approved,
          ProposalStatus.applied,
        ),
        isTrue,
      );
    });

    test('transições inválidas são bloqueadas', () {
      const invalid = [
        (ProposalStatus.draft, ProposalStatus.approved),
        (ProposalStatus.draft, ProposalStatus.applied),
        (ProposalStatus.draft, ProposalStatus.rejected),
        (ProposalStatus.approved, ProposalStatus.pendingReview),
        (ProposalStatus.applied, ProposalStatus.draft),
        (ProposalStatus.rejected, ProposalStatus.approved),
        (ProposalStatus.pendingReview, ProposalStatus.draft),
        (ProposalStatus.approved, ProposalStatus.rejected),
      ];
      for (final (from, to) in invalid) {
        expect(
          RoadChangeProposal.canTransition(from, to),
          isFalse,
          reason: '$from → $to deveria ser inválida',
        );
      }
    });

    test('transitionTo registra auditoria e muda estado', () {
      final evolved = _proposal(ProposalStatus.draft)
          .transitionTo(ProposalStatus.pendingReview);
      expect(evolved.status, ProposalStatus.pendingReview);
      expect(evolved.history, hasLength(1));
      expect(evolved.history.last.action, ProposalAction.sentToReview);
      // imutabilidade: original permanece rascunho
      expect(_proposal(ProposalStatus.draft).status, ProposalStatus.draft);
    });

    test('transitionTo inválida lança StateError', () {
      expect(
        () =>
            _proposal(ProposalStatus.draft)
                .transitionTo(ProposalStatus.applied),
        throwsStateError,
      );
    });
  });

  group('validação de valores', () {
    test('limite de velocidade fora da faixa é rejeitado', () {
      expect(RoadChangeValidation.speedKmh(null), isNotNull);
      expect(RoadChangeValidation.speedKmh(4), isNotNull);
      expect(RoadChangeValidation.speedKmh(161), isNotNull);
      expect(RoadChangeValidation.speedKmh(50), isNull);
    });

    test('faixas fora da faixa são rejeitadas', () {
      expect(RoadChangeValidation.lanes(0), isNotNull);
      expect(RoadChangeValidation.lanes(9), isNotNull);
      expect(RoadChangeValidation.lanes(3), isNull);
    });

    test('justificativa curta é rejeitada', () {
      expect(RoadChangeValidation.justification('curta demais'), isNotNull);
      expect(
        RoadChangeValidation.justification(
          'Justificativa suficientemente longa.',
        ),
        isNull,
      );
    });
  });
}
