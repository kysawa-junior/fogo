import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fogo/app/router/app_router.dart';
import 'package:fogo/features/map/presentation/pages/map_3d_page/map_3d_page.dart';
import 'package:fogo/features/predictive_city/presentation/pages/predictive_city_page.dart';

void main() {
  testWidgets(
    'root, inventory and predictive URLs select their existing pages',
    (WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      );

      // Rota '/' é a Central de Operações no Motor 3D (base regional OSM).
      expect(_pageFor('/', context), isA<Map3dPage>());
      // '/inventory' NÃO é uma tela: é o workspace com o card flutuante
      // do inventário já aberto.
      expect(_pageFor('/inventory', context), isA<Map3dPage>());
      expect(_pageFor('/predictive', context), isA<PredictiveCityPage>());
    },
  );
}

Widget _pageFor(String location, BuildContext context) {
  final router = AppRouter.config;
  final RouteMatchList matches = router.configuration.findMatch(
    Uri.parse(location),
  );
  final match = matches.last;
  final GoRouterState state = match.buildState(
    router.configuration,
    matches,
    metadata: const {},
  );
  final GoRoute route = match.route;
  final Page<void> page = route.pageBuilder!(context, state);

  return (page as CustomTransitionPage<void>).child;
}
