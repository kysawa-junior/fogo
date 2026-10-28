part of 'inventory_page.dart';

/// Card de viatura registrada: tile do tipo, placa, tipo·id e estado.
class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final Color status = vehicleStatusColor(vehicle.status);
    return Container(
      width: _cardWidth,
      constraints: const BoxConstraints(minHeight: _cardMinHeight),
      padding: const EdgeInsets.all(FogoSpacing.md),
      decoration: BoxDecoration(
        color: FogoColors.surfaceRaised,
        borderRadius: BorderRadius.circular(FogoSpacing.radiusMd),
        border: Border.all(color: FogoColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: status.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
              border: Border.all(color: status.withValues(alpha: 0.35)),
            ),
            child: Icon(vehicleKindIcon(vehicle.kind), size: 17, color: status),
          ),
          const SizedBox(width: FogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.plate,
                  style: FogoText.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${vehicleKindLabel(vehicle.kind)} · ${vehicle.id}',
                  style: FogoText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          FogoChip(label: vehicleStatusLabel(vehicle.status), color: status),
        ],
      ),
    );
  }
}
