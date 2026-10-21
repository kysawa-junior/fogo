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

/// F.O.G.O.-owned low-saturation night palette and existing layer controls.
/// Colors follow the current F.O.G.O. map palette; they are not Mapbox tokens.
class FogoMapStyle {
  FogoMapStyle({
    this.background = const Color(0xFF01010A),
    this.water = const Color(0xFF0A1727),
    this.green = const Color(0xFF101A19),
    this.farmland = const Color(0xFF0D130D),
    this.building = const Color(0xFF191927),
    this.buildingStroke = const Color(0xFF292938),
    this.boundary = const Color(0xFF292938),
    this.roadCasing = const Color(0xFF01010A),
    this.roadCasingBridge = const Color(0xFF01010A),
    this.roadMotorway = const Color(0xFF0E0E18),
    this.roadTrunk = const Color(0xFF0B0B15),
    this.roadPrimary = const Color(0xFF080812),
    this.roadSecondary = const Color(0xFF060610),
    this.roadTertiary = const Color(0xFF04040F),
    this.roadUnclassified = const Color(0xFF01010E),
    this.roadResidential = const Color(0xFF01010E),
    this.roadService = const Color(0xFF01010E),
    this.roadTrack = const Color(0xFF01010E),
    this.roadPath = const Color(0xFF01010E),
    this.railBed = const Color(0xFF20202E),
    this.railTie = const Color(0xFF343443),
    this.railDisused = const Color(0xFF181824),
    this.waterLine = const Color(0xFF0F2036),
    this.onewayArrow = const Color(0xFF85859A),
    this.shieldBg = const Color(0xFF191927),
    this.shieldBorder = const Color(0xFF343443),
    this.shieldText = const Color(0xFFD5D5E0),
    this.labelRoad = const Color(0xFFC9C9D8),
    this.labelCity = const Color(0xFFD5D5E0),
    this.labelSuburb = const Color(0xFF85859A),
    this.labelPoi = const Color(0xFF85859A),
    this.labelHalo = const Color(0xFF01010A),
    this.poiDot = const Color(0xFF74748A),
    this.showAreas = true,
    this.showWaterLines = true,
    this.showRail = true,
    this.showRoads = true,
    this.showBuildings = true,
    this.showPois = true,
    this.showLabels = true,
    this.showAttribution = true,
    Set<FogoRoadFilterGroup> roadFilter = const {},
  }) : roadFilter = Set.unmodifiable(roadFilter);

  static final FogoMapStyle fogoNight = FogoMapStyle();

  final Color background;
  final Color water;
  final Color green;
  final Color farmland;
  final Color building;
  final Color buildingStroke;
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
