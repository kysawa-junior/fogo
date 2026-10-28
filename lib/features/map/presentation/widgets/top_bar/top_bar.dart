/// Top bar library: the status badge lives in a sibling part; the bar
/// composes the map tools here.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../providers/map_engine_providers.dart';

part 'status_badges.dart';

/// Barra superior flutuante: ferramentas de mapa e estado do motor
/// cartográfico 3D. As abas de módulo viraram o rail lateral e a busca
/// geográfica mudou para a barra inferior (base-design.pen) — a
/// identidade F.O.G.O. vive no title bar do sistema.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.engineState, this.onFrameRegion});

  final MapEngineState? engineState;

  /// Ferramenta de enquadramento regional (mira do header).
  final VoidCallback? onFrameRegion;

  @override
  Widget build(BuildContext context) {
    final status = engineState == null
        ? null
        : _engineStatusPresentation(engineState!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FogoSpacing.lg),
      child: SizedBox(
        height: FogoSpacing.topBarHeight,
        // base-design.pen: o header NÃO tem fundo próprio (sem vidro,
        // blur ou sombra) — só as ferramentas alinhadas à direita.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FogoIconButton(
              icon: LucideIcons.layers,
              onTap: null,
              iconColor: FogoColors.textTertiary,
            ),
            const SizedBox(width: FogoSpacing.xs),
            FogoIconButton(
              icon: LucideIcons.ruler,
              onTap: null,
              iconColor: FogoColors.textTertiary,
            ),
            const SizedBox(width: FogoSpacing.xs),
            FogoIconButton(
              icon: LucideIcons.crosshair,
              onTap: onFrameRegion,
              iconColor: FogoColors.textSecondary,
            ),
            // Divisor entre ferramentas e status da base.
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: FogoSpacing.xs),
              color: FogoColors.textTertiary,
            ),
            if (status != null)
              _MapStatusBadge(label: status.$1, color: status.$2),
          ],
        ),
      ),
    );
  }
}
