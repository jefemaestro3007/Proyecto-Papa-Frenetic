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
## - Papas de Bienestar U (vestidas, con habilidades propias): el cliente deja sus compras en el
##   piso (resbala), la promotora lanza muestras en llamas (arden unos beats y dejan fuego), el
##   reponedor lanza su carrito antes de embestir, los globos explotan con daño de área y el
##   guardia te empuja hacia la papa más cercana (si está solo, pega más fuerte).
## Las papas lejos de la pantalla duermen (sin proceso ni física), así el costo de la partida
## depende de lo que se ve y no de cuántas papas tiene el mapa.

signal hit_landed(enemy: Enemy, judgment: int, defeated: bool)
signal player_hurt(enemy: Enemy)
## El jugador chocó contra una papa en un stomp o dash fuera de tiempo (el calor ya lo puso el juicio).
signal player_bounced(enemy: Enemy)
signal whiffed(judgment: int)
signal projectile_hit(at: Vector2)
## Daño que no viene del cuerpo de una papa (carrito, explosión, fuego): calor y texto.
signal hazard_hurt(heat: float, text: String, at: Vector2)
## Explotaron los globos en `at` con ese radio (para el estallido y el temblor).
signal blast(at: Vector2, radius: float)

## Margen hacia atrás que todavía cuenta como "adelante".
const BEHIND_MARGIN := 12.0
const GRAZE_INVULNERABLE := 0.15
## Distancia fuera de la pantalla a la que las papas despiertan (llegan a moverse antes de verse).
const WAKE_MARGIN := 900.0
## Cada cuántos frames de física se revisa qué papas despertar.
const WAKE_INTERVAL := 6

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
## Papas indexadas por el centro de su carril (se mueven dentro de él) y las despiertas ahora.
var _sleep_index := SpatialIndex.new()
var _indexed: Array[Enemy] = []
var _awake: Array[Enemy] = []
## Mitad del carril más ancho: cuánto puede alejarse una papa del ancla del índice.
var _max_reach := 0.0
## Compras y fuego en el piso (se crea al hacer falta dentro de `world`).
var _hazards: FloorHazards
## Beats que le quedan al jugador ardiendo.
var _burn_left := 0


func _ready() -> void:
	Conductor.beat.connect(_on_beat)


func register_enemy(enemy: Enemy) -> void:
	enemies.append(enemy)
	var anchor := Vector2((enemy.lane_left + enemy.lane_right) * 0.5, enemy.position.y)
	_max_reach = maxf(_max_reach, (enemy.lane_right - enemy.lane_left) * 0.5)
	_sleep_index.add(_indexed.size(), anchor)
	_indexed.append(enemy)
	# Nace despierta; la próxima revisión la duerme si está lejos.
	_awake.append(enemy)
	# Al morir vuelve a procesar (termina su animación aunque salga de la pantalla).
	enemy.defeated.connect(func(defeated_enemy: Enemy) -> void:
		defeated_enemy.process_mode = Node.PROCESS_MODE_INHERIT)
	enemy.reached_player.connect(_on_contact)
	enemy.defeated.connect(func(defeated_enemy: Enemy) -> void: enemies.erase(defeated_enemy))
	if enemy is ThrowerEnemy:
		enemy.projectile_requested.connect(_spawn_projectile.bind(enemy is PromoterEnemy))
	if enemy is ShopperEnemy:
		enemy.spilled.connect(func(feet: Vector2) -> void: hazards().add_spill(feet, params.spill_beats))
	if enemy is StockerEnemy:
		enemy.lead_seconds = params.cart_lead_beats * Conductor.beat_length()
		enemy.cart_thrown.connect(_throw_cart)
	if enemy is BalloonEnemy:
		enemy.trigger_distance = params.balloon_trigger
		enemy.detonated.connect(_explode)
	if enemy is GuardEnemy:
		enemy.rest_seconds = params.guard_rest_beats * Conductor.beat_length()


func clear() -> void:
	enemies.clear()
	_dash_hit.clear()
	_sleep_index.clear()
	_indexed.clear()
	_awake.clear()
	_max_reach = 0.0
	_burn_left = 0
	if is_instance_valid(_hazards):
		_hazards.clear()


