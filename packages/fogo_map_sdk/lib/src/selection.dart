import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'coordinates.dart';

enum FogoSelectionSource { secondaryClick, longPress, programmatic }

/// A map coordinate selected by a pointer or through the controller.
@immutable
class FogoMapSelection {
  const FogoMapSelection({
    required this.coordinate,
    required this.screenPosition,
    required this.source,
  });

  final FogoCoordinate coordinate;
  final Offset screenPosition;
  final FogoSelectionSource source;
}
