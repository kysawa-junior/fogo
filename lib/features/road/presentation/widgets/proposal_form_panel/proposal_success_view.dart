part of 'proposal_form_panel.dart';

/// Post-creation view: draft id, local review flow explanation and actions.
class _ProposalSuccessView extends StatelessWidget {
  const _ProposalSuccessView({
    required this.createdId,
    required this.onSendToReview,
    required this.onDone,
  });

  final String createdId;
  final VoidCallback onSendToReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return FogoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.check,
                size: 18,
                color: FogoColors.statusNormal,
              ),
              const SizedBox(width: FogoSpacing.sm),
              Text('Rascunho $createdId criado', style: FogoText.subtitle),
            ],
          ),
          const SizedBox(height: FogoSpacing.sm),
          Text(
            'A proposta segue o fluxo local: revisão → aprovação → aplicação, '
            'com trilha de auditoria registrada.',
            style: FogoText.caption,
          ),
          const SizedBox(height: FogoSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FogoButton(
                  label: 'Enviar p/ revisão',
                  icon: LucideIcons.send,
                  variant: FogoButtonVariant.primary,
                  expanded: true,
                  onTap: onSendToReview,
                ),
              ),
              const SizedBox(width: FogoSpacing.sm),
              FogoButton(label: 'Concluir', onTap: onDone),
            ],
          ),
        ],
      ),
    );
  }
}
