class_name CombatController
extends Node
## Ataques del jugador contra enemigos, juzgados contra el beat (inspirado en el prototipo
## `feature/gameplay-prototype`, adaptado al Conductor y al combo de este proyecto).
## - Ataque (J o clic izquierdo): en el suelo golpea hacia adelante; en el aire, en un arco amplio
##   adelante, arriba y abajo (nunca atrás). Al enemigo más cercano al alcance.
##   A tiempo (PERFECTO/BIEN) lo daña; fuera de tiempo rebota y rompe el combo.
##   Sin enemigo al alcance es un tajo al aire: no rompe el combo, pero fuera de tiempo calienta
##   (`whiffed`), así se castiga el spam sin juzgar cada tajo como fallo.
## - Stomp (caída forzada): al aterrizar golpea a las papas cerca de los pies con el juicio de la
##   caída. Si alguna aguanta, el jugador rebota sobre ella; fallado contra una papa, lo empuja.
## - Dash (Shift, en el suelo): se juzga al iniciarlo y cuenta por cada papa que atraviesa. A tiempo
##   la golpea (si aguanta, el dash se corta y rebota); fuera de tiempo choca y lo empuja.
## - Contacto con un enemigo (salvo invulnerable): el jugador recibe el golpe y pierde el combo.
## - Papas fritas de la tiradora: suman calor y dan un respiro breve, sin romper el combo.

signal hit_landed(enemy: Enemy, judgment: int, defeated: bool)
signal player_hurt(enemy: Enemy)
## El jugador chocó contra una papa en un stomp o dash fuera de tiempo (el calor ya lo puso el juicio).
signal player_bounced(enemy: Enemy)
signal whiffed(judgment: int)
signal projectile_hit(at: Vector2)

## Margen hacia atrás que todavía cuenta como "adelante".
const BEHIND_MARGIN := 12.0
const GRAZE_INVULNERABLE := 0.15

var params := CombatParams.new()
var player: PlayerPrototype
var tracker: RhythmTracker
## Dónde se agregan los proyectiles (el contenido generado de la zona).
var world: Node2D
var style: ArtStyle
## Falso fuera de partida (game over, victoria): no se ataca ni se recibe daño.
var active := true
var enemies: Array[Enemy] = []

var _dash_judgment := ConductorClock.Judgment.MISS
var _dash_hit: Array[Enemy] = []


func register_enemy(enemy: Enemy) -> void:
	enemies.append(enemy)
	enemy.reached_player.connect(_on_contact)
	enemy.defeated.connect(func(defeated_enemy: Enemy) -> void: enemies.erase(defeated_enemy))
	if enemy is ThrowerEnemy:
		enemy.projectile_requested.connect(_spawn_projectile)


func clear() -> void:
	enemies.clear()
	_dash_hit.clear()


func bind_player(new_player: PlayerPrototype) -> void:
	player = new_player
	player.dash_started.connect(_on_dash_started)


func _physics_process(_delta: float) -> void:
	if player == null or player.scripted or not active or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if Input.is_action_just_pressed("attack"):
		attack()
	if player.is_dashing():
		_check_dash_contacts()


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
			in_reach = forward <= params.ground_reach + reach \
					and absf(enemy.body_center().y - center.y) <= params.ground_height
		if in_reach:
			out.append(enemy)
	_sort_by_distance(out, center)
	return out


func attack() -> void:
	var airborne := not player.is_on_floor()
	var list := targets(airborne)
	if list.is_empty():
		player.play_attack(airborne, false)
		whiffed.emit(Conductor.judge())
		return
	var judgment := tracker.register(&"air_attack" if airborne else &"attack")
	var target := list[0]
	var hit := judgment != ConductorClock.Judgment.MISS
	player.play_attack(airborne, hit)
	if hit:
		_hit(target, judgment, player.facing)
	else:
		# Golpe fuera de tiempo: la papa aguanta y el jugador rebota.
		player.velocity.x = -player.facing * params.miss_recoil


