import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';

/// Superfície flutuante padrão (painéis sobre o mapa).
/// Altura limitada com rolagem interna, para nunca cobrir o mapa por completo.
class FogoPanel extends StatelessWidget {
  const FogoPanel({
    super.key,
    required this.child,
    this.width,
    this.maxHeightFactor = 0.78,
    this.padding = FogoSpacing.panelPadding,
    this.elevated = true,
    this.bordered = true,
  });

  final Widget child;
  final double? width;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  /// Sombra projetada — desativada em painéis como o de propostas
  /// (espelha o base-design.pen, onde o modal não tem sombra).
  final bool elevated;

  /// Contorno — desativado nos cards flutuantes minimalistas
  /// (legenda e zoom).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;
    return Container(
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: FogoColors.surfaceCard,
        borderRadius: BorderRadius.circular(FogoSpacing.radiusMd),
        border: bordered ? Border.all(color: FogoColors.border) : null,
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x73000000),
                  offset: Offset(0, 8),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: SingleChildScrollView(padding: padding, child: child),
    );
  }
}
