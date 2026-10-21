import 'package:flutter/widgets.dart';

import '../../../core/design_system/fogo_colors.dart';
import '../domain/road.dart';

/// Rótulos e cores de apresentação do domínio de vias.
String roadTypeLabel(RoadType type) => switch (type) {
  RoadType.avenue => 'Avenida',
  RoadType.street => 'Rua',
  RoadType.arterial => 'Via arterial',
  RoadType.corridor => 'Corredor',
};

String flowDirectionLabel(FlowDirection direction) => switch (direction) {
  FlowDirection.oneWay => 'Sentido único',
  FlowDirection.twoWay => 'Duplo sentido',
  FlowDirection.alternating => 'Sentido alternado',
  FlowDirection.closed => 'Circulação fechada',
};

String operationalStatusLabel(OperationalStatus status) => switch (status) {
  OperationalStatus.normal => 'Normal',
  OperationalStatus.attention => 'Atenção',
  OperationalStatus.critical => 'Crítico',
  OperationalStatus.closed => 'Fechada',
};

String permissionLabel(RoadPermission permission) => switch (permission) {
  RoadPermission.pedestrian => 'Pedestres',
  RoadPermission.bicycle => 'Ciclistas',
  RoadPermission.bus => 'Ônibus',
  RoadPermission.truck => 'Caminhões',
  RoadPermission.emergency => 'Emergência',
  RoadPermission.loading => 'Carga e descarga',
};

Color operationalStatusColor(OperationalStatus status) => switch (status) {
  OperationalStatus.normal => FogoColors.statusNormal,
  OperationalStatus.attention => FogoColors.statusAttention,
  OperationalStatus.critical => FogoColors.statusCritical,
  OperationalStatus.closed => FogoColors.statusOffline,
};
