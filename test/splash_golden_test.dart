import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/app/boot/splash.dart';
import 'package:fogo/app/boot/splash_brand_panel.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async => null);
    await _loadFont('Inter', <String>[
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]);
    await _loadFont('JetBrainsMono', <String>[
      'assets/fonts/JetBrainsMono-Regular.ttf',
    ]);
    await _loadFont('packages/flutter_lucide/lucide', <String>[
      'packages/flutter_lucide/fonts/lucide.ttf',
    ]);
  });

  testWidgets('golden', (tester) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FogoSplashApp());
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(FogoSplashApp),
      matchesGoldenFile('splash_final.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('golden painel de marca com 42% (barra determinada)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(330, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SplashBrandPanel(
          phase: 'Interpretando OSM',
          progress: 0.42,
          onExit: _noop,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(SplashBrandPanel),
      matchesGoldenFile('splash_brand_42.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _noop() {}

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    if (path.startsWith('packages/')) {
      final String pkg = path.split('/')[1];
      final File file = File('${_pkgRoot(pkg)}/lib/fonts/lucide.ttf');
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
      continue;
    }
    loader.addFont(rootBundle.load(path));
  }
  await loader.load();
}

String _pkgRoot(String pkg) {
  final File config = File('.dart_tool/package_config.json');
  final Map<String, dynamic> json =
      jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final Object? entry in json['packages'] as List<Object?>) {
    final Map<String, dynamic> pkgEntry = entry as Map<String, dynamic>;
    if (pkgEntry['name'] == pkg) {
      final String rootUri = pkgEntry['rootUri'] as String;
      return rootUri.startsWith('file://')
          ? rootUri.substring('file://'.length)
          : rootUri;
    }
  }
  throw StateError('pacote não encontrado: $pkg');
}