## Aterrizaje de la caída forzada con su juicio (lo registra la zona). Devuelve true si había
## papas debajo (entonces cuenta como golpe).
func stomp(judgment: int) -> bool:
	if not active:
		return false
	var feet := player.global_position
	var list: Array[Enemy] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.active \
				and enemy.body_center().distance_to(feet) <= params.stomp_radius + enemy.body_radius:
			list.append(enemy)
	if list.is_empty():
		return false
	_sort_by_distance(list, feet)
	if judgment == ConductorClock.Judgment.MISS:
		# Stomp fuera de ritmo: la papa aguanta y empuja al jugador.
		player.hurt(list[0].global_position.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y) * 0.6,
				params.hurt_invulnerable)
		player_bounced.emit(list[0])
		return true
	var survivor: Enemy = null
	for enemy in list:
		if not _hit(enemy, judgment, signf(enemy.global_position.x - feet.x)):
			survivor = enemy
	if survivor != null:
		# Una papa resistente aguanta el stomp: el jugador rebota sobre ella.
		player.recoil(survivor.global_position.x)
	return true


func _on_dash_started(_direction: float) -> void:
	# El timing se fija al pulsar; solo cuenta si el dash atraviesa a una papa.
	_dash_judgment = Conductor.judge()
	_dash_hit.clear()


func _check_dash_contacts() -> void:
	var rect := Rect2(player.global_position - Vector2(PlayerPrototype.SIZE.x * 0.5, PlayerPrototype.SIZE.y),
			PlayerPrototype.SIZE)
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or not enemy.active or _dash_hit.has(enemy):
			continue
		if not rect.grow(enemy.body_radius).has_point(enemy.body_center()):
			continue
		_dash_hit.append(enemy)
		var judgment := tracker.register_judgment(&"dash", _dash_judgment)
		if judgment == ConductorClock.Judgment.MISS:
			# Dash fuera de ritmo: choca contra la papa.
			player.cancel_dash()
			player.hurt(enemy.global_position.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y) * 0.6,
					params.hurt_invulnerable)
			player_bounced.emit(enemy)
			return
		if not _hit(enemy, judgment, player.facing):
			# Resiste (tanque): el dash se corta y el jugador rebota.
			player.recoil(enemy.global_position.x)
			return


## Golpea a una papa. Devuelve true si la derrota (las resistentes pueden aguantar).
func _hit(enemy: Enemy, judgment: int, direction: float) -> bool:
	var defeated := enemy.receive_hit(direction, judgment == ConductorClock.Judgment.PERFECT)
	hit_landed.emit(enemy, judgment, defeated)
	return defeated


func _on_contact(enemy: Enemy) -> void:
	if not active or not enemy.active or player == null or player.is_invulnerable():
		return
	player.hurt(enemy.global_position.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y),
			params.hurt_invulnerable)
	tracker.break_combo(&"hit")
	player_hurt.emit(enemy)
	if enemy.consumed_on_contact:
		enemy.defeat(signf(enemy.global_position.x - player.global_position.x))


func _spawn_projectile(origin: Vector2, velocity: Vector2) -> void:
	if not active or world == null:
		return
	var projectile := PotatoProjectile.new()
	projectile.position = origin
	projectile.velocity = velocity
	projectile.target = player
	projectile.style = style
	projectile.hit_player.connect(_on_projectile_hit)
	world.add_child(projectile)


func _on_projectile_hit(projectile: PotatoProjectile) -> void:
	if not active or player.is_invulnerable():
		return
	player.graze(GRAZE_INVULNERABLE)
	projectile_hit.emit(projectile.global_position)
	projectile.queue_free()


static func _sort_by_distance(list: Array[Enemy], from: Vector2) -> void:
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return from.distance_squared_to(a.body_center()) < from.distance_squared_to(b.body_center()))
