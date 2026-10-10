extends Node
## Papas vestidas de Bienestar U en una partida real (Azotea sin enemigos al azar): cada vestuario
## usa el sprite de su tipo y suma su habilidad. Cliente: deja compras que resbalan. Promotora:
## muestras en llamas (arde unos beats y deja fuego). Reponedor: lanza el carrito y carga después.
## Globos: se arman cerca y explotan con área. Guardia: empuja hacia otra papa o, solo, pega más.
## Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_enemies.tscn

const SCENE := "res://src/world/levels/azotea/azotea.tscn"
const DRESSED := {
	&"normal": ["ShopperEnemy", &"cliente"], &"tank": ["GuardEnemy", &"guardia"],
	&"flyer": ["BalloonEnemy", &"globos"], &"charger": ["StockerEnemy", &"reponedor"],
	&"thrower": ["PromoterEnemy", &"promotora"],
}

var _failures := 0
var _level: ZoneLevel
var _combat: CombatController
var _heat: HeatMeter
var _player: PlayerPrototype


func _ready() -> void:
	Settings.use_defaults()
	Conductor.params.metronome_enabled = false
	_test_roster()
	await _start()
	await _test_shopper()
	await _test_promoter()
	await _test_stocker()
	await _test_balloon()
	await _test_guard()
	print("test_bienestar_enemies: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_roster() -> void:
	var params := CombatParams.new()
	var rng := RandomNumberGenerator.new()
	for type: StringName in DRESSED:
		var enemy := EnemyRoster.make(type, params, rng, true)
		var script: Script = enemy.get_script()
		_check(script.get_global_name() == DRESSED[type][0], "make(%s, vestida) = %s" % [type, DRESSED[type][0]])
		_check(enemy.enemy_type == type, "%s conserva el sprite de %s" % [DRESSED[type][0], type])
		_check(enemy.costume == DRESSED[type][1], "%s viste %s" % [DRESSED[type][0], DRESSED[type][1]])
		enemy.free()
	var plain := EnemyRoster.make(&"normal", params, rng)
	_check(plain.costume == &"" and not plain is ShopperEnemy, "sin vestir por defecto")
	plain.free()
	var guard := EnemyRoster.make(&"tank", params, rng, true)
	_check(guard.move_speed == params.guard_speed and guard.move_speed > params.tank_speed * 2.0, "el guardia corre")
	_check(guard.max_health == params.tank_health, "el guardia conserva la vida del tanque")
	guard.free()


func _start() -> void:
	var combat := CombatParams.new()
	combat.enemy_density = 0.0
	combat.passive_heating = 0.0
	combat.game_over_enabled = false
	combat.bienestar_enemies = true
	_level = load(SCENE).instantiate()
	_level.combat = combat
	_level.params.seed = 5
	_level.params.roof_count = 4
	_level.set("_hide_menu", true)
	add_child(_level)
	await _frames(2)
	_combat = _level.get("_combat")
	_heat = _level.get("_heat")
	_player = _level.get("_player")
	await _wait_on_floor()
	_check(_combat.enemies.is_empty(), "sin papas al azar")


func _test_shopper() -> void:
	var shopper := _place(&"normal", _player.position + Vector2(300.0, 0.0))
	shopper.receive_hit(1.0, true)
	_check(not shopper.active, "el cliente muere de un golpe")
	_check(_combat.hazards().count(FloorHazards.Kind.SPILL) == 1, "deja sus compras en el piso")
	# Las compras debajo del jugador: resbala (arranca y frena despacio).
	_combat.hazards().add_spill(_player.global_position, 8)
	await _frames(2)
	_check(is_equal_approx(_player.traction, _level.combat.spill_traction), "sobre las compras hay poca tracción")
	_player.velocity.x = _player.params.max_speed
	await _frames(8)
	_check(_player.velocity.x > _player.params.max_speed * 0.6, "resbala: casi no frena (%.0f)" % _player.velocity.x)
	_combat.hazards().clear()
	await _frames(2)
	_check(is_equal_approx(_player.traction, 1.0), "fuera de las compras, tracción normal")
	_player.velocity = Vector2.ZERO


func _test_promoter() -> void:
	var combat := _level.combat
	await _wait_on_floor()
	_player.reset_state()
	var before := _heat.heat
	_combat.call(&"_spawn_projectile", _player.global_position + Vector2(0.0, -40.0), Vector2.ZERO, true)
	await _frames(3)
	_check(_combat.is_burning(), "la muestra en llamas lo hace arder")
	_check(_heat.heat - before >= combat.projectile_heat - 0.01, "el impacto suma calor")
	var after_hit := _heat.heat
	await _beats(combat.burn_beats + 1.5)
	_check(not _combat.is_burning(), "deja de arder después de %d beats" % combat.burn_beats)
	_check(absf(_heat.heat - after_hit - combat.burn_beats * combat.burn_heat) < 0.01,
			"arde %d beats: +%.1f (%.1f)" % [combat.burn_beats, combat.burn_beats * combat.burn_heat, _heat.heat - after_hit])
	# Una muestra que cae al piso deja fuego; pisarlo enciende al jugador.
	var floor_point := _player.global_position + Vector2(400.0, 0.0)
	_combat.call(&"_spawn_projectile", floor_point + Vector2(0.0, -120.0), Vector2(0.0, 300.0), true)
	await _frames(40)
	_check(_combat.hazards().count(FloorHazards.Kind.FIRE) == 1, "la muestra que cae deja fuego")
	_player.reset_state()
	_player.position.x = floor_point.x
	await _frames(3)
	_check(_combat.is_burning(), "pisar el fuego hace arder")
	_combat.clear()
	await _beats(1.0)


func _test_stocker() -> void:
	await _wait_on_floor()
	_player.reset_state()
	var stocker := _place(&"charger", _player.position + Vector2(500.0, 0.0)) as StockerEnemy
	_check(stocker.has_cart, "el reponedor empieza con carrito")
	var cart: ShoppingCart = null
	for _i in 90:
		await _frames(1)
		cart = _find_cart()
		if cart != null:
			break
	_check(cart != null and not stocker.has_cart, "lanza el carrito tras el aviso")
	_check(stocker.state == ChargerEnemy.State.WINDUP, "todavía no carga cuando lanza el carrito")
	if cart != null:
		_check(cart.direction < 0.0, "el carrito va hacia el jugador")
	var before := _heat.heat
	var charged := false
	for _i in 90:
		await _frames(1)
		charged = charged or stocker.state == ChargerEnemy.State.CHARGE
	_check(charged, "se lanza detrás del carrito")
	_check(_heat.heat > before, "el carrito o la carga alcanzan al jugador")
	stocker.defeat()
	_combat.clear()
	await _frames(30)


func _test_balloon() -> void:
	await _wait_on_floor()
	_player.reset_state()
	var combat := _level.combat
	var bystander := _place(&"normal", _player.position + Vector2(-120.0, 0.0))
	bystander.set_physics_process(false)
	var balloon := _place(&"flyer", _player.position + Vector2(60.0, -80.0)) as BalloonEnemy
	await _frames(3)
	_check(balloon.is_armed() or not balloon.active, "cerca del jugador se arma")
	var before := _heat.heat
	_player.reset_state()
	var exploded := false
	for _i in 120:
		await _frames(1)
		_player.reset_state()
		if not balloon.active:
			exploded = true
			break
	_check(exploded, "explota en el beat")
	_check(not bystander.active, "la explosión alcanza a otras papas")
	_check(absf(_heat.heat - before - combat.contact_heat * combat.balloon_blast_scale) < 0.01,
			"la explosión suma %.1f de calor (%.1f)" % [combat.contact_heat * combat.balloon_blast_scale, _heat.heat - before])
	_combat.clear()
	await _frames(30)


func _test_guard() -> void:
	await _wait_on_floor()
	_player.reset_state()
	var combat := _level.combat
	var guard := _place(&"tank", _player.position + Vector2(-60.0, 0.0)) as GuardEnemy
	var other := _place(&"normal", _player.position + Vector2(400.0, 0.0))
	other.set_physics_process(false)
	guard.set_physics_process(false)
	var before := _heat.heat
	_combat.call(&"_on_contact", guard)
	_check(_player.velocity.x > combat.guard_push * 0.9, "lo empuja hacia la otra papa (%.0f)" % _player.velocity.x)
	_check(absf(_heat.heat - before - combat.contact_heat) < 0.01, "con compañía pega lo normal")
	_check(guard.is_resting(), "descansa tras alcanzarlo")
	other.defeat()
	await _frames(2)
	guard.set("_rest_left", 0.0)
	_player.reset_state()
	before = _heat.heat
	_combat.call(&"_on_contact", guard)
	_check(absf(_heat.heat - before - combat.contact_heat * combat.guard_alone_scale) < 0.01,
			"solo pega ×%.1f (%.1f)" % [combat.guard_alone_scale, _heat.heat - before])
	guard.defeat()


func _place(type: StringName, feet: Vector2) -> Enemy:
	var enemy := EnemyRoster.make(type, _level.combat, RandomNumberGenerator.new(), true)
	_level.spawn_enemy(enemy, feet, feet.x - 600.0, feet.x + 600.0)
	return enemy


func _find_cart() -> ShoppingCart:
	for child in _combat.world.get_children():
		if child is ShoppingCart:
			return child
	return null


func _wait_on_floor() -> void:
	for _i in 120:
		if _player.is_on_floor():
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
