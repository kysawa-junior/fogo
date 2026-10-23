/// Title bar library: the bar itself lives here; the window button and its
/// glyph painter live in sibling parts.
library;

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../app/window_close_handler.dart';
import '../../../../core/constants/app_constants.dart';
import '../../fogo_colors.dart';

part 'window_button.dart';
part 'window_glyph_painter.dart';

/// Motion tokens da titlebar — mesmos valores do LienneDart
/// (`TitlebarMotion`: fast 120ms, press scale 0.94).
abstract final class FogoTitlebarMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Curve curve = Curves.easeInOut;
  static const double windowButtonPressScale = 0.94;
}

/// Titlebar própria do F.O.G.O. — janela frameless (title bar nativa
/// ocultada via window_manager): marca à esquerda, área central arrastável
/// e botões de janela à direita. Porte do padrão LienneDart.
class FogoTitlebar extends StatelessWidget {
  const FogoTitlebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: FogoColors.bg),
      child: Row(
        children: [
          const _Brand(),
          // Área central arrastável (arrasta a janela frameless).
          const Expanded(child: DragToMoveArea(child: SizedBox(height: 40))),
          _WindowButton(
            action: WindowAction.minimize,
            onTap: () => windowManager.minimize(),
          ),
          const SizedBox(width: 6),
          _WindowButton(
            action: WindowAction.maximize,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.restore();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          const SizedBox(width: 6),
          _WindowButton(action: WindowAction.close, onTap: closeApplication),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppConstants.appTitle,
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: FogoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
