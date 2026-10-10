class_name BienestarWorld
extends Node2D
## Mecánicas de Bienestar U con su estado y sus colisiones (las vistas solo leen el estado):
## - Racks: estar debajo o encima suma un beat de carga; al llegar al límite se derrumban en el beat
##   (dañan a quien esté debajo y dejan escombros). Un stomp sobre la viga los tira en el acto.
## - Freezers: abren y cierran con el beat; enfrente de uno abierto la papa se enfría (con tope por
##   freezer) y la escarcha frena.
## - Cintas de caja: llevan al jugador solo durante el primer tramo de cada beat.
## - Piso mojado: poca tracción.
## - Carritos: W para montarse (inercia y más velocidad; atropellan papas), S para bajarse.
## - Cortinas metálicas: ciclo abierta → bajan de a un escalón por beat → cerradas → suben. Con poco
##   espacio solo se pasa en dash.
## - Freidoras: salpican aceite cada N beats.
## Solo se recorre lo cercano al jugador (SpatialIndex), así el costo no depende del tamaño.

## Daño de una mecánica (rack, aceite, cortina): calor y texto. La zona lo aplica.
signal hurt(heat: float, text: String)
## Enfriamiento de un freezer (calor negativo); `first` = primer frío de ese freezer.
signal cooled(amount: float, first: bool)
## Se derrumbó un rack (para el estallido y el temblor).
signal rack_collapsed(index: int)

const NEAR := 1400.0
## Altura libre mínima para pasar caminando bajo una cortina (alto del jugador) y en dash.
const WALK_GAP := 96.0
const DASH_GAP := 40.0
const BELT_ACTIVE := 0.35
const SPLASH_BEATS := 0.4
const DEBRIS_HEIGHT := 60.0
const CART_REACH := 80.0
const CART_TRACTION := 0.3

var data: BienestarMapData
var params: BienestarParams
var combat: CombatParams
var player: PlayerPrototype
var enemies: Callable

## Por rack: beats de carga y si ya cayó (con su edad para la animación).
var rack_stress: PackedInt32Array = []
var rack_down: Array[bool] = []
var rack_age: PackedFloat32Array = []
## Lo que le queda por enfriar a cada freezer.
var freezer_left: PackedFloat32Array = []
## Carritos estacionados (pies) y si el jugador va montado.
var parked: Array[Vector2] = []
var riding := false
## Desplazamiento acumulado de las cintas (para dibujar las franjas).
var belt_travel := 0.0

var _rack_bodies: Array[StaticBody2D] = []
var _shutter_bodies: Array[StaticBody2D] = []
var _shutter_shapes: Array[RectangleShape2D] = []
var _rack_index := SpatialIndex.new()
var _freezer_index := SpatialIndex.new()
var _shutter_index := SpatialIndex.new()
var _fryer_index := SpatialIndex.new()
var _frosted := false
var _splashed: Dictionary = {}
var _dash_through: Array[StaticBody2D] = []


func setup(p_data: BienestarMapData, p_params: BienestarParams, p_combat: CombatParams, p_player: PlayerPrototype) -> void:
	data = p_data
	params = p_params
	combat = p_combat
	player = p_player
	rack_stress.resize(data.racks.size())
	rack_stress.fill(0)
	rack_down.clear()
	rack_age.resize(data.racks.size())
	rack_age.fill(0.0)
	for i in data.racks.size():
		rack_down.append(false)
		var rack := data.racks[i]
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = rack.rect.size
		shape.shape = rect
		shape.position = rack.rect.get_center()
		shape.one_way_collision = true
		body.add_child(shape)
		add_child(body)
		_rack_bodies.append(body)
		_rack_index.add(i, rack.rect.get_center())
	freezer_left.resize(data.freezers.size())
	freezer_left.fill(params.freezer_cap)
	for i in data.freezers.size():
		_freezer_index.add(i, data.freezers[i].rect.get_center())
	for i in data.shutters.size():
		var shutter := data.shutters[i]
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
		_shutter_bodies.append(body)
		_shutter_shapes.append(rect)
		_shutter_index.add(i, Vector2(shutter.x, data.surface_y(shutter.floor)))
		_update_shutter_body(i)
	for i in data.fryers.size():
		_fryer_index.add(i, data.fryers[i].rect.get_center())
	parked = data.carts.duplicate()
	riding = false
	if not Conductor.beat.is_connected(_on_beat):
		Conductor.beat.connect(_on_beat)


