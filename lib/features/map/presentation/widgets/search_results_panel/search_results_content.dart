part of 'search_results_panel.dart';

/// Panel content, one branch per search status.
class _SearchResultsContent extends StatelessWidget {
  const _SearchResultsContent({required this.search, required this.onSelect});

  final SearchState search;
  final void Function(GeoSearchResult) onSelect;

  @override
  Widget build(BuildContext context) {
    switch (search.status) {
      case SearchStatus.loading:
        return Padding(
          padding: EdgeInsets.all(FogoSpacing.md),
          child: Row(
            children: [
              const SizedBox(width: 14, height: 14, child: FogoSpinner()),
              SizedBox(width: FogoSpacing.sm),
              Text('Buscando…', style: FogoText.caption),
            ],
          ),
        );
      case SearchStatus.error:
        return Padding(
          padding: const EdgeInsets.all(FogoSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.circle_alert,
                size: 14,
                color: FogoColors.statusCritical,
              ),
              const SizedBox(width: FogoSpacing.sm),
              Expanded(
                child: Text(
                  search.error ?? 'Falha na busca.',
                  style: FogoText.caption.copyWith(
                    color: FogoColors.statusCritical,
                  ),
                ),
              ),
            ],
          ),
        );
      case SearchStatus.idle:
        return const SizedBox.shrink();
      case SearchStatus.ready:
        if (search.results.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(FogoSpacing.md),
            child: Text(
              'Nenhum resultado (OSM/Nominatim).',
              style: FogoText.caption,
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final GeoSearchResult result in search.results)
              _SearchResultRow(result: result, onTap: () => onSelect(result)),
            const Padding(
              padding: EdgeInsets.all(FogoSpacing.sm),
              child: Text(
                '© OpenStreetMap contributors (Nominatim)',
                style: FogoText.micro,
              ),
            ),
          ],
        );
    }
  }
}
