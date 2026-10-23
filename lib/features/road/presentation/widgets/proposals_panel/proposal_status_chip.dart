part of 'proposals_panel.dart';

/// Workflow status chip (draft → review → approved/rejected → applied).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ProposalStatus.draft => (FogoColors.statusOffline, 'Rascunho'),
      ProposalStatus.pendingReview => (FogoColors.statusAttention, 'Pendente'),
      ProposalStatus.approved => (FogoColors.statusNormal, 'Aprovada'),
      ProposalStatus.rejected => (FogoColors.statusCritical, 'Rejeitada'),
      ProposalStatus.applied => (FogoColors.accent, 'Aplicada'),
    };
    return FogoChip(label: label, color: color, showDot: false, outlined: true);
  }
}
