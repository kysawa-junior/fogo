import 'package:flutter/widgets.dart';

import '../../../../core/design_system/fogo_colors.dart';

/// Badge numerada de parada da rota otimizada (marcador sobre o mapa).
class RouteStopBadge extends StatelessWidget {
  const RouteStopBadge({
    super.key,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
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
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: selected ? FogoColors.onAccent : FogoColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: FogoColors.bg, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
                color: selected ? FogoColors.accent : FogoColors.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
