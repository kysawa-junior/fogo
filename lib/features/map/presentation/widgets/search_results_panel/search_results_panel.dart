/// Search results library: the panel lives here; the per-status content and
/// the result row live in sibling parts.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_spinner.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../data/geocoding_service.dart' show GeoSearchResult;
import '../../../providers/search_provider.dart';

part 'search_results_content.dart';
part 'search_result_row.dart';

/// Resultados da busca geográfica real (Nominatim/OSM) sobre o mapa.
class SearchResultsPanel extends ConsumerWidget {
  const SearchResultsPanel({super.key, required this.onSelect});

  final void Function(GeoSearchResult) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchState search = ref.watch(searchQueryProvider);
    if (search.query.trim().length < 2) return const SizedBox.shrink();
    if (search.status == SearchStatus.idle) return const SizedBox.shrink();

    return FogoPanel(
      padding: const EdgeInsets.symmetric(
        vertical: FogoSpacing.sm,
        horizontal: FogoSpacing.sm,
      ),
      child: _SearchResultsContent(search: search, onSelect: onSelect),
    );
  }
}
