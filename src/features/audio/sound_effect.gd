@tool
class_name SoundEffect
extends Resource
## Un efecto de sonido del juego. Los `.tres` de `src/shared/resources/sfx/` se agrupan por el
## prefijo del nombre (`hurt_grave.tres` → grupo `hurt`): `SfxPlayer` toca una variante al azar
## del grupo. Para agregar una variante basta con crear otro `.tres` con el mismo prefijo.
## Los WAV se importan con `edit/trim` para que no tengan silencio al inicio (en un juego de ritmo
## el retraso se nota).

@export var stream: AudioStream
## Ajuste de volumen de este sonido respecto al volumen general de efectos.
@export_range(-40.0, 12.0) var volume_db: float = 0.0
## Variación aleatoria del tono (0,05 = ±5 %) para que repetirlo no canse.
@export_range(0.0, 0.3) var pitch_variation: float = 0.0
