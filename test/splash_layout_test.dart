import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/app/boot/splash.dart';
import 'package:fogo/app/boot/splash_brand_panel.dart';
import 'package:fogo/app/boot/splash_map_panel.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
  });

  testWidgets('splash fica vazia enquanto o viewport está colapsado', (
    tester,
  ) async {
    // Janela Splash nasce oculta: o primeiro frame chega 1x1.
    tester.view.physicalSize = const Size(1, 1);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FogoSplashApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SplashBrandPanel), findsNothing);
    expect(find.byType(SplashMapPanel), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('splash mostra marca e painel cartográfico no tamanho da janela', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FogoSplashApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SplashBrandPanel), findsOneWidget);
    expect(find.byType(SplashMapPanel), findsOneWidget);
    expect(find.text('FOGO'), findsOneWidget);
    expect(find.text('OPERAÇÕES COM BASE CARTOGRÁFICA 3D'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