## Peligros del piso de la zona actual (los crea la primera vez).
func hazards() -> FloorHazards:
	if not is_instance_valid(_hazards) or _hazards.get_parent() != world:
		_hazards = FloorHazards.new()
		_hazards.style = style
		_hazards.player = player
		world.add_child(_hazards)
	return _hazards


func is_burning() -> bool:
	return _burn_left > 0


func bind_player(new_player: PlayerPrototype) -> void:
	player = new_player
	player.dash_started.connect(_on_dash_started)


func _physics_process(_delta: float) -> void:
	if world != null and Engine.get_physics_frames() % WAKE_INTERVAL == 0:
		update_awake()
	if player == null:
		return
	_update_floor()
	if player.scripted or not active or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if Input.is_action_just_pressed("attack"):
		attack()
	if player.is_dashing():
		_check_dash_contacts()


## Despierta las papas cerca de la pantalla y duerme a las que se alejaron. Solo recorre las
## celdas del índice cercanas a la pantalla, no todas las papas.
func update_awake() -> void:
	var screen := SpatialIndex.screen_rect(world, WAKE_MARGIN)
	var now: Array[Enemy] = []
	for i in _sleep_index.query(screen.grow(_max_reach)):
		var enemy := _indexed[i]
		if is_instance_valid(enemy) and enemy.active and screen.has_point(enemy.global_position):
			now.append(enemy)
	for enemy in _awake:
		if is_instance_valid(enemy) and enemy.active and not now.has(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for enemy in now:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
	_awake = now


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
	if enemy is BalloonEnemy:
		(enemy as BalloonEnemy).detonate()
		return
	if enemy is GuardEnemy:
		_guard_contact(enemy as GuardEnemy)
		return
	player.hurt(enemy.global_position.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y),
			params.hurt_invulnerable)
	tracker.break_combo(&"hit")
	player_hurt.emit(enemy)
	if enemy.consumed_on_contact:
		enemy.defeat(signf(enemy.global_position.x - player.global_position.x))


func _spawn_projectile(origin: Vector2, velocity: Vector2, flaming := false) -> void:
	if not active or world == null:
		return
	var projectile := PotatoProjectile.new()
	projectile.position = origin
	projectile.velocity = velocity
	projectile.target = player
	projectile.style = style
	projectile.flaming = flaming
	projectile.hit_player.connect(_on_projectile_hit)
	if flaming:
		projectile.hit_solid.connect(_on_flaming_landed)
	world.add_child(projectile)


func _on_projectile_hit(projectile: PotatoProjectile) -> void:
	if not active or player.is_invulnerable():
		return
	player.graze(GRAZE_INVULNERABLE)
	projectile_hit.emit(projectile.global_position)
	if projectile.flaming:
		_ignite()
	projectile.queue_free()


## Una muestra en llamas cayó al piso: deja fuego donde cayó (si debajo hay piso cerca).
func _on_flaming_landed(projectile: PotatoProjectile) -> void:
	if not active or world == null:
		return
	var from := projectile.global_position + Vector2(0.0, -PotatoProjectile.RADIUS * 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 160.0), 1)
	query.exclude = [player.get_rid()]
	var hit := world.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		hazards().add_fire(hit["position"], params.fire_beats)


## El jugador empieza a arder (o se reaviva): calor en cada beat durante `burn_beats`.
func _ignite() -> void:
	if params.burn_beats <= 0:
		return
	_burn_left = params.burn_beats
	hazards().burning = true


func _on_beat(_index: int) -> void:
	if _burn_left <= 0:
		return
	_burn_left -= 1
	if active and player != null:
		hazard_hurt.emit(params.burn_heat, "", player.global_position)
	if _burn_left <= 0 and is_instance_valid(_hazards):
		_hazards.burning = false


## Piso bajo los pies: las compras resbalan y el fuego enciende al jugador.
func _update_floor() -> void:
	if not is_instance_valid(_hazards) or _hazards.get_parent() != world:
		player.traction = 1.0
		return
	var feet := player.global_position
	player.traction = _hazards.traction_at(feet, params.spill_traction) if player.is_on_floor() else 1.0
	if active and not player.scripted and _burn_left <= 0 and _hazards.on_fire(feet):
		_ignite()
		hazard_hurt.emit(params.burn_heat, "¡QUEMA!", player.global_position)