func _exit_tree() -> void:
	if Conductor.beat.is_connected(_on_beat):
		Conductor.beat.disconnect(_on_beat)


# --- Estado que leen las vistas ----------------------------------------------------------

## 0 (sin carga) a 1 (se cae en el próximo beat).
func rack_load(index: int) -> float:
	return float(rack_stress[index]) / maxi(params.rack_collapse_beats, 1)


func freezer_open(index: int) -> bool:
	return posmod(Conductor.beat_index() + data.freezers[index].phase, 4) < 2


## Altura libre bajo la cortina (desde el piso) y beats que faltan para que cierre (-1 si no baja).
func shutter_gap(index: int) -> float:
	var shutter := data.shutters[index]
	var height := data.surface_y(shutter.floor) - data.floors[shutter.floor].ceiling
	var t := _shutter_time(index)
	var open := float(params.shutter_open_beats)
	var lower := float(params.shutter_lower_beats)
	var closed := float(params.shutter_closed_beats)
	if t < open:
		return height
	if t < open + lower:
		# Baja de a un escalón por beat (se nota el compás), con un pequeño deslizamiento.
		var step := floorf(t - open) + smoothstep(0.0, 0.25, fposmod(t - open, 1.0))
		return height * (1.0 - step / lower)
	if t < open + lower + closed:
		return 0.0
	return height * clampf(t - open - lower - closed, 0.0, 1.0)


func shutter_beats_left(index: int) -> int:
	var t := _shutter_time(index)
	var open := float(params.shutter_open_beats)
	var lower := float(params.shutter_lower_beats)
	if t >= open and t < open + lower:
		return ceili(open + lower - t)
	return -1


func _shutter_time(index: int) -> float:
	var cycle := params.shutter_open_beats + params.shutter_lower_beats + params.shutter_closed_beats + 1
	return fposmod(Conductor.beat_position() + data.shutters[index].phase, cycle)


## 0..1 mientras dura una salpicadura de la freidora (0 si no salpica).
func fryer_splash(index: int) -> float:
	var position := Conductor.beat_position()
	var beat := floori(position)
	if posmod(beat + data.fryers[index].phase, maxi(params.fryer_every, 1)) != 0:
		return 0.0
	var t := (position - beat) / SPLASH_BEATS
	return clampf(t, 0.0, 1.0) if t < 1.0 else 0.0


## Zona que alcanza el aceite de una freidora.
func fryer_area(index: int) -> Rect2:
	var rect := data.fryers[index].rect
	return Rect2(rect.position.x - 70.0, rect.position.y - 190.0, rect.size.x + 140.0, rect.size.y + 190.0)


## Si las cintas se mueven ahora (primer tramo de cada beat).
func belts_moving() -> bool:
	return Conductor.phase() < BELT_ACTIVE


func is_frosted() -> bool:
	return _frosted


# --- Jugador ---------------------------------------------------------------------------

## Agarre del piso bajo el jugador (piso mojado, carrito).
func traction() -> float:
	var value := CART_TRACTION if riding else 1.0
	if player.is_on_floor():
		var feet := player.global_position
		for wet in data.wet:
			if wet.has_point(feet + Vector2(0.0, -4.0)):
				value = minf(value, params.wet_traction)
	return value


