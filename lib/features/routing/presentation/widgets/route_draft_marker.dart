import 'package:flutter/widgets.dart';

import '../../../../core/design_system/fogo_colors.dart';

/// Marcador de parada criada pelo usuário (dado real, não demonstrativo).
class RouteDraftMarker extends StatelessWidget {
  const RouteDraftMarker({super.key, required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: FogoColors.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: FogoColors.accent, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
                color: FogoColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
