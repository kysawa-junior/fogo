import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../engine/fogo_engine.dart';
import '../label_candidates.dart';
import '../map_icons.dart';
import 'map_2d_renderer.dart';

/// BASE 2D PERMANENTE — nunca desligada nem trocada: um CustomPainter
/// desenha vias/áreas/footprints (primitivas leves do [Map2DScene]) num
/// único passe de canvas, sob a camada 3D dinâmica. Os rótulos (nomes de
/// via, áreas, POIs) são pintados NO MESMO canvas, deitados sobre as
/// vias — mesma linguagem dos decals de nome de via da cena 3D; não há
/// overlay de widgets de rótulo.
///
/// É o ÚNICO dono do tick da câmera (amortecimento + WASD) — o viewport
/// 3D apenas observa. Quando a camada 3D está totalmente opaca
/// ([overlayOpacity] >= 0.999), o repaint é suprimido, mas o tick da
/// câmera continua (o amortecimento não para).
///
/// Controles: arrastar move o mapa (conteúdo segue o dedo); rolagem
/// aproxima do ponto sob o cursor; WASD move. Toque curto num ícone
/// ([MapIcon]) dispara [onIconTap] — mesmo card da camada 3D.
class Map2DView extends StatefulWidget {
  const Map2DView({
    super.key,
    required this.engine,
    required this.camera,
    required this.labelCandidates,
    this.mapIcons = const [],
    this.onIconTap,
    this.overlayOpacity,
    this.visibleKinds,
    this.heat = const [],
    this.onAreaTap,
  });

  final FogoEngine engine;
  final OrbitCamera camera;
  final List<LabelCandidate> labelCandidates;

  /// Ícones (semáforos, viaturas, radares, câmeras) da base 2D.
  final List<MapIcon> mapIcons;
  final void Function(MapIcon icon)? onIconTap;

  /// Filtro de ícones (Modo Normal): tipos visíveis; null = todos.
  final Set<MapIconKind>? visibleKinds;

  /// Células do heatmap de risco (Cidade Preditiva), em mundo (x/z).
  final List<HeatCell> heat;

  /// Toque curto numa célula do heatmap (quando [heat] não vazio).
  final void Function(HeatCell cell)? onAreaTap;

  /// Opacidade corrente da camada 3D sobreposta (0..1). Usada apenas
  /// para SUPRIMIR o repaint quando o 3D cobre a tela por completo.
  final ValueListenable<double>? overlayOpacity;

  @override
  State<Map2DView> createState() => _Map2DViewState();
}

