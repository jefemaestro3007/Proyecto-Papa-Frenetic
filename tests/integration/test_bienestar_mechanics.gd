extends Node
## Mecánicas de Bienestar U en tiendas reales (sin papas al azar ni calor pasivo): racks que se
## derrumban por beats debajo o por stomp, freezers que enfrían con tope y frenan, piso mojado,
## cintas de caja que llevan en el beat, carritos (montarse, más velocidad, atropellar), escaleras
## mecánicas a favor y a contramano, cortinas que bajan por beats y se pasan en dash, y freidoras.
## Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_mechanics.tscn

const SCENE := "res://src/world/levels/bienestar/supermercado.tscn"

var _failures := 0
var _level: Node
var _data: BienestarMapData
var _world: BienestarWorld
var _player: PlayerPrototype
var _heat: HeatMeter
var _params: BienestarParams
var _combat_params: CombatParams


func _ready() -> void:
	Settings.use_defaults()
	Conductor.params.metronome_enabled = false
	await _load(BienestarParams.Mode.SUPERMARKET, 3)
	await _test_rack()
	await _test_rack_stomp()
	await _test_freezer()
	await _test_wet_and_belt()
	await _test_cart()
	await _load(BienestarParams.Mode.MALL, 4)
	await _test_escalator()
	await _test_shutter()
	await _test_fryer()
	print("test_bienestar_mechanics: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _load(mode: int, seed: int) -> void:
	if _level != null:
		_level.queue_free()
		await _frames(2)
	var params := BienestarParams.new()
	params.mode = mode
	params.seed = seed
	params.rack_chance = 1.0
	params.shutter_chance = 1.0
	var combat := CombatParams.new()
	combat.enemy_density = 0.0
	combat.passive_heating = 0.0
	combat.game_over_enabled = false
	_params = params
	_combat_params = combat
	_level = load(SCENE).instantiate()
	_level.params = params
	_level.combat = combat
	_level.set("_hide_menu", true)
	add_child(_level)
	await _frames(3)
	_data = _level.data()
	_world = _level.world()
	_player = _level.player()
	_heat = _level.get("_heat")


## Pone al jugador de pie en `feet` y espera a que toque el piso.
func _place(feet: Vector2) -> void:
	_player.reset_state()
	_player.position = feet + Vector2(0.0, -4.0)
	_player.velocity = Vector2.ZERO
	for _i in 30:
		await get_tree().physics_frame
		if _player.is_on_floor():
			return


func _test_rack() -> void:
	_check(not _data.racks.is_empty(), "el supermercado tiene racks")
	if _data.racks.is_empty():
		return
	var rack := _data.racks[0]
	var index := 0
	await _place(Vector2(rack.rect.get_center().x, _data.surface_y(rack.floor)))
	var limit := _params.rack_collapse_beats
	await _beats(limit - 1.5)
	_check(not _world.rack_down[index] and _world.rack_stress[index] >= limit - 2,
			"debajo del rack suma un beat de carga por beat (%d)" % _world.rack_stress[index])
	var before := _heat.heat
	await _beats(2.0)
	_check(_world.rack_down[index], "se derrumba a los %d beats" % limit)
	_check(_heat.heat > before, "el derrumbe le pega a quien está debajo")
	_check(_player.global_position.y <= _data.surface_y(rack.floor) - BienestarWorld.DEBRIS_HEIGHT + 4.0,
			"queda encima de los escombros (no atrapado)")


func _test_rack_stomp() -> void:
	if _data.racks.size() < 2:
		return
	var index := 1
	var rack := _data.racks[index]
	# Una papa común debajo y el jugador cae en stomp sobre la viga.
	var enemy := EnemyRoster.make(&"normal", _combat_params, RandomNumberGenerator.new(), true)
	_level.spawn_enemy(enemy, Vector2(rack.rect.get_center().x + 40.0, _data.surface_y(rack.floor)),
			rack.rect.position.x, rack.rect.end.x)
	enemy.set_physics_process(false)
	_player.reset_state()
	_player.position = Vector2(rack.rect.get_center().x, rack.rect.position.y - 300.0)
	await get_tree().physics_frame
	Input.action_press("move_down")
	await _frames(2)
	Input.action_release("move_down")
	for _i in 60:
		await get_tree().physics_frame
		if _world.rack_down[index]:
			break
	_check(_world.rack_down[index], "un stomp sobre la viga tira el rack en el acto")
	_check(not enemy.active, "el rack cae sobre la papa de abajo")


func _test_freezer() -> void:
	_check(not _data.freezers.is_empty(), "hay congelados")
	if _data.freezers.is_empty():
		return
	var freezer := _data.freezers[0]
	await _place(Vector2(freezer.rect.get_center().x, freezer.rect.end.y))
	_heat.change(50.0 - _heat.heat)
	# Espera a que abra y mide el frío de un beat abierto.
	for _i in 240:
		if _world.freezer_open(0):
			break
		await get_tree().physics_frame
	var before := _heat.heat
	await _frames(20)
	_check(_heat.heat < before - 0.5, "enfrente de un freezer abierto se enfría (%.2f → %.2f)" % [before, _heat.heat])
	_check(_world.is_frosted() and is_equal_approx(_player.speed_scale, _params.freezer_slow),
			"la escarcha frena al jugador")
	# El tope: aunque se quede, ese freezer no enfría más de `freezer_cap`.
	_world.freezer_left[0] = 0.0
	before = _heat.heat
	await _frames(30)
	_check(_heat.heat >= before - 0.01, "un freezer vacío ya no enfría")
	await _place(Vector2(freezer.rect.position.x - 400.0, freezer.rect.end.y))
	await _frames(2)
	_check(is_equal_approx(_player.speed_scale, 1.0), "lejos del freezer, velocidad normal")


func _test_wet_and_belt() -> void:
	_check(not _data.wet.is_empty(), "hay piso mojado")
	if not _data.wet.is_empty():
		var wet := _data.wet[0]
		await _place(Vector2(wet.get_center().x, wet.end.y - 6.0))
		await _frames(2)
		_check(is_equal_approx(_player.traction, _params.wet_traction), "el piso mojado resbala")
	_check(not _data.belts.is_empty(), "hay cajas con cinta")
	if _data.belts.is_empty():
		return
	var belt := _data.belts[0]
	await _place(Vector2(belt.rect.position.x + 40.0, belt.rect.position.y))
	var start := _player.global_position.x
	await _beats(2.0)
	var moved := _player.global_position.x - start
	_check(moved > _params.belt_step * 1.5, "la cinta lleva al jugador en cada beat (%.0f px en 2 beats)" % moved)


func _test_cart() -> void:
	_check(not _data.carts.is_empty(), "hay carritos")
	if _data.carts.is_empty():
		return
	var cart: Vector2 = _world.parked[0]
	await _place(cart)
	Input.action_press("move_up")
	await _frames(2)
	Input.action_release("move_up")
	_check(_world.riding, "W junto a un carrito se monta")
	_check(is_equal_approx(_player.speed_scale, _params.cart_speed_scale), "en carrito va más rápido")
	Input.action_press("move_right")
	await _frames(70)
	_check(_player.velocity.x > _player.params.max_speed * 1.1, "toma velocidad (%.0f)" % _player.velocity.x)
	# Atropella: una papa adelante pierde una vida sin dañar al jugador.
	var enemy := EnemyRoster.make(&"normal", _combat_params, RandomNumberGenerator.new(), true)
	_level.spawn_enemy(enemy, _player.global_position + Vector2(120.0, 0.0), _player.global_position.x,
			_player.global_position.x + 600.0)
	enemy.set_physics_process(false)
	var before := _heat.heat
	_level.get("_combat").call(&"_on_contact", enemy)
	_check(not enemy.active, "el carrito atropella a la papa")
	_check(_heat.heat <= before, "atropellar no calienta")
	Input.action_release("move_right")
	Input.action_press("move_down")
	await _frames(2)
	Input.action_release("move_down")
	_check(not _world.riding and _world.parked.size() >= 1, "S se baja y el carrito queda estacionado")


func _test_escalator() -> void:
	_check(not _data.escalators.is_empty(), "el centro comercial tiene escaleras mecánicas")
	if _data.escalators.is_empty():
		return
	var escalator := _data.escalators[0]
	# Espera a que suba y la toma a favor: llega rápido.
	await _until(func() -> bool: return escalator.going_up(_bar(), _params.escalator_bars), 30.0)
	await _place(escalator.foot)
	Input.action_press("move_up")
	await _frames(2)
	Input.action_release("move_up")
	_check(_level.is_riding_escalator(), "W al pie sube a la escalera")
	var with_seconds := await _ride_seconds()
	_check(absf(_player.global_position.y - escalator.top.y) < 6.0, "a favor llega arriba")
	_check(with_seconds < _params.escalator_seconds + 0.4, "a favor tarda ~%.1f s (%.2f)" % [
			_params.escalator_seconds, with_seconds])
	# A contramano (bajando cuando sube): lento.
	await _until(func() -> bool: return escalator.going_up(_bar(), _params.escalator_bars), 30.0)
	await _place(escalator.top)
	Input.action_press("move_down")
	await _frames(2)
	Input.action_release("move_down")
	var against := await _ride_seconds()
	_check(absf(_player.global_position.y - escalator.foot.y) < 6.0, "a contramano también se llega")
	_check(against > with_seconds * 1.5, "a contramano tarda más (%.2f s vs %.2f s)" % [against, with_seconds])


func _ride_seconds() -> float:
	var frames := 0
	while _level.is_riding_escalator() and frames < 60 * 30:
		await get_tree().physics_frame
		frames += 1
	return frames / 60.0


func _test_shutter() -> void:
	_check(not _data.shutters.is_empty(), "hay cortinas metálicas")
	if _data.shutters.is_empty():
		return
	var index := 0
	var shutter := _data.shutters[index]
	var floor_y := _data.surface_y(shutter.floor)
	var height := floor_y - _data.floors[shutter.floor].ceiling
	await _until(func() -> bool: return _world.shutter_gap(index) <= 0.0, 30.0)
	_check(_world.shutter_gap(index) <= 0.0, "la cortina llega a cerrarse")
	# Cerrada: no se pasa caminando.
	await _place(Vector2(shutter.x - 120.0, floor_y))
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(_player.global_position.x < shutter.x, "cerrada no deja pasar")
	await _until(func() -> bool: return _world.shutter_gap(index) >= height - 1.0, 30.0)
	_check(_world.shutter_gap(index) >= height - 1.0, "vuelve a abrirse (nunca atasca)")
	# Bajando con poco espacio: en dash se pasa por debajo.
	await _until(func() -> bool:
		var gap := _world.shutter_gap(index)
		return gap >= BienestarWorld.DASH_GAP + 10.0 and gap < BienestarWorld.WALK_GAP - 10.0, 40.0)
	await _place(Vector2(shutter.x - 120.0, floor_y))
	_player.facing = 1.0
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	await _frames(20)
	Input.action_release("move_right")
	_check(_player.global_position.x > shutter.x + shutter.width, "en dash se pasa por debajo (x %.0f)" % _player.global_position.x)


func _test_fryer() -> void:
	_check(not _data.fryers.is_empty(), "el patio de comidas tiene freidoras")
	if _data.fryers.is_empty():
		return
	var fryer := _data.fryers[0]
	await _place(Vector2(fryer.rect.position.x - 40.0, fryer.rect.end.y))
	var before := _heat.heat
	await _beats(_params.fryer_every + 1.0)
	_check(_heat.heat >= before + _params.fryer_heat - 0.01, "la salpicadura de aceite calienta (+%.1f)" % (_heat.heat - before))


func _bar() -> int:
	return floori(Conductor.beat_position() / ConductorClock.BEATS_PER_BAR)


func _until(condition: Callable, seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for _i in frames:
		if condition.call():
			return
		await get_tree().physics_frame


func _beats(count: float) -> void:
	await _frames(ceili(count * Conductor.beat_length() * 60.0))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)
