/// Proposals panel library: the list lives here; the proposal card, its
/// actions and its status chip live in sibling parts.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../../core/design_system/widgets/fogo_empty_state.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../map/presentation/widgets/panel_header.dart';
import '../../../domain/road_change_proposal.dart';
import '../../../providers/proposals_provider.dart';
import '../../../providers/roads_provider.dart';

part 'proposal_card.dart';
part 'proposal_actions.dart';
part 'proposal_status_chip.dart';

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
      modal: true,
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
