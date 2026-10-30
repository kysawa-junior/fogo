/// Map 3D page library: the workspace page lives here; source panel,
/// selection panel and status chip live in sibling `part` files.
library;

import 'package:file_selector/file_selector.dart';

import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../../core/design_system/widgets/fogo_glass.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_text_field.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../../engine/fogo_engine.dart';
import '../../../../inventory/presentation/pages/inventory_page/inventory_page.dart';
import '../../../../predictive_city/domain/risk_area.dart';
import '../../../../predictive_city/providers/predictive_providers.dart';
import '../../../data/geocoding_service.dart' show GeoSearchResult;
import '../../../domain/map_selection.dart' show FeatureSelection;
import '../../../providers/map_engine_providers.dart';
import '../../../providers/search_provider.dart';
import '../../render/flutter_scene_adapter.dart';
import '../../render/fogo_scene_view.dart';
import '../../render/label_candidates.dart';
import '../../render/map_2d/map_2d_renderer.dart'
    show HeatCell, Map2DRenderer, heatColor;
import '../../render/map_2d/map_2d_view.dart';
import '../../render/map_icons.dart';
import '../../render/scene_overlay.dart';
import '../../selection_details.dart';
import '../../widgets/search_results_panel/search_results_panel.dart';
import '../../widgets/top_bar/top_bar.dart';

part 'map3d_selection_panel.dart';
part 'map3d_predictive_panel.dart';
part 'map3d_icon_filter.dart';

/// Largura do rail de módulos (botão 30px + 2×5px de padding).
const double _kNavRailWidth = 40;

/// Espaço mínimo entre o rail de módulos e o card flutuante do inventário.
const double _kInventoryCardGap = 60;

/// Central de Operações 3D — F.O.G.O. Engine: arquivo OSM XML →
/// entidades cartográficas → geometria → Flutter Scene → viewport
/// interativo (MVVM: estado no [MapEngineNotifier], view só renderiza).
class Map3dPage extends ConsumerStatefulWidget {
  const Map3dPage({super.key, this.initialInventoryOpen = false});

  /// Abre o card flutuante do inventário já no carregamento (rota
  /// '/inventory' — deep link entra no workspace com o modal aberto).
  final bool initialInventoryOpen;

  @override
  ConsumerState<Map3dPage> createState() => _Map3dPageState();
}

class _Map3dPageState extends ConsumerState<Map3dPage> {
  late final FlutterSceneAdapter _adapter = FlutterSceneAdapter();
  List<LabelCandidate> _labelCandidates = const [];
  List<MapIcon> _mapIcons = const [];
  // Nasce AFASTADO (maxDistance): visão geral 2D limpa — a camada 3D
  // surge progressivamente quando o usuário aproxima.
  final OrbitCamera _camera = OrbitCamera(distanceMeters: 25000);

  /// Opacidade corrente da camada 3D sobre a base 2D permanente
  /// (escrita pelo ticker do [_SceneOverlayLayer], lida pelo Map2DView
  /// para suprimir repaint quando o 3D cobre a tela).
  final ValueNotifier<double> _sceneOverlay = ValueNotifier(0.0);

  /// Células do heatmap (cache: só re-projeta quando a lista de áreas
  /// muda — identidade da instância vinda do FutureProvider).
  List<RiskArea> _heatSource = const [];
  List<HeatCell> _heatCache = const [];

  /// Área selecionada no modo Cidade Preditiva (id da célula).
  String? _selectedRiskAreaId;

  /// Inventário aberto como card flutuante (modal) sobre o mapa.
  bool _inventoryOpen = false;

  void _toggleInventory() => setState(() => _inventoryOpen = !_inventoryOpen);

  void _closeInventory() => setState(() => _inventoryOpen = false);