## W cerca de un carrito estacionado: se monta. Devuelve true si se montó.
func try_mount() -> bool:
	if riding or not player.is_on_floor():
		return false
	var feet := player.global_position
	for i in parked.size():
		if absf(parked[i].x - feet.x) < CART_REACH and absf(parked[i].y - feet.y) < 30.0:
			parked.remove_at(i)
			riding = true
			return true
	return false


## Se baja: el carrito queda donde está.
func dismount() -> void:
	if not riding:
		return
	riding = false
	parked.append(player.global_position)


func _physics_process(delta: float) -> void:
	if data == null or player == null:
		return
	var near := Rect2(player.global_position - Vector2(NEAR, NEAR), Vector2(NEAR, NEAR) * 2.0)
	for i in _shutter_index.query(near):
		_update_shutter_body(i)
		_shutter_dash(i)
	player.speed_scale = (params.cart_speed_scale if riding else 1.0) * (params.freezer_slow if _frosted else 1.0)
	_frosted = false
	if player.scripted:
		return
	var feet := player.global_position
	for i in _freezer_index.query(near):
		var freezer := data.freezers[i]
		if freezer_open(i) and feet.x > freezer.rect.position.x - 20.0 and feet.x < freezer.rect.end.x + 20.0 \
				and absf(feet.y - freezer.rect.end.y) < 40.0:
			_frosted = true
			if freezer_left[i] > 0.0:
				var amount := minf(params.freezer_cooling * delta, freezer_left[i])
				var first := is_equal_approx(freezer_left[i], params.freezer_cap)
				freezer_left[i] -= amount
				cooled.emit(-amount, first)
	if belts_moving() and player.is_on_floor():
		var step := params.belt_step / (BELT_ACTIVE * Conductor.beat_length()) * delta
		for belt in data.belts:
			if feet.x > belt.rect.position.x and feet.x < belt.rect.end.x and absf(feet.y - belt.rect.position.y) < 6.0:
				player.position.x += belt.direction * step
				break
	if belts_moving():
		belt_travel += params.belt_step / (BELT_ACTIVE * Conductor.beat_length()) * delta
	for i in _fryer_index.query(near):
		var splash := fryer_splash(i)
		if splash <= 0.0:
			_splashed.erase(i)
		elif not _splashed.has(i) and fryer_area(i).has_point(feet + Vector2(0.0, -40.0)):
			_splashed[i] = true
			if not player.is_invulnerable():
				player.graze(0.3)
				hurt.emit(params.fryer_heat, "¡ACEITE!")


func _process(delta: float) -> void:
	for i in rack_down.size():
		if rack_down[i]:
			rack_age[i] += delta


# --- Racks ---------------------------------------------------------------------------------

func _on_beat(_index: int) -> void:
	if data == null or player == null or player.scripted:
		return
	var feet := player.global_position
	var near := Rect2(feet - Vector2(NEAR, NEAR), Vector2(NEAR, NEAR) * 2.0)
	for i in _rack_index.query(near):
		if rack_down[i] or not _in_rack(i, feet):
			continue
		rack_stress[i] += 1
		if rack_stress[i] >= params.rack_collapse_beats:
			collapse(i)


## El jugador está debajo de la viga (de pie en el piso) o encima.
func _in_rack(index: int, feet: Vector2) -> bool:
	var rack := data.racks[index]
	if feet.x < rack.rect.position.x or feet.x > rack.rect.end.x:
		return false
	var floor_y := data.surface_y(rack.floor)
	return feet.y > rack.rect.position.y - 8.0 and feet.y < floor_y + 8.0


## Rack bajo los pies (de pie sobre la viga) o -1.
func rack_under(feet: Vector2) -> int:
	for i in _rack_index.query(Rect2(feet - Vector2(600.0, 600.0), Vector2(1200.0, 1200.0))):
		var rect := data.racks[i].rect
		if not rack_down[i] and feet.x >= rect.position.x and feet.x <= rect.end.x and absf(feet.y - rect.position.y) < 8.0:
			return i
	return -1


