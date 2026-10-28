import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../predictive_city/domain/risk_area.dart';
import '../domain/equipment.dart';
import '../domain/vehicle.dart';

/// Cliente HTTP do Inventário Inteligente (fogo-server).
///
/// URL sobrescrevível em build:
/// `flutter run --dart-define=FOGO_API_URL=http://10.0.2.2:8026`
class FogoApiClient {
  FogoApiClient({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'FOGO_API_URL',
              defaultValue: 'http://127.0.0.1:8026',
            ),
          );

  final http.Client _client;

  /// Base do fogo-server (ex.: `http://127.0.0.1:8026`).
  final Uri baseUri;

  static const _timeout = Duration(seconds: 10);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = baseUri.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  /// Catálogo de equipamentos (GET /equipment).
  Future<List<Equipment>> equipment() async {
    final rows = await _list('/equipment', 'equipamento');
    return [for (final row in rows) _equipment(row)];
  }

  /// Frota registrada (GET /vehicles).
  Future<List<Vehicle>> vehicles() async {
    final rows = await _list('/vehicles', 'viatura');
    return [for (final row in rows) _vehicle(row)];
  }

  /// Áreas de risco (GET /risk/areas) — Cidade Preditiva.
  Future<List<RiskArea>> riskAreas({double cellMeters = 400}) async {
    final rows = await _list(
      '/risk/areas?cell=${cellMeters.round()}',
      'áreas de risco',
    );
    return [
      for (final row in rows) RiskArea.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<List<dynamic>> _list(String path, String recurso) async {
    late final http.Response response;
    try {
      response = await _client.get(_uri(path)).timeout(_timeout);
    } on TimeoutException {
      throw FogoApiException('Servidor não respondeu ($path).');
    } catch (error) {
      debugPrint('FogoApi $path falhou: $error');
      throw FogoApiException('Servidor indisponível ($path).');
    }
    if (response.statusCode != 200) {
      throw FogoApiException(
        'Servidor respondeu ${response.statusCode} ao listar $recurso.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  Equipment _equipment(Map<String, dynamic> json) => Equipment(
    id: json['id'] as String,
    name: json['name'] as String,
    category: EquipmentCategory.values.byName(json['category'] as String),
    location: _latLng(json['location'] as Map<String, dynamic>),
    status: EquipmentStatus.values.byName(json['status'] as String),
    lastSeenAt: DateTime.tryParse(json['lastSeenAt'] as String? ?? ''),
    telemetry:
        (json['telemetry'] as Map<String, dynamic>?)?.cast<String, String>() ??
        const {},
    roadId: json['roadId'] as String?,
  );

  Vehicle _vehicle(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    plate: json['plate'] as String,
    kind: VehicleKind.values.byName(json['kind'] as String),
    status: VehicleStatus.values.byName(json['status'] as String),
  );

  LatLng _latLng(Map<String, dynamic> json) => LatLng(
    (json['latitude'] as num).toDouble(),
    (json['longitude'] as num).toDouble(),
  );
}

/// Falha de integração com o fogo-server (rede, timeout ou status).
class FogoApiException implements Exception {
  FogoApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
