import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/features/inventory/data/fogo_api_client.dart';
import 'package:fogo/features/inventory/presentation/pages/inventory_page/inventory_page.dart';
import 'package:fogo/features/inventory/providers/equipment_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  testWidgets('visual inventário', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final override = fogoApiClientProvider.overrideWith(
      (ref) => FogoApiClient(
        baseUri: Uri.parse('http://test.local'),
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              switch (request.url.path) {
                '/equipment' => _equipmentJson,
                '/vehicles' => _vehiclesJson,
                _ => '[]',
              },
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    final router = GoRouter(
      initialLocation: '/inventario',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/inventario',
          // Card flutuante no tamanho do .pen (1100×600) sobre o canvas.
          builder: (context, state) => const ColoredBox(
            color: Color(0xFF01010A),
            child: Center(
              child: SizedBox(
                width: 1100,
                height: 600,
                child: InventoryPage(),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [override],
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Inter'),
          child: WidgetsApp.router(
            routerConfig: router,
            color: const Color(0xFF01010A),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('tmp_inventory.png'),
    );

    await tester.tap(find.text('Atenção').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('tmp_inventory_filter.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

const String _equipmentJson =
    '[{"id":"EQ-001","name":"Radar Avenida Sul","category":"radar",'
    '"location":{"latitude":-22.21,"longitude":-49.94},"status":"online",'
    '"lastSeenAt":"2026-10-30T10:00:00Z","roadId":"way/123",'
    '"telemetry":{"temperatura":"42 C","sinal":"-58 dBm","tensao":"220 V"}},'
    '{"id":"EQ-002","name":"Camera Marginal Norte","category":"camera",'
    '"location":{"latitude":-22.22,"longitude":-49.93},"status":"attention",'
    '"lastSeenAt":"2026-10-30T09:40:00Z","telemetry":{"fps":"24"}},'
    '{"id":"EQ-003","name":"Balança Rodovia Leste","category":"scale",'
    '"location":{"latitude":-22.19,"longitude":-49.91},"status":"offline",'
    '"lastSeenAt":null},'
    '{"id":"EQ-004","name":"Cancela Terminal Central","category":"gate",'
    '"location":{"latitude":-22.18,"longitude":-49.95},"status":"maintenance"},'
    '{"id":"EQ-005","name":"Totem Praça do Centro","category":"kiosk",'
    '"location":{"latitude":-22.17,"longitude":-49.96},"status":"online"},'
    '{"id":"EQ-006","name":"Sensor Várzea Sul","category":"sensor",'
    '"location":{"latitude":-22.16,"longitude":-49.97},"status":"online"},'
    '{"id":"EQ-007","name":"Patinete Área Industrial","category":"scooter",'
    '"location":{"latitude":-22.15,"longitude":-49.98},"status":"offline"},'
    '{"id":"EQ-008","name":"Semáforo Avenida Principal","category":"semaforo",'
    '"location":{"latitude":-22.14,"longitude":-49.99},"status":"online"}]';

const String _vehiclesJson =
    '[{"id":"VT-001","plate":"ABC1D23","kind":"fire","status":"em_manutencao"},'
    '{"id":"VT-002","plate":"XYZ9K88","kind":"police","status":"ativa"}]';

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
