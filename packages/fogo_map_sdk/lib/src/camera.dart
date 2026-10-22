import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

import 'coordinates.dart';
import 'selection.dart';

/// Vertical field of view of the 3D camera, in degrees. Keeps the center
/// scale invariant at any pitch, like mainstream GL map engines.
const double kFogoCameraFovDegrees = 36.87;

/// Maximum camera tilt in degrees. Beyond this the empty horizon dominates
/// the regional coverage and near-plane clipping degrades street legibility.
const double kFogoMaxPitchDegrees = 60;

/// Immutable value passed across the SDK/app camera boundary.
@immutable
class FogoCameraState {
  const FogoCameraState({
    required this.center,
    required this.zoom,
    this.pitch = 0,
    this.bearing = 0,
  });

  factory FogoCameraState.initial() => const FogoCameraState(
    center: FogoCoordinate(-22.2225, -49.8044),
    zoom: 11,
  );

  final FogoCoordinate center;
  final double zoom;

  /// Camera tilt in degrees: 0 is top-down, up to [kFogoMaxPitchDegrees].
  final double pitch;

  /// Camera rotation clockwise from north, normalized to [0, 360).
  final double bearing;

  static double _normalizeBearing(double value) {
    if (!value.isFinite) return 0;
    return (value % 360 + 360) % 360;
  }

  FogoCameraState copyWith({
    FogoCoordinate? center,
    double? zoom,
    double? pitch,
    double? bearing,
  }) => FogoCameraState(
    center: center ?? this.center,
    zoom: zoom ?? this.zoom,
    pitch: pitch ?? this.pitch,
    bearing: _normalizeBearing(bearing ?? this.bearing),
  );

  @override
  bool operator ==(Object other) =>
      other is FogoCameraState &&
      other.center == center &&
      other.zoom == zoom &&
      other.pitch == pitch &&
      other.bearing == bearing;

  @override
  int get hashCode => Object.hash(center, zoom, pitch, bearing);

  @override
  String toString() =>
      'FogoCameraState($center, zoom: $zoom, pitch: $pitch, bearing: $bearing)';
}

/// True 3D pinhole camera over the Web Mercator ground plane.
///
/// Ground points live in "ground pixels": Web Mercator metres scaled by the
/// current zoom and measured relative to the camera center, east in `dx` and
/// north in `dy`. Heights use the same unit. The center point projects to the
/// viewport center at 1:1 scale at every pitch, so 2D zoom semantics are
/// unchanged when pitch is 0.
@immutable
class FogoCameraTransform {
  FogoCameraTransform(this.camera, this.viewport) {
    if (!camera.center.isValid ||
        !camera.zoom.isFinite ||
        !camera.pitch.isFinite ||
        !camera.bearing.isFinite ||
        camera.pitch < 0 ||
        camera.pitch > kFogoMaxPitchDegrees ||
        !viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width < 0 ||
        viewport.height < 0) {
      throw ArgumentError('Camera transform requires finite camera and size');
    }
  }

  final FogoCameraState camera;
  final Size viewport;

  /// Screen pixels per Web Mercator metre at the current zoom.
  double get scale =>
      256 *
      math.pow(2, camera.zoom).toDouble() /
      FogoProjection.worldCircumference;

  double get _tanHalfFov => math.tan(kFogoCameraFovDegrees * math.pi / 360);

  double get _pitchRad => camera.pitch * math.pi / 180;
  double get _bearingRad => camera.bearing * math.pi / 180;

  /// Pinhole distance from the camera to the center ground point, in ground
  /// pixels. Depends only on viewport height, so zoom keeps its 2D meaning.
  double get centerDepth {
    final double half = math.max(1.0, viewport.height / 2);
    return half / _tanHalfFov;
  }

  /// Focal length in screen pixels; equals [centerDepth] so the center keeps
  /// 1:1 ground-to-screen scale.
  double get focalLength => centerDepth;

  double get nearPlane => math.max(1.0, 0.02 * centerDepth);

  /// Ground-plane pixel offset of a coordinate relative to the camera
  /// center. This is the shared basis for road surfaces and extrusions.
  Offset groundOffset(FogoCoordinate coordinate) {
    final Offset world = FogoProjection.project(coordinate);
    final Offset center = FogoProjection.project(camera.center);
    return Offset(
      (world.dx - center.dx) * scale,
      (world.dy - center.dy) * scale,
    );
  }

  /// Converts a height in metres to ground pixels (Mercator stretch
  /// included) so extrusions match the ground scale at this latitude.
  double heightToPixels(double meters) {
    final double latitude = camera.center.latitude * math.pi / 180;
    return meters * scale / math.cos(latitude);
  }

