import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/fogo_colors.dart';
import '../../../core/design_system/fogo_spacing.dart';
import '../../../core/design_system/widgets/fogo_button.dart';
import '../../../core/design_system/widgets/fogo_panel.dart';
import '../../../core/theme/fogo_typography.dart';
import '../../features/inventory/presentation/pages/inventory_page/inventory_page.dart';
import '../../features/map/presentation/pages/map_3d_page/map_3d_page.dart';
import '../../features/predictive_city/presentation/pages/predictive_city_page.dart';

/// Rotas do F.O.G.O. — páginas customizadas (sem página Material).
abstract final class AppRouter {
  static final GoRouter config = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        // Motor 3D próprio com base regional OSM (sem WebView/Mapbox GL JS).
        pageBuilder: (context, state) => _page(state, const Map3dPage()),
      ),
      GoRoute(
        path: '/inventory',
        pageBuilder: (context, state) => _page(state, const InventoryPage()),
      ),
      GoRoute(
        path: '/predictive',
        pageBuilder: (context, state) =>
            _page(state, const PredictiveCityPage()),
      ),
    ],
    errorPageBuilder: (context, state) => _page(state, const _NotFoundPage()),
  );

  static CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FogoColors.bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(FogoSpacing.xl),
      child: FogoPanel(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rota não encontrada', style: FogoText.title),
            const SizedBox(height: FogoSpacing.sm),
            const Text(
              'O endereço acessado não corresponde a nenhum módulo.',
              style: FogoText.body,
            ),
            const SizedBox(height: FogoSpacing.lg),
            FogoButton(
              label: 'Voltar ao workspace',
              variant: FogoButtonVariant.primary,
              onTap: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
  }
}
