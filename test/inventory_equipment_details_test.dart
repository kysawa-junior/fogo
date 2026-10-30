import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/features/inventory/data/fogo_api_client.dart';
import 'package:fogo/features/inventory/presentation/pages/inventory_page/inventory_page.dart';
import 'package:fogo/features/inventory/providers/equipment_provider.dart';
import 'package:fogo/features/map/domain/map_selection.dart';
import 'package:fogo/features/map/providers/workspace_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Modal de detalhes do equipamento: abre no clique do card, mostra todas
/// as informações, fecha com ESC e navega pelo botão "Ver no mapa".
void main() {
  const equipmentJson =
      '[{"id":"EQ-001","name":"Radar Avenida Sul","category":"radar",'
      '"location":{"latitude":-22.21,"longitude":-49.94},"status":"online",'
      '"lastSeenAt":"2026-10-30T10:00:00Z","roadId":"way/123",'
      '"telemetry":{"temperatura":"42 C","sinal":"-58 dBm"}}]';

  Widget harness() {
    final override = fogoApiClientProvider.overrideWith(
      (ref) => FogoApiClient(
        baseUri: Uri.parse('http://test.local'),
        client: MockClient((request) async {
          return http.Response(
            request.url.path == '/equipment' ? equipmentJson : '[]',
            200,
          );
        }),
      ),
    );
    final router = GoRouter(
      initialLocation: '/inventario',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('MAPA')),
        ),
        GoRoute(
          path: '/inventario',
          builder: (context, state) => const InventoryPage(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [override],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('clique no card abre o modal com todos os detalhes', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Radar Avenida Sul'));
    await tester.pumpAndSettle();

    expect(find.text('Ver no mapa'), findsOneWidget);
    expect(find.text('VIA ASSOCIADA'), findsOneWidget);
    expect(find.text('way/123'), findsOneWidget);
    expect(find.text('LOCALIZAÇÃO'), findsOneWidget);
    expect(find.text('-22.21000, -49.94000'), findsOneWidget);
    expect(find.text('ÚLTIMA ATUALIZAÇÃO'), findsOneWidget);
    expect(find.text('LEITURAS'), findsOneWidget);
    expect(find.text('2 campos'), findsOneWidget);
    expect(find.text('TELEMETRIA'), findsOneWidget);
    expect(find.text('temperatura'), findsOneWidget);
    expect(find.text('42 C'), findsOneWidget);
  });

  testWidgets('ESC fecha o modal', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Radar Avenida Sul'));
    await tester.pumpAndSettle();
    expect(find.text('Ver no mapa'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Ver no mapa'), findsNothing);
    expect(find.text('Radar Avenida Sul'), findsOneWidget);
  });

  testWidgets('Ver no mapa fecha o modal, seleciona e navega', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Radar Avenida Sul'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver no mapa'));
    await tester.pumpAndSettle();

    expect(find.text('MAPA'), findsOneWidget);
    expect(find.text('Ver no mapa'), findsNothing);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('MAPA')),
    );
    final MapSelection selection = container.read(selectionProvider);
    expect(selection, isA<EquipmentSelection>());
    expect((selection as EquipmentSelection).equipmentId, 'EQ-001');
  });
}
