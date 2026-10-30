part of 'inventory_page.dart';

/// Card de viatura registrada: tile do tipo, placa, tipo·id e badge de
/// estado.
class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final Color status = vehicleStatusColor(vehicle.status);
    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FogoColors.bg,
        borderRadius: BorderRadius.circular(FogoSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: status.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(FogoSpacing.radiusMd),
            ),
            child: Icon(vehicleKindIcon(vehicle.kind), size: 18, color: status),
          ),
          const SizedBox(width: FogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vehicle.plate,
                  style: FogoText.subtitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${vehicleKindLabel(vehicle.kind)} · ${vehicle.id}',
                  style: FogoText.caption.copyWith(
                    fontSize: 11.5,
                    color: FogoColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          _StatusBadge(
            label: vehicleStatusLabel(vehicle.status),
            color: status,
          ),
        ],
      ),
    );
  }
}
