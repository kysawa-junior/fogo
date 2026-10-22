import 'package:flutter/widgets.dart';

/// Estilo cartográfico F.O.G.O. v5 — paleta noturna inspirada no Mapbox
/// Standard night (ADR-0005): terreno azul quase preto, água azul-escura e
/// vias em fitas claras dessaturadas que LÊEM contra o terreno, em vez de
/// afundar nele (hierarquia invertida da v4). Extrusões 3D usam paredes
/// duas-tones com luz fixa a noroeste.
///
/// Os tokens são próprios do F.O.G.O.; nada é copiado do estilo Mapbox.
abstract final class FogoMapStyle {
  // Fundo — azul quase preto
  static const Color mapCanvas = Color(0xFF0D0F14);

  // Áreas naturais
  static const Color water = Color(0xFF0B1726);
  static const Color green = Color(0xFF0F1815);
  static const Color farmland = Color(0xFF0D130E);

  // Edificações: telhado + contorno; paredes lit/dark ficam no SDK
  static const Color building = Color(0xFF1B1E26);
  static const Color buildingStroke = Color(0xFF2A2E39);

  // Limites territoriais
  static const Color boundary = Color(0xFF262A33);

  // Vias: casing no fundo (halo) + hierarquia clara do motorway ao path
  static const Color roadCasing = Color(0xFF0D0F14);
  static const Color roadCasingBridge = Color(0xFF0D0F14);
  static const Color roadMotorway = Color(0xFF585F6E);
  static const Color roadTrunk = Color(0xFF505663);
  static const Color roadPrimary = Color(0xFF474D59);
  static const Color roadSecondary = Color(0xFF3D434E);
  static const Color roadTertiary = Color(0xFF353B46);
  static const Color roadUnclassified = Color(0xFF2A2F3A);
  static const Color roadResidential = Color(0xFF2A2F3A);
  static const Color roadService = Color(0xFF22262F);
  static const Color roadTrack = Color(0xFF1C2028);
  static const Color roadPath = Color(0xFF171A21);

  // Ferrovia: ativa (leito + dormentes)
  static const Color railBed = Color(0xFF232732);
  static const Color railTie = Color(0xFF3A3F4C);

  // Água linear (rios/córregos)
  static const Color waterLine = Color(0xFF12283F);

  // Direções / anotações de via
  static const Color onewayArrow = Color(0xFF8E94A3);
  static const Color shieldBg = Color(0xFF1B1E26);
  static const Color shieldBorder = Color(0xFF3A3F4C);
  static const Color shieldText = Color(0xFFDDE0E8);

  // Rótulos — claros, com halo na cor do fundo
  static const Color labelRoad = Color(0xFFC6CBD6);
  static const Color labelCity = Color(0xFFDDE0E8);
  static const Color labelSuburb = Color(0xFF9096A5);
  static const Color labelPoi = Color(0xFF9096A5);
  static const Color labelHalo = Color(0xFF0D0F14);
  static const Color poiDot = Color(0xFF7C8292);
}
