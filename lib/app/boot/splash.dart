import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall;
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design_system/fogo_colors.dart';
import '../../core/theme/fogo_typography.dart';
import '../window_close_handler.dart';
import 'boot.dart';
import 'splash_brand_panel.dart';
import 'splash_map_panel.dart';

/// Tamanho fixo da janela Splash de carregamento.
const Size kSplashWindowSize = Size(800, 500);

/// Largura do painel de marca (base-design.pen · "Metade Escura · Marca").
const double kSplashBrandWidth = 330;

/// Estado exibido pela Splash.
class SplashState {
  const SplashState({
    this.phase = 'Preparando ambiente…',
    this.progress = 0,
    this.error,
  });

  /// Fase atual da carga do mapa (ex.: "Interpretando OSM").
  final String phase;

  /// Fração real da carga (0..1) — preenche a barra da esquerda à direita.
  final double progress;

  /// Mensagem de falha (quando a carga do mapa falha).
  final String? error;

  bool get hasError => error != null;

  /// Aplica uma mensagem do protocolo Splash.
  SplashState applyMessage(String method, Object? arguments) {
    final Map<String, dynamic> payload = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : const <String, dynamic>{};
    switch (method) {
      case SplashMessage.progress:
        return SplashState(
          phase: payload['phase'] as String? ?? phase,
          progress: (payload['progress'] as num?)?.toDouble() ?? progress,
        );
      case SplashMessage.error:
        return SplashState(
          error: payload['message'] as String? ?? 'Falha ao carregar o mapa.',
        );
      default:
        return this;
    }
  }
}

/// Janela Splash de carregamento (800x500) — engine própria criada pelo
/// desktop_multi_window. Exibe o progresso da carga do mapa (espelhado
/// pela janela definitiva) e fecha quando o app definitivo está pronto.
class FogoSplashApp extends StatefulWidget {
  const FogoSplashApp({super.key});

  @override
  State<FogoSplashApp> createState() => _FogoSplashAppState();
}

class _FogoSplashAppState extends State<FogoSplashApp> {
  SplashState _state = const SplashState();

  @override
  void initState() {
    super.initState();
    unawaited(_setupWindow());
  }

  Future<void> _setupWindow() async {
    // Handler registrado ANTES da janela aparecer: nenhuma mensagem do
    // app definitivo se perde.
    try {
      final WindowController controller =
          await WindowController.fromCurrentEngine();
      await controller.setWindowMethodHandler(_onMessage);
    } catch (error) {
      debugPrint('FOGO: Splash sem canal de mensagens ($error)');
    }

    if (!isDesktopWindowPlatform) return;

    // Geometria e aparência ANTES do primeiro mapeamento: a janela do
    // plugin nasce 1280x720 e um resize de janela já mapeada wedgea o
    // pipeline Impeller/Wayland.
    await windowManager.ensureInitialized();
    await windowManager.setTitle('F.O.G.O.');
    await windowManager.setSize(kSplashWindowSize);
    await windowManager.setMinimumSize(kSplashWindowSize);
    await windowManager.setResizable(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setBackgroundColor(FogoColors.bg);
    await windowManager.setAlignment(Alignment.center);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  Future<dynamic> _onMessage(MethodCall call) async {
    if (call.method == SplashMessage.close) {
      await _closeWindow();
      return null;
    }
    if (mounted) {
      setState(() => _state = _state.applyMessage(call.method, call.arguments));
    }
    return null;
  }

  Future<void> _closeWindow() async {
    // shortcut: bug upstream do embedder Linux (flutter/flutter#193742) —
    // o teardown GTK dispara FlutterEngineRemoveView com kInvalidArguments
    // ("The implicit view cannot be removed") e pode levar a
    // use-after-free. No Linux a Splash é apenas ocultada; o processo
    // segue vivo com a janela definitiva.
    if (defaultTargetPlatform == TargetPlatform.linux) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: FogoColors.bg,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DefaultTextStyle.merge(
        style: FogoText.body,
        child: ColoredBox(
          color: FogoColors.bg,
          child: Center(child: _content()),
        ),
      ),
    );
  }

  Widget _content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Frame transitório: a janela Splash nasce OCULTA
        // (desktop_multi_window) e o primeiro frame chega com o viewport
        // colapsado (1x1) — o conteúdo não cabe e o Column/Row estouram
        // (RenderFlex overflow). Splash vazia até a janela ter o tamanho
        // definitivo (800x500).
        if (constraints.maxWidth < kSplashWindowSize.width ||
            constraints.maxHeight < kSplashWindowSize.height) {
          return const SizedBox.shrink();
        }
        // base-design.pen · "Splash / Carregamento": painel de marca
        // (330) à esquerda, mock cartográfico (470) à direita.
        return Row(
          children: <Widget>[
            SizedBox(
              width: kSplashBrandWidth,
              child: SplashBrandPanel(
                phase: _state.phase,
                progress: _state.progress,
                error: _state.error,
                onExit: closeApplication,
              ),
            ),
            const Expanded(child: SplashMapPanel()),
          ],
        );
      },
    );
  }
}