  /// Applies the bearing rotation to a ground point. Returns
  /// `(east, north, height)` in the rotated camera basis where north is
  /// screen-up.
  (double, double, double) rotateGround(Offset ground, double height) {
    final double b = _bearingRad;
    final double ca = math.cos(b);
    final double sa = math.sin(b);
    return (
      ca * ground.dx - sa * ground.dy,
      sa * ground.dx + ca * ground.dy,
      height,
    );
  }

  double rotatedDepth(double north, double height) {
    final double p = _pitchRad;
    return centerDepth + north * math.sin(p) - height * math.cos(p);
  }

  /// Projects a rotated ground point to the screen; null when at or behind
  /// the near plane.
  Offset? projectRotated(double east, double north, double height) {
    final double depth = rotatedDepth(north, height);
    if (depth <= nearPlane) return null;
    final double p = _pitchRad;
    final double up = north * math.cos(p) + height * math.sin(p);
    return Offset(
      viewport.width / 2 + focalLength * east / depth,
      viewport.height / 2 - focalLength * up / depth,
    );
  }

  /// Screen position of a ground coordinate at zero height; null behind the
  /// camera.
  Offset? project(FogoCoordinate coordinate) {
    final Offset ground = groundOffset(coordinate);
    final (double, double, double) rotated = rotateGround(ground, 0);
    return projectRotated(rotated.$1, rotated.$2, rotated.$3);
  }

  /// Projects one ground-pixel point (with optional height in ground pixels)
  /// to the screen; null behind the near plane.
  Offset? projectGround(Offset ground, [double height = 0]) {
    final (double, double, double) rotated = rotateGround(ground, height);
    return projectRotated(rotated.$1, rotated.$2, rotated.$3);
  }

  /// Screen position of an absolute Web Mercator point (in metres) at
  /// [height] ground pixels. Shared by the pan-stable surface pipeline.
  Offset? projectMeters(Offset meters, [double height = 0]) {
    final Offset center = FogoProjection.project(camera.center);
    return projectGround(
      Offset((meters.dx - center.dx) * scale, (meters.dy - center.dy) * scale),
      height,
    );
  }

  /// Camera-space depth of an absolute-mercator point on the ground; used
  /// for painter's-algorithm ordering of extrusions.
  double metersDepth(Offset meters) {
    final Offset center = FogoProjection.project(camera.center);
    final (double, double, double) rotated = rotateGround(
      Offset((meters.dx - center.dx) * scale, (meters.dy - center.dy) * scale),
      0,
    );
    return rotatedDepth(rotated.$2, rotated.$3);
  }

  /// Near-plane-clipped screen runs of an absolute-mercator-metre polyline
  /// at a constant height in ground pixels.
  List<List<Offset>> projectMetersPolyline(
    List<Offset> meters, [
    double height = 0,
  ]) {
    final Offset center = FogoProjection.project(camera.center);
    return projectGroundPolyline([
      for (final Offset point in meters)
        Offset((point.dx - center.dx) * scale, (point.dy - center.dy) * scale),
    ], height);
  }

  /// Near-plane-clipped screen polygon for absolute-mercator-metre input;
  /// null when nothing remains in front of the near plane.
  List<Offset>? projectMetersPolygon(List<Offset> meters, [double height = 0]) {
    final Offset center = FogoProjection.project(camera.center);
    return projectGroundPolygon([
      for (final Offset point in meters)
        Offset((point.dx - center.dx) * scale, (point.dy - center.dy) * scale),
    ], height);
  }

  /// Projects a ground polyline, clipping each segment against the near
  /// plane. Returns screen-space runs; a new run starts after a fully
  /// clipped segment, so pitched views stay continuous where visible.
  List<List<Offset>> projectGroundPolyline(
    List<Offset> ground, [
    double height = 0,
  ]) {
    if (ground.length < 2) return const [];
    // Clip slightly above the near plane so the interpolated endpoint still
    // projects (points exactly at nearPlane are rejected as degenerate).
    final double near = nearPlane * 1.01;
    final List<List<Offset>> runs = [];
    List<Offset> run = [];
    for (int i = 0; i < ground.length - 1; i++) {
      final (double, double, double) a = rotateGround(ground[i], height);
      final (double, double, double) b = rotateGround(ground[i + 1], height);
      final double depthA = rotatedDepth(a.$2, a.$3);
      final double depthB = rotatedDepth(b.$2, b.$3);
      if (depthA <= near && depthB <= near) {
        if (run.isNotEmpty) runs.add(run);
        run = [];
        continue;
      }
      (double, double, double) start = a;
      (double, double, double) end = b;
      if (depthA <= near || depthB <= near) {
        final double t = (near - depthA) / (depthB - depthA);
        if (depthA <= near) {
          start = _lerpRotated(a, b, t.clamp(0, 1));
        } else {
          end = _lerpRotated(a, b, t.clamp(0, 1));
        }
      }
      final Offset? screenStart = projectRotated(start.$1, start.$2, start.$3);
      final Offset? screenEnd = projectRotated(end.$1, end.$2, end.$3);
      if (screenStart == null || screenEnd == null) {
        if (run.isNotEmpty) runs.add(run);
        run = [];
        continue;
      }
      if (run.isEmpty) {
        run.add(screenStart);
      } else if ((run.last - screenStart).distance > 0.01) {
        runs.add(run);
        run = [screenStart];
      }
      run.add(screenEnd);
    }
    if (run.length >= 2) runs.add(run);
    return runs;
  }

