/// Modelo vetorial puro (sem dependências de UI) da base cartográfica real.
/// Origem: OpenStreetMap (ver tool/map_data/build_map_data.py), formato v2.
///
/// A biblioteca é dividida por responsabilidade: tipos de classificação
/// (`feature_types.dart`), registros geográficos (`features.dart`), manifesto
/// (`manifest.dart`) e célula decodificada (`cell_data.dart`).
library;

part 'feature_types.dart';
part 'features.dart';
part 'manifest.dart';
part 'cell_data.dart';
