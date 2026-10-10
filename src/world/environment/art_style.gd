@tool
class_name ArtStyle
extends Resource
## Modo gráfico de una zona: cómo se dibujan estructura, objetos y marcas, y el post-proceso
## de pantalla. Sección "Estilo" del menú de debug. Los datos del mapa no cambian entre estilos.

## Los que también son uniforms de frenetic_post.gdshader (mismo nombre).
const POST_UNIFORMS: Array[StringName] = [
	&"pixel_size", &"color_levels", &"dither", &"vignette", &"vignette_softness", &"desaturate",
	&"tint", &"grain", &"aberration", &"spotlight", &"spotlight_radius", &"light_shaft",
]

## Presets de cielo e iluminación que acompañan a este estilo (nombre de archivo sin .tres).
@export var sky_preset: String = "rojo_frenetico"
@export var lighting_preset: String = "rojo_frenetico"

@export_group("Trazo")
@export_range(0.0, 12.0) var outline_width: float = 4.0
## Irregularidad del contorno en px (0 = geométrico, más = dibujado a mano).
@export_range(0.0, 10.0) var wobble: float = 0.0
@export var drop_shadows: bool = false
@export var hazard_stripes: bool = true
@export var facade_windows: bool = true

@export_group("Marcas")
## Fracción de cada tipo de marca generada que se muestra (0..1).
@export_range(0.0, 1.0) var blood_amount: float = 0.35
@export_range(0.0, 1.0) var crack_amount: float = 0.5
@export_range(0.0, 1.0) var stain_amount: float = 0.3
@export_range(0.0, 1.0) var rubble_amount: float = 0.3
## Probabilidad de que una ventana de fachada esté encendida.
@export_range(0.0, 1.0) var lit_windows: float = 0.12
## Mugre de las texturas (azoteas y skyline).
@export_range(0.0, 1.0) var grime: float = 0.2
@export_range(0.0, 1.0) var skyline_dirt: float = 0.35

@export_group("Colores")
@export var structure: Color = FreneticPalette.NAVY
@export var structure_dark: Color = FreneticPalette.NAVY_DARK
@export var structure_light: Color = FreneticPalette.NAVY_LIGHT
@export var edge: Color = FreneticPalette.CREAM
@export var outline: Color = FreneticPalette.INK
@export var accent: Color = FreneticPalette.YELLOW
@export var blood: Color = FreneticPalette.BLOOD
@export var rock: Color = Color("5a5458")
@export var rock_light: Color = Color("7c7579")
@export var window_dark: Color = FreneticPalette.NAVY_DARK
@export var window_lit: Color = Color("ffb08a")

@export_group("Post-proceso")
## Tamaño del pixel de pantalla (1 = sin pixelar).
@export_range(1.0, 12.0) var pixel_size: float = 1.0
## Niveles por canal de color (0 = sin reducir paleta).
@export_range(0.0, 32.0) var color_levels: float = 0.0
@export_range(0.0, 1.0) var dither: float = 0.0
@export_range(0.0, 1.0) var vignette: float = 0.0
@export_range(0.0, 1.0) var vignette_softness: float = 0.5
@export_range(0.0, 1.0) var desaturate: float = 0.0
@export var tint: Color = Color.WHITE
@export_range(0.0, 0.3) var grain: float = 0.0
@export_range(0.0, 6.0) var aberration: float = 1.5
## Foco de luz que sigue al jugador (0 = apagado).
@export_range(0.0, 1.0) var spotlight: float = 0.0
@export_range(0.1, 1.5) var spotlight_radius: float = 0.6
## Haz de luz diagonal desde arriba.
@export_range(0.0, 1.0) var light_shaft: float = 0.0


## Firma de todos los valores: si cambia, hay que redibujar lo estático.
func signature() -> int:
	var values := []
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append(get(property.name))
	return hash(values)
