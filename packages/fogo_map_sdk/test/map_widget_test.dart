import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';

import 'test_support.dart';

void main() {
  testWidgets('drag, pinch, double-tap, wheel, and fling update camera', (
    WidgetTester tester,
  ) async {
    final FogoMapController controller = _controller();
    final StubMapDataSource source = StubMapDataSource(
      testManifest(),
      cell: FogoMapCellData(),
    );
    await _pumpMap(tester, controller, source);
    final Finder map = find.byType(FogoMapView);

    final FogoCoordinate beforeDrag = controller.camera.center;
    await tester.drag(map, const Offset(50, 20));
    await tester.pump();
    expect(controller.camera.center, isNot(beforeDrag));

    controller.setCamera(
      const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 10),
    );
    final TestGesture first = await tester.startGesture(
      const Offset(150, 150),
      pointer: 1,
    );
    final TestGesture second = await tester.startGesture(
      const Offset(250, 150),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(const Offset(120, 150));
    await second.moveTo(const Offset(280, 150));
    await tester.pump(const Duration(milliseconds: 80));
    await first.up();
    await second.up();
    await tester.pump();
    expect(controller.camera.zoom, greaterThan(10));

    controller.setCamera(
      const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 10),
    );
    await tester.tapAt(const Offset(200, 150));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(200, 150));
    await tester.pump();
    expect(controller.camera.zoom, 11);

    controller.setCamera(
      const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 10),
    );
    final TestPointer wheel = TestPointer(90, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      wheel.addPointer(location: const Offset(200, 150)),
    );
    await tester.sendEventToBinding(wheel.hover(const Offset(200, 150)));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -120)));
    await tester.pump();
    expect(controller.camera.zoom, closeTo(10.5, 1e-9));
    await tester.sendEventToBinding(wheel.removePointer());

    controller.setCamera(
      const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 10),
    );
    await tester.fling(map, const Offset(120, 0), 900);
    await tester.pump(const Duration(milliseconds: 800));
    expect(controller.camera.center.longitude, isNot(0));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('secondary-click and long-press select independent coordinates', (
    WidgetTester tester,
  ) async {
    final FogoMapController controller = _controller();
    final StubMapDataSource source = StubMapDataSource(
      testManifest(),
      cell: FogoMapCellData(),
    );
    final List<FogoMapSelection> callbacks = [];
    await _pumpMap(tester, controller, source, onSelection: callbacks.add);

    await tester.tapAt(
      const Offset(120, 110),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await tester.longPressAt(const Offset(280, 190));
    await tester.pump();

    expect(callbacks.map((selection) => selection.source), [
      FogoSelectionSource.secondaryClick,
      FogoSelectionSource.longPress,
    ]);
    expect(callbacks.first.coordinate, isNot(callbacks.last.coordinate));
    expect(controller.camera.center, const FogoCoordinate(0, 0));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'viewport loads only covered cells and reports empty/outside states',
    (WidgetTester tester) async {
      final FogoMapController controller = _controller();
      final StubMapDataSource source = StubMapDataSource(
        testManifest(),
        cell: FogoMapCellData(),
      );
      final List<FogoMapDataStatus> statuses = [];
      await _pumpMap(tester, controller, source, onDataStatus: statuses.add);
      expect(statuses.last.phase, FogoMapDataPhase.empty);
      expect(source.requests, isNotEmpty);
      expect(
        source.requests.every(
          (request) =>
              request.$2 >= 0 &&
              request.$2 < testManifest().columns &&
              request.$3 >= 0 &&
              request.$3 < testManifest().rows,
        ),
        isTrue,
      );

      controller.moveTo(const FogoCoordinate(0, 2), zoom: 10);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(
        statuses.last.phase,
        anyOf(FogoMapDataPhase.empty, FogoMapDataPhase.ready),
      );
      expect(statuses.last.requestedCellCount, greaterThan(0));

      controller.moveTo(const FogoCoordinate(10, 10), zoom: 10);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(statuses.last.phase, FogoMapDataPhase.outsideCoverage);
      expect(statuses.last.requestedCellCount, 0);

      final int requestsBeforeReturn = source.requests.length;
      controller.moveTo(const FogoCoordinate(0, 0), zoom: 10);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(
        source.requests.length,
        greaterThan(requestsBeforeReturn),
        reason: 'outside-coverage transition prunes prior viewport cells',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'corrupt cell becomes typed status and does not stop camera input',
    (WidgetTester tester) async {
      final MemoryAssetBundle bundle = MemoryAssetBundle({
        'assets/map/manifest.json': utf8.encode(jsonEncode(manifestJson())),
        'assets/map/cells/l0_2_2.json.gz': [0x1f, 0x8b, 0x00],
      });
      final FogoMapDataSource source = FogoMapDataSource(assetBundle: bundle);
      final FogoMapController controller = FogoMapController(
        initialCamera: const FogoCameraState(
          center: FogoCoordinate(-1, -1),
          zoom: 10,
        ),
      );
      final List<FogoMapDataStatus> statuses = [];
      await _pumpMap(
        tester,
        controller,
        source,
        onDataStatus: statuses.add,
        style: FogoMapStyle.fogoNight,
      );
      expect(statuses.last.phase, FogoMapDataPhase.empty);

      // At zoom 10, viewport crosses cell boundaries. Move to a corrupt cell.
      controller.moveTo(const FogoCoordinate(0.5, 0.5), zoom: 10);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(statuses.any((status) => status.hasErrors), isTrue);
      final FogoMapDataError error = statuses
          .lastWhere((status) => status.hasErrors)
          .errors
          .single;
      expect(error.kind, FogoMapDataErrorKind.cell);
      expect(error.tier, FogoCellTier.l0);
      final FogoCoordinate before = controller.camera.center;
      await tester.drag(find.byType(FogoMapView), const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.camera.center, isNot(before));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('data-source swap ignores stale async manifest completion', (
    WidgetTester tester,
  ) async {
    final Completer<FogoMapManifest> oldManifest = Completer<FogoMapManifest>();
    final _DeferredMapDataSource oldSource = _DeferredMapDataSource(
      oldManifest,
    );
    final StubMapDataSource newSource = StubMapDataSource(
      testManifest(source: 'new-source'),
      cell: FogoMapCellData(),
    );
    final FogoMapController controller = _controller();
    final List<FogoMapDataStatus> statuses = [];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: ExcludeSemantics(
            child: FogoMapView(
              controller: controller,
              dataSource: oldSource,
              onDataStatus: statuses.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: ExcludeSemantics(
            child: FogoMapView(
              controller: controller,
              dataSource: newSource,
              onDataStatus: statuses.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    oldManifest.complete(testManifest(source: 'stale-source'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(statuses.last.manifest?.source, 'new-source');
    expect(
      statuses.any((status) => status.manifest?.source == 'stale-source'),
      isFalse,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'routes remain gesture-independent; marker shares map transform',
    (WidgetTester tester) async {
      final FogoMapController controller = _controller();
      final StubMapDataSource source = StubMapDataSource(
        testManifest(),
        cell: FogoMapCellData(),
      );
      const FogoCoordinate markerCoordinate = FogoCoordinate(0.01, 0.01);
      int markerTaps = 0;
      final FogoMapPolyline route = FogoMapPolyline(
        id: 'route',
        points: const [FogoCoordinate(0, -0.5), FogoCoordinate(0, 0.5)],
        color: const Color(0xFFFF0000),
        width: 4,
      );
      await _pumpMap(
        tester,
        controller,
        source,
        polylines: [route],
        markers: [
          FogoMapMarker(
            id: 'route-stop',
            coordinate: markerCoordinate,
            width: 20,
            height: 20,
            child: GestureDetector(
              onTap: () => markerTaps++,
              child: const ColoredBox(
                key: ValueKey('route-marker-child'),
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ],
      );
      final Finder marker = find.byKey(const ValueKey('route-marker-child'));
      expect(
        tester.getCenter(marker),
        controller.coordinateToScreen(markerCoordinate),
      );
      await tester.tap(marker);
      expect(markerTaps, 1);

      controller.setPitch(45);
      await tester.pump();
      expect(
        tester.getCenter(marker),
        controller.coordinateToScreen(markerCoordinate),
      );

      final FogoCoordinate before = controller.camera.center;
      await tester.dragFrom(const Offset(70, 150), const Offset(50, 0));
      await tester.pump();
      expect(controller.camera.center, isNot(before));
      expect(route.points, [
        const FogoCoordinate(0, -0.5),
        const FogoCoordinate(0, 0.5),
      ]);
      expect(
        tester.getCenter(marker),
        controller.coordinateToScreen(markerCoordinate),
      );

      await tester.pump(kDoubleTapTimeout);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('attribution text is shown when enabled', (
    WidgetTester tester,
  ) async {
    final FogoMapController controller = _controller();
    await _pumpMap(
      tester,
      controller,
      StubMapDataSource(testManifest(), cell: FogoMapCellData()),
      style: FogoMapStyle.fogoNight,
    );
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('map zoom semantics includes valid value increment metadata', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semanticsHandle = tester.ensureSemantics();
    final FogoMapController controller = _controller();
    await _pumpMap(
      tester,
      controller,
      StubMapDataSource(testManifest(), cell: FogoMapCellData()),
      excludeSemantics: false,
    );
    final Finder map = find.bySemanticsLabel('F.O.G.O. regional map');
    expect(map, findsOneWidget);
    final mapNode = tester.getSemantics(map);
    final semanticsData = mapNode.getSemanticsData();
    expect(semanticsData.value, 'Zoom 10.0');
    expect(semanticsData.increasedValue, 'Zoom 11.0');
    expect(semanticsData.decreasedValue, 'Zoom 9.0');
    expect(semanticsData.hasAction(SemanticsAction.increase), isTrue);
    expect(semanticsData.hasAction(SemanticsAction.decrease), isTrue);
    mapNode.owner!.performAction(mapNode.id, SemanticsAction.increase);
    await tester.pump();
    expect(controller.camera.zoom, 11);
    mapNode.owner!.performAction(mapNode.id, SemanticsAction.decrease);
    await tester.pump();
    expect(controller.camera.zoom, 10);
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

FogoMapController _controller() => FogoMapController(
  initialCamera: const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 10),
);

Future<void> _pumpMap(
  WidgetTester tester,
  FogoMapController controller,
  FogoMapDataSource source, {
  FogoMapStyle? style,
  ValueChanged<FogoMapSelection>? onSelection,
  ValueChanged<FogoMapDataStatus>? onDataStatus,
  List<FogoMapPolyline> polylines = const [],
  List<FogoMapMarker> markers = const [],
  bool excludeSemantics = true,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 400,
        height: 300,
        child: Builder(
          builder: (context) {
            final Widget map = FogoMapView(
              controller: controller,
              dataSource: source,
              style: style ?? _quietStyle,
              onSelection: onSelection,
              onDataStatus: onDataStatus,
              polylines: polylines,
              markers: markers,
            );
            return excludeSemantics ? ExcludeSemantics(child: map) : map;
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump();
  await tester.pumpAndSettle();
}

final FogoMapStyle _quietStyle = FogoMapStyle(
  background: const Color(0xFF101010),
  showAreas: false,
  showWaterLines: false,
  showRail: false,
  showRoads: false,
  showBuildings: false,
  showLabels: false,
  showPois: false,
  showAttribution: false,
);

class _DeferredMapDataSource extends StubMapDataSource {
  _DeferredMapDataSource(this.manifestCompleter)
    : super(testManifest(source: 'waiting'));

  final Completer<FogoMapManifest> manifestCompleter;

  @override
  Future<FogoMapManifest> loadManifest() => manifestCompleter.future;
}
