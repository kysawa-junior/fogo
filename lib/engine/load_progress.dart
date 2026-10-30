/// Progresso real da carga do mapa — fração global 0..1.
///
/// A fração global = peso das fases já concluídas + peso da fase atual ×
/// fração interna da fase. DENTRO da fase o progresso é trabalho real
/// (itens processados / total); o peso de cada fase é a MEDIÇÃO do custo
/// real dela no pipeline (release nativo, regiao.osm.gz: ~22 s).
library;

/// Callback de progresso: fase, contagem de itens e fração global (0..1).
typedef LoadProgressCallback = void Function(
  String phase,
  int count,
  double fraction,
);

/// Peso de cada fase do pipeline na fração global (soma = 1).
///
/// Medido no pipeline real (regiao.osm.gz, release nativo, ~22 s):
/// parse 1,7 s · elementos 0,15 s · dedupe 0,02 s · topologia 0,04 s ·
/// frota 0,001 s · geometria 3D 3,0 s · vegetação 13,0 s · junções 1,6 s ·
/// particionamento 2,2 s.
const Map<String, double> kLoadPhaseWeight = <String, double>{
  'Interpretando OSM': 0.076,
  'Interpretando elementos': 0.007,
  'Deduplicando vias': 0.001,
  'Construindo topologia': 0.002,
  'Simulando viaturas': 0.001,
  'Gerando geometria 3D': 0.132,
  'Gerando vegetação': 0.6,
  'Gerando junções': 0.072,
  'Particionando espacialmente': 0.109,
};

/// Emite o progresso global do pipeline de carga.
class LoadProgress {
  LoadProgress([this.onProgress]);

  final LoadProgressCallback? onProgress;

  String _phase = '';
  double _weight = 0;
  double _done = 0;
  double _last = -1;

  /// Abre uma fase: credita o peso da fase anterior.
  void begin(String phase, {int count = 0}) {
    _done += _weight;
    _phase = phase;
    _weight = kLoadPhaseWeight[phase] ?? 0;
    _last = _done;
    onProgress?.call(phase, count, _done.clamp(0.0, 1.0).toDouble());
  }

  /// Progresso dentro da fase: [ratio] = trabalho real da fase (0..1).
  void step(int count, double ratio) {
    final double r = ratio.clamp(0.0, 1.0).toDouble();
    final double fraction = (_done + _weight * r).clamp(0.0, 1.0).toDouble();
    // No máximo uma msg a cada 0,2% — o isolate não leva milhares.
    if (r < 1 && fraction - _last < 0.002) return;
    _last = fraction;
    onProgress?.call(_phase, count, fraction);
  }

  /// Fim do pipeline: fração 1.
  void finish(int count) {
    _done += _weight;
    _last = 1;
    onProgress?.call(_phase, count, 1.0);
  }
}
