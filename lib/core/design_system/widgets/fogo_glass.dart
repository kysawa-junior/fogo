import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../fogo_spacing.dart';

/// Superfície flutuante de vidro do base-design.pen: backdrop-blur 24 +
/// sombra projetada. Header flutuante, Navegador de Cidades e cards
/// usam esta mesma composição (fill + radius por chamador).
class FogoGlass extends StatelessWidget {
  const FogoGlass({
    super.key,
    required this.child,
    required this.radius,
    this.fill,
    this.shadow = FogoSpacing.cardShadow,
    this.blur = 24,
  });

  final Widget child;
  final double radius;
  final Color? fill;
  final List<BoxShadow>? shadow;
  final double blur;

  @override
  Widget build(BuildContext context) {
    // Sombra fora do clip: recorte cortaria a projeção.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(color: fill, child: child),
        ),
      ),
    );
  }
}
