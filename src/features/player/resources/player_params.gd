@tool
class_name PlayerParams
extends Resource
## Opciones del jugador. Sección "Jugador" del menú de debug.

@export_group("Movimiento")
@export_range(100.0, 1500.0) var max_speed: float = 560.0
@export_range(500.0, 10000.0) var ground_accel: float = 4200.0
@export_range(0.0, 10000.0) var air_accel: float = 2600.0

@export_group("Salto")
@export_range(300.0, 2000.0) var jump_force: float = 1080.0
@export_range(500.0, 6000.0) var gravity: float = 2700.0
## Gravedad extra al caer (más peso, menos "flote").
@export_range(1.0, 3.0) var fall_gravity_multiplier: float = 1.0
## Al soltar el salto mientras sube, la velocidad vertical se multiplica por esto (1 = desactivado).
@export_range(0.1, 1.0) var jump_cut: float = 0.5
## Tiempo para saltar después de salir de un borde.
@export_range(0.0, 0.3) var coyote_time: float = 0.08
## Tiempo que se recuerda un salto pulsado antes de tocar suelo.
@export_range(0.0, 0.3) var jump_buffer: float = 0.1

@export_group("Caídas")
## Una caída normal solo "ataca" (estallido, glitch) si cae desde al menos esta altura en px.
## Las caídas forzadas atacan siempre.
@export_range(0.0, 2000.0) var hard_landing_height: float = 320.0

@export_group("Caída forzada")
@export var fast_fall_enabled: bool = true
@export_range(800.0, 5000.0) var fast_fall_speed: float = 2400.0
## Multiplicador de puntos de un aterrizaje forzado a tiempo.
@export_range(1.0, 5.0) var slam_points_multiplier: float = 2.0
## Castigo por aterrizaje forzado fuera de tiempo: duración y velocidad durante el aturdimiento.
@export_range(0.0, 2.0) var stumble_time: float = 0.5
@export_range(0.0, 1.0) var stumble_speed: float = 0.4

@export_group("Recompensas de ritmo")
@export_range(1.0, 2.0) var jump_boost_perfect: float = 1.18
@export_range(1.0, 2.0) var jump_boost_good: float = 1.08
@export_range(1.0, 2.5) var turn_boost_perfect: float = 1.4
@export_range(1.0, 2.5) var turn_boost_good: float = 1.2
@export_range(0.0, 2.0) var boost_time: float = 0.45
@export_range(0.05, 1.0) var spin_time: float = 0.28

@export_group("Visual")
## Cuánto rebota el personaje al compás estando en el suelo.
@export_range(0.0, 0.4) var beat_bounce: float = 0.1
