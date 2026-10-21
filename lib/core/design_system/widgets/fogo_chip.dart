import 'package:flutter/widgets.dart';

import '../../constants/app_constants.dart';
import '../../theme/fogo_typography.dart';
import '../fogo_colors.dart';
import '../fogo_spacing.dart';

/// Chip genérico (rótulo + ponto opcional) para estados e categorias.
class FogoChip extends StatelessWidget {
  const FogoChip({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool showDot;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined
            ? FogoColors.transparent
            : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
        border: Border.all(
          color: outlined
              ? color.withValues(alpha: 0.5)
              : FogoColors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: FogoSpacing.xs + 1),
          ],
          Text(
            label,
            style: FogoText.caption.copyWith(
              color: outlined ? color : FogoColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marcação visual obrigatória de qualquer dado sintético exibido na interface.
class FogoDemoTag extends StatelessWidget {
  const FogoDemoTag({super.key});

  @override
  Widget build(BuildContext context) => const FogoChip(
    label: AppConstants.demoTag,
    color: FogoColors.statusAttention,
    showDot: false,
    outlined: true,
  );
}
