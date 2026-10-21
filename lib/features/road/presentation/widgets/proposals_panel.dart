import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../core/design_system/widgets/fogo_empty_state.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../../map/presentation/widgets/panel_header.dart';
import '../../domain/road_change_proposal.dart';
import '../../providers/proposals_provider.dart';
import '../../providers/roads_provider.dart';

/// Painel de propostas de alteração viária: revisão, aprovação, rejeição,
/// aplicação e histórico — fluxo local de demonstração.
class ProposalsPanel extends ConsumerStatefulWidget {
  const ProposalsPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<ProposalsPanel> createState() => _ProposalsPanelState();
}

class _ProposalsPanelState extends ConsumerState<ProposalsPanel> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final proposals = ref.watch(proposalsProvider);
    final roads = ref.watch(roadsProvider);

    return FogoPanel(
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            icon: LucideIcons.clipboard_list,
            title: 'Propostas de alteração',
            subtitle: '${proposals.length} registradas',
            onClose: widget.onClose,
          ),
          const SizedBox(height: FogoSpacing.sm),
          if (proposals.isEmpty)
            FogoEmptyState(
              icon: LucideIcons.file_text,
              title: 'Nenhuma proposta',
              message: 'Selecione uma via no mapa e use "Propor alteração" para iniciar.',
              compact: true,
            )
          else
            for (final proposal in proposals)
              _ProposalCard(
                proposal: proposal,
                roadName:
                    findRoad(roads, proposal.roadId)?.name ?? proposal.roadId,
                expanded: _expanded.contains(proposal.id),
                onToggleExpanded: () => _toggle(proposal.id),
              ),
          const SizedBox(height: FogoSpacing.md),
          Text(
            'Fluxo local de demonstração: revisão e trilha de auditoria locais, '
            'sem backend nem autorização real.',
            style: FogoText.micro,
          ),
        ],
      ),
    );
  }

  void _toggle(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });
}

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
