import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app/fogo_app.dart';
import 'app/window_close_handler.dart';
import 'core/design_system/fogo_colors.dart';
import 'core/persistence/preferences_provider.dart';

/// Tamanho mínimo da janela (setado pelo window_manager).
const Size kAppWindowMinSize = Size(960, 600);

/// Engine principal: JANELA ÚNICA e DIRETA — mapeada no T0 no tamanho
/// definitivo (frameless; nasce workarea-clamped pelo runner C — resize
/// pós-criação wedgea o pipeline Impeller/Wayland: buffer pela metade,
/// frames congelados, fundo preto — medido, "Timed out ... have 1x1").
/// O carregamento é exibido pela própria UI da página (sem splash).
Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktopWindowPlatform) {
    // Visível desde o primeiro frame: mapeada pelo runner C no tamanho
    // final; aqui confirma foco, mínimo e encerramento controlado.
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      backgroundColor: FogoColors.bg,
      title: 'F.O.G.O.',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FogoApp(),
    ),
  );
}
