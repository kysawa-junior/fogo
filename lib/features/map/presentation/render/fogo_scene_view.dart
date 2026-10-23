import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fscene;
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../engine/fogo_engine.dart';
import 'flutter_scene_adapter.dart';

/// Viewport 3D do F.O.G.O.: hospeda o `SceneView` do Flutter Scene,
/// aplica os gestos na câmera orbital do motor e resolve a seleção por
/// raycast (entidade ↔ objeto gráfico é mapeamento do adapter).
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

  @override
  State<FogoSceneView> createState() => _FogoSceneViewState();
}

class _FogoSceneViewState extends State<FogoSceneView> {
  Size _viewSize = Size.zero;
  int? _dragButton;
  Offset _lastPosition = Offset.zero;
  bool _moved = false;

  fscene.PerspectiveCamera _buildCamera(_) {
    final pos = widget.camera.position;
    final target = widget.camera.target;
    return fscene.PerspectiveCamera(
      position: vm.Vector3(pos.x, pos.y, pos.z),
      target: vm.Vector3(target.x, target.y, target.z),
      fovNear: 0.5,
      // Regiões chegam a dezenas de km; o padrão (1000) as corta.
      fovFar: 60000,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _dragButton =
        event.buttons & kMiddleMouseButton != 0 ||
            event.buttons & kSecondaryButton != 0
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
    if (_dragButton == 1) {
      widget.camera.rotate(delta.dx, delta.dy);
    } else {
      widget.camera.pan(delta.dx, delta.dy);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.enabled &&
        _dragButton == 1 &&
        !_moved &&
        _viewSize != Size.zero) {
      final camera = _buildCamera(null);
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
    // deltaY positivo = rolagem para baixo = afasta.
    widget.camera.zoom(event.scrollDelta.dy <= 0 ? 1.12 : 1 / 1.12);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerSignal: _onPointerSignal,
          child: fscene.SceneView(
            widget.adapter.scene,
            key: ValueKey(widget.adapter.sceneVersion),
            cameraBuilder: _buildCamera,
          ),
        );
      },
    );
  }
}
