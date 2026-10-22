import 'package:flutter/widgets.dart';

import 'data.dart';

enum FogoRoadFilterGroup {
  main,
  primary,
  secondary,
  tertiary,
  local,
  service,
  rural,
}

/// F.O.G.O.-owned night palette v3, tuned toward the Mapbox Standard night
/// appearance: near-black blue land, dark navy water, and light desaturated
/// road ribbons that read against the land instead of sinking into it. The
/// tokens are F.O.G.O.'s own; nothing is copied from Mapbox's style JSON.
class FogoMapStyle {
  FogoMapStyle({
    this.background = const Color(0xFF0D0F14),
    this.water = const Color(0xFF0B1726),
    this.green = const Color(0xFF0F1815),
    this.farmland = const Color(0xFF0D130E),
    this.building = const Color(0xFF1B1E26),
    this.buildingStroke = const Color(0xFF2A2E39),
    this.buildingWallLit = const Color(0xFF232733),
    this.buildingWallDark = const Color(0xFF14161D),
    this.boundary = const Color(0xFF262A33),
    this.roadCasing = const Color(0xFF0D0F14),
    this.roadCasingBridge = const Color(0xFF0D0F14),
    this.roadMotorway = const Color(0xFF585F6E),
    this.roadTrunk = const Color(0xFF505663),
    this.roadPrimary = const Color(0xFF474D59),
    this.roadSecondary = const Color(0xFF3D434E),
    this.roadTertiary = const Color(0xFF353B46),
    this.roadUnclassified = const Color(0xFF2A2F3A),
    this.roadResidential = const Color(0xFF2A2F3A),
    this.roadService = const Color(0xFF22262F),
    this.roadTrack = const Color(0xFF1C2028),
    this.roadPath = const Color(0xFF171A21),
    this.railBed = const Color(0xFF232732),
    this.railTie = const Color(0xFF3A3F4C),
    this.railDisused = const Color(0xFF1A1E27),
    this.waterLine = const Color(0xFF12283F),
    this.onewayArrow = const Color(0xFF8E94A3),
    this.shieldBg = const Color(0xFF1B1E26),
    this.shieldBorder = const Color(0xFF3A3F4C),
    this.shieldText = const Color(0xFFDDE0E8),
    this.labelRoad = const Color(0xFFC6CBD6),
    this.labelCity = const Color(0xFFDDE0E8),
    this.labelSuburb = const Color(0xFF9096A5),
    this.labelPoi = const Color(0xFF9096A5),
    this.labelHalo = const Color(0xFF0D0F14),
    this.poiDot = const Color(0xFF7C8292),
    this.showAreas = true,
    this.showWaterLines = true,
    this.showRail = true,
    this.showRoads = true,
    this.showBuildings = true,
    this.showPois = true,
    this.showLabels = true,
    this.showAttribution = true,
    this.estimateBuildingHeights = true,
    Set<FogoRoadFilterGroup> roadFilter = const {},
  }) : roadFilter = Set.unmodifiable(roadFilter);

  static final FogoMapStyle fogoNight = FogoMapStyle();

  final Color background;
  final Color water;
  final Color green;
  final Color farmland;
  final Color building;
  final Color buildingStroke;

  /// Extrusion wall shades for the fixed northwest light; the roof keeps
  /// [building] and the lit wall reads slightly above it, like Mapbox's
  /// night extrusions.
  final Color buildingWallLit;
  final Color buildingWallDark;
  final Color boundary;
  final Color roadCasing;
  final Color roadCasingBridge;
  final Color roadMotorway;
  final Color roadTrunk;
  final Color roadPrimary;
  final Color roadSecondary;
  final Color roadTertiary;
  final Color roadUnclassified;
  final Color roadResidential;
  final Color roadService;
  final Color roadTrack;
  final Color roadPath;
  final Color railBed;
  final Color railTie;
  final Color railDisused;
  final Color waterLine;
  final Color onewayArrow;
  final Color shieldBg;
  final Color shieldBorder;
  final Color shieldText;
  final Color labelRoad;
  final Color labelCity;
  final Color labelSuburb;
  final Color labelPoi;
  final Color labelHalo;
  final Color poiDot;
  final bool showAreas;
  final bool showWaterLines;
  final bool showRail;
  final bool showRoads;
  final bool showBuildings;
  final bool showPois;
  final bool showLabels;
  final bool showAttribution;

  /// When true, buildings without an explicit OSM `height` extrude using
  /// deterministic display-only estimates (ADR-0005). Cell data is never
  /// modified; set false to extrude only real heights.
  final bool estimateBuildingHeights;
  final Set<FogoRoadFilterGroup> roadFilter;

  bool roadClassVisible(FogoRoadClass roadClass) {
    if (roadFilter.isEmpty) return true;
    return switch (roadClass) {
      FogoRoadClass.motorway ||
      FogoRoadClass.trunk => roadFilter.contains(FogoRoadFilterGroup.main),
      FogoRoadClass.primary => roadFilter.contains(FogoRoadFilterGroup.primary),
      FogoRoadClass.secondary => roadFilter.contains(
        FogoRoadFilterGroup.secondary,
      ),
      FogoRoadClass.tertiary => roadFilter.contains(
        FogoRoadFilterGroup.tertiary,
      ),
      FogoRoadClass.unclassified || FogoRoadClass.residential =>
        roadFilter.contains(FogoRoadFilterGroup.local),
      FogoRoadClass.service ||
      FogoRoadClass.other => roadFilter.contains(FogoRoadFilterGroup.service),
      FogoRoadClass.track ||
      FogoRoadClass.path => roadFilter.contains(FogoRoadFilterGroup.rural),
    };
  }

  Color roadColor(FogoRoadClass roadClass) => switch (roadClass) {
    FogoRoadClass.motorway => roadMotorway,
    FogoRoadClass.trunk => roadTrunk,
    FogoRoadClass.primary => roadPrimary,
    FogoRoadClass.secondary => roadSecondary,
    FogoRoadClass.tertiary => roadTertiary,
    FogoRoadClass.unclassified || FogoRoadClass.other => roadUnclassified,
    FogoRoadClass.residential => roadResidential,
    FogoRoadClass.service => roadService,
    FogoRoadClass.track => roadTrack,
    FogoRoadClass.path => roadPath,
  };
}
