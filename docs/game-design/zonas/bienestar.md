# Zona Bienestar U (nivel 3)

Un supermercado y un centro comercial abandonados, en vista lateral pero **con profundidad**: el
plano jugable es la boca de una caja y detrás hay piso, techo y pared que se alejan hacia un punto
de fuga, que es la cámara. La dirección de arte está en
[Perspectiva de Oferta](../art-direction/perspectiva-de-oferta.md). La canción es
`centro_comercial` (140 BPM).

| Subnivel | Escena | Qué es |
|---|---|---|
| 3-1 Supermercado | `src/world/levels/bienestar/supermercado.tscn` | Un piso largo: entrada → secciones → cajas → salida |
| 3-2 Centro comercial | `src/world/levels/bienestar/centro_comercial.tscn` | Tres pisos con escaleras mecánicas; se entra abajo a la izquierda y se sale arriba a la derecha |

```bash
godot --path . res://src/world/levels/bienestar/supermercado.tscn
godot --path . res://src/world/levels/bienestar/centro_comercial.tscn -- --autorun
```

## Controles

| Acción | Tecla |
|---|---|
| Mover / saltar / atacar / dash / stomp | Como siempre (A/D, Espacio, J, Shift, S en el aire) |
| Montarse en un carrito estacionado / bajarse | W junto al carrito / S (o W) |
| Subir una escalera mecánica (al pie) / bajarla (arriba) | W / S; a contramano, W/S **a tiempo** dan pasos |

## Secciones

**Supermercado** (`BienestarParams.mode = 0`): entrada (carritos, cartel de ofertas, puertas de
vidrio con el cielo rojo detrás), una mezcla al azar de **pasillos** (góndolas al fondo con su
cartel colgante "N · RUBRO", racks sobre el pasillo y pallets), **congelados**, **frutas y
verduras** (puestos con pirámides de fruta, balanzas, charcos de los rociadores), **piso mojado**
(carteles de pie y balde), **carritos** (pasillo largo para ir rápido), **cajas** y salida.
Siempre hay al menos un pasillo y congelados.

**Centro comercial** (`mode = 1`): pisos de locales con nombre al fondo (algunos cerrados),
maceteros, bancas y kioscos; **cortinas metálicas** que cruzan el pasillo; **huecos del atrio** (se
cae al piso de abajo); el **patio de comidas** en el último piso y tragaluces en el techo.

## Mecánicas

| Mecánica | Cómo funciona | Ritmo |
|---|---|---|
| **Racks** | Estar debajo o encima suma un beat de carga (luces bajo la viga; tiembla cada vez más). Al llegar a `rack_collapse_beats` (6) se derrumba: a quien está debajo le pega (calor ×1,5) y lo deja encima de los escombros (60 px, se saltan); a las papas de abajo les quita una vida. **Un stomp sobre la viga lo tira en el acto** sobre las papas | Carga por beat, cae en el beat |
| **Freezers** | Abren 2 beats y cierran 2. Enfrente de uno abierto la papa se enfría (`freezer_cooling`/s) hasta `freezer_cap` por freezer (después se apaga); la escarcha frena (`freezer_slow`) | Puertas en el beat |
| **Piso mojado** | Agarre `wet_traction`: cuesta arrancar y frenar; el dash se desliza | — |
| **Cintas de caja** | Los mostradores son sólidos y su cinta lleva al jugador `belt_step` px por beat, solo en el primer tramo de cada beat (la flecha se enciende) | Avanzan en el beat |
| **Carritos** | W para montarse: más velocidad (`cart_speed_scale`) y mucha inercia. Desde `cart_ram_speed` **atropella** papas (les quita una vida) sin recibir daño | — |
| **Escaleras mecánicas** | Cambian de sentido cada `escalator_bars` (4) compases; las flechas titilan el compás antes. A favor el viaje dura `escalator_seconds`; a contramano se avanza al `escalator_against` y cada W/S a tiempo suma `escalator_step` | Cambian por compases, pasos a tiempo |
| **Cortinas metálicas** | Ciclo: abiertas 8 beats → bajan de a un escalón por beat (cuenta atrás) → cerradas 4 beats → suben. Bajando y con 40-96 px libres solo se pasa **en dash**. Siempre vuelven a abrir: nunca atascan | Escalón por beat |
| **Freidoras** | Cada `fryer_every` beats salpican aceite alrededor del mostrador (`fryer_heat`); el beat anterior burbujean | Salpican a tempo |

