import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app/fogo_app.dart';
import 'app/window_close_handler.dart';
import 'core/persistence/preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Janela frameless: title bar nativa oculta — o app tem titlebar própria
  // (mesmo padrão do projeto LienneDart).
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(960, 600),
    title: 'F.O.G.O.',
    titleBarStyle: TitleBarStyle.hidden,
    center: true,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // Todo fechamento nativo (Alt+F4/WM) passa pelo encerramento controlado.
    await windowManager.setPreventClose(true);
  });

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Diagnóstico/CI: fecha a janela pelo mesmo caminho do botão X.
  const String autoCloseMs = String.fromEnvironment('FOGO_AUTOCLOSE_MS');
  if (autoCloseMs.isNotEmpty) {
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
