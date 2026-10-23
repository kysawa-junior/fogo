/// Map 3D page library: the workspace page lives here; source panel,
/// selection panel and status chip live in sibling `part` files.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_spinner.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../../engine/fogo_engine.dart';
import '../../../data/geocoding_service.dart' show GeoSearchResult;
import '../../../domain/map_selection.dart' show FeatureSelection;
import '../../../providers/map_engine_providers.dart';
import '../../render/flutter_scene_adapter.dart';
import '../../render/fogo_scene_view.dart';
import '../../selection_details.dart';
import '../../widgets/search_results_panel/search_results_panel.dart';
import '../../widgets/top_bar/top_bar.dart';

part 'map3d_source_panel.dart';
part 'map3d_selection_panel.dart';

/// Central de Operações 3D — F.O.G.O. Engine: arquivo OSM XML →
/// entidades cartográficas → geometria → Flutter Scene → viewport
/// interativo (MVVM: estado no [MapEngineNotifier], view só renderiza).
class Map3dPage extends ConsumerStatefulWidget {
  const Map3dPage({super.key});

  @override
  ConsumerState<Map3dPage> createState() => _Map3dPageState();
}

class _Map3dPageState extends ConsumerState<Map3dPage> {
  late final FlutterSceneAdapter _adapter = FlutterSceneAdapter();
  final OrbitCamera _camera = OrbitCamera();

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      mapEngineProvider.select((s) => s.engineVersion),
      (_, _) => _uploadScene(),
    );
    ref.listenManual(
      mapEngineProvider.select((s) => s.fitCameraTick),
      (_, _) => _fitCamera(),
    );
    ref.listenManual(
      mapEngineProvider.select((s) => s.focusTick),
      (_, _) => _focusRequest(),
    );
    ref.listenManual(
      mapEngineProvider.select((s) => s.selection),
      (prev, next) => _updateHighlight(prev, next),
    );
  }

  void _uploadScene() {
    final engine = ref.read(mapEngineProvider.notifier).engine;
    if (engine == null) return;
    _adapter.uploadScene(engine.scene);
    setState(() {});
  }

  void _fitCamera() {
    final engine = ref.read(mapEngineProvider.notifier).engine;
    if (engine == null) return;
    _camera
      ..setTargetBounds(engine.scene.worldBounds)
      ..fit(engine.scene.worldBounds);
  }

  void _focusRequest() {
    final state = ref.read(mapEngineProvider);
    final engine = ref.read(mapEngineProvider.notifier).engine;
    final lat = state.focusLat;
    final lng = state.focusLng;
    if (lat == null || lng == null || engine == null) return;
    _camera.target = engine.projector.project(GeoCoordinate(lat, lng)).clone();
    _camera.distanceMeters = _camera.distanceMeters.clamp(
      400,
      _camera.maxDistance,
    );
  }

  void _updateHighlight(dynamic prev, dynamic next) {
    final prevId = prev is FeatureSelection ? prev.entityId : null;
    final nextId = next is FeatureSelection ? next.entityId : null;
    if (prevId == nextId) return;
    if (prevId != null) _adapter.setEntityColor(prevId, null);
    if (nextId != null) {
      _adapter.setEntityColor(nextId, FogoPalette.selection);
    }
    setState(() {});
  }

  Future<void> _importOsmFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'OSM XML', extensions: ['osm', 'osm.gz', 'gz']),
      ],
    );
    if (file == null) return;
    await ref.read(mapEngineProvider.notifier).importFile(file.path);
  }

  void _selectSearchResult(GeoSearchResult result) {
    ref
        .read(mapEngineProvider.notifier)
        .focusGeoPoint(result.point.latitude, result.point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapEngineProvider);
    final bool loading = state.phase is MapLoading;

    return Container(
      color: FogoColors.bg,
      child: Stack(
        children: [
          // Viewport 3D — interações chegam aqui e vão para o ViewModel.
          Positioned.fill(
            child: FogoSceneView(
              key: ValueKey(_adapter.sceneVersion),
              adapter: _adapter,
              camera: _camera,
              enabled: !loading,
              onEntityPicked: (entityId) =>
                  ref.read(mapEngineProvider.notifier).selectEntity(entityId),
            ),
          ),
          // Barra superior: módulos, busca real, status da base.
          TopBar(
            activeModule: FogoModule.operations,
            engineState: state,
            onSelectResult: _selectSearchResult,
          ),
          // Painel de fontes (cidades do catálogo + importar .osm).
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FogoSpacing.md,
                FogoSpacing.topBarHeight + FogoSpacing.md,
                0,
                0,
              ),
              child: _SourcePanel(onImport: _importOsmFile),
            ),
          ),
          // Resultados da busca geográfica.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                top: FogoSpacing.topBarHeight + FogoSpacing.md,
              ),
              child: SearchResultsPanel(onSelect: _selectSearchResult),
            ),
          ),
          // Painel de seleção (propriedades da entidade).
          if (state.selection is FeatureSelection)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  FogoSpacing.topBarHeight + FogoSpacing.md,
                  FogoSpacing.md,
                  0,
                ),
                child: _SelectionPanel(details: state.details),
              ),
            ),
          // Barra inferior: atribuição OSM + estatísticas + dica de câmera.
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomBar(state: state),
          ),
        ],
      ),
    );
  }
}

/// Rodapé: estatísticas da base carregada, atribuição obrigatória do OSM
/// e dicas de câmera.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.state});

  final MapEngineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = state.stats;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: FogoSpacing.md,
        vertical: FogoSpacing.xs,
      ),
      decoration: const BoxDecoration(color: FogoColors.overlayFaint),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Dados cartográficos © OpenStreetMap contributors',
              style: const TextStyle(
                fontSize: 10,
                color: FogoColors.textSecondary,
              ),
            ),
          ),
          if (stats != null)
            Text(
              '${stats.roadCount} vias · ${stats.buildingCount} edifícios · '
              '${stats.crossingCount} travessias · ${stats.signalCount} '
              'semáforos · ${stats.triangleCount} triângulos'
              '${stats.issueCount > 0 ? ' · ${stats.issueCount} avisos' : ''}',
              style: const TextStyle(
                fontSize: 10,
                color: FogoColors.textSecondary,
              ),
            ),
          const SizedBox(width: FogoSpacing.md),
          const Text(
            'Arraste: orbitar · Direito: mover · Rolagem: zoom · Clique: selecionar',
            style: TextStyle(fontSize: 10, color: FogoColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
