@tool
class_name SkyParams
extends Resource
## Parámetros del cielo procedural (suave o pixel-art). Sección "Cielo" del menú de debug.
## Los nombres en SHADER_UNIFORMS coinciden 1:1 con los uniforms de sky.gdshader.

const SHADER_UNIFORMS: Array[StringName] = [
	&"pixelate", &"pixel_resolution", &"star_density", &"cloud_coverage", &"mountain_layers",
	&"sun_position", &"sun_elevation", &"sun_size", &"horizon_line", &"dither_strength",
	&"snowfall", &"sky_apex", &"horizon_glow", &"sun_color", &"water_color", &"land_color",
]

@export_group("Cielo")
## Pixel-art con dithering; apagado = cielo suave a resolución completa.
@export var pixelate: bool = false
@export_range(64, 640) var pixel_resolution: int = 320
@export_range(0.0, 1.0) var star_density: float = 0.0
@export_range(0.0, 1.0) var cloud_coverage: float = 0.25
@export_range(0, 6) var mountain_layers: int = 0
@export_range(0.0, 1.0) var sun_position: float = 0.72
@export_range(0.0, 1.0) var sun_elevation: float = 0.45
@export_range(0.0, 64.0) var sun_size: float = 30.0
@export_range(0.2, 1.0) var horizon_line: float = 0.82
@export_range(0.0, 1.0) var dither_strength: float = 0.6
@export_range(0.0, 1.0) var snowfall: float = 0.06

@export_group("Paleta")
@export var sky_apex: Color = Color("c4121b")
@export var horizon_glow: Color = Color("e8262c")
@export var sun_color: Color = Color("ffb08a")
@export var water_color: Color = Color("2b2a45")
@export var land_color: Color = Color("6e2a35")


## Colores de las capas de skyline, derivados de la paleta para que la ciudad
## siempre pertenezca al cielo que tiene detrás.
func skyline_far_color() -> Color:
	return land_color.lerp(horizon_glow, 0.5)


func skyline_near_color() -> Color:
	return land_color.lerp(horizon_glow, 0.18)
