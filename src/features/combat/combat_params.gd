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
## Calor al fallar un movimiento (saltar, girar), como fracción del de fallar un golpe.
@export_range(0.0, 1.0) var movement_heat_scale: float = 0.25
## Moverse a tiempo enfría poco (PERFECTO / BIEN)...
@export_range(0.0, 5.0) var movement_cooling_perfect: float = 1.0
@export_range(0.0, 5.0) var movement_cooling_good: float = 0.5
## ...y como mucho cancela esta parte del calor pasivo (< 1: moverse solo no salva a nadie).
@export_range(0.0, 0.95) var movement_cooling_share: float = 0.75
## Caída forzada fuera de ritmo: el ataque de caída no se limita, pero fallarlo castiga fuerte.
@export_range(0.0, 40.0) var slam_miss_heat: float = 20.0
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
## Papa tanque: lenta, grande y aguanta varios golpes.
@export_range(0.0, 600.0) var tank_speed: float = 115.0
@export_range(1, 10) var tank_health: int = 3
## Papa voladora.
@export_range(0.0, 600.0) var flyer_speed: float = 150.0
## Papa embestidora: velocidad de la carga y aturdimiento después.
@export_range(200.0, 2500.0) var charger_speed: float = 1000.0
@export_range(0.2, 3.0) var charger_recover: float = 1.0
## Papa tiradora: compases entre ráfagas y peso de los patrones rápidos (la negra pesa 1).
@export_range(1, 8) var thrower_bars_between: int = 1
@export_range(0.0, 3.0) var thrower_eighths: float = 0.6
@export_range(0.0, 3.0) var thrower_sixteenths: float = 0.4

@export_group("Bienestar U")
## Usa las papas vestidas de Bienestar U (con sus habilidades) en cualquier zona, para probarlas.
@export var bienestar_enemies: bool = false
## Cliente: al morir desparrama sus compras; el piso queda resbaloso esos beats.
@export_range(1, 64) var spill_beats: int = 16
## Tracción del jugador sobre las compras (1 = normal, poco = hielo).
@export_range(0.02, 1.0) var spill_traction: float = 0.15
## Promotora: muestras en llamas. Al impactar el jugador arde esos beats (calor en cada beat)...
@export_range(0, 16) var burn_beats: int = 3
@export_range(0.0, 20.0) var burn_heat: float = 2.0
## ...y si cae al suelo deja fuego esos beats.
@export_range(0, 32) var fire_beats: int = 6
## Reponedor: lanza el carrito y se lanza detrás después de estos beats.
@export_range(200.0, 2500.0) var cart_speed: float = 900.0
@export_range(0.0, 4.0) var cart_lead_beats: float = 1.0
## Globos: al acercarse se inflan un beat y explotan; el radio y el calor de la explosión.
@export_range(40.0, 600.0) var balloon_trigger: float = 150.0
@export_range(60.0, 800.0) var balloon_blast_radius: float = 230.0
@export_range(0.5, 4.0) var balloon_blast_scale: float = 1.5
## Guardia: corre rápido; al tocarte te empuja hacia la papa más cercana y, si está solo, pega más.
@export_range(0.0, 900.0) var guard_speed: float = 380.0
@export_range(100.0, 2000.0) var guard_push_range: float = 750.0
@export_range(100.0, 2000.0) var guard_push: float = 950.0
@export_range(1.0, 4.0) var guard_alone_scale: float = 2.0
## Beats que se queda quieto el guardia después de alcanzarte.
@export_range(0.0, 8.0) var guard_rest_beats: float = 2.0

@export_group("Stomp")
## Radio alrededor de los pies en el que la caída forzada golpea al aterrizar.
@export_range(40.0, 400.0) var stomp_radius: float = 120.0

@export_group("Sensación")
## Congela la acción un instante en cada golpe (los beats no se desplazan).
@export var hitstop_enabled: bool = true
@export_range(0.0, 3.0) var hitstop_scale: float = 1.0
## Acercamiento de cámara en los impactos.
@export_range(0.0, 3.0) var zoom_punch_scale: float = 1.0
## Temblor de cámara por golpes ("trauma").
@export_range(0.0, 3.0) var trauma_scale: float = 1.0
## Temblor y balanceo continuos cuando el calor pasa el umbral de tensión.
@export_range(0.0, 3.0) var tension_shake_scale: float = 1.0