  /// Projects a closed ground polygon, clipped against the near plane with
  /// Sutherland–Hodgman so large features stay visible in pitched views
  /// instead of being dropped when one corner falls behind the camera.
  /// Null only when nothing remains in front of the near plane.
  List<Offset>? projectGroundPolygon(List<Offset> ground, [double height = 0]) {
    if (ground.length < 3) return null;
    final double near = nearPlane * 4;
    List<(double, double, double)> polygon = [
      for (final Offset point in ground) rotateGround(point, height),
    ];
    final List<(double, double, double)> clipped = [];
    for (int i = 0; i < polygon.length; i++) {
      final (double, double, double) a = polygon[i];
      final (double, double, double) b = polygon[(i + 1) % polygon.length];
      final double depthA = rotatedDepth(a.$2, a.$3);
      final double depthB = rotatedDepth(b.$2, b.$3);
      final bool aIn = depthA >= near;
      final bool bIn = depthB >= near;
      if (aIn) clipped.add(a);
      if (aIn != bIn) {
        clipped.add(_lerpRotated(a, b, (near - depthA) / (depthB - depthA)));
      }
    }
    if (clipped.length < 3) return null;
    final List<Offset> screen = [];
    for (final (double, double, double) point in clipped) {
      final Offset? projected = projectRotated(point.$1, point.$2, point.$3);
      if (projected == null) return null;
      screen.add(projected);
    }
    return screen;
  }

  /// Inverse transform: screen point to the ground coordinate. Null when
  /// the ray meets the horizon before the ground (possible at high pitch).
  FogoCoordinate? unproject(Offset screenPosition) {
    final double dx = (screenPosition.dx - viewport.width / 2) / focalLength;
    final double dy = (viewport.height / 2 - screenPosition.dy) / focalLength;
    final double denom = 1 - dy * math.tan(_pitchRad);
    if (denom <= 1e-6) return null;
    final double depth = centerDepth / denom;
    final double east = dx * depth;
    final double north = dy * depth / math.cos(_pitchRad);
    final double b = _bearingRad;
    final double ca = math.cos(b);
    final double sa = math.sin(b);
    final Offset ground = Offset(
      ca * east + sa * north,
      -sa * east + ca * north,
    );
    final Offset center = FogoProjection.project(camera.center);
    return FogoProjection.unproject(
      Offset(center.dx + ground.dx / scale, center.dy + ground.dy / scale),
    );
  }

  /// Conservative geographic bounds of what may be visible. At pitch the
  /// far side of the viewport extends toward the horizon, so top-edge
  /// samples and a bearing-direction far cap are included.
  FogoGeoBounds get visibleBounds {
    final double width = viewport.width;
    final double height = viewport.height;
    final List<FogoCoordinate> points = [];
    for (final Offset corner in [
      Offset.zero,
      Offset(width, 0),
      Offset(width, height),
      Offset(0, height),
    ]) {
      final FogoCoordinate? hit = unproject(corner);
      if (hit != null) points.add(hit);
    }
    // Sample the top edge moving down until rays hit the ground; pitched
    // views push the visible ground far toward the bearing.
    for (final double fraction in [0.0, 0.12, 0.25, 0.4]) {
      for (final double x in [width * 0.15, width * 0.5, width * 0.85]) {
        final FogoCoordinate? hit = unproject(Offset(x, height * fraction));
        if (hit != null) points.add(hit);
      }
    }
    // Far cap along the bearing for rays that never reach the ground.
    final double capPx = 2.6 * centerDepth;
    final double b = _bearingRad;
    final double p = _pitchRad;
    final double reachPx = capPx * math.sin(p);
    final double capMeters = math.min(
      reachPx / math.max(scale, 1e-9),
      40000000,
    );
    final Offset center = FogoProjection.project(camera.center);
    final FogoCoordinate far = FogoProjection.unproject(
      Offset(
        center.dx + math.sin(b) * capMeters,
        center.dy + math.cos(b) * capMeters,
      ),
    );
    points.add(far);
    points.add(camera.center);
    return FogoGeoBounds(
      west: points.map((point) => point.longitude).reduce(math.min),
      south: points.map((point) => point.latitude).reduce(math.min),
      east: points.map((point) => point.longitude).reduce(math.max),
      north: points.map((point) => point.latitude).reduce(math.max),
    );
  }

