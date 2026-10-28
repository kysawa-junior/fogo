import 'package:flutter/widgets.dart';

import '../core/design_system/fogo_colors.dart';
import '../core/design_system/widgets/fogo_titlebar/fogo_titlebar.dart';
import '../core/theme/fogo_typography.dart';
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
      builder: (context, child) {
        // Titlebar como child FIXO (altura natural 40): nunca em flex —
        // Flexible default é flex:1 e dividiria a coluna com o Expanded
        // (a página ficava presa em h=432 = metade do viewport 864, banda
        // preta abaixo). O medo do 1×1 é de outra era: a janela nasce com
        // o tamanho final no runner (my_application.cc), sem frame 1×1.
        final Widget appContent = Column(
          children: [
            if (isDesktopWindowPlatform) const FogoTitlebar(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
        return DefaultTextStyle.merge(
          style: FogoText.body,
          child: isDesktopWindowPlatform
              ? WindowCloseHandler(child: appContent)
              : appContent,
        );
      },
    );
  }
}
