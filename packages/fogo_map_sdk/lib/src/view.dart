import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'camera.dart';
import 'coordinates.dart';
import 'data.dart';
import 'data_source.dart';
import 'overlays.dart';
import 'renderer.dart';
import 'road_geometry.dart';
import 'selection.dart';
import 'style.dart';

typedef FogoMapStatusBuilder = Widget Function(
  BuildContext context,
  FogoMapDataStatus status,
);

/// Self-contained regional OSM map surface. The caller owns camera
/// persistence, routing/search state, and geographic overlay data.
class FogoMapView extends StatefulWidget {
  FogoMapView({
    super.key,
    required this.controller,
    required this.dataSource,
    FogoMapStyle? style,
    this.polylines = const [],
    this.markers = const [],
    this.onCameraChanged,
    this.onSelection,
    this.onDataStatus,
    this.statusBuilder,
  }) : style = style ?? FogoMapStyle.fogoNight;

  final FogoMapController controller;
  final FogoMapDataSource dataSource;
  final FogoMapStyle style;
  final List<FogoMapPolyline> polylines;
  final List<FogoMapMarker> markers;
  final ValueChanged<FogoCameraState>? onCameraChanged;
  final ValueChanged<FogoMapSelection>? onSelection;
  final ValueChanged<FogoMapDataStatus>? onDataStatus;
  final FogoMapStatusBuilder? statusBuilder;

  @override
  State<FogoMapView> createState() => _FogoMapViewState();
}