class _Map2DViewState extends State<Map2DView>
    with SingleTickerProviderStateMixin {
  Size _viewSize = Size.zero;
  Offset _lastPosition = Offset.zero;
  bool _dragging = false;
  double _dragDistance = 0;
  Duration _lastFrame = Duration.zero;

  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  bool _wasdActive = false;

  Map2DRenderer? _renderer;
  late final Ticker _ticker;

  // Dirty check: mapa parado = zero repaint (congelamento barato).
  double _lastX = double.nan,
      _lastZ = double.nan,
      _lastAz = double.nan,
      _lastD = double.nan;
  int _lastFleetRev = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(Map2DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.engine, oldWidget.engine)) {
      _renderer = Map2DRenderer(widget.engine.map2d);
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastFrame == Duration.zero
        ? 0.0
        : (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    // Único dono do amortecimento: tick roda SEMPRE (a camada 3D
    // observa; tickar lá dobraria a velocidade).
    if (dt > 0) widget.camera.tick(dt.clamp(0.0, 0.1));
    // Único dono do tick da FROTA (viaturas) — idem.
    if (dt > 0) widget.engine.vehicles.tick(dt.clamp(0.0, 0.1));
    _applyWasd();

    final camera = widget.camera;
    final fleetRev = widget.engine.vehicles.revision;
    if (camera.target.x != _lastX ||
        camera.target.z != _lastZ ||
        camera.azimuthRadians != _lastAz ||
        camera.distanceMeters != _lastD ||
        fleetRev != _lastFleetRev) {
      // Camada 3D opaca por cima: pula o repaint (os campos _last
      // ficam velhos de propósito — o 2D repinta assim que a camada
      // 3D sai de cima, mesmo com a câmera parada).
      if ((widget.overlayOpacity?.value ?? 0) >= 0.999) return;
      setState(() {
        _lastX = camera.target.x;
        _lastZ = camera.target.z;
        _lastAz = camera.azimuthRadians;
        _lastD = camera.distanceMeters;
        _lastFleetRev = fleetRev;
      });
    }
  }

  /// Ícones correntes: estáticos (semáforos/radares/câmeras) + viaturas
  /// da frota simulada (posições correntes, por frame).
  List<MapIcon> _currentIcons() {
    final fleet = widget.engine.vehicles;
    final visible = widget.visibleKinds;
    bool ok(MapIcon icon) => visible == null || visible.contains(icon.kind);
    if (fleet.vehicles.isEmpty) {
      return widget.mapIcons.where(ok).toList();
    }
    return [
      ...widget.mapIcons.where(ok),
      for (final v in fleet.vehicles)
        if (ok(_fleetIcon(v))) _fleetIcon(v),
    ];
  }

  MapIcon _fleetIcon(Vehicle v) => MapIcon(
    id: 'vehicle/${v.kind.name}/${v.id}',
    x: v.x,
    z: v.z,
    kind: v.kind == VehicleKind.police
        ? MapIconKind.policeVehicle
        : MapIconKind.fireVehicle,
  );

  // --- gestos (mesma semântica do viewport 3D, mapeada para o plano) ---

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    _dragging = true;
    _dragDistance = 0;
    _lastPosition = event.localPosition;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragging) return;
    final delta = event.localPosition - _lastPosition;
    _dragDistance += delta.distance;
    _lastPosition = event.localPosition;
    _panBy(delta.dx, delta.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    final bool wasTap = _dragging && _dragDistance < 6;
    _dragging = false;
    if (!wasTap) return;
    final camera = widget.camera;
    final s = Map2DRenderer.pxPerMeter(_viewSize.height, camera.distanceMeters);
    if (s <= 0) return;
    // Hit-test nos ícones (raio 14 px > alvo de dedo mínimo razoável);
    // alpha 0 = fora da banda de zoom → sem hit.
    final alpha = Map2DRenderer.iconAlpha(camera.distanceMeters);
    if (widget.onIconTap != null && alpha > 0) {
      MapIcon? hit;
      var best = double.infinity;
      for (final icon in _currentIcons()) {
        final p = Map2DRenderer.iconScreenPoint(
          worldX: icon.x,
          worldZ: icon.z,
          targetX: camera.target.x,
          targetZ: camera.target.z,
          azimuth: camera.azimuthRadians,
          s: s,
          viewWidth: _viewSize.width,
          viewHeight: _viewSize.height,
        );
        if (p == null) continue;
        final d = (p - event.localPosition).distance;
        if (d <= 14 && d < best) {
          best = d;
          hit = icon;
        }
      }
      if (hit != null) {
        widget.onIconTap!(hit);
        return;
      }
    }
    // Hit-test do heatmap (Cidade Preditiva): ponto de tela → mundo
    // (inversa do transform do painter) e célula contendo o ponto.
    if (widget.onAreaTap != null && widget.heat.isNotEmpty) {
      final dxs = event.localPosition.dx - _viewSize.width / 2;
      final dys = event.localPosition.dy - _viewSize.height / 2;
      final az = camera.azimuthRadians;
      final wx =
          camera.target.x + (-math.sin(az) * dxs + math.cos(az) * dys) / s;
      final wz =
          camera.target.z + (math.cos(az) * dxs + math.sin(az) * dys) / s;
      for (final cell in widget.heat) {
        if (cell.rect.contains(Offset(wx, wz))) {
          widget.onAreaTap!(cell);
          return;
        }
      }
    }
  }

  /// Pan: move o ALVO para o conteúdo seguir o dedo. MESMA semântica do
  /// viewport 3D (`pan(-dx, dy)` — mouse flipa dx): a base do painter
  /// agora é idêntica à do 3D, então os argumentos também são. A
  /// velocidade é em px/m reais (não a fração 0.0016 do 3D).
  void _panBy(double dx, double dy) {
    final s = Map2DRenderer.pxPerMeter(
      _viewSize.height,
      widget.camera.goalDistance,
    );
    if (s <= 0) return;
    widget.camera.pan(-dx, dy, speed: 1 / (s * widget.camera.goalDistance));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Zoom direcionado no mundo sob o cursor — mesma transform do
    // painter (inversa da base top-down).
    final camera = widget.camera;
    final s = Map2DRenderer.pxPerMeter(_viewSize.height, camera.distanceMeters);
    if (s <= 0) return;
    final dxs = event.localPosition.dx - _viewSize.width / 2;
    final dys = event.localPosition.dy - _viewSize.height / 2;
    final az = camera.azimuthRadians;
    // Inversa do transform do painter (rotate(az + π/2), scale(s,-s)):
    // screen-right = (-sinA, cosA), screen-up = -(cosA, sinA) — a MESMA
    // base do viewport 3D. O ponto sob o cursor é o mesmo nos dois.
    final wx = camera.target.x + (-math.sin(az) * dxs + math.cos(az) * dys) / s;
    final wz = camera.target.z + (math.cos(az) * dxs + math.sin(az) * dys) / s;
    final factor = event.scrollDelta.dy <= 0 ? 1.15 : 1 / 1.15;
    camera.zoomToward(factor, Vector3(wx, 0, wz));
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    _wasdActive =
        _pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyD);
  }

  void _applyWasd() {
    if (!_wasdActive) return;
    const speed = 120.0; // px/s (idêntico ao 3D)
    final dx = _pressedKeys.contains(LogicalKeyboardKey.keyA)
        ? -speed * (1 / 60)
        : _pressedKeys.contains(LogicalKeyboardKey.keyD)
        ? speed * (1 / 60)
        : 0.0;
    final dy = _pressedKeys.contains(LogicalKeyboardKey.keyW)
        ? speed * (1 / 60)
        : _pressedKeys.contains(LogicalKeyboardKey.keyS)
        ? -speed * (1 / 60)
        : 0.0;
    if (dx != 0 || dy != 0) {
      // WASD NÃO flipa dx (igual ao 3D); _panBy flipa (semântica mouse).
      _panBy(-dx, dy);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        _renderer ??= Map2DRenderer(widget.engine.map2d);
        final camera = widget.camera;
        return Focus(
          focusNode: _focusNode,
          onKeyEvent: (_, event) {
            _onKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerSignal: _onPointerSignal,
            child: Stack(
              children: [
                // Fundo escuro do sistema (base-design.pen).
                const Positioned.fill(child: ColoredBox(color: FogoColors.bg)),
                Positioned.fill(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _Map2DPainter(
                      renderer: _renderer!,
                      targetX: camera.target.x,
                      targetZ: camera.target.z,
                      azimuth: camera.azimuthRadians,
                      distance: camera.distanceMeters,
                      labels: widget.labelCandidates,
                      icons: _currentIcons(),
                      iconAlphaScale: 1 - (widget.overlayOpacity?.value ?? 0),
                      viewWidth: _viewSize.width,
                      viewHeight: _viewSize.height,
                      heat: widget.heat,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Painter fino: delega ao [Map2DRenderer]; repaint só quando os campos
/// mudam (a view faz dirty check antes de rebuildar).
class _Map2DPainter extends CustomPainter {
  _Map2DPainter({
    required this.renderer,
    required this.targetX,
    required this.targetZ,
    required this.azimuth,
    required this.distance,
    required this.labels,
    required this.icons,
    required this.iconAlphaScale,
    required this.viewWidth,
    required this.viewHeight,
    this.heat = const [],
  });

  final Map2DRenderer renderer;
  final double targetX, targetZ, azimuth, distance, viewWidth, viewHeight;
  final List<LabelCandidate> labels;
  final List<MapIcon> icons;
  final double iconAlphaScale;
  final List<HeatCell> heat;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.paint(
      canvas,
      targetX: targetX,
      targetZ: targetZ,
      azimuth: azimuth,
      pxPerMeter: Map2DRenderer.pxPerMeter(viewHeight, distance),
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      distanceMeters: distance,
      labels: labels,
      icons: icons,
      iconAlphaScale: iconAlphaScale,
      heat: heat,
    );
  }

  @override
  bool shouldRepaint(_Map2DPainter old) =>
      renderer != old.renderer ||
      targetX != old.targetX ||
      targetZ != old.targetZ ||
      azimuth != old.azimuth ||
      distance != old.distance ||
      viewWidth != old.viewWidth ||
      viewHeight != old.viewHeight ||
      iconAlphaScale != old.iconAlphaScale ||
      !identical(labels, old.labels) ||
      !identical(icons, old.icons) ||
      !identical(heat, old.heat);
}