## Derrumbe: la viga desaparece, quedan escombros y lo que estaba debajo recibe el golpe.
func collapse(index: int) -> void:
	if rack_down[index]:
		return
	rack_down[index] = true
	rack_age[index] = 0.0
	_rack_bodies[index].queue_free()
	var rack := data.racks[index]
	var floor_y := data.surface_y(rack.floor)
	var debris := Rect2(rack.rect.position.x + 20.0, floor_y - DEBRIS_HEIGHT, rack.rect.size.x - 40.0, DEBRIS_HEIGHT)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = debris.size
	shape.shape = rect
	shape.position = debris.get_center()
	body.add_child(shape)
	add_child.call_deferred(body)
	rack_collapsed.emit(index)
	var feet := player.global_position
	if not player.scripted and feet.x > rack.rect.position.x and feet.x < rack.rect.end.x \
			and feet.y > rack.rect.end.y and feet.y < floor_y + 8.0:
		# Lo aplasta: queda arriba de los escombros, empujado y con calor.
		player.position.y = debris.position.y - 2.0
		if not player.is_invulnerable():
			player.hurt(rack.rect.get_center().x, Vector2(combat.hurt_knockback_x, combat.hurt_knockback_y),
					combat.hurt_invulnerable)
			hurt.emit(combat.contact_heat * 1.5, "¡DERRUMBE!")
	if enemies.is_valid():
		for enemy: Enemy in enemies.call():
			var at := enemy.global_position
			if is_instance_valid(enemy) and enemy.active and at.x > rack.rect.position.x and at.x < rack.rect.end.x \
					and at.y > rack.rect.end.y and at.y < floor_y + 30.0:
				enemy.receive_hit(signf(at.x - rack.rect.get_center().x), true)


# --- Cortinas ------------------------------------------------------------------------------

func _update_shutter_body(index: int) -> void:
	var shutter := data.shutters[index]
	var floor_y := data.surface_y(shutter.floor)
	var ceiling := data.floors[shutter.floor].ceiling
	var bottom := floor_y - shutter_gap(index)
	var height := maxf(bottom - ceiling, 1.0)
	_shutter_shapes[index].size = Vector2(shutter.width, height)
	var shape := _shutter_bodies[index].get_child(0) as CollisionShape2D
	shape.position = Vector2(shutter.x + shutter.width * 0.5, ceiling + height * 0.5)
	# Si baja sobre el jugador, lo saca hacia el lado más cercano.
	var feet := player.global_position if player != null else Vector2.INF
	if player != null and not player.scripted and not _dash_through.has(_shutter_bodies[index]) \
			and absf(feet.x - (shutter.x + shutter.width * 0.5)) < shutter.width * 0.5 + PlayerPrototype.SIZE.x * 0.5 \
			and feet.y - PlayerPrototype.SIZE.y < bottom and feet.y > ceiling and feet.y <= floor_y + 4.0:
		var side := -1.0 if feet.x < shutter.x + shutter.width * 0.5 else 1.0
		player.position.x = shutter.x + shutter.width * 0.5 + side * (shutter.width * 0.5 + PlayerPrototype.SIZE.x * 0.5 + 2.0)


## En dash, con lugar suficiente, se pasa por debajo aunque no quepa caminando.
func _shutter_dash(index: int) -> void:
	var body := _shutter_bodies[index]
	var can := player.is_dashing() and shutter_gap(index) >= DASH_GAP
	if can and not _dash_through.has(body):
		player.add_collision_exception_with(body)
		_dash_through.append(body)
	elif not can and _dash_through.has(body):
		var shutter := data.shutters[index]
		var inside := absf(player.global_position.x - (shutter.x + shutter.width * 0.5)) \
				< shutter.width * 0.5 + PlayerPrototype.SIZE.x * 0.5
		if not inside:
			player.remove_collision_exception_with(body)
			_dash_through.erase(body)
