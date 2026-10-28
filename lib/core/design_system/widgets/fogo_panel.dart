import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';
import 'fogo_glass.dart';

/// Painel flutuante padrão sobre o mapa (base-design.pen: Card Base
/// Cartográfica e modais). Vidro: backdrop-blur + sombra, sem borda.
/// Altura limitada com rolagem interna, para nunca cobrir o mapa.
class FogoPanel extends StatelessWidget {
  const FogoPanel({
    super.key,
    required this.child,
    this.width,
    this.maxHeightFactor = 0.78,
    this.padding = FogoSpacing.panelPadding,
    this.elevated = true,
    this.bordered = false,
    this.radius = FogoSpacing.radiusLg,
    this.modal = false,
  });

  final Widget child;
  final double? width;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  /// Sombra projetada — desativada em painéis como o de propostas
  /// (espelha o base-design.pen, onde o modal não tem sombra).
  final bool elevated;

  /// Contorno opcional — o design usa vidro sem borda; mantido para
  /// painéis densos que precisam de separação do mapa.
  final bool bordered;

  /// Raios do design: cards 12 (`radiusLg`), modais 14 (`radiusXl`).
  final double radius;

  /// Modais usam raio 14 e sombra mais profunda (base-design.pen).
  final bool modal;

  @override
  Widget build(BuildContext context) {
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;
    final double effectiveRadius = modal ? FogoSpacing.radiusXl : radius;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: FogoGlass(
        radius: effectiveRadius,
        fill: FogoColors.surfaceCard,
        shadow: modal
            ? (elevated ? FogoSpacing.modalShadow : null)
            : (elevated ? FogoSpacing.cardShadow : null),
        child: Container(
          width: width,
          padding: padding,
          decoration: bordered
              ? BoxDecoration(
                  border: Border.all(color: FogoColors.borderSubtle),
                  borderRadius: BorderRadius.circular(effectiveRadius),
                )
              : null,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}
