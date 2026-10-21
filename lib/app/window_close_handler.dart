import 'dart:io' show Platform, exit;

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Encerramento controlado do F.O.G.O.
///
/// shortcut: bug upstream do embedder Linux (flutter/flutter#193742): o
/// teardown GTK dispara `FlutterEngineRemoveView` com `kInvalidArguments`
/// ("The implicit view cannot be removed") e pode levar a use-after-free no
/// shutdown. Até o fix do engine, no Linux a janela é ocultada e o processo
/// encerrado de forma determinística; nas demais plataformas o caminho
/// padrão (destroy) é mantido — o bug é específico do embedder Linux.
Future<void> closeApplication() async {
  if (Platform.isLinux) {
    await windowManager.hide();
    exit(0);
  }
  await windowManager.destroy();
}

/// Interceptor de fechamento nativo (Alt+F4 / WM): com `setPreventClose(true)`,
/// todo fechamento nativo cai em [onWindowClose] e passa pelo mesmo
/// encerramento controlado do botão X da titlebar.
class WindowCloseHandler extends StatefulWidget {
  const WindowCloseHandler({super.key, required this.child});

  final Widget child;

  @override
  State<WindowCloseHandler> createState() => _WindowCloseHandlerState();
}

class _WindowCloseHandlerState extends State<WindowCloseHandler>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() => closeApplication();

  @override
  Widget build(BuildContext context) => widget.child;
}
