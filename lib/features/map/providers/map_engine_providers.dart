import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/fogo_engine.dart';
import '../domain/map_selection.dart';
import '../application/load_map_use_case.dart';
import '../presentation/selection_details.dart';

/// Fases do pipeline de carga do mapa 3D.
sealed class MapLoadPhase {
  const MapLoadPhase();
}

class MapIdle extends MapLoadPhase {
  const MapIdle();
}

class MapLoading extends MapLoadPhase {
  const MapLoading(this.label, this.count);

  final String label;
  final int count;
}

class MapReady extends MapLoadPhase {
  const MapReady();
}

class MapError extends MapLoadPhase {
  const MapError(this.message);

  final String message;
}

/// Estado do motor exposto à UI (MVVM): o [FogoEngine] pesado fica no
/// notifier (não no estado serializável); a UI o consulta por provider.
class MapEngineState {
  const MapEngineState({
    this.phase = const MapIdle(),
    this.activeCityId = '',
    this.sourceLabel = '',
    this.stats,
    this.selection = const NoSelection(),
    this.details,
    this.engineVersion = 0,
    this.fitCameraTick = 0,
    this.focusTick = 0,
    this.focusLat,
    this.focusLng,
    this.issues = const [],
  });

  final MapLoadPhase phase;
  final String activeCityId;
  final String sourceLabel;
  final FogoEngineStats? stats;
  final MapSelection selection;
  final EntityDetails? details;

  /// Incrementa a cada carga: a view faz upload da nova cena.
  final int engineVersion;

  /// Incrementa após carga: a view enquadra a região carregada.
  final int fitCameraTick;

  /// Incrementa quando um resultado de busca pede foco geográfico.
  final int focusTick;
  final double? focusLat;
  final double? focusLng;

  /// Primeiros problemas de importação (não fatais).
  final List<String> issues;

  MapEngineState copyWith({
    MapLoadPhase? phase,
    String? activeCityId,
    String? sourceLabel,
    FogoEngineStats? stats,
    MapSelection? selection,
    EntityDetails? details,
    bool clearDetails = false,
    int? engineVersion,
    int? fitCameraTick,
    int? focusTick,
    double? focusLat,
    double? focusLng,
    List<String>? issues,
  }) => MapEngineState(
    phase: phase ?? this.phase,
    activeCityId: activeCityId ?? this.activeCityId,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    stats: stats ?? this.stats,
    selection: selection ?? this.selection,
    details: clearDetails ? null : (details ?? this.details),
    engineVersion: engineVersion ?? this.engineVersion,
    fitCameraTick: fitCameraTick ?? this.fitCameraTick,
    focusTick: focusTick ?? this.focusTick,
    focusLat: focusLat ?? this.focusLat,
    focusLng: focusLng ?? this.focusLng,
    issues: issues ?? this.issues,
  );
}

/// ViewModel do mapa 3D (Riverpod Notifier — mesmo padrão do projeto).
/// Coordena importação, progresso, erros, seleção e configurações;
/// parsing/triangulação/malhas ficam no motor, nunca aqui.
class MapEngineNotifier extends Notifier<MapEngineState> {
  final LoadMapUseCase _useCase = LoadMapUseCase();
  FogoEngine? engine;

  @override
  MapEngineState build() => const MapEngineState();

  /// Carrega uma cidade do catálogo regional (asset empacotado).
  Future<void> loadCity(MapCity city) => _load(
    () => _useCase.loadAsset(city.osmAssetPath!),
    activeCityId: city.id,
    label: city.name,
  );

  /// Importa um arquivo `.osm`/`.osm.gz` escolhido pelo usuário.
  Future<void> importFile(String path) => _load(
    () => _useCase.loadFile(path),
    activeCityId: '',
    label: path.split(Platform.pathSeparator).last,
  );

  Future<void> _load(
    Future<FogoEngine?> Function() run, {
    required String activeCityId,
    required String label,
  }) async {
    state = state.copyWith(
      phase: MapLoading(label, 0),
      activeCityId: activeCityId,
      sourceLabel: label,
      selection: const NoSelection(),
      clearDetails: true,
    );
    try {
      final result = await run();
      if (result == null) {
        // Cancelado pelo usuário: volta ao estado anterior.
        state = state.copyWith(phase: const MapIdle());
        return;
      }
      engine = result;
      state = state.copyWith(
        phase: const MapReady(),
        stats: result.stats,
        engineVersion: state.engineVersion + 1,
        fitCameraTick: state.fitCameraTick + 1,
        issues: result.issues
            .take(5)
            .map(
              (i) => i.elementId == null
                  ? i.message
                  : '${i.elementId}: ${i.message}',
            )
            .toList(),
      );
    } catch (error) {
      state = state.copyWith(phase: MapError('Falha ao importar: $error'));
    }
  }

  /// Cancela a importação em andamento.
  void cancelLoad() {
    _useCase.cancel();
    state = state.copyWith(phase: const MapIdle());
  }

  /// Seleciona uma entidade por id (vinda do raycast do backend).
  void selectEntity(String entityId) {
    final feature = engine?.model.byId(entityId);
    if (feature == null) return;
    state = state.copyWith(
      selection: FeatureSelection(entityId),
      details: buildEntityDetails(feature),
    );
  }

  void clearSelection() {
    state = state.copyWith(selection: const NoSelection(), clearDetails: true);
  }

  /// Foco geográfico (resultado de busca): a view move o alvo da câmera.
  void focusGeoPoint(double lat, double lng) {
    state = state.copyWith(
      focusLat: lat,
      focusLng: lng,
      focusTick: state.focusTick + 1,
    );
  }
}

final mapEngineProvider = NotifierProvider<MapEngineNotifier, MapEngineState>(
  MapEngineNotifier.new,
);
