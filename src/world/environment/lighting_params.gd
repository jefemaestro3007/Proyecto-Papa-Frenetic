@tool
class_name LightingParams
extends Resource
## Iluminación dinámica del mundo. Sección "Iluminación" del menú de debug.

## Los que también son uniforms del shader del cielo.
const SHADER_UNIFORMS: Array[StringName] = [&"beat_flash", &"sun_beat_pulse"]

## 1 = mundo a plena luz; menos = se tiñe del color del cielo.
@export_range(0.0, 1.0) var ambient: float = 1.0
## Cuánto tiñe el color del sol al mundo.
@export_range(0.0, 1.0) var sun_light: float = 0.25
## Intensidad del destello en cada beat (cielo y mundo).
@export_range(0.0, 1.0) var beat_flash: float = 0.5
## Cuánto crece el sol en cada beat.
@export_range(0.0, 1.0) var sun_beat_pulse: float = 0.6
## Cuánto amplifica el combo el destello del mundo.
@export_range(0.0, 1.0) var combo_flash: float = 0.6


## Tinte multiplicativo del mundo (CanvasModulate) para un pulso (0..1) y calor de combo (0..1).
func world_tint(sky: SkyParams, pulse: float, heat: float) -> Color:
	var tint := Color.WHITE.lerp(sky.sky_apex.lightened(0.35), 1.0 - ambient)
	tint *= Color.WHITE.lerp(sky.sun_color, sun_light * 0.4)
	var flash := sky.horizon_glow * (pulse * beat_flash * (0.12 + heat * combo_flash * 0.3))
	return Color(tint.r + flash.r, tint.g + flash.g, tint.b + flash.b, 1.0)
