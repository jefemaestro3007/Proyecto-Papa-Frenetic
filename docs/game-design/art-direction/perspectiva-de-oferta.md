# Perspectiva de Oferta — filosofía algorítmica del nivel 3 (Bienestar U)

Zona: **Bienestar U** (`src/world/levels/bienestar/`), supermercado (3-1) y centro comercial
(3-2). Hereda la paleta y las reglas de [Rojo Frenético](rojo-frenetico.md); lo nuevo es la
profundidad.

## Filosofía

**Un mundo plano que de pronto tiene fondo.** Las dos primeras zonas son siluetas recortadas
sobre el rojo: todo vive en un mismo plano. Bienestar U abre una caja: el plano jugable es la
boca de un escenario y detrás hay un piso que se aleja, un techo con tubos fluorescentes y una
pared del fondo. Todo converge en **un único punto de fuga, que es la cámara**. Cuando el
jugador corre, las góndolas del fondo giran, sus costados aparecen y desaparecen, y la tienda
entera se siente tridimensional sin dejar las tintas planas.

**La perspectiva es una regla, no un efecto.** Cada punto del mundo tiene una profundidad `d`
(0 = plano jugable, 1 = punto de fuga) y se dibuja en `vp + (p − vp)·(1 − d)`. No hay
modelos 3D, ni cámaras 3D, ni degradados: solo polígonos planos con contorno de tinta, en tres
tonos por caja (frente, lado, techo). Qué cara se ve sale sola de la posición del objeto
respecto de la cámara: lo que está a la izquierda muestra su lado derecho, y lo que está por
debajo del ojo muestra su techo.

**El orden del comercio y el caos de la ruina.** Un supermercado es una grilla perfecta:
góndolas en fila, precios alineados, pasillos numerados. Lo generativo es cómo se rompe esa
grilla: racks sobrecargados que ceden, charcos donde se rompió una botella, freezers que
parpadean, cortinas metálicas a medio bajar. Igual que en la Azotea, **el orden es la regla y el
daño es la variación**.

**El ritmo mueve la tienda.** Los carteles de OFERTA giran un cuarto de vuelta en cada beat
como prismas, los precios colgantes se balancean al compás, los fluorescentes parpadean a
tempo, las cintas de caja avanzan solo en el beat, las escaleras mecánicas cambian de sentido
cada cuatro compases y las cortinas bajan contando beats. Nada usa el reloj del sistema para el
tempo: todo lee `Conductor`.

**El rojo sigue afuera.** El cielo Rojo Frenético se ve por los tragaluces del techo y por las
puertas de entrada y salida: el interior es azul tinta, cremas y acentos de producto (amarillo,
cian, verde), y el rojo aparece como lo que hay afuera y como alarma.

## Cómo se construye

| Capa | Profundidad | Qué es | Cómo se dibuja |
|---|---|---|---|
| Pared del fondo | 0,45 | Pared, puertas de bodega, vitrinas de locales | Rectángulo proyectado por piso |
| Piso y techo | 0 → 0,45 | Baldosas y tubos que se alejan | Líneas hacia el punto de fuga; el piso solo si está bajo el ojo, el techo solo si está sobre él |
| Góndolas del fondo | 0,12 → 0,45 | Cabeceras de pasillo con su costado | Prismas largos hacia el fondo, ordenados de afuera hacia el centro |
| Mobiliario jugable | 0 → 0,08 | Racks, cajas, freezers, mostradores, pallets | Prismas cortos: el frente es la colisión exacta |
| Carteles colgantes | 0,04 | Precios, número de pasillo, OFERTA | Rombos que se balancean y prismas que giran |

Lo que depende de la cámara se redibuja cada frame, pero solo lo que está en pantalla
(`SpatialIndex`): el costo no crece con el largo de la tienda.

## Reglas de implementación

- Todo el azar sale de un `RandomNumberGenerator` sembrado (`BienestarParams.seed`).
- La geometría de juego (pisos, sólidos, plataformas) es plana y exacta; la perspectiva es solo
  dibujo.
- Las alturas respetan el salto: obstáculos ≤ 150 px, vigas de rack a 180 px (salto base 216 px).
- Los estilos (Default, Pixel, Isaac) se aplican con las primitivas de `StyledCanvas` (trazo a
  mano, sombras, ladrillos, borde de luz) y con el material `ruin_grunge` compartido (manchas y
  semitono); las marcas del mapa (`MapMark`) van en un plano de piso aparte y en la pared del fondo.
