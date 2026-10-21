import 'package:flutter/widgets.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/theme/fogo_typography.dart';

import 'package:flutter_lucide/flutter_lucide.dart';

/// Cabeçalho padrão dos painéis flutuantes sobre o mapa.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: FogoColors.accentSoft,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          ),
          child: Icon(icon, size: 15, color: FogoColors.accent),
        ),
        const SizedBox(width: FogoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FogoText.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(subtitle, style: FogoText.mono),
            ],
          ),
        ),
        ?trailing,
        if (onClose != null) ...[
          const SizedBox(width: FogoSpacing.xs),
          FogoIconButton(
            icon: LucideIcons.x,
            size: 24,
            iconSize: 14,
            onTap: onClose,
          ),
        ],
      ],
    );
  }
}
