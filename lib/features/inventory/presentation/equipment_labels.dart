import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/design_system/fogo_colors.dart';
import '../domain/equipment.dart';
import '../domain/vehicle.dart';

/// Rótulos, ícones e cores de apresentação do domínio de equipamentos.
String equipmentCategoryLabel(EquipmentCategory category) => switch (category) {
  EquipmentCategory.camera => 'Câmera',
  EquipmentCategory.radar => 'Radar',
  EquipmentCategory.scale => 'Balança',
  EquipmentCategory.gate => 'Cancela',
  EquipmentCategory.kiosk => 'Totem',
  EquipmentCategory.scooter => 'Patinete',
  EquipmentCategory.sensor => 'Sensor',
  EquipmentCategory.semaforo => 'Semáforo',
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
      EquipmentCategory.semaforo => LucideIcons.traffic_cone,
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

/// Rótulos da frota registrada (mesmos nomes do fogo-server).
String vehicleKindLabel(VehicleKind kind) => switch (kind) {
  VehicleKind.police => 'Polícia',
  VehicleKind.fire => 'Bombeiro',
};

IconData vehicleKindIcon(VehicleKind kind) => switch (kind) {
  VehicleKind.police => LucideIcons.shield,
  VehicleKind.fire => LucideIcons.flame,
};

String vehicleStatusLabel(VehicleStatus status) => switch (status) {
  VehicleStatus.ativa => 'Ativa',
  VehicleStatus.disponivel => 'Disponível',
  VehicleStatus.em_manutencao => 'Em manutenção',
};

Color vehicleStatusColor(VehicleStatus status) => switch (status) {
  VehicleStatus.ativa => FogoColors.statusNormal,
  VehicleStatus.disponivel => FogoColors.info,
  VehicleStatus.em_manutencao => FogoColors.statusAttention,
};
