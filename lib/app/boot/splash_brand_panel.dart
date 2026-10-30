import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/design_system/fogo_colors.dart';
import '../../core/design_system/widgets/fogo_button.dart';
import 'splash_type.dart';

/// Painel de marca da Splash (330×500) — base-design.pen, frame
/// "Metade Escura · Marca": marca, linha de status com trilha de
/// progresso e bloco de versão.
class SplashBrandPanel extends StatelessWidget {
  const SplashBrandPanel({
    super.key,
    required this.phase,
    required this.progress,
    this.error,
    required this.onExit,
  });

  /// Fase atual da carga (exibida em caixa alta na linha de status).
  final String phase;

  /// Fração real da carga (0..1) — barra e percentual à direita.
  final double progress;

  /// Mensagem de falha (quando a carga do mapa falha).
  final String? error;

  /// Ação do botão de saída (tela de erro).
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FogoColors.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 36),
        child: Column(
          children: [
            const Spacer(flex: 3),
            const _BrandMark(),
            const SizedBox(height: 20),
            const Text('FOGO', style: SplashType.logo),
            const SizedBox(height: 20),
            // Subtítulo de largura fixa: uma linha só (o design não
            // quebra) — o texto excede a caixa em ~12px de espaçamento
            // final, mas a tinta cabe (como no Pencil).
            const Text(
              'OPERAÇÕES COM BASE CARTOGRÁFICA 3D',
              style: SplashType.subtitle,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 18),
            if (error == null) ..._loading() else _failure(error!),
            const SizedBox(height: 96),
            const Text(
              'VERSÃO 2026.10 · BUILD 31027',
              style: SplashType.version,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              '© 2026 Instrum Labs · Dados OSM / Overture',
              style: SplashType.credits,
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  /// Linha de status + trilha de progresso.
  List<Widget> _loading() => <Widget>[
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            phase.toUpperCase(),
            style: SplashType.status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text('${(progress * 100).round()}%', style: SplashType.counter),
      ],
    ),
    const SizedBox(height: 12),
    SplashProgressTrack(value: progress),
  ];

  /// Falha da carga: mensagem + saída.
  Widget _failure(String message) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: SplashType.error),
      const SizedBox(height: 14),
      FogoButton(
        label: 'Sair',
        variant: FogoButtonVariant.ghost,
        onTap: onExit,
      ),
    ],
  );
}

/// Marca da Splash: bloco ciano 56×56 com o ícone de chama e halo.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: FogoColors.activeSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: FogoColors.activeSurface.withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: const Icon(
        LucideIcons.flame,
        size: 28,
        color: FogoColors.textPrimary,
      ),
    );
  }
}

/// Trilha de progresso da Splash — base-design.pen, frame "Trilha":
/// trilho de 2px, preenchimento ciano ancorado à ESQUERDA e cabeça clara
/// no fim do preenchimento. Determinada: a largura é a fração carregada.
class SplashProgressTrack extends StatelessWidget {
  const SplashProgressTrack({super.key, required this.value});

  /// Fração carregada (0..1).
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 220),
        builder: (context, v, _) =>
            CustomPaint(painter: _SplashProgressPainter(v)),
      ),
    );
  }
}

class _SplashProgressPainter extends CustomPainter {
  const _SplashProgressPainter(this.fraction);

  /// Fração preenchida da trilha (0..1).
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Radius radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = FogoColors.splashTrack,
    );
    final double width = size.width * fraction.clamp(0.0, 1.0);
    if (width <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, size.height), radius),
      Paint()..color = FogoColors.activeSurface,
    );
    canvas.drawCircle(
      Offset(width, size.height / 2),
      2.5,
      Paint()..color = FogoColors.splashProgressHead,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashProgressPainter old) =>
      old.fraction != fraction;
}

/// Rótulo de sinal sobre o mock cartográfico.
class SplashSinalTag extends StatelessWidget {
  const SplashSinalTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FogoColors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FogoColors.activeSurface.withValues(alpha: 0.25),
        ),
      ),
      child: const Text('SINAL 07 · ROTA ATIVA', style: SplashType.tag),
    );
  }
}
