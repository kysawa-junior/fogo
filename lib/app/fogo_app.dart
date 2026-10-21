import 'package:flutter/widgets.dart';

import '../../core/design_system/fogo_colors.dart';
import '../../core/design_system/widgets/fogo_titlebar.dart';
import '../../core/theme/fogo_typography.dart';
import 'router/app_router.dart';
import 'window_close_handler.dart';

/// Raiz da aplicação — WidgetsApp (sem MaterialApp / Material Design).
/// Titlebar própria em chrome fixo no topo, acima de todas as rotas.
class FogoApp extends StatelessWidget {
  const FogoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp.router(
      routerConfig: AppRouter.config,
      title: 'F.O.G.O.',
      color: FogoColors.bg,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DefaultTextStyle.merge(
        style: FogoText.body,
        child: WindowCloseHandler(
          child: Column(
            children: [
              const FogoTitlebar(),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
