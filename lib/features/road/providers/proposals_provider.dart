import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../road/domain/road_change.dart';
import '../../road/domain/road_change_proposal.dart';
import 'roads_provider.dart';

/// Fluxo local de propostas de alteração viária (estado + trilha de auditoria).
/// shortcut: persistência e autorização locais de demonstração; migrar para backend com autenticação real.
final proposalsProvider =
    NotifierProvider<ProposalsNotifier, List<RoadChangeProposal>>(
      ProposalsNotifier.new,
    );

class ProposalsNotifier extends Notifier<List<RoadChangeProposal>> {
  @override
  List<RoadChangeProposal> build() => const [];

  /// Registra rascunho e devolve o id gerado.
  String createDraft({
    required String roadId,
    required RoadChange change,
    required String justification,
  }) {
    final String id = 'PR-${(state.length + 1).toString().padLeft(3, '0')}';
    final DateTime now = DateTime.now();
    final proposal = RoadChangeProposal(
      id: id,
      roadId: roadId,
      change: change,
      justification: justification,
      status: ProposalStatus.draft,
      createdAt: now,
      history: [
        AuditEntry(
          at: now,
          actor: kLocalProposalActor,
          action: ProposalAction.created,
        ),
      ],
    );
    state = [...state, proposal];
    return id;
  }

  bool sendToReview(String id) => _transition(id, ProposalStatus.pendingReview);

  bool approve(String id) => _transition(id, ProposalStatus.approved);

  bool reject(String id) => _transition(id, ProposalStatus.rejected);

  /// Aplica uma proposta aprovada à representação operacional da via.
  bool apply(String id) {
    final RoadChangeProposal? proposal = _find(id);
    if (proposal == null ||
        !RoadChangeProposal.canTransition(
          proposal.status,
          ProposalStatus.applied,
        )) {
      return false;
    }
    ref
        .read(roadsProvider.notifier)
        .applyChange(proposal.roadId, proposal.change);
    return _transition(id, ProposalStatus.applied);
  }

  /// Descarta apenas rascunhos (não deixa trilha porque o registro é removido).
  bool discard(String id) {
    final RoadChangeProposal? proposal = _find(id);
    if (proposal == null || proposal.status != ProposalStatus.draft) {
      return false;
    }
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
    return true;
  }

  bool _transition(String id, ProposalStatus to) {
    final RoadChangeProposal? proposal = _find(id);
    if (proposal == null ||
        !RoadChangeProposal.canTransition(proposal.status, to)) {
      return false;
    }
    state = [
      for (final p in state)
        if (p.id == id) p.transitionTo(to) else p,
    ];
    return true;
  }

  RoadChangeProposal? _find(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return null;
  }
}
