/// Nível de risco (mesmos nomes do fogo-server).
enum RiskLevel { baixo, moderado, alto, critico }

/// Contribuição ponderada de cada fator (o que mais pesou no score).
class RiskBreakdown {
  const RiskBreakdown({
    required this.chuva,
    required this.eletricos,
    required this.manutencao,
    required this.falhas,
    required this.viario,
  });

  final double chuva;
  final double eletricos;
  final double manutencao;
  final double falhas;
  final double viario;

  factory RiskBreakdown.fromJson(Map<String, dynamic> json) => RiskBreakdown(
    chuva: (json['chuva'] as num).toDouble(),
    eletricos: (json['eletricos'] as num).toDouble(),
    manutencao: (json['manutencao'] as num).toDouble(),
    falhas: (json['falhas'] as num).toDouble(),
    viario: (json['viario'] as num).toDouble(),
  );

  /// Fatores em ordem decrescente de contribuição ("o que mais pesou").
  List<(String, double)> ranked() => [
    ('Chuva prevista', chuva),
    ('Elétricos (semáforo/radar/câmera)', eletricos),
    ('Manutenção/inativos', manutencao),
    ('Histórico de falhas', falhas),
    ('Densidade viária', viario),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Célula do grid de risco do fogo-server (GET /risk/areas).
class RiskArea {
  const RiskArea({
    required this.id,
    required this.score,
    required this.level,
    required this.centroidLatitude,
    required this.centroidLongitude,
    required this.bounds,
    required this.breakdown,
  });

  final String id;
  final int score;
  final RiskLevel level;
  final double centroidLatitude;
  final double centroidLongitude;

  /// bounds: [minLat, minLng, maxLat, maxLng] (graus).
  final List<double> bounds;
  final RiskBreakdown breakdown;

  factory RiskArea.fromJson(Map<String, dynamic> json) {
    final centroid = json['centroid'] as Map<String, dynamic>;
    return RiskArea(
      id: json['id'] as String,
      score: (json['score'] as num).toInt(),
      level: RiskLevel.values.byName(json['level'] as String),
      centroidLatitude: (centroid['latitude'] as num).toDouble(),
      centroidLongitude: (centroid['longitude'] as num).toDouble(),
      bounds: [
        for (final v in json['bounds'] as List<dynamic>) (v as num).toDouble(),
      ],
      breakdown: RiskBreakdown.fromJson(
        json['breakdown'] as Map<String, dynamic>,
      ),
    );
  }
}
