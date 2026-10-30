import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app/boot/boot.dart';
import 'app/boot/splash.dart';
import 'app/fogo_app.dart';
import 'app/window_close_handler.dart';
import 'core/design_system/fogo_colors.dart';
import 'core/persistence/preferences_provider.dart';

/// Tamanho mínimo da janela (setado pelo window_manager).
const Size kAppWindowMinSize = Size(960, 600);

/// O startup multi-window (Splash 800x500) roda só no Linux: é o
/// único runner com a janela definitiva oculta nativamente E com o
/// window_manager apontando para a janela do próprio isolate. Em
/// Windows/macOS o plugin cria a janela da Splash sem plugins do app e
/// o window_manager controla a janela principal — o app segue com a
/// janela única.
bool get multiWindowBootSupported =>
    defaultTargetPlatform == TargetPlatform.linux;

/// Engine principal: JANELA ÚNICA e DIRETA — mapeada no T0 no tamanho
/// definitivo (frameless; nasce workarea-clamped pelo runner C — resize
/// pós-criação wedgea o pipeline Impeller/Wayland: buffer pela metade,
/// frames congelados, fundo preto — medido, "Timed out ... have 1x1").
///
/// Startup MULTI WINDOW: a janela do runner NASCE OCULTA (o runner C
/// cria e realiza, mas não mapeia) e a janela Splash 800x500 é exibida
/// primeiro. A Splash carrega o mapa (espelhando o progresso da carga)
/// e, com o mapa pronto, a janela definitiva é revelada e a Splash
/// fecha. O mapa e as interações só aparecem depois.
Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await detectWindowRole() == FogoWindowRole.splash) {
    // Janela Splash: engine própria (desktop_multi_window).
    runApp(const FogoSplashApp());
    return;
  }

  if (isDesktopWindowPlatform) {
    // A janela já existe (runner) e está oculta: aqui confirma mínimo,
    // título e encerramento controlado. O mapeamento (show) fica com o
    // BootCoordinator, quando o mapa estiver pronto.
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      backgroundColor: FogoColors.bg,
      title: 'F.O.G.O.',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(kAppWindowMinSize);
      // Todo fechamento nativo (Alt+F4/WM) passa pelo encerramento
      // controlado.
      await windowManager.setPreventClose(true);
    });
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Diagnóstico/CI: fecha a janela pelo mesmo caminho do botão X.
  const String autoCloseMs = String.fromEnvironment('FOGO_AUTOCLOSE_MS');
  if (isDesktopWindowPlatform && autoCloseMs.isNotEmpty) {
    Future<void>.delayed(
      Duration(milliseconds: int.parse(autoCloseMs)),
      closeApplication,
    );
  }

  // Container explícito: a carga do mapa começa FORA da árvore de
  // widgets (a janela definitiva ainda não tem frames enquanto está
  // oculta) — o app consome o mesmo container.
  final ProviderContainer container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const FogoApp()),
  );

  // Startup multi-window (Linux): Splash 800x500 + carga do mapa com
  // progresso espelhado; a janela definitiva é revelada quando o mapa
  // está pronto. Nas demais plataformas o mapa é carregado pela
  // própria página.
  if (multiWindowBootSupported) {
    unawaited(BootCoordinator(container: container).run());
  }
}
