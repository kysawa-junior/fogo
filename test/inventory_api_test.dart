import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:fogo/features/inventory/data/fogo_api_client.dart';
import 'package:fogo/features/inventory/domain/equipment.dart';
import 'package:fogo/features/inventory/domain/vehicle.dart';

/// Integração do cliente HTTP do Inventário com o contrato do
/// fogo-server (payloads reais dos endpoints /equipment e /vehicles).
void main() {
  const equipmentJson =
      '''[{"id":"EQ-001","name":"Radar Avenida Sul","category":"radar",
        "location":{"latitude":-22.2139,"longitude":-49.9434},
        "status":"online","lastSeenAt":"2026-10-27T12:00:00Z",
        "telemetry":{"velocidadeRegistradaKmh":"87"},"roadId":"RD-001"},
        {"id":"EQ-002","name":"Semaforo Centro","category":"semaforo",
        "location":{"latitude":-22.21,"longitude":-49.94},"status":"offline"}]''';
  const vehiclesJson =
      '''[{"id":"VT-001","plate":"ABC1D23","kind":"police","status":"ativa"},
        {"id":"VT-002","plate":"DEF5678","kind":"fire","status":"em_manutencao"}]''';

  FogoApiClient clientWith({required String body, int status = 200}) {
    return FogoApiClient(
      baseUri: Uri.parse('http://test.local'),
      client: MockClient((request) async => http.Response(body, status)),
    );
  }

  test('decodifica equipamentos, incluindo semaforo', () async {
    final list = await clientWith(body: equipmentJson).equipment();
    expect(list, hasLength(2));
    expect(list.first.category, EquipmentCategory.radar);
    expect(list.first.location, LatLng(-22.2139, -49.9434));
    expect(list.first.telemetry['velocidadeRegistradaKmh'], '87');
    expect(list.first.roadId, 'RD-001');
    expect(list.first.lastSeenAt, isNotNull);
    expect(list.last.category, EquipmentCategory.semaforo);
    expect(list.last.telemetry, isEmpty);
    expect(list.last.roadId, isNull);
  });

  test('decodifica a frota registrada', () async {
    final list = await clientWith(body: vehiclesJson).vehicles();
    expect(list, hasLength(2));
    expect(list.first.id, 'VT-001');
    expect(list.first.plate, 'ABC1D23');
    expect(list.first.kind, VehicleKind.police);
    expect(list.first.status, VehicleStatus.ativa);
    expect(list.last.status, VehicleStatus.em_manutencao);
  });

  test('falha legível quando o servidor responde erro', () async {
    await expectLater(
      clientWith(body: 'boom', status: 500).equipment(),
      throwsA(
        isA<FogoApiException>().having(
          (e) => e.message,
          'message',
          contains('500'),
        ),
      ),
    );
  });

  test('falha legível quando o servidor está indisponível', () async {
    final client = FogoApiClient(
      baseUri: Uri.parse('http://test.local'),
      client: MockClient(
        (request) async => throw Exception('conexão recusada'),
      ),
    );
    await expectLater(client.vehicles(), throwsA(isA<FogoApiException>()));
  });
}
