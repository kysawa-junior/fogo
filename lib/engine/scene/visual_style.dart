import 'package:vector_math/vector_math_64.dart';

/// Modo de iluminação da cena (ETAPA 07).
enum SceneLightingMode {
  /// Noturno (identidade original): UnlitMaterial + sombreamento de
  /// fachadas por vertex colors — o estilo atual do F.O.G.O.
  night,

  /// Diurno: PhysicallyBasedMaterial com a MESMA paleta base +
  /// DirectionalLight real — volumes, sombras e profundidade por luz
  /// dinâmica, sem alterar nenhuma cor da identidade.
  day,
}

/// Configuração visual centralizada do F.O.G.O. 3D (estética cartográfica
/// limpa; paleta permanece em [FogoPalette]). Todos os valores de
/// sombreamento/volumetria moram AQUI — nunca espalhados nos builders.
class Fogo3DStyle {
  const Fogo3DStyle({
    this.buildJunctionPads = true,
    this.padLiftMeters = 0.04,
    this.padMinAreaMeters = 0.5,
    this.padCornerLimitFactor = 2.0,
    this.wallAmbient = 0.55,
    this.wallDiffuse = 0.45,
    this.roofShade = 1.0,
    this.lightDirection,
    this.minBuildingHeight = 2.5,
    this.maxBuildingHeight = 300,
    this.lightingMode = SceneLightingMode.night,
    this.dayLightDirection,
    this.dayLightIntensity = 2.5,
    this.dayAmbientIntensity = 1.0,
  });

  /// Junções viárias: caixa de interseção sobre cada nó compartilhado.
  final bool buildJunctionPads;

  /// Deslocamento vertical das pads sobre o plano da via (m) — evita
  /// z-fighting com as capas das vias mantendo continuidade visual
  /// (soma-se ao `Material.depthLayer` aplicado no adapter).
  final double padLiftMeters;

  /// Pads com área menor que isso são descartadas (vias colineares de
  /// mesma largura já se tocam perfeitamente — pad degenerada é ruído).
  final double padMinAreaMeters;

  /// Canto de junção além de `fator × maior meia-largura` do nó vira
  /// bevel (linha reta entre as bocas) — mesmo limite de miter do
  /// motor 2D, evitando picos em cunhas agudas.
  final double padCornerLimitFactor;

  /// Sombreamento das fachadas (luz direcional fake, sem custo):
  /// shade = ambient + diffuse · max(dot(normal, luz), 0).
  final double wallAmbient;
  final double wallDiffuse;

  /// Multiplicador de cor das coberturas (1 = cor base).
  final double roofShade;

  /// Direção horizontal da luz (unitária, aponta PARA a luz).
  /// Noroeste por padrão — convenção Mapbox-like sem imitar cores.
  final Vector3? lightDirection;

  Vector3 get light {
    final dir = lightDirection;
    if (dir != null) return dir;
    return Vector3(-0.5, 0, -0.85)..normalize();
  }

  /// Limites de extrusão: dados inválidos não geram edifícios invisíveis
  /// nem arranha-céus absurdos por erro de tags.
  final double minBuildingHeight;
  final double maxBuildingHeight;

  static const Fogo3DStyle standard = Fogo3DStyle();

  static const Fogo3DStyle day = Fogo3DStyle(
    lightingMode: SceneLightingMode.day,
  );

  // ── ETAPA 07: iluminação dinâmica (modo diurno) ──

  /// Modo de iluminação ativo.
  final SceneLightingMode lightingMode;

  /// Direção da luz solar no modo diurno (aponta PARA a luz).
  /// Nordeste, meio-dia — mesma direção do sombreamento fake noturno.
  final Vector3? dayLightDirection;

  Vector3 get dayLight => dayLightDirection ?? Vector3(-0.5, 1.0, -0.85)
    ..normalize();

  /// Intensidade da luz direcional diurna.
  final double dayLightIntensity;

  /// Intensidade do ambiente diurno.
  final double dayAmbientIntensity;
}