  static (double, double, double) _lerpRotated(
    (double, double, double) a,
    (double, double, double) b,
    double t,
  ) => (
    a.$1 + (b.$1 - a.$1) * t,
    a.$2 + (b.$2 - a.$2) * t,
    a.$3 + (b.$3 - a.$3) * t,
  );
}

/// Owns camera commands and emits immutable state and selection events.
/// The app owns persistence; pitch and bearing are not persisted.
class FogoMapController extends ChangeNotifier {
  FogoMapController({
    FogoCameraState? initialCamera,
    this.minZoom = 3,
    this.maxZoom = 19,
  }) : _camera = initialCamera ?? FogoCameraState.initial() {
    if (!minZoom.isFinite || !maxZoom.isFinite || minZoom > maxZoom) {
      throw ArgumentError('Invalid zoom range');
    }
    _validateCamera(_camera);
  }

  final double minZoom;
  final double maxZoom;
  FogoCameraState _camera;
  Size _viewport = Size.zero;
  final StreamController<FogoCameraState> _cameraEvents =
      StreamController<FogoCameraState>.broadcast();
  final StreamController<FogoMapSelection> _selectionEvents =
      StreamController<FogoMapSelection>.broadcast();

  FogoCameraState get camera => _camera;
  Stream<FogoCameraState> get cameraEvents => _cameraEvents.stream;
  Stream<FogoMapSelection> get selectionEvents => _selectionEvents.stream;

  /// Called by [FogoMapView] during layout; useful to callers that also
  /// exercise projection commands outside the widget tree.
  void updateViewportSize(Size size) {
    if (size.width.isFinite &&
        size.height.isFinite &&
        size.width >= 0 &&
        size.height >= 0) {
      _viewport = size;
    }
  }

  FogoCameraTransform get transform => FogoCameraTransform(_camera, _viewport);

  Offset? coordinateToScreen(FogoCoordinate coordinate) =>
      _hasViewport ? transform.project(coordinate) : null;

  FogoCoordinate? screenToCoordinate(Offset screenPosition) =>
      _hasViewport ? transform.unproject(screenPosition) : null;

  bool get _hasViewport => _viewport.width > 0 && _viewport.height > 0;

  void moveTo(FogoCoordinate center, {double? zoom}) {
    _setCamera(
      _camera.copyWith(
        center: center,
        zoom: zoom?.clamp(minZoom, maxZoom).toDouble(),
      ),
    );
  }

  void setCamera(FogoCameraState state) {
    // NaN zoom must not silently clamp (double.clamp treats NaN as
    // greater than every limit), so finiteness is checked explicitly.
    if (!state.center.isValid || !state.zoom.isFinite) {
      throw ArgumentError.value(state, 'camera', 'Invalid camera state');
    }
    _setCamera(
      state.copyWith(zoom: state.zoom.clamp(minZoom, maxZoom).toDouble()),
    );
  }

  /// Tilts the camera, clamped to [kFogoMaxPitchDegrees].
  void setPitch(double degrees) {
    if (!degrees.isFinite) return;
    _setCamera(_camera.copyWith(pitch: degrees.clamp(0, kFogoMaxPitchDegrees)));
  }

  /// Rotates the camera clockwise, in degrees, normalized to [0, 360).
  void setBearing(double degrees) {
    if (!degrees.isFinite) return;
    _setCamera(_camera.copyWith(bearing: degrees));
  }

  void rotateBy(double deltaDegrees) =>
      setBearing(_camera.bearing + deltaDegrees);

  void panByScreenDelta(Offset pointerDelta) {
    if (!_hasViewport ||
        !pointerDelta.dx.isFinite ||
        !pointerDelta.dy.isFinite) {
      return;
    }
    // Content follows the pointer: the ground under (center - delta) moves
    // to the center. High pitch can push that ray above the horizon, so the
    // vertical component shrinks until the ray lands.
    Offset target = Offset(
      _viewport.width / 2 - pointerDelta.dx,
      _viewport.height / 2 - pointerDelta.dy,
    );
    FogoCoordinate? hit = transform.unproject(target);
    if (hit == null) {
      for (double shrink = 0.75; shrink >= 0.05; shrink -= 0.25) {
        hit = transform.unproject(
          Offset(
            _viewport.width / 2 - pointerDelta.dx * shrink,
            _viewport.height / 2 - pointerDelta.dy * shrink,
          ),
        );
        if (hit != null) break;
      }
    }
    if (hit != null) _setCamera(_camera.copyWith(center: hit));
  }

