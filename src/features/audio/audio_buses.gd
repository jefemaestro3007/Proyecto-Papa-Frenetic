class_name AudioBuses
extends RefCounted
## Nombres de los buses de audio (los crea `Settings` al iniciar, hacia Master). Clase aparte sin
## dependencias para que el Conductor y los efectos no dependan del autoload de configuración.

const MUSIC := &"Musica"
## Efectos, metrónomo y guía sonora.
const SFX := &"Efectos"
