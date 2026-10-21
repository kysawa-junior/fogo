import 'road_change.dart';

/// Estados possíveis de uma proposta de alteração viária.
enum ProposalStatus { draft, pendingReview, approved, rejected, applied }

/// Ações registradas na trilha de auditoria.
enum ProposalAction { created, sentToReview, approved, rejected, applied }

/// Autor local das ações de demonstração.
/// shortcut: sem backend não há autenticação real; trocar por usuário da sessão quando houver integração.
const String kLocalProposalActor = 'usuario-local (demo)';

class AuditEntry {
  const AuditEntry({
    required this.at,
    required this.actor,
    required this.action,
  });

  final DateTime at;
  final String actor;
  final ProposalAction action;
}

/// Proposta de alteração viária com trilha de auditoria embutida.
class RoadChangeProposal {
  const RoadChangeProposal({
    required this.id,
    required this.roadId,
    required this.change,
    required this.justification,
    required this.status,
    required this.createdAt,
    required this.history,
  });

  final String id;
  final String roadId;
  final RoadChange change;
  final String justification;
  final ProposalStatus status;
  final DateTime createdAt;
  final List<AuditEntry> history;

  /// Matriz de transições permitidas entre estados.
  static bool canTransition(ProposalStatus from, ProposalStatus to) {
    return switch ((from, to)) {
      (ProposalStatus.draft, ProposalStatus.pendingReview) => true,
      (ProposalStatus.pendingReview, ProposalStatus.approved) => true,
      (ProposalStatus.pendingReview, ProposalStatus.rejected) => true,
      (ProposalStatus.approved, ProposalStatus.applied) => true,
      _ => false,
    };
  }

  /// Evolui a proposta, registrando auditoria.
  /// Lança [StateError] em transição inválida (o chamador valida com [canTransition]).
  RoadChangeProposal transitionTo(
    ProposalStatus to, {
    String actor = kLocalProposalActor,
  }) {
    if (!canTransition(status, to)) {
      throw StateError('Transição inválida: $status → $to');
    }
    return RoadChangeProposal(
      id: id,
      roadId: roadId,
      change: change,
      justification: justification,
      status: to,
      createdAt: createdAt,
      history: [
        ...history,
        AuditEntry(at: DateTime.now(), actor: actor, action: _actionFor(to)),
      ],
    );
  }

  static ProposalAction _actionFor(ProposalStatus to) => switch (to) {
    ProposalStatus.draft => ProposalAction.created,
    ProposalStatus.pendingReview => ProposalAction.sentToReview,
    ProposalStatus.approved => ProposalAction.approved,
    ProposalStatus.rejected => ProposalAction.rejected,
    ProposalStatus.applied => ProposalAction.applied,
  };
}