Todas las cifras están en la pestaña **Mapa** del menú de debug (grupo Mecánicas) y en
`BienestarParams`.

## Papas

Solo papas **vestidas** (ver [combate](../combate.md#papas-vestidas-bienestar-u)), por los carriles
de cada piso (`BienestarMapData.lanes`), nunca cerca de la entrada ni de la salida. Orden de
presentación: supermercado cliente → reponedor → promotora → globos → guardia; centro comercial
cliente → globos → guardia → promotora → reponedor.

## Garantías de la generación

`BienestarGenerator` (todo sembrado; los detalles usan otro RNG para no cambiar el trazado):

1. Todo obstáculo apoyado en el piso mide como mucho 150 px (salto base 216 px) y entre dos
   obstáculos quedan al menos 160 px para aterrizar.
2. Las vigas de los racks están a 180 px y debajo de un rack no hay sólidos.
3. Centro comercial: al menos una escalera mecánica entre cada par de pisos, con sus extremos sobre
   piso, lejos de huecos, cortinas, entrada y salida; todas cambian de sentido.
4. Huecos del atrio de ≤ 360 px (se saltan), nunca en el piso 0 ni junto a la salida.
5. Siempre hay congelados, cajas y carritos en el supermercado, y freidoras si hay patio de comidas.

`test_bienestar_generator` lo verifica en 300 tiendas y `test_bienestar_traversal` hace que un bot
(`BienestarBot`) recorra tiendas reales con la física y los controles del jugador hasta la salida.

## Dibujo y rendimiento

- **Estático, a profundidad fija** (`DepthPlane` + `StoreBackdrop` en trozos con `ChunkedView`):
  pared del fondo con estantes, letreros y locales, frentes de góndolas y freezers. Se dibuja una
  vez; cada frame solo se escala hacia el punto de fuga.
- **Lo que depende de la cámara** (`StoreDepthView`, dos pasadas, y `StoreFixturesView`): piso,
  techo, paredes de los extremos, costados de góndolas y freezers, escaleras, sólidos en prisma,
  racks, cortinas, carteles. Solo lo que está en pantalla (`SpatialIndex`); baldosas y tubos en una
  sola llamada.
- **Estilos (Default / Pixel / Isaac)**: un material `ruin_grunge` compartido (manchas y semitono)
  se aplica a todas las vistas de la tienda; el generador siembra marcas de pared (grietas,
  manchas, sangre, afiches, grafitis) y de piso (papeles, escombros, huesos, sangre) que cada estilo
  muestra en su medida (`MapMark.weight`), con telarañas en las esquinas (Pixel). Los frentes usan
  las primitivas de `StyledCanvas` (trazo a mano y sombras proyectadas en Isaac; ladrillos, borde de
  luz y caras sombreadas en Pixel) y las moscas (`FliesView`) rondan las marcas del piso. El
  mobiliario jugable se dibuja **delante** de las papas.

Benchmark (ventana 1920×1080): supermercado de 8 o 24 secciones ≈ 6 ms por frame; centro
comercial de 7 secciones × 3 pisos o 20 × 5 ≈ 8-10 ms. No crece con el tamaño.

## Argumentos de línea de comandos

Además de los de toda zona: `--start-x=` y `--start-floor=` empiezan en otro lugar (capturas),
`--no-enemies` sin papas.
