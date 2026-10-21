import 'package:flutter/widgets.dart';

import 'coordinates.dart';

/// Geographic polyline painted above local OSM features.
class FogoMapPolyline {
  FogoMapPolyline({
    required this.id,
    required List<FogoCoordinate> points,
    required this.color,
    required this.width,
    this.borderColor,
    this.borderWidth = 0,
    List<double> dashPattern = const [],
  }) : points = List.unmodifiable(points),
       dashPattern = List.unmodifiable(dashPattern) {
    if (id.isEmpty || points.length < 2 || !width.isFinite || width <= 0) {
      throw ArgumentError(
        'A polyline needs an id, two points and positive width',
      );
    }
    if (points.any((point) => !point.isValid)) {
      throw ArgumentError('Polyline contains an invalid coordinate');
    }
    if (!borderWidth.isFinite || borderWidth < 0) {
      throw ArgumentError.value(borderWidth, 'borderWidth');
    }
    if (dashPattern.any((value) => !value.isFinite || value <= 0)) {
      throw ArgumentError('Dash lengths must be finite and positive');
    }
  }

  final String id;
  final List<FogoCoordinate> points;
  final Color color;
  final double width;
  final Color? borderColor;
  final double borderWidth;

  /// Alternating on/off pixel lengths, for example `[12, 9]`.
  final List<double> dashPattern;
}

/// Widget marker anchored to a geographic coordinate using the map transform.
class FogoMapMarker {
  const FogoMapMarker({
    required this.id,
    required this.coordinate,
    required this.child,
    this.width = 24,
    this.height = 24,
    this.alignment = Alignment.center,
  });

  final String id;
  final FogoCoordinate coordinate;
  final Widget child;
  final double width;
  final double height;
  final Alignment alignment;
}
