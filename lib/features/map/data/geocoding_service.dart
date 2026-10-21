import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeoSearchResult {
  const GeoSearchResult({
    required this.label,
    required this.sublabel,
    required this.point,
  });

  final String label;
  final String sublabel;
  final LatLng point;
}

/// Busca geográfica real via Nominatim (OSM).
/// shortcut: serviço público com política de uso leve (debounce na UI);
/// para produção usar instância própria/planilha de provedor.
class GeocodingService {
  GeocodingService({http.Client? client, this.userAgent = 'fogo-desktop-dev'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String userAgent;

  static const String _base = 'https://nominatim.openstreetmap.org';

  Future<List<GeoSearchResult>> search(String query) async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse(
              '$_base/search?q=${Uri.encodeQueryComponent(query)}'
              '&format=jsonv2&limit=8&accept-language=pt-BR'
              // viés regional (não restrito): prioriza a área das operações
              '&viewbox=-50.04,-22.13,-49.59,-22.31&bounded=0',
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw GeocodingException('Serviço de busca inacessível: $e');
    }
    if (res.statusCode != 200) {
      throw GeocodingException('Serviço de busca respondeu ${res.statusCode}.');
    }
    final List<dynamic> body;
    try {
      body = jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      throw const GeocodingException('Resposta inválida da busca.');
    }
    return [
      for (final dynamic item in body)
        GeoSearchResult(
          label:
              (item as Map<String, dynamic>)['display_name'] as String? ?? '',
          sublabel: '${item['category'] ?? ''}/${item['type'] ?? ''}',
          point: LatLng(
            double.parse(item['lat'] as String),
            double.parse(item['lon'] as String),
          ),
        ),
    ];
  }
}

final geocodingServiceProvider = Provider<GeocodingService>(
  (ref) => GeocodingService(),
);
