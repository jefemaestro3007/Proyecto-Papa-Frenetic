# 0003 — Recorrido garantizado por grafo y espacio de estados

**Estado:** aceptada

## Contexto

Oficinas debe poder completarse siempre, sin ser lineal: escaleras, ascensores, caídas de un
solo sentido, pasillos al fondo, puertas con llave. Un error de generación que deje al
jugador atrapado arruina la partida.

## Decisión

- `OficinasLayout` modela el edificio como un **grafo dirigido** de nodos (piso, módulo).
- La reparación garantiza que desde **cualquier** nodo se llega a la salida (no solo desde los
  alcanzables: así un salto inesperado tampoco atrapa) y, si se pide, que todo sea alcanzable;
  lo irreparable se sella.
- Las cerraduras se validan en el **espacio de estados** (nodo × llaves): ningún estado
  alcanzable queda sin salida.
- La física se mantiene fiel al grafo y se comprueba con un **bot** que juega con los mismos
  controles que el jugador (`tests/test_scenes/oficinas_traversal.tscn`).

## Consecuencias

Cada cambio de mecánica debe reflejarse en el grafo y pasar el test de recorrido. Varias
decisiones de física (cápsula como colisión del jugador, muros con remate en cuña, escaleras y
ascensores de fondo) salieron de los fallos que encontró ese test.
