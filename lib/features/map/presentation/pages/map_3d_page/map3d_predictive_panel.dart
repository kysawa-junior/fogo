part of 'map_3d_page.dart';

/// Rótulo PT dos níveis de risco (mesmos nomes do fogo-server).
String _riskLevelLabel(RiskLevel level) => switch (level) {
  RiskLevel.baixo => 'Baixo',
  RiskLevel.moderado => 'Moderado',
  RiskLevel.alto => 'Alto',
  RiskLevel.critico => 'Crítico',
};

/// Painel Cidade Preditiva (modo heatmap): Top 5 áreas de risco +
/// detalhe da área selecionada (score, nível e fatores que mais
/// pesaram). Dados do fogo-server (GET /risk/areas).
class _PredictivePanel extends StatelessWidget {
  const _PredictivePanel({
    required this.areas,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
  });

  final List<RiskArea> areas;
  final String? selectedId;
  final void Function(String id) onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return FogoPanel(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: FogoSpacing.md),
            const Text(
              'Sem áreas de risco: carregue a base (OSM) e cadastre '
              'equipamentos no Inventário.',
              style: TextStyle(fontSize: 11, color: FogoColors.textSecondary),
            ),
          ],
        ),
      );
    }
    RiskArea? selected;
    for (final a in areas) {
      if (a.id == selectedId) selected = a;
    }
    return FogoPanel(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: FogoSpacing.md),
          Text('TOP ÁREAS DE RISCO', style: FogoText.caption),
          const SizedBox(height: FogoSpacing.xs),
          for (final area in areas.take(5)) _row(area),
          if (selected != null) ...[
            const SizedBox(height: FogoSpacing.md),
            Container(
              padding: const EdgeInsets.all(FogoSpacing.sm),
              decoration: BoxDecoration(
                color: FogoColors.surfaceRaised,
                borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _solidColor(selected.score),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: FogoSpacing.xs),
                      Expanded(
                        child: Text(
                          '${selected.id} · Score ${selected.score} · '
                          '${_riskLevelLabel(selected.level)}',
                          style: FogoText.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FogoSpacing.xs),
                  // Fatores que mais pesaram (contribuição ponderada).
                  for (final (label, value) in selected.breakdown.ranked())
                    if (value > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FogoColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Expanded(child: Text('Cidade Preditiva', style: FogoText.title)),
      FogoIconButton(icon: LucideIcons.x, onTap: onClose),
    ],
  );

  Widget _row(RiskArea area) {
    final bool isSelected = area.id == selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: () => onSelect(area.id),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FogoSpacing.sm,
            vertical: FogoSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? FogoColors.surfaceRaised
                : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _solidColor(area.score),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: FogoSpacing.sm),
              Expanded(child: Text(area.id, style: FogoText.body)),
              Text('${area.score}', style: FogoText.body),
              const SizedBox(width: FogoSpacing.sm),
              Text(
                _riskLevelLabel(area.level),
                style: const TextStyle(
                  fontSize: 11,
                  color: FogoColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cor sólida do marcador (o heatmap usa alpha; o painel não).
Color _solidColor(int score) {
  final c = heatColor(score);
  return c.withAlpha(0xFF);
}
