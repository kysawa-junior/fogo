import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_map_style.dart' as app_map_style;
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_spinner.dart';
import '../../../../core/persistence/camera_preferences.dart';
import '../../../../core/persistence/preferences_provider.dart';
import '../../../routing/presentation/widgets/route_draft_marker.dart';
import '../../../routing/presentation/widgets/route_panel.dart';
import '../../../routing/presentation/widgets/route_stop_badge.dart';
import '../../../routing/providers/routing_providers.dart';
import '../../data/geocoding_service.dart' show GeoSearchResult;
import '../../domain/map_selection.dart' show SidePanel;
import '../../domain/road_filter.dart';
import '../../providers/layers_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/workspace_providers.dart';
import '../../region/fogo_region.dart';
import '../widgets/layers_panel.dart';
import '../widgets/legend_panel.dart';
import '../widgets/region_controls.dart';
import '../widgets/search_results_panel.dart';
import '../widgets/top_bar.dart';
import '../widgets/zoom_controls.dart';
import '../../../road/presentation/widgets/proposals_panel.dart';

/// Central de Operações — base cartográfica REAL de Marília-SP e Garça-SP
/// (OSM vetorial, carregamento progressivo). Estado operacional separado:
/// funciona com zero operações; paradas reais são criadas pelo usuário.
class MapWorkspacePage extends ConsumerStatefulWidget {
  const MapWorkspacePage({super.key});

  @override
  ConsumerState<MapWorkspacePage> createState() => _MapWorkspacePageState();
}

class _MapWorkspacePageState extends ConsumerState<MapWorkspacePage> {
  Timer? _saveTimer;

  late final CameraPreferences _cameraPrefs = ref.read(
    cameraPreferencesProvider,
  );
  late final ({double lat, double lng, double zoom})? _saved = _cameraPrefs
      .load();
  late final FogoMapController _mapController = FogoMapController(
    initialCamera: FogoCameraState(
      center: _saved == null
          ? FogoRegion.corridorMidpoint
          : FogoCoordinate(_saved.lat, _saved.lng),
      zoom: _saved?.zoom ?? 11,
    ),
  );
  final FogoMapDataSource _mapDataSource = FogoMapDataSource();
  FogoMapDataStatus _mapStatus = FogoMapDataStatus(
    phase: FogoMapDataPhase.loading,
    manifest: null,
    errors: const [],
    requestedCellCount: 0,
    loadedCellCount: 0,
  );

