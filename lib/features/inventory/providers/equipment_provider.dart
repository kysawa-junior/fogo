import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/equipment.dart';

/// Catálogo de equipamentos.
/// shortcut: sem fonte de dados nesta etapa (lista vazia); trocar por
/// repositório HTTP quando houver backend.
final equipmentProvider = Provider<List<Equipment>>((ref) => const []);

/// Busca um equipamento por id na lista fornecida.
Equipment? findEquipment(List<Equipment> list, String id) {
  for (final equipment in list) {
    if (equipment.id == id) return equipment;
  }
  return null;
}