  /// Zoom by powers of two, keeping [focalPoint] fixed on screen when
  /// possible. Anchor correction runs twice so it holds at any pitch and
  /// bearing.
  void zoomBy(double delta, {Offset? focalPoint}) {
    if (!delta.isFinite) return;
    final double zoom = (_camera.zoom + delta)
        .clamp(minZoom, maxZoom)
        .toDouble();
    if (zoom == _camera.zoom) return;
    if (!_hasViewport || focalPoint == null) {
      _setCamera(_camera.copyWith(zoom: zoom));
      return;
    }
    final FogoCoordinate? anchor = transform.unproject(focalPoint);
    _setCamera(_camera.copyWith(zoom: zoom));
    if (anchor == null) return;
    // Perspective at pitch makes each linear correction partial, so iterate
    // until the anchor is pinned within a fraction of a pixel.
    for (int i = 0; i < 6; i++) {
      final Offset? screen = transform.project(anchor);
      if (screen == null) break;
      final Offset error = screen - focalPoint;
      if (error.distance < 0.05) break;
      // Content must move opposite to the anchor drift to re-pin it.
      panByScreenDelta(-error);
    }
  }

  void fitBounds(FogoGeoBounds bounds, {EdgeInsets padding = EdgeInsets.zero}) {
    if (!bounds.isValid || !_hasViewport) return;
    final double paddedWidth = math.max(
      1,
      _viewport.width - padding.left - padding.right,
    );
    final double paddedHeight = math.max(
      1,
      _viewport.height - padding.top - padding.bottom,
    );
    // Fit uses the top-down projection: pitch and bearing stay untouched.
    final Offset southWest = FogoProjection.project(
      FogoCoordinate(bounds.south, bounds.west),
    );
    final Offset northEast = FogoProjection.project(
      FogoCoordinate(bounds.north, bounds.east),
    );
    final double fitScale = math.min(
      paddedWidth / (northEast.dx - southWest.dx),
      paddedHeight / (northEast.dy - southWest.dy),
    );
    final double zoom =
        (math.log(fitScale * FogoProjection.worldCircumference / 256) /
                math.ln2)
            .clamp(minZoom, maxZoom)
            .toDouble();
    final double s =
        256 * math.pow(2, zoom).toDouble() / FogoProjection.worldCircumference;
    // Shift the camera so the bounds midpoint lands at the center of the
    // padded rectangle, not the raw viewport center.
    final double offsetX = (padding.left - padding.right) / 2;
    final double offsetY = (padding.top - padding.bottom) / 2;
    final Offset middle = Offset(
      (southWest.dx + northEast.dx) / 2,
      (southWest.dy + northEast.dy) / 2,
    );
    _setCamera(
      _camera.copyWith(
        center: FogoProjection.unproject(
          Offset(middle.dx - offsetX / s, middle.dy + offsetY / s),
        ),
        zoom: zoom,
      ),
    );
  }

  void selectAt(
    Offset screenPosition, {
    FogoSelectionSource source = FogoSelectionSource.programmatic,
  }) {
    if (!_hasViewport) return;
    final FogoCoordinate? coordinate = transform.unproject(screenPosition);
    if (coordinate == null) return;
    _selectionEvents.add(
      FogoMapSelection(
        coordinate: coordinate,
        screenPosition: screenPosition,
        source: source,
      ),
    );
  }

  void _setCamera(FogoCameraState next) {
    _validateCamera(next);
    if (_camera == next) return;
    _camera = next;
    notifyListeners();
    _cameraEvents.add(next);
  }

  void _validateCamera(FogoCameraState camera) {
    if (!camera.center.isValid ||
        !camera.zoom.isFinite ||
        camera.zoom < minZoom ||
        camera.zoom > maxZoom ||
        !camera.pitch.isFinite ||
        camera.pitch < 0 ||
        camera.pitch > kFogoMaxPitchDegrees ||
        !camera.bearing.isFinite) {
      throw ArgumentError.value(camera, 'camera', 'Invalid camera state');
    }
  }

  @override
  void dispose() {
    _cameraEvents.close();
    _selectionEvents.close();
    super.dispose();
  }
}
