import 'package:flutter/widgets.dart';

import '../fogo_spacing.dart';

/// Equivalente Flutter do `animateColorAsState` do Compose: alvo dirigido
/// por estado — o [TweenAnimationBuilder] anima do valor anterior ao novo
/// (lerp no nível de render, sem rebuild do conteúdo). O [child] estático
/// atravessa os ticks intacto; apenas o [builder] roda por frame.
class FogoAnimatedColor extends StatelessWidget {
  const FogoAnimatedColor({
    super.key,
    required this.color,
    required this.builder,
    this.child,
    this.duration = FogoMotion.fast,
    this.curve = FogoMotion.curve,
  });

  final Color color;
  final Widget Function(BuildContext context, Color color, Widget? child)
  builder;
  final Widget? child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    // begin == end no primeiro build (sem flash de montagem); em retarget
    // o begin é ignorado e a animação parte do valor anterior.
    final resolve = builder;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: color, end: color),
      duration: duration,
      curve: curve,
      builder: (context, value, child) =>
          resolve(context, value ?? color, child),
      child: child,
    );
  }
}
