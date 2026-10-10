class_name CombatController
extends Node
## Ataques del jugador contra enemigos, juzgados contra el beat (inspirado en el prototipo
## `feature/gameplay-prototype`, adaptado al Conductor y al combo de este proyecto).
## - Ataque (J o clic izquierdo): en el suelo golpea hacia adelante; en el aire, en un arco amplio
##   adelante, arriba y abajo (nunca atrás). Al enemigo más cercano al alcance.
##   A tiempo (PERFECTO/BIEN) lo daña; fuera de tiempo rebota y rompe el combo.
##   Sin enemigo al alcance es un tajo al aire: no se juzga.
## - Contacto con un enemigo (salvo invulnerable): el jugador recibe el golpe y pierde el combo.

signal hit_landed(enemy: Enemy, judgment: int)
signal player_hurt(enemy: Enemy)

## Margen hacia atrás que todavía cuenta como "adelante".
const BEHIND_MARGIN := 12.0

var params := CombatParams.new()
var player: PlayerPrototype
var tracker: RhythmTracker
## Efecto de impacto: func(posición: Vector2, intensidad: float).
var on_impact: Callable
var enemies: Array[Enemy] = []


func register_enemy(enemy: Enemy) -> void:
	enemies.append(enemy)
	enemy.reached_player.connect(_on_contact)
	enemy.defeated.connect(func(defeated_enemy: Enemy) -> void: enemies.erase(defeated_enemy))


func clear() -> void:
	enemies.clear()


func _physics_process(_delta: float) -> void:
	if player == null or player.scripted:
		return
	if Input.is_action_just_pressed("attack"):
		attack()


func has_target() -> bool:
	return player != null and not targets(not player.is_on_floor()).is_empty()


## Enemigos al alcance, del más cercano al más lejano.
func targets(airborne: bool) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var feet := player.global_position
	var center := feet + Vector2(0.0, -PlayerPrototype.SIZE.y * 0.5)
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.active:
			continue
		var offset := enemy.body_center() - center
		if offset.x * player.facing < -BEHIND_MARGIN:
			continue
		var reach := enemy.body_radius
		var in_reach := false
		if airborne:
			in_reach = offset.length() <= params.air_radius + reach
		else:
			var forward := offset.x * player.facing
			in_reach = forward <= params.ground_reach + reach and absf(enemy.global_position.y - feet.y) <= params.ground_height
		if in_reach:
			out.append(enemy)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return center.distance_squared_to(a.body_center()) < center.distance_squared_to(b.body_center()))
	return out


func attack() -> void:
	var airborne := not player.is_on_floor()
	var list := targets(airborne)
	if list.is_empty():
		player.play_attack(airborne, false)
		return
	var judgment := tracker.register(&"attack")
	var target := list[0]
	var hit := judgment != ConductorClock.Judgment.MISS
	player.play_attack(airborne, hit)
	if hit:
		var strong := judgment == ConductorClock.Judgment.PERFECT
		var position := target.body_center()
		target.receive_hit(player.facing, strong)
		if on_impact.is_valid():
			on_impact.call(position, 0.9 if strong else 0.6)
		hit_landed.emit(target, judgment)
	else:
		# Golpe fuera de tiempo: la papa aguanta y el jugador rebota.
		player.velocity.x = -player.facing * params.miss_recoil


func _on_contact(enemy: Enemy) -> void:
	if not enemy.active or player == null or player.is_invulnerable():
		return
	player.hurt(enemy.global_position.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y),
			params.hurt_invulnerable)
	tracker.break_combo(&"hit")
	player_hurt.emit(enemy)
	if enemy.consumed_on_contact:
		enemy.defeat(signf(enemy.global_position.x - player.global_position.x))