  @override
  void initState() {
    super.initState();
    if (_saved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitBounds(FogoRegion.regionBounds, padding: 60);
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// O SDK carrega as células visíveis; o host persiste câmera com debounce.
  void _onCameraChanged(FogoCameraState camera) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      _cameraPrefs.save(
        camera.center.latitude,
        camera.center.longitude,
        camera.zoom,
      );
    });
  }

  /// Botão direito / toque longo: cria parada REAL georreferenciada.
  void _addStop(FogoCoordinate point) {
    ref
        .read(routingFlowProvider.notifier)
        .addStop(LatLng(point.latitude, point.longitude));
    ref.read(sidePanelProvider.notifier).openRouting();
  }

  void _fitBounds(FogoGeoBounds bounds, {double padding = 80}) {
    _mapController.fitBounds(bounds, padding: EdgeInsets.all(padding));
  }

  FogoMapStyle _mapStyle(
    Set<MapLayerId> activeLayers,
    Set<RoadFilterGroup> roadFilter,
  ) => FogoMapStyle(
    background: app_map_style.FogoMapStyle.mapCanvas,
    water: app_map_style.FogoMapStyle.water,
    green: app_map_style.FogoMapStyle.green,
    farmland: app_map_style.FogoMapStyle.farmland,
    building: app_map_style.FogoMapStyle.building,
    buildingStroke: app_map_style.FogoMapStyle.buildingStroke,
    boundary: app_map_style.FogoMapStyle.boundary,
    roadCasing: app_map_style.FogoMapStyle.roadCasing,
    roadCasingBridge: app_map_style.FogoMapStyle.roadCasingBridge,
    roadMotorway: app_map_style.FogoMapStyle.roadMotorway,
    roadTrunk: app_map_style.FogoMapStyle.roadTrunk,
    roadPrimary: app_map_style.FogoMapStyle.roadPrimary,
    roadSecondary: app_map_style.FogoMapStyle.roadSecondary,
    roadTertiary: app_map_style.FogoMapStyle.roadTertiary,
    roadUnclassified: app_map_style.FogoMapStyle.roadUnclassified,
    roadResidential: app_map_style.FogoMapStyle.roadResidential,
    roadService: app_map_style.FogoMapStyle.roadService,
    roadTrack: app_map_style.FogoMapStyle.roadTrack,
    roadPath: app_map_style.FogoMapStyle.roadPath,
    railBed: app_map_style.FogoMapStyle.railBed,
    railTie: app_map_style.FogoMapStyle.railTie,
    railDisused: FogoColors.textDisabled,
    waterLine: app_map_style.FogoMapStyle.waterLine,
    onewayArrow: app_map_style.FogoMapStyle.onewayArrow,
    shieldBg: app_map_style.FogoMapStyle.shieldBg,
    shieldBorder: app_map_style.FogoMapStyle.shieldBorder,
    shieldText: app_map_style.FogoMapStyle.shieldText,
    labelRoad: app_map_style.FogoMapStyle.labelRoad,
    labelCity: app_map_style.FogoMapStyle.labelCity,
    labelSuburb: app_map_style.FogoMapStyle.labelSuburb,
    labelPoi: app_map_style.FogoMapStyle.labelPoi,
    labelHalo: app_map_style.FogoMapStyle.labelHalo,
    poiDot: app_map_style.FogoMapStyle.poiDot,
    showBuildings: activeLayers.contains(MapLayerId.buildings),
    showLabels: activeLayers.contains(MapLayerId.labels),
    showAttribution: false,
    roadFilter: {
      for (final RoadFilterGroup group in roadFilter)
        FogoRoadFilterGroup.values.byName(group.name),
    },
  );

  void _onMapSelection(FogoMapSelection selection) {
    if (selection.source == FogoSelectionSource.secondaryClick ||
        selection.source == FogoSelectionSource.longPress) {
      _addStop(selection.coordinate);
    }
  }

  void _onMapDataStatus(FogoMapDataStatus status) {
    if (!mounted) return;
    final FogoMapDataStatus previous = _mapStatus;
    final bool visibleStatusChanged =
        previous.phase != status.phase ||
        previous.manifest?.attribution != status.manifest?.attribution ||
        previous.hasErrors != status.hasErrors;
    _mapStatus = status;
    if (visibleStatusChanged) setState(() {});
  }

  void _togglePitch() {
    _mapController.setPitch(_mapController.camera.pitch == 0 ? 45 : 0);
    setState(() {});
  }

  void _selectSearchResult(GeoSearchResult result) {
    _mapController.moveTo(_coordinate(result.point), zoom: 16);
    ref.read(searchQueryProvider.notifier).clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final RoutingFlowState routing = ref.watch(routingFlowProvider);
    final SidePanel sidePanel = ref.watch(sidePanelProvider);
    final Set<MapLayerId> activeLayers = ref.watch(layersProvider);
    final Set<RoadFilterGroup> roadFilter = ref.watch(roadFilterProvider);
    final RoadRouteResult? result = routing.result;
    final FogoMapStyle mapStyle = _mapStyle(activeLayers, roadFilter);
    final List<FogoMapPolyline> routePolylines =
        result != null && result.geometry.length >= 2
        ? [
            FogoMapPolyline(
              id: 'optimized-route',
              points: [
                for (final LatLng point in result.geometry) _coordinate(point),
              ],
              color: FogoColors.accent,
              width: 4,
              borderColor: FogoColors.bg,
              borderWidth: 1.2,
              dashPattern: const [12, 9],
            ),
          ]
        : const [];
    final List<FogoMapMarker> routeMarkers = [
      for (int i = 0; i < routing.drafts.length; i++)
        FogoMapMarker(
          id: 'draft-${routing.drafts[i].id}',
          coordinate: _coordinate(routing.drafts[i].point),
          width: 22,
          height: 22,
          child: RouteDraftMarker(
            index: i + 1,
            onTap: () => ref.read(sidePanelProvider.notifier).openRouting(),
          ),
        ),
      if (result != null)
        for (int i = 0; i < result.stops.length; i++)
          FogoMapMarker(
            id: 'optimized-${result.stops[i].id}',
            coordinate: _coordinate(result.stops[i].point),
            width: 18,
            height: 18,
            child: RouteStopBadge(
              index: i + 1,
              selected: false,
              onTap: () => _mapController.moveTo(
                _coordinate(result.stops[i].point),
                zoom: 16,
              ),
            ),
          ),
    ];

    return Container(
      color: FogoColors.bg,
      child: Stack(
        children: [
          // O SDK carrega a base regional e mantém overlays no mesmo transform.
          Positioned.fill(
            child: FogoMapView(
              controller: _mapController,
              dataSource: _mapDataSource,
              style: mapStyle,
              polylines: routePolylines,
              markers: routeMarkers,
              onCameraChanged: _onCameraChanged,
              onSelection: _onMapSelection,
              onDataStatus: _onMapDataStatus,
            ),
          ),

          // Barra flutuante de identificação e módulos.
          Positioned(
            top: FogoSpacing.md,
            left: FogoSpacing.md,
            right: FogoSpacing.md,
            child: TopBar(
              activeModule: FogoModule.operations,
              onSelectResult: _selectSearchResult,
              mapStatus: _mapStatus,
            ),
          ),

          // Resultados de busca real sobre o mapa.
          Positioned(
            top: 78,
            right: FogoSpacing.md,
            width: 360,
            child: SearchResultsPanel(onSelect: _selectSearchResult),
          ),

          // Painel lateral: rotas ou propostas.
          // Painel lateral. width obrigatório: no Flutter 3.47 um
          // Positioned(top, right) sem width dá largura NÃO-LIMITADA ao
          // filho — painéis com Row(Expanded) quebrariam o layout e
          // corromperiam o pipeline de semântica (parentDataDirty).
          Positioned(
            top: 78,
            right: FogoSpacing.md,
            width: 360,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _buildSidePanel(sidePanel),
            ),
          ),

          // Camadas.
          Positioned(
            top: 78,
            right: sidePanel == SidePanel.hidden ? FogoSpacing.md : 392,
            child: const LayersPanel(),
          ),

          // Legenda (inferior esquerda).
          Positioned(
            left: FogoSpacing.md,
            bottom: FogoSpacing.md,
            child: LegendPanel(status: _mapStatus),
          ),

          // Zoom (inferior direita).
          Positioned(
            right: FogoSpacing.md,
            bottom: FogoSpacing.md,
            child: ZoomControls(
              onZoomIn: () => _mapController.zoomBy(1),
              onZoomOut: () => _mapController.zoomBy(-1),
              onFrameAll: () => _fitBounds(FogoRegion.regionBounds),
              is3D: _mapController.camera.pitch == 45,
              onToggle3D: _togglePitch,
            ),
          ),

          // Atalhos de região (inferior centro).
          Positioned(
            left: 0,
            right: 0,
            bottom: FogoSpacing.md,
            child: Center(
              child: RegionControls(
                onRegion: () => _fitBounds(FogoRegion.regionBounds),
                onMarilia: () => _fitBounds(FogoRegion.mariliaBounds()),
                onGarca: () => _fitBounds(FogoRegion.garcaBounds()),
              ),
            ),
          ),

          // Indicador de carregamento da base.
          if (_mapStatus.isLoading)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 92,
              child: Center(child: _BaseLoadingChip()),
            ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(SidePanel sidePanel) {
    switch (sidePanel) {
      case SidePanel.hidden:
        return const SizedBox.shrink();
      case SidePanel.routing:
        return RoutePanel(
          key: const ValueKey('route-panel'),
          onSelectStop: (stop) =>
              _mapController.moveTo(_coordinate(stop.point), zoom: 16),
          onClose: () => ref.read(sidePanelProvider.notifier).hide(),
        );
      case SidePanel.proposals:
        return ProposalsPanel(
          key: const ValueKey('proposals-panel'),
          onClose: () => ref.read(sidePanelProvider.notifier).hide(),
        );
      case SidePanel.proposalForm:
        return const SizedBox.shrink(); // dormente até fonte de vias
    }
  }
}

FogoCoordinate _coordinate(LatLng point) =>
    FogoCoordinate(point.latitude, point.longitude);

class _BaseLoadingChip extends StatelessWidget {
  const _BaseLoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FogoColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: FogoColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 12, height: 12, child: FogoSpinner()),
          SizedBox(width: 8),
          Text(
            'carregando base cartográfica…',
            style: TextStyle(fontSize: 11, color: FogoColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
