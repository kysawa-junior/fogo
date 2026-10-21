import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';

/// Controles de zoom e enquadramento do mapa.
class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFrameAll,
    required this.is3D,
    required this.onToggle3D,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFrameAll;
  final bool is3D;
  final VoidCallback onToggle3D;

  @override
  Widget build(BuildContext context) {
    return FogoPanel(
      elevated: false,
      bordered: false,
      padding: const EdgeInsets.all(FogoSpacing.xs),
      maxHeightFactor: 0.2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FogoIconButton(icon: LucideIcons.plus, onTap: onZoomIn),
          FogoIconButton(icon: LucideIcons.minus, onTap: onZoomOut),
          FogoIconButton(icon: LucideIcons.maximize, onTap: onFrameAll),
          _ThreeDToggle(is3D: is3D, onToggle: onToggle3D),
        ],
      ),
    );
  }
}

class _ThreeDToggle extends StatefulWidget {
  const _ThreeDToggle({required this.is3D, required this.onToggle});

  final bool is3D;
  final VoidCallback onToggle;

  @override
  State<_ThreeDToggle> createState() => _ThreeDToggleState();
}

class _ThreeDToggleState extends State<_ThreeDToggle> {
  bool _hovered = false;
  bool _focused = false;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onToggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Visão 3D',
    value: widget.is3D ? 'Ativada' : 'Desativada',
    toggled: widget.is3D,
    onTap: widget.onToggle,
    child: ExcludeSemantics(
      child: Focus(
        canRequestFocus: true,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: FogoSpacing.iconButtonSize,
              height: FogoSpacing.iconButtonSize,
              decoration: BoxDecoration(
                color: _hovered
                    ? FogoColors.surfaceHover
                    : FogoColors.transparent,
                borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
                border: Border.all(
                  color: _focused ? FogoColors.accent : FogoColors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  '3D',
                  style: FogoText.caption.copyWith(
                    color: widget.is3D
                        ? FogoColors.accent
                        : FogoColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
