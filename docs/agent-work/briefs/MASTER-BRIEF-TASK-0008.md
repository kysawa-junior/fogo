# Master Brief — TASK-0008 Mapbox MVT no Motor 3D

## Pedido do usuário

"A parte web não está funcionando direito, use o Motor 3D para renderizar
os dados obtidos do MapBox."

## Decisões registradas (usuário, 2026-10-25)

- Fonte: tiles vetoriais MVT (`mapbox.mapbox-streets-v8`), sem Mapbox GL JS.
- Cobertura: sob demanda conforme pan/zoom (não cidade inteira pré-baixada).
- Camadas: vias, edifícios, água, áreas verdes, POIs e rótulos.
- Fonte padrão ao abrir: Mapbox MVT (OSM local permanece como alternativa).
- WebView (Mapbox GL JS): remover por completo — página, bridge, testes,
  dependência `flutter_inappwebview`, cópia local WPE.
- Spec aprovada: `docs/superpowers/specs/2026-10-25-mapbox-mvt-3d-engine.md`.

## Restrições

- Preservar TODAS as alterações locais não commitadas (motor, testes,
  README). Mudanças no motor são aditivas; nada é reescrito.
- Sem Design Work Package: estilo visual é o do motor existente
  (FogoPalette/mesh builders). Sem Integration Contract: um só time
  (engineering) toca o código.
- Token público `pk` padrão permanece; nunca token `sk`.
- Atribuição Mapbox/OSM obrigatória na tela (ToS).

## Entregáveis

- ENG-0008: pipeline MVT→motor 3D + remoção WebView + testes.
- Handoff e delivery audit na conclusão.