class _FogoMapViewState extends State<FogoMapView>
    with SingleTickerProviderStateMixin {
  FogoMapManifest? _manifest;
  FogoMapRenderData _renderData = FogoMapRenderData();
  FogoMapDataStatus _status = FogoMapDataStatus(
    phase: FogoMapDataPhase.loading,
    manifest: null,
    errors: const [],
    requestedCellCount: 0,
    loadedCellCount: 0,
  );
  final Map<String, FogoMapCellData?> _visibleL0 = {};
  final Map<String, FogoMapCellData?> _visibleL1 = {};
  final Map<String, FogoMapDataError> _errors = {};
  final Set<String> _failedCells = {};
  final FogoRoadSurfaceCache _surfaceCache = FogoRoadSurfaceCache();
  final FogoProjectionCache _projectionCache = FogoProjectionCache();
  Timer? _viewportTimer;
  int _viewportGeneration = 0;
  Size _viewportSize = Size.zero;
  Offset _lastScaleFocal = Offset.zero;
  Offset _doubleTapPosition = Offset.zero;
  double _lastGestureScale = 1;
  double _lastTrackpadScale = 1;
  bool _dragging = false;
  late final AnimationController _fling = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..addListener(_applyFling);
  Offset _flingVelocity = Offset.zero;
  double _flingProgress = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCameraChanged);
    unawaited(_loadManifest());
  }

  @override
  void didUpdateWidget(covariant FogoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCameraChanged);
      widget.controller.addListener(_onCameraChanged);
      widget.controller.updateViewportSize(_viewportSize);
      _scheduleViewportLoad();
    }
    if (oldWidget.dataSource != widget.dataSource) {
      _viewportTimer?.cancel();
      _viewportGeneration++;
      _manifest = null;
      _visibleL0.clear();
      _visibleL1.clear();
      _errors.clear();
      _failedCells.clear();
      _renderData = FogoMapRenderData();
      _setStatus(FogoMapDataPhase.loading);
      unawaited(_loadManifest());
    }
  }

  @override
  void dispose() {
    _viewportTimer?.cancel();
    widget.controller.removeListener(_onCameraChanged);
    _fling.dispose();
    super.dispose();
  }

  Future<void> _loadManifest() async {
    final FogoMapDataSource dataSource = widget.dataSource;
    try {
      final FogoMapManifest manifest = await dataSource.loadManifest();
      if (!mounted || widget.dataSource != dataSource) return;
      setState(() => _manifest = manifest);
      _scheduleViewportLoad();
    } on FogoMapDataException catch (error) {
      if (!mounted || widget.dataSource != dataSource) return;
      _errors[error.error.key] = error.error;
      setState(() {
        _manifest = null;
        _renderData = FogoMapRenderData();
      });
      _setStatus(FogoMapDataPhase.error);
    } catch (error) {
      if (!mounted || widget.dataSource != dataSource) return;
      final FogoMapDataError issue = FogoMapDataError(
        kind: FogoMapDataErrorKind.manifest,
        assetPath: widget.dataSource.manifestAsset,
        message: error.toString(),
      );
      _errors[issue.key] = issue;
      setState(() {
        _manifest = null;
        _renderData = FogoMapRenderData();
      });
      _setStatus(FogoMapDataPhase.error);
    }
  }

  void _onCameraChanged() {
    widget.onCameraChanged?.call(widget.controller.camera);
    _scheduleViewportLoad();
    if (mounted) setState(() {});
  }

  void _scheduleViewportLoad() {
    _viewportTimer?.cancel();
    final int generation = ++_viewportGeneration;
    _viewportTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(_loadViewport(generation));
    });
  }

  Future<void> _loadViewport(int generation) async {
    final FogoMapManifest? manifest = _manifest;
    if (!mounted ||
        manifest == null ||
        _viewportSize.width <= 0 ||
        _viewportSize.height <= 0) {
      return;
    }
    final FogoCameraTransform transform = FogoCameraTransform(
      widget.controller.camera,
      _viewportSize,
    );
    final FogoGeoBounds visible = transform.visibleBounds;
    if (!visible.intersects(manifest.bounds)) {
      _visibleL0.clear();
      _visibleL1.clear();
      _renderData = FogoMapRenderData();
      _setStatus(
        FogoMapDataPhase.outsideCoverage,
        requestedCellCount: 0,
        loadedCellCount: 0,
      );
      if (mounted) setState(() {});
      return;
    }

    // Retain the existing viewport prefetch window while bounding view state.
    final double padX = (visible.east - visible.west) * 0.4;
    final double padY = (visible.north - visible.south) * 0.4;
    final double west = math.max(manifest.bounds.west, visible.west - padX);
    final double east = math.min(manifest.bounds.east, visible.east + padX);
    final double south = math.max(manifest.bounds.south, visible.south - padY);
    final double north = math.min(manifest.bounds.north, visible.north + padY);
    final int x0 = ((west - manifest.bounds.west) / manifest.cellSize)
        .floor()
        .clamp(0, manifest.columns - 1)
        .toInt();
    final int x1 = ((east - manifest.bounds.west) / manifest.cellSize)
        .floor()
        .clamp(0, manifest.columns - 1)
        .toInt();
    final int y0 = ((south - manifest.bounds.south) / manifest.cellSize)
        .floor()
        .clamp(0, manifest.rows - 1)
        .toInt();
    final int y1 = ((north - manifest.bounds.south) / manifest.cellSize)
        .floor()
        .clamp(0, manifest.rows - 1)
        .toInt();
    final Set<String> requestedL0 = {
      for (int x = x0; x <= x1; x++)
        for (int y = y0; y <= y1; y++) '$x/$y',
    };
    final bool showL1 = widget.controller.camera.zoom >= 15.5;
    final Set<String> requestedL1 = showL1 ? requestedL0 : const {};
    _visibleL0.removeWhere((key, _) => !requestedL0.contains(key));
    _visibleL1.removeWhere((key, _) => !requestedL1.contains(key));
    _refreshRenderData();

    final List<_CellRequest> requests = [];
    for (final String key in requestedL0) {
      final (int x, int y) = _parseCellKey(key);
      if (!_visibleL0.containsKey(key) && !_failedCells.contains('l0/$key')) {
        requests.add(_CellRequest(FogoCellTier.l0, x, y, key));
      }
    }
    for (final String key in requestedL1) {
      final (int x, int y) = _parseCellKey(key);
      if (!_visibleL1.containsKey(key) && !_failedCells.contains('l1/$key')) {
        requests.add(_CellRequest(FogoCellTier.l1, x, y, key));
      }
    }
    final int requestedCount = requestedL0.length + requestedL1.length;
    if (requests.isEmpty) {
      final FogoMapDataPhase phase = _renderData.isEmpty
          ? FogoMapDataPhase.empty
          : FogoMapDataPhase.ready;
      _setStatus(
        phase,
        requestedCellCount: requestedCount,
        loadedCellCount: _loadedCellCount,
      );
      if (mounted) setState(() {});
      return;
    }

    _setStatus(
      FogoMapDataPhase.loading,
      requestedCellCount: requestedCount,
      loadedCellCount: _loadedCellCount,
    );
    if (mounted) setState(() {});
    final List<_CellResult> results = await Future.wait(
      requests.map(_loadCell),
    );
    if (!mounted || generation != _viewportGeneration) return;
    for (final _CellResult result in results) {
      final Map<String, FogoMapCellData?> target =
          result.request.tier == FogoCellTier.l0 ? _visibleL0 : _visibleL1;
      if (result.error != null) {
        _errors[result.error!.key] = result.error!;
        _failedCells.add('${result.request.tier.name}/${result.request.key}');
      } else {
        target[result.request.key] = result.cell;
      }
    }
    _refreshRenderData();
    final FogoMapDataPhase phase = _renderData.isEmpty
        ? FogoMapDataPhase.empty
        : FogoMapDataPhase.ready;
    _setStatus(
      phase,
      requestedCellCount: requestedCount,
      loadedCellCount: _loadedCellCount,
    );
    setState(() {});
  }

  Future<_CellResult> _loadCell(_CellRequest request) async {
    try {
      final FogoMapCellData? cell = await widget.dataSource.loadCell(
        request.tier,
        request.x,
        request.y,
      );
      return _CellResult(request, cell: cell);
    } on FogoMapDataException catch (error) {
      return _CellResult(request, error: error.error);
    } catch (error) {
      return _CellResult(
        request,
        error: FogoMapDataError(
          kind: FogoMapDataErrorKind.cell,
          assetPath: '${request.tier.name}_${request.x}_${request.y}.json.gz',
          message: error.toString(),
          tier: request.tier,
          x: request.x,
          y: request.y,
        ),
      );
    }
  }

  int get _loadedCellCount => [
    ..._visibleL0.values,
    ..._visibleL1.values,
  ].where((cell) => cell != null).length;

  void _refreshRenderData() {
    _renderData = FogoMapRenderData.fromCells([
      for (final FogoMapCellData? cell in [
        ..._visibleL0.values,
        ..._visibleL1.values,
      ])
        ?cell,
    ]);
  }

  void _setStatus(
    FogoMapDataPhase phase, {
    int requestedCellCount = 0,
    int loadedCellCount = 0,
  }) {
    final FogoMapDataStatus status = FogoMapDataStatus(
      phase: phase,
      manifest: _manifest,
      errors: _errors.values.toList(growable: false),
      requestedCellCount: requestedCellCount,
      loadedCellCount: loadedCellCount,
    );
    _status = status;
    widget.onDataStatus?.call(status);
  }

  static (int, int) _parseCellKey(String key) {
    final int separator = key.indexOf('/');
    return (
      int.parse(key.substring(0, separator)),
      int.parse(key.substring(separator + 1)),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _fling.stop();
    _lastScaleFocal = details.localFocalPoint;
    _lastGestureScale = 1;
    _dragging = true;
    setState(() {});
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final Offset focal = details.localFocalPoint;
    widget.controller.panByScreenDelta(focal - _lastScaleFocal);
    final double scale = details.scale;
    if (scale.isFinite && scale > 0 && _lastGestureScale > 0) {
      widget.controller.zoomBy(
        math.log(scale / _lastGestureScale) / math.ln2,
        focalPoint: focal,
      );
    }
    _lastScaleFocal = focal;
    _lastGestureScale = scale;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _dragging = false;
    setState(() {});
    final Offset velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance > 50) {
      _flingVelocity = velocity;
      _flingProgress = 0;
      _fling.forward(from: 0);
    }
  }

  void _applyFling() {
    final double seconds = _fling.value * 0.75;
    final double progress = (1 - math.exp(-5 * seconds)) / 5;
    final double delta = progress - _flingProgress;
    _flingProgress = progress;
    if (delta > 0) widget.controller.panByScreenDelta(_flingVelocity * delta);
  }

  void _select(Offset localPosition, FogoSelectionSource source) {
    final FogoCoordinate? coordinate = widget.controller.screenToCoordinate(
      localPosition,
    );
    if (coordinate == null) return;
    final FogoMapSelection selection = FogoMapSelection(
      coordinate: coordinate,
      screenPosition: localPosition,
      source: source,
    );
    widget.controller.selectAt(localPosition, source: source);
    widget.onSelection?.call(selection);
  }

  void _handleWheel(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      widget.controller.zoomBy(
        -event.scrollDelta.dy / 240,
        focalPoint: event.localPosition,
      );
    }
  }

  void _handleTrackpadStart(PointerPanZoomStartEvent event) {
    _lastTrackpadScale = 1;
  }

  void _handleTrackpadUpdate(PointerPanZoomUpdateEvent event) {
    widget.controller.panByScreenDelta(event.panDelta);
    if (event.scale > 0 && _lastTrackpadScale > 0) {
      widget.controller.zoomBy(
        math.log(event.scale / _lastTrackpadScale) / math.ln2,
        focalPoint: event.localPosition,
      );
    }
    _lastTrackpadScale = event.scale;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        widget.controller.panByScreenDelta(const Offset(40, 0));
        break;
      case LogicalKeyboardKey.arrowRight:
        widget.controller.panByScreenDelta(const Offset(-40, 0));
        break;
      case LogicalKeyboardKey.arrowUp:
        widget.controller.panByScreenDelta(const Offset(0, 40));
        break;
      case LogicalKeyboardKey.arrowDown:
        widget.controller.panByScreenDelta(const Offset(0, -40));
        break;
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.add:
        widget.controller.zoomBy(1);
        break;
      case LogicalKeyboardKey.minus:
        widget.controller.zoomBy(-1);
        break;
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Size size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size != _viewportSize) {
        _viewportSize = size;
        widget.controller.updateViewportSize(size);
        _scheduleViewportLoad();
      }
      final FogoCameraState camera = widget.controller.camera;
      final FogoCameraTransform transform = FogoCameraTransform(camera, size);
      return Focus(
        onKeyEvent: _onKeyEvent,
        child: Semantics(
          container: true,
          label: 'F.O.G.O. regional map',
          value: 'Zoom ${camera.zoom.toStringAsFixed(1)}',
          increasedValue:
              'Zoom ${(camera.zoom + 1).clamp(widget.controller.minZoom, widget.controller.maxZoom).toStringAsFixed(1)}',
          decreasedValue:
              'Zoom ${(camera.zoom - 1).clamp(widget.controller.minZoom, widget.controller.maxZoom).toStringAsFixed(1)}',
          onIncrease: () => widget.controller.zoomBy(1),
          onDecrease: () => widget.controller.zoomBy(-1),
          child: MouseRegion(
            cursor: _dragging
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab,
            child: Listener(
              onPointerSignal: _handleWheel,
              onPointerPanZoomStart: _handleTrackpadStart,
              onPointerPanZoomUpdate: _handleTrackpadUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: _handleScaleEnd,
                    onDoubleTapDown: (details) =>
                        _doubleTapPosition = details.localPosition,
                    onDoubleTap: () => widget.controller.zoomBy(
                      1,
                      focalPoint: _doubleTapPosition,
                    ),
                    onSecondaryTapUp: (details) => _select(
                      details.localPosition,
                      FogoSelectionSource.secondaryClick,
                    ),
                    onLongPressStart: (details) => _select(
                      details.localPosition,
                      FogoSelectionSource.longPress,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: widget.style.background),
                        if (_manifest case final FogoMapManifest manifest)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: FogoMapPainter(
                                camera: camera,
                                data: _renderData,
                                manifest: manifest,
                                style: widget.style,
                                polylines: widget.polylines,
                                surfaceCache: _surfaceCache,
                                projectionCache: _projectionCache,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final FogoMapMarker marker in widget.markers)
                    if (marker.coordinate.isValid &&
                        marker.width.isFinite &&
                        marker.height.isFinite &&
                        marker.width > 0 &&
                        marker.height > 0)
                      _marker(marker, transform),
                  if (widget.style.showAttribution)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Semantics(
                        label:
                            _manifest?.attribution ??
                            '© OpenStreetMap contributors',
                        child: Text(
                          _manifest?.attribution ??
                              '© OpenStreetMap contributors',
                          style: TextStyle(
                            color: widget.style.labelSuburb,
                            fontSize: 10,
                            shadows: [
                              Shadow(
                                color: widget.style.background,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (widget.statusBuilder
                      case final FogoMapStatusBuilder builder)
                    builder(context, _status),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _marker(FogoMapMarker marker, FogoCameraTransform transform) {
    final Offset point = transform.project(marker.coordinate);
    return Positioned(
      key: ValueKey<String>(marker.id),
      left: point.dx - (marker.alignment.x + 1) * marker.width / 2,
      top: point.dy - (marker.alignment.y + 1) * marker.height / 2,
      width: marker.width,
      height: marker.height,
      child: Align(
        alignment: marker.alignment,
        child: SizedBox(
          width: marker.width,
          height: marker.height,
          child: marker.child,
        ),
      ),
    );
  }
}

class _CellRequest {
  const _CellRequest(this.tier, this.x, this.y, this.key);
  final FogoCellTier tier;
  final int x;
  final int y;
  final String key;
}

class _CellResult {
  const _CellResult(this.request, {this.cell, this.error});
  final _CellRequest request;
  final FogoMapCellData? cell;
  final FogoMapDataError? error;
}
