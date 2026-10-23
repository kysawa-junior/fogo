part of 'proposals_panel.dart';

/// One proposal: summary row, expandable justification + audit trail.
class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({
    required this.proposal,
    required this.roadName,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final RoadChangeProposal proposal;
  final String roadName;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FogoSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(FogoSpacing.sm),
        decoration: BoxDecoration(
          color: FogoColors.surfaceRaised,
          borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          border: Border.all(color: FogoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleExpanded,
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? LucideIcons.chevron_up
                        : LucideIcons.chevron_down,
                    size: 14,
                    color: FogoColors.textSecondary,
                  ),
                  const SizedBox(width: FogoSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${proposal.id} · $roadName',
                          style: FogoText.subtitle.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(proposal.change.summary, style: FogoText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: FogoSpacing.sm),
                  _StatusChip(status: proposal.status),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: FogoSpacing.sm),
              Text('Justificativa', style: FogoText.caption),
              const SizedBox(height: 2),
              Text(proposal.justification, style: FogoText.body),
              const SizedBox(height: FogoSpacing.sm),
              Text('Trilha de auditoria', style: FogoText.caption),
              for (final entry in proposal.history)
                Text(
                  '${_formatDate(entry.at)} · ${_actionLabel(entry.action)} · ${entry.actor}',
                  style: FogoText.mono,
                ),
              const SizedBox(height: FogoSpacing.sm),
              _Actions(proposal: proposal),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static String _actionLabel(ProposalAction action) => switch (action) {
    ProposalAction.created => 'criada',
    ProposalAction.sentToReview => 'enviada p/ revisão',
    ProposalAction.approved => 'aprovada',
    ProposalAction.rejected => 'rejeitada',
    ProposalAction.applied => 'aplicada à via',
  };
}
