import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';

/// Cidade Preditiva: módulo em preparação — sem simulações.
class PredictiveCityPage extends ConsumerWidget {
  const PredictiveCityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: FogoColors.bg,
      padding: const EdgeInsets.all(FogoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FogoIconButton(
                icon: LucideIcons.arrow_left,
                onTap: () => context.go('/'),
              ),
              const SizedBox(width: FogoSpacing.md),
              const Text('Cidade Preditiva', style: FogoText.title),
              const SizedBox(width: FogoSpacing.sm),
              const FogoChip(
                label: 'Em preparação',
                color: FogoColors.statusAttention,
                outlined: true,
                showDot: false,
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: FogoPanel(
              width: 480,
              maxHeightFactor: 0.7,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.trending_up,
                    size: 26,
                    color: FogoColors.activeSurface,
                  ),
                  const SizedBox(height: FogoSpacing.md),
                  const Text(
                    'O que existe nesta etapa',
                    style: FogoText.subtitle,
                  ),
                  const SizedBox(height: FogoSpacing.xs),
                  const Text(
                    'A base cartográfica real de Marília e Garça está disponível '
                    'no workspace, com malha viária, edificações e busca '
                    'georreferenciada reais. Modelos preditivos (calor, risco, '
                    'previsões) exigem fontes de dados e backend — nada é '
                    'simulado aqui.',
                    style: FogoText.body,
                  ),
                  const SizedBox(height: FogoSpacing.lg),
                  FogoButton(
                    label: 'Abrir workspace operacional',
                    icon: LucideIcons.map,
                    variant: FogoButtonVariant.active,
                    expanded: true,
                    onTap: () => context.go('/'),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Próximos passos técnicos: fontes de dados urbanos reais, modelos '
            'de previsão e indicadores de risco servidos por backend.',
            style: FogoText.micro,
          ),
        ],
      ),
    );
  }
}
