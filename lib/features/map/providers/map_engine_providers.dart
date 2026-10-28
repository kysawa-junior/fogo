import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/fogo_engine.dart';
import '../../../engine/scene/visual_style.dart';
import '../domain/map_selection.dart';
import '../application/load_map_use_case.dart';
import '../presentation/render/map_icons.dart';
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
    this.lightingMode = SceneLightingMode.night,
    this.focusDistanceMeters,
    this.uploadProgress = 0,
    this.sceneReady = false,
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

  /// ETAPA 07: modo de iluminação ativo (noturno/diurno).
  final SceneLightingMode lightingMode;

  /// Distância de câmera desejada no próximo foco ([focusTick]); null =
  /// manter a distância atual (foco por busca). Foco por cidade define
  /// a distância para enquadrar a caixa urbana inteira.
  final double? focusDistanceMeters;

  /// Progresso do upload da cena ao renderer (0..1), reportado pela
  /// view durante o upload fatiado.
  final double uploadProgress;

  /// Cena 3D completa enviada ao renderer (parse + geometria + ícones
  /// — semáforos, POIs, radares — já anexados). Torna-se true após o
  /// upload fatiado terminar.
  final bool sceneReady;

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
    SceneLightingMode? lightingMode,
    double? focusDistanceMeters,
    bool clearFocusDistance = false,
    double? uploadProgress,
    bool? sceneReady,
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
    // ENG-0008 (correção de 1 linha): lightingMode era aceito no
    // copyWith e silenciosamente descartado — toggles voltavam sempre
    // ao noturno. Agora propaga.
    lightingMode: lightingMode ?? this.lightingMode,
    focusDistanceMeters: clearFocusDistance
        ? null
        : (focusDistanceMeters ?? this.focusDistanceMeters),
    uploadProgress: uploadProgress ?? this.uploadProgress,
    sceneReady: sceneReady ?? this.sceneReady,
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

  /// Carrega a base regional única (extrato OSM com as três cidades +
  /// corredor, empacotado como asset).
  Future<void> loadRegion() => _load(
    ({onProgress}) => _useCase.loadAsset(
      RegionCatalog.regionOsmAssetPath,
      onProgress: onProgress,
    ),
    activeCityId: 'regiao',
    label: 'Região · Marília · Vera Cruz · Garça',
  );

  /// Importa um arquivo `.osm`/`.osm.gz` escolhido pelo usuário.
  Future<void> importFile(String path) => _load(
    ({onProgress}) => _useCase.loadFile(path, onProgress: onProgress),
    activeCityId: '',
    label: path.split(Platform.pathSeparator).last,
  );

  Future<void> _load(
    Future<FogoEngine?> Function({void Function(String, int)? onProgress})
    run, {
    required String activeCityId,
    required String label,
  }) async {
    state = state.copyWith(
      phase: MapLoading(label, 0),
      activeCityId: activeCityId,
      sourceLabel: label,
      selection: const NoSelection(),
      clearDetails: true,
      sceneReady: false,
      uploadProgress: 0,
    );
    try {
      final result = await run(
        onProgress: (phase, count) {
          // Progresso do pipeline no isolate (fases de parse).
          if (state.phase is MapLoading) {
            state = state.copyWith(phase: MapLoading(label, count));
          }
        },
      );
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

  /// Progresso do upload fatiado da cena (0..1), reportado pela view.
  void reportUploadProgress(double progress) {
    state = state.copyWith(uploadProgress: progress);
  }

  /// Cena 3D + ícones (semáforos, POIs, radares, viaturas de cena)
  /// anexados e enviados ao renderer — carregamento completo.
  void markSceneReady() {
    state = state.copyWith(sceneReady: true);
  }

  /// Centraliza a câmera em cima de uma cidade do catálogo: alvo no
  /// centro da caixa urbana e distância para enquadrá-la inteira.
  void focusCity(MapCity city) {
    final projector = engine?.projector;
    if (projector == null) return;
    final b = city.bounds;
    final a = projector.project(GeoCoordinate(b.south, b.west));
    final c = projector.project(GeoCoordinate(b.north, b.east));
    final diag = Vector3(c.x - a.x, 0, c.z - a.z).length;
    state = state.copyWith(
      focusLat: (b.south + b.north) / 2,
      focusLng: (b.west + b.east) / 2,
      focusDistanceMeters: diag * 1.15,
      focusTick: state.focusTick + 1,
      activeCityId: city.id,
    );
  }

  /// Reenquadra a base regional inteira (botão "Região" do navegador).
  void activateRegion() {
    state = state.copyWith(activeCityId: 'regiao');
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

  /// Ícone de dispositivo demo (viatura/radar/câmera) tocado na base
  /// 2D: card próprio no MESMO painel de detalhes da seleção.
  /// Ícone tocado na base 2D: semáforo usa a seleção REAL da feature
  /// (mesmo card do raycast 3D); dispositivos/viaturas recebem card
  /// próprio pelo mesmo painel de detalhes.
  void showDeviceDetails(MapIcon icon) {
    final isVehicle = icon.id.startsWith('vehicle/');
    state = state.copyWith(
      selection: FeatureSelection(icon.id),
      details: EntityDetails(
        title: icon.kind.label,
        subtitle:
            '${isVehicle ? 'Viatura em serviço' : 'Equipamento'} — ${icon.id}',
        properties: [
          ('Tipo', icon.kind.label),
          ('ID', icon.id),
          (
            'Status',
            isVehicle ? 'Em serviço (simulação)' : 'Operacional (demo)',
          ),
        ],
      ),
    );
  }

  /// ETAPA 07: alterna noturno ↔ diurno. A view aplica o modo no
  /// adapter e reconstrói a cena.
  void toggleLightingMode() {
    final next = state.lightingMode == SceneLightingMode.night
        ? SceneLightingMode.day
        : SceneLightingMode.night;
    state = state.copyWith(lightingMode: next);
  }

  void clearSelection() {
    state = state.copyWith(selection: const NoSelection(), clearDetails: true);
  }

  /// Foco geográfico (resultado de busca): a view move o alvo da câmera,
  /// mantendo a distância atual (limpa distância fixada por cidade).
  void focusGeoPoint(double lat, double lng) {
    state = state.copyWith(
      focusLat: lat,
      focusLng: lng,
      clearFocusDistance: true,
      focusTick: state.focusTick + 1,
    );
  }
}

final mapEngineProvider = NotifierProvider<MapEngineNotifier, MapEngineState>(
  MapEngineNotifier.new,
);
