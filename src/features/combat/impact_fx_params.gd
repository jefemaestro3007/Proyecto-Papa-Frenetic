@tool
class_name ImpactFxParams
extends Resource
## Efectos del impacto de una caída que "ataca". Sección "Efectos" del menú de debug.

@export_group("Rayos")
@export_range(0, 48) var ray_count_min: int = 10
@export_range(0, 48) var ray_count_max: int = 16
@export_range(10.0, 600.0) var ray_length_min: float = 80.0
@export_range(10.0, 600.0) var ray_length_max: float = 190.0
@export_range(2.0, 80.0) var ray_width_min: float = 16.0
@export_range(2.0, 80.0) var ray_width_max: float = 30.0
## Apertura del abanico, centrado hacia arriba (360 = círculo completo).
@export_range(10.0, 360.0) var spread_degrees: float = 162.0
## Desplazamiento lateral del quiebre de cada rayo (aspecto dentado).
@export_range(0.0, 40.0) var jaggedness: float = 6.0
@export_range(0.0, 1.0) var ray_lifetime: float = 0.28
@export_range(0.1, 3.0) var scale_start: float = 0.6
@export_range(0.1, 3.0) var scale_end: float = 1.25
@export var fill_color: Color = FreneticPalette.YELLOW
@export var outline_color: Color = FreneticPalette.INK
@export_range(0.0, 12.0) var outline_width: float = 4.0

@export_group("Escombros")
@export_range(0, 120) var debris_count: int = 12
@export_range(0.0, 2000.0) var debris_speed_min: float = 250.0
@export_range(0.0, 2000.0) var debris_speed_max: float = 750.0
@export_range(0.0, 6000.0) var debris_gravity: float = 2400.0
@export_range(1.0, 40.0) var debris_size_min: float = 4.0
@export_range(1.0, 40.0) var debris_size_max: float = 10.0
@export_range(0.05, 3.0) var debris_lifetime: float = 0.6
@export var debris_color: Color = FreneticPalette.CREAM
@export var debris_color_alt: Color = FreneticPalette.NAVY_LIGHT

@export_group("Pantalla")
@export_range(0.0, 60.0) var screen_shake: float = 18.0
@export_range(0.0, 2.0) var glitch_strength: float = 1.0

@export_group("Intensidad por caída")
## Escala de todo el efecto según el tipo de caída y el juicio de ritmo (0 = sin efecto).
@export_range(0.0, 4.0) var hard_landing_perfect: float = 1.6
@export_range(0.0, 4.0) var hard_landing_good: float = 1.15
@export_range(0.0, 4.0) var hard_landing_miss: float = 0.7
@export_range(0.0, 4.0) var slam_perfect: float = 2.1
@export_range(0.0, 4.0) var slam_good: float = 1.5
@export_range(0.0, 4.0) var slam_miss: float = 0.5
## Chispa al despegar con un salto a tiempo (no es caída; 0 la desactiva).
@export_range(0.0, 2.0) var jump_spark: float = 0.5


## Cuánto glitch de pantalla produce un impacto de esta intensidad (0..1).
func shock_for(strength: float) -> float:
	return clampf((strength - 0.4) * 0.6, 0.0, 1.0) * glitch_strength