## El reponedor suelta su carrito: rueda por su carril hacia donde mira.
func _throw_cart(stocker: StockerEnemy) -> void:
	if not active or world == null or stocker.get_parent() != world:
		return
	var cart := ShoppingCart.new()
	cart.direction = float(stocker.facing)
	cart.speed = params.cart_speed
	cart.lane_left = stocker.lane_left - stocker.body_radius
	cart.lane_right = stocker.lane_right + stocker.body_radius
	# Mismo padre que la papa (el contenido de la zona): el carril está en sus coordenadas.
	cart.position = stocker.position + Vector2(stocker.facing * stocker.body_radius, 0.0)
	cart.target = player
	cart.style = style
	cart.hit_player.connect(_on_cart_hit)
	world.add_child(cart)


func _on_cart_hit(cart: ShoppingCart) -> void:
	if not active or player.is_invulnerable() or not cart.is_rolling():
		return
	player.hurt(cart.global_position.x - cart.direction * 60.0,
			Vector2(params.hurt_knockback_x, params.hurt_knockback_y), params.hurt_invulnerable)
	tracker.break_combo(&"hit")
	hazard_hurt.emit(params.contact_heat * 1.5, "¡CARRITO!", player.global_position)


## Explotan los globos: el jugador y las papas dentro del radio reciben el golpe.
func _explode(balloon: BalloonEnemy) -> void:
	if not active:
		return
	var at := balloon.body_center()
	var radius := params.balloon_blast_radius
	blast.emit(at, radius)
	for enemy in enemies.duplicate():
		if enemy != balloon and is_instance_valid(enemy) and enemy.active \
				and enemy.body_center().distance_to(at) <= radius + enemy.body_radius:
			enemy.receive_hit(signf(enemy.global_position.x - at.x), true, 99)
	if player == null or player.is_invulnerable():
		return
	var center := player.global_position + Vector2(0.0, -PlayerPrototype.SIZE.y * 0.5)
	if center.distance_to(at) <= radius:
		player.hurt(at.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y) * 1.2, params.hurt_invulnerable)
		tracker.break_combo(&"hit")
		hazard_hurt.emit(params.contact_heat * params.balloon_blast_scale, "¡BOOM!", player.global_position)


## El guardia te alcanza: te empuja hacia la papa más cercana (con un respiro tan corto que esa
## papa puede golpearte) o, si no hay otra cerca, te cobra más calor.
func _guard_contact(guard: GuardEnemy) -> void:
	if guard.is_resting():
		return
	guard.rest()
	tracker.break_combo(&"hit")
	var nearest := _nearest_other(guard)
	if nearest != null:
		var side := signf(nearest.global_position.x - player.global_position.x)
		if side == 0.0:
			side = 1.0
		player.hurt(player.global_position.x - side, Vector2(params.guard_push, params.hurt_knockback_y * 0.5),
				GRAZE_INVULNERABLE)
		guard.contact_heat_scale = 1.0
	else:
		player.hurt(guard.global_position.x, Vector2(params.hurt_knockback_x, params.hurt_knockback_y),
				params.hurt_invulnerable)
		guard.contact_heat_scale = params.guard_alone_scale
	player_hurt.emit(guard)


## La papa viva más cercana al jugador (sin contar `except`) dentro del alcance del empujón y más
## o menos a su altura.
func _nearest_other(except: Enemy) -> Enemy:
	var best: Enemy = null
	var best_distance := params.guard_push_range
	for enemy in enemies:
		if enemy == except or not is_instance_valid(enemy) or not enemy.active:
			continue
		if absf(enemy.global_position.y - player.global_position.y) > PlayerPrototype.SIZE.y * 1.5:
			continue
		var distance := absf(enemy.global_position.x - player.global_position.x)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


static func _sort_by_distance(list: Array[Enemy], from: Vector2) -> void:
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return from.distance_squared_to(a.body_center()) < from.distance_squared_to(b.body_center()))
