import 'package:flutter/widgets.dart';

/// Estilo cartográfico F.O.G.O. v4 — mapa escuro PROFISSIONAL ancorado no
/// fundo padrão do tema (#01010A), com hierarquia visual legível entre
/// ruas, edificações, áreas naturais, hidrografia e rótulos.
///
/// Nenhuma inversão/filtro é aplicada a imagens: as cores são intencionais
/// por feição (dados vetoriais OSM), no padrão de mapas escuros de produto.
///
/// shortcut: sem extrusão 3D até engine com suporte (MapLibre Native).
abstract final class FogoMapStyle {
  // Fundo — cor padrão do tema
  static const Color mapCanvas = Color(0xFF01010A);

  // Áreas naturais — identificáveis, sem competir com as vias
  static const Color water = Color(0xFF0A1727);
  static const Color green = Color(0xFF101A19);
  static const Color farmland = Color(0xFF0D130D);

  // Edificações: preenchimento visível + contorno secundário discreto
  static const Color building = Color(0xFF191927);
  static const Color buildingStroke = Color(0xFF292938);

  // Limites territoriais / contornos secundários
  static const Color boundary = Color(0xFF292938);

  // Vias: casing na cor do fundo + hierarquia escura aprovada para o overlay.
  static const Color roadCasing = Color(0xFF01010A);
  static const Color roadCasingBridge = Color(0xFF01010A);
  static const Color roadMotorway = Color(0xFF0E0E18);
  static const Color roadTrunk = Color(0xFF0B0B15);
  static const Color roadPrimary = Color(0xFF080812);
  static const Color roadSecondary = Color(0xFF060610);
  static const Color roadTertiary = Color(0xFF04040F);
  static const Color roadUnclassified = Color(0xFF01010E);
  static const Color roadResidential = Color(0xFF01010E);
  static const Color roadService = Color(0xFF01010E);
  static const Color roadTrack = Color(0xFF01010E);
  static const Color roadPath = Color(0xFF01010E);

  // Ferrovia: ativa (leito + dormentes) e desativada
  static const Color railBed = Color(0xFF20202E);
  static const Color railTie = Color(0xFF343443);

  // Água linear (rios/córregos)
  static const Color waterLine = Color(0xFF0F2036);

  // Direções / anotações de via
  static const Color onewayArrow = Color(0xFF85859A);
  static const Color shieldBg = Color(0xFF191927);
  static const Color shieldBorder = Color(0xFF343443);
  static const Color shieldText = Color(0xFFD5D5E0);

  // Rótulos — claros, com halo na cor do fundo
  static const Color labelRoad = Color(0xFFC9C9D8);
  static const Color labelCity = Color(0xFFD5D5E0);
  static const Color labelSuburb = Color(0xFF85859A);
  static const Color labelPoi = Color(0xFF85859A);
  static const Color labelHalo = Color(0xFF01010A);
  static const Color poiDot = Color(0xFF74748A);
}
