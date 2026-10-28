import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fscene;
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../engine/fogo_engine.dart';
import 'flutter_scene_adapter.dart';

/// Viewport 3D do F.O.G.O. — CAMADA DINÂMICA sobre a base 2D permanente:
/// hospeda o `SceneView` do Flutter Scene, aplica os gestos na câmera
/// orbital do motor (o AMORTECIMENTO — `camera.tick` — pertence ao
/// ticker do Map2DView, sempre ativo; este widget só OBSERVA) e resolve
/// a seleção por raycast.
///
/// Controles: arrastar (esquerdo) orbita; botão direito/meio move o
/// chão; rolagem aproxima DO PONTO SOB O CURSOR; clique seleciona.
class FogoSceneView extends StatefulWidget {
  const FogoSceneView({
    super.key,
    required this.adapter,
    required this.camera,
    required this.onEntityPicked,
    this.enabled = true,
  });

  final FlutterSceneAdapter adapter;
  final OrbitCamera camera;
  final void Function(String entityId) onEntityPicked;
  final bool enabled;

  // Rótulos UI NÃO existem no 3D: nomes de via são decals de cena
  // (MapScene.annotations); no 2D são pintados no canvas do renderer.

  @override
  State<FogoSceneView> createState() => _FogoSceneViewState();
}

class _FogoSceneViewState extends State<FogoSceneView> {
  Size _viewSize = Size.zero;
  int? _dragButton;
  Offset _lastPosition = Offset.zero;
  bool _moved = false;

  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  bool _wasdActive = false;

  /// Snapshot da câmera para o frame do SceneView e para o raycast —
  /// SEM tick (o amortecimento roda no ticker do Map2DView; tickar aqui
  /// dobraria a velocidade).
  fscene.PerspectiveCamera _snapshotCamera() {
    _applyWasd();
    // Limite de vista: tiles fora do raio da câmera nem vão à GPU.
    // (vector_math_64 do motor ≠ vm daqui — converte na fronteira.)
    final t = widget.camera.target;
    final pos = widget.camera.position;
    widget.adapter.updateLOD(
      widget.camera.distanceMeters,
      cullCenter: vm.Vector3(t.x, t.y, t.z),
      elevationRadians: widget.camera.elevationRadians,
      cameraPosition: vm.Vector3(pos.x, pos.y, pos.z),
    );
    // Viaturas: posição/rotação corrente da frota (tickada pelo dono da
    // câmera — Map2DView; aqui só APLICAMOS ao nós da cena).
    widget.adapter.syncVehicles();
    return fscene.PerspectiveCamera(
      position: vm.Vector3(pos.x, pos.y, pos.z),
      target: vm.Vector3(t.x, t.y, t.z),
      fovNear: 0.5,
      // Regiões chegam a dezenas de km; o padrão (1000) as corta.
      fovFar: 60000,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _dragButton =
        event.buttons & kSecondaryButton != 0 ||
            event.buttons & kMiddleMouseButton != 0
        ? 2
        : 1;
    _lastPosition = event.localPosition;
    _moved = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled || _dragButton == null) return;
    final delta = event.localPosition - _lastPosition;
    _lastPosition = event.localPosition;
    if (delta.distanceSquared > 4) _moved = true;
    if (_dragButton == 2) {
      widget.camera.rotate(delta.dx, delta.dy);
    } else {
      widget.camera.pan(-delta.dx, delta.dy);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.enabled &&
        _dragButton == 1 &&
        !_moved &&
        _viewSize != Size.zero) {
      final camera = _snapshotCamera();
      final entityId = widget.adapter.pickEntity(
        event.localPosition,
        _viewSize,
        camera,
      );
      if (entityId != null) widget.onEntityPicked(entityId);
    }
    _dragButton = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enabled || event is! PointerScrollEvent) return;
    final camera = _snapshotCamera();
    final factor = event.scrollDelta.dy <= 0 ? 1.15 : 1 / 1.15;

    // Zoom direcionado: interseção do raio do cursor com o plano do
    // solo (y=0). Sem interseção (rasante apontando pro horizonte),
    // zoom simples.
    final ray = camera.screenPointToRay(event.localPosition, _viewSize);
    if (ray.direction.y < -1e-4) {
      final t = -ray.origin.y / ray.direction.y;
      if (t.isFinite && t > 0) {
        widget.camera.zoomToward(
          factor,
          Vector3(
            ray.origin.x + ray.direction.x * t,
            0,
            ray.origin.z + ray.direction.z * t,
          ),
        );
        return;
      }
    }
    widget.camera.zoom(factor);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
    // Velocidade suave: delta fixo de frame (60fps tipico) — progressivo,
    // sem saltos. (O tick amortecido da câmera roda no Map2DView.)
    const dt = 1 / 60;
    const speed = 120.0; // px/s
    var dx = 0.0, dy = 0.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW)) dy += speed * dt;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS)) dy -= speed * dt;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA)) dx -= speed * dt;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD)) dx += speed * dt;
    if (dx != 0 || dy != 0) {
      // Mouse flipa dx; WASD NAO flipa (semantica de camera vs grab).
      widget.camera.pan(dx, dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Focus(
          focusNode: _focusNode,
          onKeyEvent: (_, event) {
            _onKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: Listener(
            onPointerDown: (event) {
              _focusNode.requestFocus();
              _onPointerDown(event);
            },
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerSignal: _onPointerSignal,
            child: fscene.SceneView(
              widget.adapter.scene,
              key: ValueKey(widget.adapter.sceneVersion),
              cameraBuilder: (_) => _snapshotCamera(),
            ),
          ),
        );
      },
    );
  }
}
