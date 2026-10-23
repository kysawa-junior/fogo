/// Inventory page library: the page lives here; the equipment row lives in
/// `equipment_row.dart`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../../core/design_system/widgets/fogo_empty_state.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_text_field.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../map/providers/workspace_providers.dart';
import '../../../domain/equipment.dart';
import '../../../providers/equipment_provider.dart';
import '../../equipment_labels.dart';

part 'equipment_row.dart';

/// Inventário Inteligente: consulta de ativos (demo) com filtro real;
/// selecionar um ativo abre o painel contextual no mapa.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  late final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openOnMap(Equipment equipment) {
    ref.read(selectionProvider.notifier).selectEquipment(equipment.id);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<Equipment> all = ref.watch(equipmentProvider);
    final List<Equipment> filtered = [
      for (final Equipment item in all)
        if (query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query))
          item,
    ];

    return Container(
      color: FogoColors.bg,
      padding: const EdgeInsets.all(FogoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho
          Row(
            children: [
              FogoIconButton(
                icon: LucideIcons.arrow_left,
                onTap: () => context.go('/'),
              ),
              const SizedBox(width: FogoSpacing.md),
              const Text('Inventário Inteligente', style: FogoText.title),
              const SizedBox(width: FogoSpacing.sm),

              const Spacer(),
              SizedBox(
                width: 320,
                child: FogoTextField(
                  hint: 'Buscar por nome ou id',
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: FogoSpacing.md),

          // Lista
          Expanded(
            child: filtered.isEmpty
                ? FogoEmptyState(
                    icon: LucideIcons.search_x,
                    title: 'Nenhum equipamento encontrado',
                    message: 'Ajuste a busca — o catálogo está vazio até a integração de backend.',
                  )
                : FogoPanel(
                    maxHeightFactor: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${filtered.length} de ${all.length} ativos',
                          style: FogoText.caption,
                        ),
                        const SizedBox(height: FogoSpacing.sm),
                        Flexible(
                          child: ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _EquipmentRow(
                              equipment: filtered[index],
                              onTap: () => _openOnMap(filtered[index]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: FogoSpacing.md),
          Text(
            'Consulta pronta; cadastro de novos ativos e sincronização com backend '
            'serão habilitados na próxima etapa.',
            style: FogoText.micro,
          ),
        ],
      ),
    );
  }
}
