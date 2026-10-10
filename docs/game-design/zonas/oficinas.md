# Zona Oficinas

Edificio administrativo abandonado y medio destruido, en vista lateral. Se entra por la
planta de inicio (izquierda) y se sale por la puerta con cartel de salida (derecha) del piso
final. Escena: `src/world/levels/oficinas/oficinas.tscn`.

```bash
godot --path . res://src/world/levels/oficinas/oficinas.tscn
```

## Controles

| Acción | Tecla |
|---|---|
| Mover / saltar | ←/→ · Espacio |
| Caída forzada (en el aire) | ↓ |
| Subir una escalera (al pie) / bajarla (arriba) | ↑ / ↓ |
| Llamar el ascensor (frente a su puerta) | ↑ |
| En la cabina: elegir hacia dónde / salir | ↑ ↓ (mantener sigue de piso en piso) / ← → |
| Entrar a una puerta al fondo / salir del área | ↑ |
| Vista solo de la habitación actual | V |
| Grafo de recorrido (depuración) | G |
| Menú de debug · cambiar estilo | Tab · F2 |

## Elementos

- **Puertas entre módulos**: se abren solas al acercarse, en el beat. Las que tienen candado
  de color piden la llave de ese color.
- **Escaleras de fondo**: pasar por delante no las usa; ↑ al pie sube, ↓ arriba baja. Se apilan
  en núcleos (tramos en zigzag), como en un edificio real.
- **Ascensores de fondo, cerrados**: la cabina llega en ≤ 2 s y abre en el beat; el viaje dura
  ≤ 1,5 s y mientras tanto solo se ve la cabina. Tipos: local (para en cada piso), expreso
  (solo extremos), de servicio (siempre tarda lo máximo en llegar) y averiado (sacudidas, luz
  que falla).
- **Puertas al fondo**: llevan a **habitaciones** (sin salida, muy detalladas: dirección,
  servidores, baño, depósito, limpieza, archivo, seguridad, cocina, oficina, reuniones) que
  pueden guardar una llave, o a **pasillos al fondo** (servicio, mantenimiento, escalera de
  incendios, trasero, derrumbado) que salen por otra puerta del edificio, incluso en otro piso.
- **Huecos pequeños** (se saltan o sirven para bajar) y **derrumbes** (se cae uno o más pisos).
- **Llaves**: en el piso o dentro de habitaciones.
- **Guía sonora**: además del metrónomo, en cada beat suena un clic posicional desde el próximo
  punto importante del camino a la salida (escalera, ascensor, puerta, hueco). El paneo indica
  hacia dónde ir.

## Garantías de la generación

`OficinasLayout` modela el edificio como un grafo dirigido (caer es de un solo sentido) y
valida, para cada edificio generado:

1. La salida es alcanzable desde la entrada.
2. **Desde cualquier lugar del edificio** se puede llegar a la salida, aunque se llegue por un
   camino inesperado (por ejemplo, saltando un derrumbe con un impulso de ritmo).
3. Con llaves: en el **espacio de estados** (lugar × llaves que se tienen) ningún estado
   alcanzable se queda sin salida; nunca hay atasco por una llave.
4. Si se pide, todo el edificio es recorrible; lo que no se puede conectar se **sella**
   (módulo tapiado con escombros, sólido).
5. Hay rutas alternativas: la ruta principal tiene desvíos y además se generan ramas.

Si una configuración es imposible, los intentos siguientes relajan las exigencias y hay un
último intento "seguro" que siempre es válido.

## Realismo y variedad

Con `realism` alto: escaleras y ascensores en columnas núcleo, cada piso tiende a repetir la
planta del de abajo y el daño se concentra en zonas. Los temas de habitación evitan repetir
el de al lado y el mobiliario no repite el mismo mueble dos veces seguidas.

## Tests

```bash
godot --headless --path . --script res://tests/unit/test_oficinas_layout.gd     # 1160 edificios
godot --headless --path . --script res://tests/unit/test_oficinas_generator.gd  # geometría y áreas
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/oficinas_traversal.tscn -- --extra=60
```

El último hace que un bot recorra edificios reales con la física y los controles del jugador
(escaleras, ascensores, puertas al fondo, llaves): 108/108 completados.