  /// Projeta os bounds (graus) de cada área para o plano x/z do motor.
  List<HeatCell> _heatCellsFor(List<RiskArea> areas, FogoEngine engine) {
    if (identical(areas, _heatSource)) return _heatCache;
    final projector = engine.projector;
    final cells = <HeatCell>[];
    for (final area in areas) {
      final b = area.bounds;
      // bounds: [minLat, minLng, maxLat, maxLng].
      final sw = projector.project(GeoCoordinate(b[0], b[1]));
      final ne = projector.project(GeoCoordinate(b[2], b[3]));
      cells.add(
        HeatCell(
          areaId: area.id,
          color: heatColor(area.score),
          rect: Rect.fromLTRB(
            sw.x <= ne.x ? sw.x : ne.x,
            sw.z <= ne.z ? sw.z : ne.z,
            sw.x <= ne.x ? ne.x : sw.x,
            sw.z <= ne.z ? ne.z : sw.z,
          ),
        ),
      );
    }
    _heatSource = areas;
    _heatCache = cells;
    return cells;
  }

  @override
  void initState() {
    super.initState();
    _inventoryOpen = widget.initialInventoryOpen;
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
    // ETAPA 07: troca de modo de iluminação → adapter + re-upload.
    ref.listenManual(mapEngineProvider.select((s) => s.lightingMode), (
      _,
      mode,
    ) {
      _adapter.lightingMode = mode;
      _uploadScene();
    });
    // Carrega automaticamente a base regional única (3 cidades +
    // corredor). O define FOGO_AUTO_CITY (smoke OSM de CI) não é mais
    // necessário: a base padrão é sempre a região inteira.
    //
    // Startup multi-window (desktop): a carga JÁ foi feita pelo
    // BootCoordinator (a janela nasce oculta e não tem frames) — aqui
    // só falta enviar a cena ao renderer e enquadrar a câmera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(mapEngineProvider);
      if (state.phase is MapReady) {
        // O boot pode ter carregado o mapa ANTES do primeiro frame da
        // página: nesse caso o listener de engineVersion já enviou a
        // cena — não envia de novo (cada upload recria os nodes).
        if (state.engineVersion != _uploadedEngineVersion) {
          _uploadScene();
          _fitCamera();
        }
        return;
      }
      if (state.phase is MapIdle) {
        ref.read(mapEngineProvider.notifier).loadRegion();
      }
    });
  }

  /// Versão da cena já enviada ao renderer (-1 = nenhuma).
  int _uploadedEngineVersion = -1;

  void _uploadScene() {
    final engine = ref.read(mapEngineProvider.notifier).engine;
    if (engine == null) return;
    _uploadedEngineVersion = ref.read(mapEngineProvider).engineVersion;
    // Rótulos vêm do MODELO (não da cena 3D): prontos antes do upload —
    // o modo 2D exibido imediatamente já os tem. Ícones 2D idem.
    _labelCandidates = extractLabelCandidates(engine);
    _mapIcons = extractMapIcons(engine);
    if (mounted) setState(() {});
    // Upload fatiado ao renderer: mantém a UI fluida e reporta o
    // progresso ao overlay. Ícones (semáforos, POIs, radares) fazem
    // parte da cena — prontos quando o upload termina.
    _uploadSceneAsync(engine);
  }

  /// Toque num ícone da base 2D: semáforo usa a seleção REAL da feature
  /// (mesmo card do raycast 3D); dispositivos demo recebem card próprio
  /// pelo mesmo painel de detalhes.
  void _onIconTap(MapIcon icon) {
    final notifier = ref.read(mapEngineProvider.notifier);
    if (icon.kind == MapIconKind.signal) {
      notifier.selectEntity(icon.id);
    } else {
      notifier.showDeviceDetails(icon);
    }
  }

  Future<void> _uploadSceneAsync(FogoEngine engine) async {
    final notifier = ref.read(mapEngineProvider.notifier);
    await _adapter.uploadScene(
      engine.scene,
      onProgress: notifier.reportUploadProgress,
    );
    // ENG-0008: cada upload cria nodes NOVOS — re-aplica o destaque da
    // seleção atual.
    final selection = ref.read(mapEngineProvider).selection;
    if (selection is FeatureSelection) {
      _adapter.setEntityColor(selection.entityId, FogoPalette.selection);
    }
    notifier.markSceneReady();
    // Viaturas: nós dinâmicos anexados à cena já carregada (o fleet
    // vive no engine; o tick é do Map2DView, a aplicação é daqui).
    // Async: carrega os glTF de assets/vehicles — syncVehicles aplica
    // as transformações quando os nós existirem.
    unawaited(_adapter.attachVehicles(engine.vehicles));
    // DIAGNÓSTICO (FOGO_VEHICLE_CAM=1): congela a frota e aponta a
    // câmera para a viatura 0 — cena estática para screenshot.
    if (Platform.environment['FOGO_VEHICLE_CAM'] == '1') {
      final v0 = engine.vehicles.vehicles.first;
      engine.vehicles.frozen = true;
      _camera
        ..goalTarget = Vector3(v0.x, 0, v0.z)
        ..goalAzimuth = 0.7
        ..goalElevation = 0.55
        ..goalDistance = 80;
      debugPrint('FOGO_VEHICLE_CAM: alvo=viatura0 (${v0.x}, ${v0.z})');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sceneOverlay.dispose();
    super.dispose();
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
    // Metas da câmera (não valores atuais): o amortecimento anima o
    // voo até o foco — e o alvo não volta atrás no próximo tick.
    final p = engine.projector.project(GeoCoordinate(lat, lng));
    _camera.goalTarget = p.clone();
    final distance = state.focusDistanceMeters;
    if (distance != null) {
      _camera.goalDistance = distance.clamp(
        _camera.minDistance,
        _camera.maxDistance,
      );
    }
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

  /// Enquadra a entidade selecionada usando seus limites espaciais
  /// reais (o motor calcula; a câmera ajusta alvo/distância sem
  /// atravessar o terreno).
  void _frameSelection() {
    final state = ref.read(mapEngineProvider);
    final selection = state.selection;
    if (selection is! FeatureSelection) return;
    final engine = ref.read(mapEngineProvider.notifier).engine;
    final bounds = engine?.boundsOf(selection.entityId);
    if (bounds == null) return;
    _camera.frameBounds(bounds);
  }

  /// Visão padrão: reenquadra toda a região carregada.
  void _frameRegion() {
    final engine = ref.read(mapEngineProvider.notifier).engine;
    final bounds = engine?.scene.worldBounds;
    if (bounds == null) return;
    _camera.fit(bounds);
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
    // Boot: a base 2D é exibida assim que o motor (modelo) fica pronto
    // — o upload da cena 3D continua em background e só é exigido para
    // mostrar a camada 3D (zoom próximo).
    final bool appVisible = state.phase is MapReady;
    final engine = ref.read(mapEngineProvider.notifier).engine;
    // Cidade Preditiva: alterna a CAMADA (ícones ↔ heatmap) sem tocar a
    // câmera. O 3D é forçado a 0 (heatmap vive na base 2D).
    final predictive = ref.watch(predictiveModeProvider);
    final iconKinds = ref.watch(mapIconFilterProvider);
    List<HeatCell> heatCells = const [];
    List<RiskArea> riskAreas = const [];
    if (predictive && engine != null) {
      riskAreas = ref.watch(riskAreasProvider).value ?? const [];
      heatCells = _heatCellsFor(riskAreas, engine);
    }

    return Container(
      color: FogoColors.bg,
      child: Stack(
        children: [
          if (appVisible) ...[
            // BASE 2D PERMANENTE embaixo (nunca desliga) + camada 3D
            // DINÂMICA por cima: a opacidade do overlay é dirigida pela
            // distância da câmera ([SceneOverlayOpacity]) — sem troca de
            // modo, sem resolução dentro do paint.
            if (engine != null)
              Positioned.fill(
                child: Map2DView(
                  engine: engine,
                  camera: _camera,
                  labelCandidates: _labelCandidates,
                  mapIcons: _mapIcons,
                  onIconTap: _onIconTap,
                  overlayOpacity: _sceneOverlay,
                  visibleKinds: predictive ? const <MapIconKind>{} : iconKinds,
                  heat: heatCells,
                  onAreaTap: (cell) =>
                      setState(() => _selectedRiskAreaId = cell.areaId),
                ),
              ),
            Positioned.fill(
              child: _SceneOverlayLayer(
                adapter: _adapter,
                camera: _camera,
                ready: state.sceneReady,
                opacity: _sceneOverlay,
                enabled: !loading,
                force2D: predictive,
                onEntityPicked: (entityId) =>
                    ref.read(mapEngineProvider.notifier).selectEntity(entityId),
              ),
            ),
            // Barra superior: ferramentas e status (abas viraram rail
            // lateral; busca mudou para a barra inferior).
            TopBar(engineState: state, onFrameRegion: _frameRegion),
            // Rail de módulos (base-design.pen tjoxx): coluna de botões
            // quadrados 30×30 à esquerda, verticalmente centrada.
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: FogoSpacing.xl),
                child: _NavRail(
                  inventoryOpen: _inventoryOpen,
                  onToggleInventory: _toggleInventory,
                ),
              ),
            ), // Resultados da busca geográfica.
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
                  child: _SelectionPanel(
                    details: state.details,
                    onFrame: _frameSelection,
                  ),
                ),
              ),
            // Barra Inferior (base-design.pen FSFgf): Stack altura 40 no
            // rodapé — campo de busca ancorado à esquerda (Align) e o
            // Navegador de Cidades exatamente centrado (Center).
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: FogoSpacing.lg),
                child: _BottomBar(
                  onSelectResult: _selectSearchResult,
                  onFrameRegion: _frameRegion,
                ),
              ),
            ),
            // Painel Cidade Preditiva (top-right, no lugar do Card Base
            // Cartográfica): Top 5 áreas + detalhe da área selecionada.
            if (predictive)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top:
                        FogoSpacing.topBarHeight +
                        FogoSpacing.xl +
                        FogoSpacing.xs,
                    right: FogoSpacing.lg,
                  ),
                  child: _PredictivePanel(
                    areas: riskAreas,
                    selectedId: _selectedRiskAreaId,
                    onSelect: (id) => setState(() => _selectedRiskAreaId = id),
                    onClose: () {
                      ref.read(predictiveModeProvider.notifier).set(false);
                      setState(() => _selectedRiskAreaId = null);
                    },
                  ),
                ),
              )
            else
              // Card Base Cartográfica + Filtro de Ícones empilhados no
              // canto superior direito (o filtro fica abaixo do card).
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top:
                        FogoSpacing.topBarHeight +
                        FogoSpacing.xl +
                        FogoSpacing.xs,
                    right: FogoSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _BaseCard(onImport: _importOsmFile),
                      const SizedBox(height: FogoSpacing.md),
                      const _IconFilterBar(),
                    ],
                  ),
                ),
              ),
            // Inventário: CARD FLUTUANTE (modal) sobre o mapa — à frente
            // do rail de módulos e encostado na lateral esquerda
            // (base-design.pen · "Card Flutuante" 1100×600).
            if (_inventoryOpen)
              Positioned.fill(
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (FocusNode node, KeyEvent event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _closeInventory();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Stack(
                    children: [
                      // Overlay do modal: escurece e desfoca o mapa — o
                      // card flutuante é o foco. Clique fora fecha.
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _closeInventory,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 12,
                              sigmaY: 12,
                            ),
                            child: ColoredBox(
                              color: FogoColors.bg.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          // Depois do rail de módulos (esquerda), com folga.
                          padding: const EdgeInsets.only(
                            left:
                                FogoSpacing.xl +
                                _kNavRailWidth +
                                _kInventoryCardGap,
                          ),
                          child: LayoutBuilder(
                            builder: (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) {
                              final double left =
                                  FogoSpacing.xl +
                                  _kNavRailWidth +
                                  _kInventoryCardGap;
                              // Tamanho do .pen (1100×600), encolhido
                              // quando a janela é menor.
                              final double width =
                                  (constraints.maxWidth - left - FogoSpacing.lg)
                                      .clamp(320.0, 1100.0)
                                      .toDouble();
                              final double height = (constraints.maxHeight - 32)
                                  .clamp(320.0, 600.0)
                                  .toDouble();
                              return SizedBox(
                                width: width,
                                height: height,
                                child: InventoryPage(
                                  onClose: _closeInventory,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Camada 3D dinâmica sobre a base 2D: um ticker observador avalia
/// [SceneOverlayOpacity.compute] a cada frame e escreve a opacidade no
/// notifier (a página reconstrói APENAS via [ValueListenableBuilder] —
/// sem setState por frame). Sem cena pronta ([ready] false) a camada
/// fica a 0: nada de cena vazia sobre o 2D durante o upload.
class _SceneOverlayLayer extends StatefulWidget {
  const _SceneOverlayLayer({
    required this.adapter,
    required this.camera,
    required this.ready,
    required this.opacity,
    required this.enabled,
    required this.onEntityPicked,
    this.force2D = false,
  });

  final FlutterSceneAdapter adapter;
  final OrbitCamera camera;
  final bool ready;
  final ValueNotifier<double> opacity;
  final bool enabled;
  final void Function(String entityId) onEntityPicked;

  /// Cidade Preditiva: 3D sempre a 0 (heatmap vive na base 2D).
  final bool force2D;

  @override
  State<_SceneOverlayLayer> createState() => _SceneOverlayLayerState();
}

class _SceneOverlayLayerState extends State<_SceneOverlayLayer>
    with SingleTickerProviderStateMixin {
  // No initState: `late final ... = createTicker(..)` é LAZY — só nasce
  // no primeiro acesso (o dispose), e o ticker nunca tickaria: a
  // opacidade ficaria em 0 para sempre (o 3D nunca apareceria).
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double o = widget.force2D
        ? 0.0
        : widget.ready
        ? SceneOverlayOpacity.compute(widget.camera.distanceMeters)
        : 0.0;
    if ((widget.opacity.value - o).abs() >= 0.002) widget.opacity.value = o;
    // Viaturas 3D só com a camada opaca; na banda do crossfade os
    // ícones 2D assumem (ver adapter.vehiclesVisible).
    widget.adapter.vehiclesVisible = o >= 1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.opacity,
      builder: (context, opacity, _) {
        final bool visible = opacity > 0;
        return Offstage(
          offstage: !visible,
          child: TickerMode(
            // 3D a 0: o ticker do viewport 3D para (não renderiza nada);
            // o AMORTECIMENTO da câmera segue no ticker do Map2DView.
            enabled: visible,
            child: IgnorePointer(
              ignoring: !visible,
              child: Opacity(
                opacity: opacity,
                // Véu da cor do BG atrás da cena: o céu do 3D (a cena
                // limpa TRANSPARENTE por default) não mostra o 2D por
                // baixo. Mesma cor do fundo do 2D — o fade 2D→3D fica
                // imperceptível e, opaco, o 2D congelado some de vez.
                child: ColoredBox(
                  color: FogoColors.bg,
                  child: FogoSceneView(
                    key: ValueKey(widget.adapter.sceneVersion),
                    adapter: widget.adapter,
                    camera: widget.camera,
                    enabled: widget.enabled,
                    onEntityPicked: widget.onEntityPicked,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Card Base Cartográfica (base-design.pen): legenda da base OSM em
/// vidro 240px à direita do mapa. Desvios declarados do .pen: botões
/// de modo de luz e importar .osm no cabeçalho (recursos do app).
class _BaseCard extends ConsumerStatefulWidget {
  const _BaseCard({required this.onImport});

  final Future<void> Function() onImport;

  @override
  ConsumerState<_BaseCard> createState() => _BaseCardState();
}

class _BaseCardState extends ConsumerState<_BaseCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapEngineProvider);
    final bool loading = state.phase is MapLoading;
    final notifier = ref.read(mapEngineProvider.notifier);
    return FogoGlass(
      radius: FogoSpacing.radiusLg,
      fill: FogoColors.surfaceCard,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.map,
                  size: 14,
                  color: FogoColors.textSecondary,
                ),
                const SizedBox(width: FogoSpacing.sm),
                const Expanded(
                  child: Text(
                    'Base Cartográfica',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FogoColors.textPrimary,
                    ),
                  ),
                ),
                // Desvio do .pen: recursos de luz e importação vivem aqui.
                FogoIconButton(
                  icon: state.lightingMode.name == 'day'
                      ? LucideIcons.moon
                      : LucideIcons.sun,
                  onTap: (state.phase is MapReady)
                      ? () => notifier.toggleLightingMode()
                      : null,
                  size: 26,
                  iconSize: 14,
                ),
                const SizedBox(width: FogoSpacing.xs),
                FogoIconButton(
                  icon: LucideIcons.upload,
                  onTap: loading ? null : () => widget.onImport(),
                  size: 26,
                  iconSize: 14,
                ),
                const SizedBox(width: FogoSpacing.xs),
                FogoIconButton(
                  icon: _expanded
                      ? LucideIcons.chevron_up
                      : LucideIcons.chevron_down,
                  onTap: () => setState(() => _expanded = !_expanded),
                  size: 26,
                  iconSize: 14,
                  filled: false,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: FogoSpacing.md),
              const _LegendRow(
                label: 'Vias',
                color: Color(0xFFA9AFC9),
                width: 14,
                height: 4,
              ),
              const _LegendRow(
                label: 'Águas',
                color: Color(0xFF5B8DEF),
                width: 14,
                height: 4,
              ),
              const _LegendRow(
                label: 'Áreas verdes',
                color: Color(0xFF4CAF7D),
                width: 14,
                height: 8,
                radius: 3,
              ),
              const _LegendRow(
                label: 'Edificações',
                color: Color(0xFFC98A5E),
                width: 10,
                height: 10,
              ),
              const SizedBox(height: FogoSpacing.md),
              const Row(
                children: [
                  Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 10,
                      color: FogoColors.textTertiary,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    LucideIcons.external_link,
                    size: 11,
                    color: FogoColors.textTertiary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Linha da legenda: amostra de cor + rótulo.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.color,
    required this.width,
    required this.height,
    this.radius = 2,
  });

  final String label;
  final Color color;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Row(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: FogoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rail de módulos (base-design.pen tjoxx "Abas de Navegação"): coluna
/// vertical de botões quadrados 30×30 só-ícone (símbolos, sem rótulo) —
/// Siren = Operações, Boxes = Inventário, Brain Circuit = Cidade
/// Preditiva. Container #01010a raio 12, padding 5, gap 4.
///
/// O botão de Inventário não navega: abre/fecha o CARD FLUTUANTE do
/// inventário sobre o mapa.
class _NavRail extends ConsumerWidget {
  const _NavRail({
    required this.inventoryOpen,
    required this.onToggleInventory,
  });

  final bool inventoryOpen;
  final VoidCallback onToggleInventory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictive = ref.watch(predictiveModeProvider);
    return Container(
      padding: const EdgeInsets.all(FogoSpacing.xs + 1),
      decoration: BoxDecoration(
        color: FogoColors.bg,
        borderRadius: BorderRadius.circular(FogoSpacing.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FogoIconButton(
            icon: LucideIcons.siren,
            onTap: () {
              // O mapa já está por baixo: o botão só fecha o card de
              // inventário (sem reiniciar a câmera).
              if (inventoryOpen) onToggleInventory();
            },
            active: !inventoryOpen,
            filled: false,
            size: 30,
            iconSize: 16,
          ),
          const SizedBox(height: FogoSpacing.xs),
          FogoIconButton(
            icon: LucideIcons.boxes,
            onTap: onToggleInventory,
            active: inventoryOpen,
            filled: false,
            size: 30,
            iconSize: 16,
          ),
          const SizedBox(height: FogoSpacing.xs),
          FogoIconButton(
            icon: LucideIcons.brain_circuit,
            onTap: () {
              // Cidade Preditiva: alterna o MODO de visão do mapa
              // (ícones ↔ heatmap) — não navega. Recarrega as
              // áreas ao entrar (score é calculado sob demanda).
              final next = !ref.read(predictiveModeProvider);
              ref.read(predictiveModeProvider.notifier).set(next);
              if (next) ref.invalidate(riskAreasProvider);
            },
            active: predictive,
            filled: false,
            size: 30,
            iconSize: 16,
          ),
        ],
      ),
    );
  }
}

/// Barra Inferior (base-design.pen FSFgf): Stack de altura 40 no rodapé.
/// Relação (como no .pen): campo de busca ancorado à esquerda
/// (Align.centerLeft — padding 24, largura 342) e o Navegador de
/// Cidades exatamente centrado na largura (Center — independe da
/// largura do campo).
class _BottomBar extends ConsumerStatefulWidget {
  const _BottomBar({required this.onSelectResult, required this.onFrameRegion});

  final void Function(GeoSearchResult) onSelectResult;
  final VoidCallback onFrameRegion;

  @override
  ConsumerState<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<_BottomBar> {
  late final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectFirst() {
    final SearchState search = ref.read(searchQueryProvider);
    if (search.results.isNotEmpty) widget.onSelectResult(search.results.first);
  }

  @override
  Widget build(BuildContext context) {
    // Busca encolhe antes de cruzar o nav box centrado (~480px + folga):
    // as pílulas se sobrepõem em larguras < ~1240 (mínimo da janela: 960),
    // e o nav box (filho posterior do Stack) rouba o hit-test da busca.
    final double searchWidth = ((MediaQuery.sizeOf(context).width - 560) / 2)
        .clamp(160.0, 342.0);
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          // Campo de Busca (base-design.pen Dlkv0): pílula de vidro
          // 342×40 raio 11 com lupa, placeholder e sufixo ⌘K.
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: FogoSpacing.xl),
              child: FogoGlass(
                radius: 11,
                fill: FogoColors.bg,
                child: FogoTextField(
                  width: searchWidth,
                  height: 40,
                  hint: 'Buscar endereço, hidrante, via…',
                  controller: _searchController,
                  fill: FogoColors.transparent,
                  bordered: false,
                  radius: 11,
                  prefix: const Icon(
                    LucideIcons.search,
                    size: 15,
                    color: FogoColors.textTertiary,
                  ),
                  suffix: const Text(
                    '⌘K',
                    style: TextStyle(
                      fontSize: 11,
                      color: FogoColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onChanged: (q) =>
                      ref.read(searchQueryProvider.notifier).set(q),
                  onSubmitted: (_) => _selectFirst(),
                ),
              ),
            ),
          ),
          Center(
            child: _BottomNavigationBox(onFrameRegion: widget.onFrameRegion),
          ),
        ],
      ),
    );
  }
}

/// Navegador de Cidades (base-design.pen HSBPK): pílula #01010a raio 11,
/// altura 40, padding horizontal 5, botões de cidade 32px de altura.
class _BottomNavigationBox extends ConsumerWidget {
  const _BottomNavigationBox({required this.onFrameRegion});

  final VoidCallback onFrameRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapEngineProvider);
    final bool ready = state.phase is MapReady;
    final notifier = ref.read(mapEngineProvider.notifier);
    final bool regionActive =
        state.activeCityId.isEmpty || state.activeCityId == 'regiao';

    final buttons = <Widget>[
      FogoButton(
        label: 'Região',
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        variant: regionActive
            ? FogoButtonVariant.active
            : FogoButtonVariant.ghost,
        glow: regionActive,
        onTap: ready
            ? () {
                notifier.activateRegion();
                onFrameRegion();
              }
            : null,
      ),
      for (final city in RegionCatalog.cities)
        FogoButton(
          label: city.name,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          variant: state.activeCityId == city.id
              ? FogoButtonVariant.active
              : FogoButtonVariant.ghost,
          glow: state.activeCityId == city.id,
          onTap: ready ? () => notifier.focusCity(city) : null,
        ),
    ];

    return FogoGlass(
      radius: 11,
      fill: FogoColors.bg,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, button) in buttons.indexed) ...[
              if (i > 0) const SizedBox(width: FogoSpacing.xs),
              button,
            ],
          ],
        ),
      ),
    );
  }
}
