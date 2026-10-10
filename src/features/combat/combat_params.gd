@tool
class_name CombatParams
extends Resource
## Combate y enemigos integrados desde el prototipo `feature/gameplay-prototype`.
## Pestaña "Combate" del menú de debug (presets en `presets/combate/`).

@export_group("Calor")
@export var heat_enabled: bool = true
## Sin game over la papa explota pero el calor se reinicia (útil para probar).
@export var game_over_enabled: bool = true
@export_range(0.0, 10.0) var passive_heating: float = 1.0
@export_range(0.0, 30.0) var perfect_cooling: float = 8.0
@export_range(0.0, 30.0) var good_cooling: float = 4.0
@export_range(0.0, 40.0) var miss_heating: float = 10.0
## Peso del calor en saltos y giros (atacar, caída forzada y dash pesan 1).
@export_range(0.0, 1.0) var movement_heat_scale: float = 0.25
@export_range(0.0, 40.0) var contact_heat: float = 10.0
@export_range(0.0, 40.0) var projectile_heat: float = 5.0
@export_range(0.0, 40.0) var fall_heat: float = 15.0
## Tajo al aire fuera de ritmo (castiga el spam sin romper el combo).
@export_range(0.0, 20.0) var whiff_heat: float = 5.0
## Desde este calor la partida se siente tensa (temblor, viñeta).
@export_range(0.0, 100.0) var intensity_threshold: float = 50.0
@export_range(1.0, 30.0) var fuse_seconds: float = 10.0

@export_group("Ataque")
## Alcance del ataque en el suelo: hacia adelante y de alto.
@export_range(40.0, 400.0) var ground_reach: float = 150.0
@export_range(40.0, 300.0) var ground_height: float = 130.0
## Radio del ataque aéreo (adelante, arriba y abajo; nunca atrás).
@export_range(40.0, 400.0) var air_radius: float = 160.0
## Rebote del jugador al golpear fuera de tiempo.
@export_range(0.0, 1200.0) var miss_recoil: float = 420.0

@export_group("Golpe recibido")
@export_range(0.0, 3.0) var hurt_invulnerable: float = 0.7
@export_range(0.0, 1500.0) var hurt_knockback_x: float = 520.0
@export_range(0.0, 1500.0) var hurt_knockback_y: float = 420.0

@export_group("Enemigos")
## Cantidad de enemigos que pone cada zona (0 = ninguno).
@export_range(0.0, 1.0) var enemy_density: float = 0.4
## Papa zombi común.
@export_range(0.0, 600.0) var potato_speed: float = 170.0
@export_range(1, 10) var potato_health: int = 1
## Distancia vertical a la que una papa considera que comparte nivel con el jugador.
@export_range(10.0, 200.0) var same_level_tolerance: float = 60.0
