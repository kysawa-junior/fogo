import 'package:flutter/widgets.dart';

import '../../theme/fogo_typography.dart';
import '../fogo_colors.dart';
import '../fogo_spacing.dart';

/// Estado vazio padronizado (sem dados, sem resultados, módulo ausente).
class FogoEmptyState extends StatelessWidget {
  const FogoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: FogoSpacing.xl,
          vertical: compact ? FogoSpacing.lg : FogoSpacing.xl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 22 : 34, color: FogoColors.textDisabled),
            SizedBox(height: compact ? FogoSpacing.sm : FogoSpacing.md),
            Text(title, style: compact ? FogoText.subtitle : FogoText.title),
            const SizedBox(height: FogoSpacing.xs),
            Text(message, style: FogoText.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
