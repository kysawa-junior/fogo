import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fogo_api_client.dart';
import '../domain/equipment.dart';
import '../domain/vehicle.dart';

/// Cliente HTTP do fogo-server (injectável para testes).
final fogoApiClientProvider = Provider<FogoApiClient>((ref) => FogoApiClient());

/// Catálogo de equipamentos do backend (GET /equipment).
/// AsyncValue: loading/erro expostos à página (servidor pode estar fora).
/// Retry automático DESATIVADO (Riverpod 3 agenda retry com Timer):
/// o refresh é manual (botão) — erro determinístico, sem "carregando…"
/// fantasma durante o backoff.
final equipmentProvider = FutureProvider<List<Equipment>>(
  (ref) => ref.watch(fogoApiClientProvider).equipment(),
  retry: (_, _) => null,
);

/// Frota registrada no backend (GET /vehicles).
final vehicleRegistryProvider = FutureProvider<List<Vehicle>>(
  (ref) => ref.watch(fogoApiClientProvider).vehicles(),
  retry: (_, _) => null,
);

/// Busca um equipamento por id na lista fornecida.
Equipment? findEquipment(List<Equipment> list, String id) {
  for (final equipment in list) {
    if (equipment.id == id) return equipment;
  }
  return null;
}
