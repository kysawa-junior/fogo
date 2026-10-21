import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/design_system/fogo_colors.dart';
import '../domain/equipment.dart';

/// Rótulos, ícones e cores de apresentação do domínio de equipamentos.
String equipmentCategoryLabel(EquipmentCategory category) => switch (category) {
  EquipmentCategory.camera => 'Câmera',
  EquipmentCategory.radar => 'Radar',
  EquipmentCategory.scale => 'Balança',
  EquipmentCategory.gate => 'Cancela',
  EquipmentCategory.kiosk => 'Totem',
  EquipmentCategory.scooter => 'Patinete',
  EquipmentCategory.sensor => 'Sensor',
};

IconData equipmentCategoryIcon(EquipmentCategory category) =>
    switch (category) {
      EquipmentCategory.camera => LucideIcons.camera,
      EquipmentCategory.radar => LucideIcons.radar,
      EquipmentCategory.scale => LucideIcons.scale,
      EquipmentCategory.gate => LucideIcons.construction,
      EquipmentCategory.kiosk => LucideIcons.monitor,
      EquipmentCategory.scooter => LucideIcons.bike,
      EquipmentCategory.sensor => LucideIcons.activity,
    };

String equipmentStatusLabel(EquipmentStatus status) => switch (status) {
  EquipmentStatus.online => 'Disponível',
  EquipmentStatus.attention => 'Atenção',
  EquipmentStatus.offline => 'Indisponível',
  EquipmentStatus.maintenance => 'Manutenção',
};

Color equipmentStatusColor(EquipmentStatus status) => switch (status) {
  EquipmentStatus.online => FogoColors.statusNormal,
  EquipmentStatus.attention => FogoColors.statusAttention,
  EquipmentStatus.offline => FogoColors.statusOffline,
  EquipmentStatus.maintenance => FogoColors.info,
};
