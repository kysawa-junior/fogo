import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fogo/app/fogo_app.dart';
import 'package:fogo/core/persistence/preferences_provider.dart';
import 'package:fogo/features/map/data/geocoding_service.dart';
import 'package:fogo/features/map/presentation/pages/map_workspace_page.dart';
import 'package:fogo/features/map/presentation/widgets/search_results_panel.dart';
import 'package:fogo/features/map/providers/search_provider.dart';
import 'package:fogo/features/routing/data/route_service.dart';
import 'package:fogo/features/routing/providers/routing_providers.dart';

const String _nominatimBody = '''
[{"display_name":"Garça, São Paulo, Brasil","lat":"-22.228","lon":"-49.6588",
  "category":"place","type":"city"}]
''';

const String _routeBody = '''
{"code":"Ok","routes":[{"distance":34500.5,"duration":2100.2,
"geometry":{"type":"LineString","coordinates":[[-49.95,-22.21],[-49.80,-22.22],[-49.66,-22.23]]},
"legs":[{"distance":18000.0,"duration":900.0},{"distance":16500.5,"duration":1200.2}]}]}
''';

void main() {
  testWidgets(
    'workspace keeps route/search independent and aligns route markers with SDK camera',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final GeocodingService geocoding = GeocodingService(
        client: MockClient((_) async => http.Response(_nominatimBody, 200)),
      );
      final RouteService routing = OsrmRouteService(
        client: MockClient((request) async {
          if (request.url.path.contains('/table/')) {
            final int count = request.url.path
                .split('/table/')
                .last
                .split(';')
                .length;
            final List<List<double>> matrix = [
              for (int i = 0; i < count; i++)
                [
                  for (int j = 0; j < count; j++)
                    i == j ? 0.0 : 1500.0 * (j - i).abs(),
                ],
            ];
            return http.Response(
              '{"code":"Ok","distances":${jsonEncode(matrix)}}',
              200,
            );
          }
          return http.Response(_routeBody, 200);
        }),
        baseUrl: 'http://test',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            geocodingServiceProvider.overrideWithValue(geocoding),
            routeServiceProvider.overrideWithValue(routing),
          ],
          // Exclude semantics collection here because SDK map zoom actions
          // currently publish a value without increased/decreased values.
          child: const ExcludeSemantics(child: FogoApp()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      final Finder workspace = find.byType(MapWorkspacePage);
      expect(workspace, findsOneWidget);
      FogoMapView mapView = tester.widget(find.byType(FogoMapView));
      final FogoMapController controller = mapView.controller;

      // The initial camera fit and explicit region shortcut both use SDK bounds fit.
      expect(controller.camera.pitch, 0);
      await tester.tap(find.text('Região'));
      await tester.pump();
      expect(controller.transform.visibleBounds.west, lessThan(-50.04));
      expect(controller.transform.visibleBounds.east, greaterThan(-49.59));
      await tester.tap(find.text('Marília'));
      await tester.pump();
      expect(
        controller.camera.center.longitude,
        inInclusiveRange(-50.04, -49.85),
      );
      expect(
        controller.camera.center.latitude,
        inInclusiveRange(-22.31, -22.12),
      );

      // Search is host-owned and moves the SDK camera without coupling it to routing.
      await tester.enterText(find.byType(EditableText).first, 'garça');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      final Finder garcaResult = find.descendant(
        of: find.byType(SearchResultsPanel),
        matching: find.text('Garça'),
      );
      expect(garcaResult, findsOneWidget);
      await tester.tap(garcaResult);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(controller.camera.center, const FogoCoordinate(-22.228, -49.6588));
      expect(controller.camera.zoom, 16);
      expect(
        ProviderScope.containerOf(tester.element(workspace))
            .read(searchQueryProvider)
            .status,
        SearchStatus.idle,
      );

      // Long-press selections continue to create host routing stops.
      await tester.longPressAt(const Offset(500, 400));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.longPressAt(const Offset(700, 500));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(workspace),
      );
      expect(container.read(routingFlowProvider).drafts, hasLength(2));
      await tester.tap(find.text('Otimizar rota'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Rota otimizada · 34.5 km · 35 min'), findsOneWidget);

      mapView = tester.widget(find.byType(FogoMapView));
      expect(mapView.polylines, hasLength(1));
      expect(mapView.markers, hasLength(4));
      final FogoMapMarker marker = mapView.markers.first;
      final Offset mapOrigin = tester.getTopLeft(find.byType(FogoMapView));
      final Offset markerCenter = tester.getCenter(
        find.byKey(ValueKey<String>(marker.id)),
      );
      expect(
        markerCenter,
        mapOrigin + controller.coordinateToScreen(marker.coordinate)!,
      );

      final FogoCoordinate cameraBeforeDrag = controller.camera.center;
      await tester.dragFrom(const Offset(120, 400), const Offset(-80, 25));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.camera.center, isNot(cameraBeforeDrag));
      expect(container.read(routingFlowProvider).drafts, hasLength(2));
      expect(
        tester.widget<FogoMapView>(find.byType(FogoMapView)).polylines,
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'workspace persists center/zoom only and exposes accessible transient 3D toggle',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: const ExcludeSemantics(child: FogoApp()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      final FogoMapController controller = tester
          .widget<FogoMapView>(find.byType(FogoMapView))
          .controller;
      controller.moveTo(const FogoCoordinate(-22.3, -49.9), zoom: 13);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();
      expect(preferences.getDouble('fogo.camera.lat'), -22.3);
      expect(preferences.getDouble('fogo.camera.lng'), -49.9);
      expect(preferences.getDouble('fogo.camera.zoom'), 13);

      Semantics toggleSemantics() => tester
          .widgetList<Semantics>(find.byType(Semantics))
          .singleWhere(
            (Semantics semantics) => semantics.properties.label == 'Visão 3D',
          );

      Semantics toggle = toggleSemantics();
      expect(toggle.properties.button, isTrue);
      expect(toggle.properties.toggled, isFalse);
      expect(toggle.properties.value, 'Desativada');
      expect(toggle.properties.onTap, isNotNull);
      toggle.properties.onTap!();
      await tester.pump();
      expect(controller.camera.pitch, 45);
      toggle = toggleSemantics();
      expect(toggle.properties.toggled, isTrue);
      expect(toggle.properties.value, 'Ativada');

      // Enter/Space path uses the same button action, but leaves pitch transient.
      Focus.of(tester.element(find.text('3D'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.camera.pitch, 0);
      expect(preferences.getDouble('fogo.camera.lat'), -22.3);
      expect(preferences.getDouble('fogo.camera.lng'), -49.9);
      expect(preferences.getDouble('fogo.camera.zoom'), 13);
      expect(
        preferences.getKeys().any((key) => key.contains('pitch')),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
