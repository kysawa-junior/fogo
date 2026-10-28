import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/features/inventory/data/fogo_api_client.dart';
import 'package:fogo/features/inventory/presentation/pages/inventory_page/inventory_page.dart';
import 'package:fogo/features/inventory/providers/equipment_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Página de Inventário consumindo o fogo-server: lista combinada
/// (equipamentos + viaturas), estado offline com retry.
void main() {
  Widget harness(String Function(String path) responder) {
    final override = fogoApiClientProvider.overrideWith(
      (ref) => FogoApiClient(
        baseUri: Uri.parse('http://test.local'),
        client: MockClient((request) async {
          return http.Response(responder(request.url.path), 200);
        }),
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const InventoryPage()),
      ],
    );
    return ProviderScope(
      overrides: [override],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  const equipmentJson =
      '[{"id":"EQ-001","name":"Radar Avenida Sul","category":"radar",'
      '"location":{"latitude":-22.21,"longitude":-49.94},"status":"online"}]';
  const vehiclesJson =
      '[{"id":"VT-001","plate":"ABC1D23","kind":"fire","status":"em_manutencao"}]';

  testWidgets('lista equipamentos e viaturas do backend', (tester) async {
    await tester.pumpWidget(
      harness((path) => path == '/equipment' ? equipmentJson : vehiclesJson),
    );
    await tester.pumpAndSettle();

    expect(find.text('Radar Avenida Sul'), findsOneWidget);
    expect(find.text('VIATURAS'), findsOneWidget);
    expect(find.text('ABC1D23'), findsOneWidget);
    expect(find.text('Bombeiro · VT-001'), findsOneWidget);
    expect(find.text('Em manutenção'), findsOneWidget);
    expect(find.text('1 de 1 equipamentos · 1 de 1 viaturas'), findsOneWidget);
  });

  testWidgets('servidor fora mostra estado de rede', (tester) async {
    final override = fogoApiClientProvider.overrideWith(
      (ref) => FogoApiClient(
        baseUri: Uri.parse('http://test.local'),
        client: MockClient((request) async => http.Response('boom', 500)),
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const InventoryPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [override],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível consultar o fogo-server'),
      findsOneWidget,
    );
  });

  testWidgets('frota vazia do server esconde a seção Viaturas', (tester) async {
    await tester.pumpWidget(
      harness((path) => path == '/equipment' ? equipmentJson : '[]'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Radar Avenida Sul'), findsOneWidget);
    expect(find.text('Viaturas'), findsNothing);
    expect(find.text('1 de 1 equipamentos · 0 de 0 viaturas'), findsOneWidget);
  });
}
