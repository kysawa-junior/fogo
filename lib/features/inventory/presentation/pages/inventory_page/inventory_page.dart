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
import '../../../data/fogo_api_client.dart';
import '../../../domain/equipment.dart';
import '../../../domain/vehicle.dart';
import '../../../providers/equipment_provider.dart';
import '../../equipment_labels.dart';

part 'equipment_row.dart';
part 'vehicle_row.dart';

/// Grade de cards: largura fixa por card, colunas emergem do Wrap.
const double _cardWidth = 360;
const double _cardMinHeight = 92;

/// Inventário Inteligente: catálogo do fogo-server (equipamentos +
/// viaturas registradas) com filtro local; selecionar um equipamento
/// abre o painel contextual no mapa.
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

  void _refresh() {
    ref.invalidate(equipmentProvider);
    ref.invalidate(vehicleRegistryProvider);
  }

  /// Erro da seção (null = sem erro) — não invalida dados em cache.
  static Object? _failure(AsyncValue<dynamic> async) => switch (async) {
    AsyncError(:final error) => error,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final AsyncValue<List<Equipment>> equipmentAsync = ref.watch(
      equipmentProvider,
    );
    final AsyncValue<List<Vehicle>> vehiclesAsync = ref.watch(
      vehicleRegistryProvider,
    );
    final FogoApiClient api = ref.watch(fogoApiClientProvider);

    final List<Equipment> equipments = equipmentAsync.value ?? const [];
    final List<Vehicle> vehicles = vehiclesAsync.value ?? const [];

    final List<Equipment> filteredEquipment = [
      for (final Equipment item in equipments)
        if (query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query))
          item,
    ];
    final List<Vehicle> filteredVehicles = [
      for (final Vehicle item in vehicles)
        if (query.isEmpty ||
            item.plate.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query))
          item,
    ];

    // Servidor fora: erro bloqueia a página só quando NENHUMA seção tem
    // dados (as duas falham juntas — mesma origem).
    final Object? failure = _failure(equipmentAsync) ?? _failure(vehiclesAsync);
    final bool allEmpty = filteredEquipment.isEmpty && filteredVehicles.isEmpty;
    final bool waiting =
        equipments.isEmpty &&
        vehicles.isEmpty &&
        (equipmentAsync.isLoading || vehiclesAsync.isLoading);

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
              FogoIconButton(icon: LucideIcons.refresh_cw, onTap: _refresh),
              const SizedBox(width: FogoSpacing.sm),
              SizedBox(
                width: 320,
                child: FogoTextField(
                  hint: 'Buscar por nome, id ou placa',
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: FogoSpacing.md),

          // Lista combinada: equipamentos + viaturas registradas.
          Expanded(
            child: switch ((failure, allEmpty, waiting)) {
              (final Object error, true, _) => _networkError(error),
              (_, true, false) => const FogoEmptyState(
                icon: LucideIcons.database,
                title: 'Inventário vazio',
                message:
                    'Nenhum equipamento ou viatura cadastrado no '
                    'fogo-server. Cadastre pelo endpoint REST para vê-los '
                    'aqui.',
              ),
              (_, false, _) || (_, _, false) => _list(
                filteredEquipment: filteredEquipment,
                filteredVehicles: filteredVehicles,
                equipments: equipments,
                vehicles: vehicles,
              ),
              _ => const FogoEmptyState(
                icon: LucideIcons.loader_circle,
                title: 'Carregando inventário…',
                message: 'Consultando o fogo-server.',
              ),
            },
          ),
          const SizedBox(height: FogoSpacing.md),
          Text(
            'Fonte: fogo-server (${api.baseUri}) — '
            'sobrescreva com --dart-define=FOGO_API_URL=<url>.',
            style: FogoText.micro,
          ),
        ],
      ),
    );
  }

  Widget _list({
    required List<Equipment> filteredEquipment,
    required List<Vehicle> filteredVehicles,
    required List<Equipment> equipments,
    required List<Vehicle> vehicles,
  }) {
    return FogoPanel(
      maxHeightFactor: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${filteredEquipment.length} de ${equipments.length} equipamentos · '
            '${filteredVehicles.length} de ${vehicles.length} viaturas',
            style: FogoText.caption,
          ),
          const SizedBox(height: FogoSpacing.sm),
          Flexible(
            child: ListView(
              controller: _scrollController,
              shrinkWrap: true,
              children: [
                // Grade de cards (Wrap): colunas emergem da largura.
                if (filteredEquipment.isNotEmpty) ...[
                  _sectionHeader('Equipamentos'),
                  Wrap(
                    spacing: FogoSpacing.md,
                    runSpacing: FogoSpacing.md,
                    children: [
                      for (final Equipment equipment in filteredEquipment)
                        _EquipmentRow(
                          equipment: equipment,
                          onTap: () => _openOnMap(equipment),
                        ),
                    ],
                  ),
                ],
                if (filteredVehicles.isNotEmpty) ...[
                  _sectionHeader('Viaturas'),
                  Wrap(
                    spacing: FogoSpacing.md,
                    runSpacing: FogoSpacing.md,
                    children: [
                      for (final Vehicle vehicle in filteredVehicles)
                        _VehicleRow(vehicle: vehicle),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cabeçalho de seção (Equipamentos / Viaturas) com barra accent.
  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(
        top: FogoSpacing.md,
        bottom: FogoSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: FogoColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          Text(label.toUpperCase(), style: FogoText.caption),
        ],
      ),
    );
  }

  /// Estado de falha de rede (servidor indisponível) com retry.
  Widget _networkError(Object error) {
    return Column(
      children: [
        Expanded(
          child: FogoEmptyState(
            icon: LucideIcons.server_off,
            title: 'Não foi possível consultar o fogo-server',
            message: '$error',
          ),
        ),
        FogoIconButton(icon: LucideIcons.refresh_cw, onTap: _refresh),
      ],
    );
  }
}
