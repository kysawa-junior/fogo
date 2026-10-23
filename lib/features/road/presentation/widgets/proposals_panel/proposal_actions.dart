part of 'proposals_panel.dart';

/// Action row for a proposal, one branch per workflow status.
class _Actions extends ConsumerWidget {
  const _Actions({required this.proposal});

  final RoadChangeProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(proposalsProvider.notifier);
    switch (proposal.status) {
      case ProposalStatus.draft:
        return Row(
          children: [
            FogoButton(
              label: 'Enviar p/ revisão',
              icon: LucideIcons.send,
              onTap: () => notifier.sendToReview(proposal.id),
            ),
            const SizedBox(width: FogoSpacing.sm),
            FogoIconButton(
              icon: LucideIcons.trash,
              danger: true,
              onTap: () => notifier.discard(proposal.id),
            ),
          ],
        );
      case ProposalStatus.pendingReview:
        return Row(
          children: [
            FogoButton(
              label: 'Aprovar',
              icon: LucideIcons.check,
              variant: FogoButtonVariant.primary,
              onTap: () => notifier.approve(proposal.id),
            ),
            const SizedBox(width: FogoSpacing.sm),
            FogoButton(
              label: 'Rejeitar',
              icon: LucideIcons.ban,
              variant: FogoButtonVariant.danger,
              onTap: () => notifier.reject(proposal.id),
            ),
          ],
        );
      case ProposalStatus.approved:
        return FogoButton(
          label: 'Aplicar alteração',
          icon: LucideIcons.check,
          variant: FogoButtonVariant.primary,
          onTap: () => notifier.apply(proposal.id),
        );
      case ProposalStatus.rejected:
      case ProposalStatus.applied:
        return const SizedBox.shrink();
    }
  }
}
