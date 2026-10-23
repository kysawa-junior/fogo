part of 'route_service.dart';

/// OSRM sobre a malha real (dados © OpenStreetMap).
/// shortcut: servidor público de demonstração sem SLA — para produção
/// aponte OSRM_BASE_URL para instância própria (variável de ambiente).
class OsrmRouteService implements RouteService {
  OsrmRouteService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'OSRM_BASE_URL',
            defaultValue: 'https://router.project-osrm.org',
          );

  final http.Client _client;
  final String baseUrl;

  static const int maxStops = 16;

  String _coordString(List<LatLng> points) =>
      points.map((p) => '${p.longitude},${p.latitude}').join(';');

  @override
  Future<RoadRoute> route(List<LatLng> orderedStops) async {
    if (orderedStops.length < 2) {
      throw const RouteServiceException('Rota requer ao menos 2 pontos.');
    }
    if (orderedStops.length > maxStops) {
      throw const RouteServiceException('Máximo de $maxStops paradas.');
    }
    final http.Response res = await _get(
      '/route/v1/driving/${_coordString(orderedStops)}'
      '?overview=full&geometries=geojson',
    );
    final Map<String, dynamic> body = _parseOk(res);
    final Map<String, dynamic> route = (body['routes'] as List).first;
    final List legs = route['legs'] as List;
    return RoadRoute(
      geometry: [
        for (final c
            in (route['geometry'] as Map<String, dynamic>)['coordinates']
                as List)
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ],
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      legDistances: [
        for (final leg in legs) (leg['distance'] as num).toDouble(),
      ],
    );
  }

  @override
  Future<RoadDistanceMatrix> matrix(List<LatLng> points) async {
    if (points.length < 2) {
      throw const RouteServiceException('Matriz requer ao menos 2 pontos.');
    }
    if (points.length > maxStops) {
      throw const RouteServiceException('Máximo de $maxStops paradas.');
    }
    final http.Response res = await _get(
      '/table/v1/driving/${_coordString(points)}?annotations=distance',
    );
    final Map<String, dynamic> body = _parseOk(res);
    final List<dynamic> raw = (body['distances'] as List?) ?? const [];
    if (raw.length != points.length) {
      throw const RouteServiceException('Resposta da matriz incompleta.');
    }
    return RoadDistanceMatrix([
      for (final dynamic row in raw)
        [for (final dynamic v in row as List) (v as num).toDouble()],
    ]);
  }

  Future<http.Response> _get(String path) async {
    final http.Response res;
    try {
      res = await _client
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw RouteServiceException('Serviço de roteamento inacessível: $e');
    }
    return res;
  }

  Map<String, dynamic> _parseOk(http.Response res) {
    if (res.statusCode != 200) {
      throw RouteServiceException(
        'Serviço de roteamento respondeu ${res.statusCode}.',
      );
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const RouteServiceException('Resposta inválida do serviço.');
    }
    if (body['code'] != 'Ok') {
      throw RouteServiceException(
        'Serviço de roteamento: ${body['code'] ?? body['message'] ?? 'erro'}',
      );
    }
    return body;
  }
}
