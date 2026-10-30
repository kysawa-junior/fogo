import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/map/providers/map_engine_providers.dart';
import '../window_close_handler.dart';

/// Papel da janela no startup multi-window.
enum FogoWindowRole {
  /// Janela definitiva (criada pelo runner nativo).
  main,

  /// Janela Splash 800x500 (criada pelo desktop_multi_window).
  splash,
}

/// Argumento que identifica a janela Splash entre as janelas do plugin.
const String kSplashWindowArgument = 'splash';

/// Métodos do protocolo Splash <-> janela definitiva.
abstract final class SplashMessage {
  /// Progresso da carga do mapa: {phase: String, progress: double (0..1)}.
  static const String progress = 'progress';

  /// Falha na carga: {message: String}.
  static const String error = 'error';

  /// Splash deve fechar (janela definitiva pronta).
  static const String close = 'close';
}

/// Detecta o papel da janela atual pelo argumento do desktop_multi_window.
Future<FogoWindowRole> detectWindowRole() async {
  if (!isDesktopWindowPlatform) return FogoWindowRole.main;
  try {
    final WindowController controller =
        await WindowController.fromCurrentEngine();
    if (controller.arguments == kSplashWindowArgument) {
      return FogoWindowRole.splash;
    }
  } catch (error) {
    // Plugin ausente (testes/CI): a janela atual é a principal.
    debugPrint('FOGO: papel da janela não detectado ($error)');
  }
  return FogoWindowRole.main;
}

/// Orquestra o startup multi-window.
///
/// A janela definitiva NASCE OCULTA (runner nativo). Esta classe abre a
/// Splash 800x500, carrega o mapa com o progresso espelhado na Splash e
/// só revela a janela definitiva quando o mapa está pronto — o mapa e
/// as interações nunca aparecem antes.
///
/// O modelo do mapa vive na RAM do isolate da janela definitiva: a
/// Splash (engine própria) não pode receber o objeto `FogoEngine`, por
/// isso ela carrega o mapa de forma indireta (espelha o progresso) em
/// vez de parsear o OSM de novo.
class BootCoordinator {
  BootCoordinator({required this.container});

  final ProviderContainer container;

  Future<void> run() async {
    // A carga começa ANTES de qualquer await: a página do mapa constrói
    // no primeiro frame (o engine renderiza mesmo com a janela oculta)
    // e não pode iniciar uma segunda importação.
    final Future<void> load = container
        .read(mapEngineProvider.notifier)
        .loadRegion();

    WindowController? splash;
    final ProviderSubscription<MapLoadPhase> subscription = container
        .listen<MapLoadPhase>(
          mapEngineProvider.select((state) => state.phase),
          (previous, next) => _reportPhase(splash, next),
        );

    splash = await _openSplashWindow();

    try {
      await load;
      final MapEngineState state = container.read(mapEngineProvider);
      if (state.phase is MapError) {
        // Falha de carga: a Splash mostra o erro e a janela definitiva
        // continua oculta (não há app para revelar).
        final MapError error = state.phase as MapError;
        debugPrint('FOGO: carga do mapa falhou — ${error.message}');
        await _post(splash, SplashMessage.error, <String, dynamic>{
          'message': error.message,
        });
        return;
      }
      await _revealMainWindow();
      await _closeSplash(splash);
    } finally {
      subscription.close();
    }
  }

  /// Cria a janela Splash (800x500) — nasce oculta; quem decide o
  /// tamanho/aparência e o primeiro mapeamento é o próprio isolate da
  /// Splash (resize de janela já mapeada wedgea o pipeline Impeller).
  Future<WindowController?> _openSplashWindow() async {
    if (!isDesktopWindowPlatform) return null;
    try {
      return await WindowController.create(
        const WindowConfiguration(
          arguments: kSplashWindowArgument,
          hiddenAtLaunch: true,
        ),
      );
    } catch (error) {
      debugPrint('FOGO: janela Splash indisponível ($error) — segue sem ela.');
      return null;
    }
  }

  void _reportPhase(WindowController? splash, MapLoadPhase phase) {
    if (splash == null || phase is! MapLoading) return;
    unawaited(
      _post(splash, SplashMessage.progress, <String, dynamic>{
        'phase': phase.label,
        'progress': phase.progress,
      }),
    );
  }

  /// Mensagem best-effort: a Splash pode ainda não ter registrado o
  /// handler (perda aceitável no progresso, unacceptable no close —
  /// que tem retry próprio).
  Future<void> _post(
    WindowController? splash,
    String method,
    Map<String, dynamic> payload,
  ) async {
    if (splash == null) return;
    try {
      await splash.invokeMethod<void>(method, payload);
    } catch (_) {
      // Splash sem handler ainda (progresso) — best-effort.
    }
  }

  /// Fecha a Splash com retry: o handler da Splash pode ainda não estar
  /// registrado quando o mapa termina de carregar.
  Future<void> _closeSplash(WindowController? splash) async {
    if (splash == null) return;
    for (int attempt = 0; attempt < 20; attempt++) {
      try {
        await splash.invokeMethod<void>(SplashMessage.close, null);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    debugPrint('FOGO: Splash não respondeu ao close — segue sem fechar.');
  }

  /// Revela a janela definitiva (o runner a criou oculta) e espera o
  /// primeiro frame — sem isso a Splash fecha sobre uma janela vazia.
  Future<void> _revealMainWindow() async {
    if (!isDesktopWindowPlatform) return;
    await windowManager.show();
    await windowManager.focus();
    final Completer<void> firstFrame = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!firstFrame.isCompleted) firstFrame.complete();
    });
    try {
      await firstFrame.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Sem frames (ambiente headless): segue — a Splash fecha assim mesmo.
    }
  }
}
