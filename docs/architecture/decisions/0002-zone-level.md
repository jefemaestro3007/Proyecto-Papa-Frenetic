# 0002 — ZoneLevel como base de las zonas

**Estado:** aceptada

## Contexto

Azotea acumuló cielo, iluminación, jugador, ritmo, efectos, estilos, post-proceso, HUD y menú
de debug en un solo script. La segunda zona (Oficinas) necesitaba todo eso igual.

## Decisión

Extraer `ZoneLevel` (`src/world/levels/zone_level.gd`) con todo lo común. Cada zona hereda y
sobrescribe solo los ganchos `_zone_*`: parámetros del mapa, generación, controles de la
pestaña Mapa, spawn, límite de caída, cámara, zoom inicial y recorrido automático.

## Consecuencias

Una zona nueva cuesta poco: un generador, sus vistas y un script de zona. Cambios en el
sistema de ritmo, estilos o menú llegan a todas las zonas a la vez. El refactor se verificó
comparando un frame renderizado de Azotea antes y después.
