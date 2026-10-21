import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/design_system/widgets/fogo_spinner.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../data/geocoding_service.dart' show GeoSearchResult;
import '../../providers/search_provider.dart';

/// Resultados da busca geográfica real (Nominatim/OSM) sobre o mapa.
class SearchResultsPanel extends ConsumerWidget {
  const SearchResultsPanel({super.key, required this.onSelect});

  final void Function(GeoSearchResult) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchState search = ref.watch(searchQueryProvider);
    if (search.query.trim().length < 2) return const SizedBox.shrink();

    Widget content;
    switch (search.status) {
      case SearchStatus.loading:
        content = Padding(
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
        content = Padding(
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
          content = Padding(
            padding: EdgeInsets.all(FogoSpacing.md),
            child: Text(
              'Nenhum resultado (OSM/Nominatim).',
              style: FogoText.caption,
            ),
          );
        } else {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final GeoSearchResult result in search.results)
                _ResultRow(result: result, onTap: () => onSelect(result)),
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

    return FogoPanel(
      padding: const EdgeInsets.symmetric(
        vertical: FogoSpacing.sm,
        horizontal: FogoSpacing.sm,
      ),
      child: content,
    );
  }
}

class _ResultRow extends StatefulWidget {
  const _ResultRow({required this.result, required this.onTap});

  final GeoSearchResult result;
  final VoidCallback onTap;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final int comma = widget.result.label.indexOf(',');
    final String title = comma > 0
        ? widget.result.label.substring(0, comma)
        : widget.result.label;
    final String subtitle = comma > 0 && widget.result.label.length > comma + 2
        ? widget.result.label
              .substring(comma + 2)
              .split(',')
              .take(3)
              .join(' · ')
        : widget.result.sublabel;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? FogoColors.surfaceHover : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.map_pin,
                size: 14,
                color: FogoColors.textSecondary,
              ),
              const SizedBox(width: FogoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FogoText.body.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: FogoText.micro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
