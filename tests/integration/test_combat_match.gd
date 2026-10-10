extends Node
## Partida real en la Azotea: reparto de enemigos por tramo, calor pasivo, stomp con rebote, dash,
## papa frita, hitstop sin desplazar los beats, game over al explotar, reintento con la misma seed
## y victoria al llegar a la salida. Corre como escena (necesita el autoload Conductor). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/combat_match.tscn

const SCENE := "res://src/world/levels/azotea/azotea.tscn"
const CLASSES := {
	&"normal": "Enemy", &"tank": "TankEnemy", &"flyer": "FlyingEnemy",
	&"charger": "ChargerEnemy", &"thrower": "ThrowerEnemy",
}

var _failures := 0
var _level: ZoneLevel


func _ready() -> void:
	Conductor.params.metronome_enabled = false
	_test_roster()
	await _test_match()
	print("test_combat_match: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_roster() -> void:
	for order: Array[StringName] in [EnemyRoster.AZOTEA, EnemyRoster.OFICINAS]:
		_check(EnemyRoster.unlocked(order, 0.0) == [&"normal"], "al inicio solo comunes")
		_check(EnemyRoster.unlocked(order, 0.19) == [&"normal"], "antes del primer tramo solo comunes")
		_check(EnemyRoster.unlocked(order, 1.0) == order, "al final todos los tipos")
		var previous := 0
		for i in 101:
			var count := EnemyRoster.unlocked(order, i / 100.0).size()
			_check(count >= previous and count - previous <= 1, "se suma de a un tipo (%d → %d)" % [previous, count])
			previous = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in 200:
		_check(EnemyRoster.pick(EnemyRoster.OFICINAS, 0.1, rng) == &"normal", "pick respeta lo desbloqueado")
	var params := CombatParams.new()
	params.tank_health = 4
	for type: StringName in CLASSES:
		var enemy := EnemyRoster.make(type, params, rng)
		var script: Script = enemy.get_script()
		_check(script.get_global_name() == CLASSES[type] and enemy.enemy_type == type, "make(%s)" % type)
		if type == &"tank":
			_check(enemy.max_health == 4, "vida del tanque desde params")
		enemy.free()


func _test_match() -> void:
	var combat := CombatParams.new()
	combat.enemy_density = 0.8
	combat.fuse_seconds = 1.0
	_level = load(SCENE).instantiate()
	_level.combat = combat
	_level.params.seed = 11
	_level.params.roof_count = 12
	_level.set("_hide_menu", true)
	add_child(_level)
	await _frames(2)
	var data: AzoteaMapData = _level.get("_data")
	var combat_node: CombatController = _level.get("_combat")
	var heat: HeatMeter = _level.get("_heat")
	var player: PlayerPrototype = _level.get("_player")

	# Reparto: tramo inicial solo comunes; aparecen tipos nuevos más adelante.
	var types := {}
	for enemy in combat_node.enemies:
		var roof := _roof_index(data, enemy.global_position.x)
		_check(roof >= 1, "la primera azotea es zona segura")
		if roof >= 1 and float(roof) / (data.roofs.size() - 1) < EnemyRoster.FIRST_NEW_TYPE_AT:
			_check(enemy.enemy_type == &"normal", "solo comunes al inicio (azotea %d: %s)" % [roof, enemy.enemy_type])
		types[enemy.enemy_type] = true
	_check(types.size() >= 3, "hay variedad de enemigos: %s" % [types.keys()])

	# Calor pasivo.
	await _frames(60)
	_check(heat.heat > 0.5 and heat.heat < 2.0, "calor pasivo ~1/s: %f" % heat.heat)

	# Stomp a tiempo sobre una papa común: la derrota. Sobre un tanque: rebota.
	var normal := _place(&"normal", player.position + Vector2(40.0, 0.0))
	combat_node.stomp(ConductorClock.Judgment.PERFECT)
	_check(not normal.active, "stomp a tiempo derrota a la común")
	await _frames(30)
	var tank := _place(&"tank", player.position + Vector2(40.0, 0.0))
	player.velocity = Vector2.ZERO
	combat_node.stomp(ConductorClock.Judgment.PERFECT)
	_check(tank.active and tank.health == tank.max_health - 1, "el tanque aguanta el stomp")
	_check(player.velocity.y < 0.0, "el jugador rebota sobre el tanque")
	tank.defeat()
	await _frames(40)
	_check(is_equal_approx(Engine.time_scale, 1.0) and Conductor.hitstop_scale == 1.0, "el hitstop termina")

	# Hitstop: congela la acción pero el beat sigue al ritmo de siempre (con --fixed-fps cada
	# frame dura 1/60 s de música aunque la acción vaya al 5 %).
	var feel: GameFeel = _level.get("_feel")
	feel.hitstop(10.0)
	var start := Conductor.beat_position()
	for _i in 30:
		await get_tree().process_frame
	_check(Engine.time_scale < 0.1, "el hitstop congela la acción")
	var expected := 30.0 / 60.0 / Conductor.beat_length()
	_check(absf(Conductor.beat_position() - start - expected) < 0.1,
			"el hitstop no desplaza los beats (%.2f vs %.2f)" % [Conductor.beat_position() - start, expected])
	feel.reset()
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and Conductor.hitstop_scale == 1.0, "el hitstop se restaura")

	# Dash a tiempo contra una papa común: la atraviesa y la derrota.
	await _wait_on_floor(player)
	player.facing = 1.0
	var target := _place(&"normal", player.position + Vector2(160.0, 0.0))
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	_check(player.is_dashing(), "Shift inicia el dash en el suelo")
	combat_node.set("_dash_judgment", ConductorClock.Judgment.PERFECT)
	await _frames(20)
	_check(not target.active, "el dash a tiempo derrota a la papa")
	_check(player.dash_cooldown_left() > 0.0, "el dash queda en espera")

	# Papa frita: suma calor.
	await _frames(30)
	var before := heat.heat
	combat_node.call("_spawn_projectile", player.position + Vector2(0.0, -200.0), Vector2(0.0, 300.0))
	await _frames(30)
	_check(heat.heat >= before + combat.projectile_heat - 0.1, "la papa frita suma calor (%f → %f)" % [before, heat.heat])

	# Sobrecalentamiento → mecha (1 s) → explota → game over.
	heat.change(100.0)
	_check(heat.overheated, "a 100 se enciende la mecha")
	await _frames(80)
	_check(_level.get("_match") == ZoneLevel.Match.GAME_OVER, "la papa explota: game over")
	_check(not player.visible, "el jugador desaparece en la explosión")

	# Reintento con la misma seed.
	var seed: int = _level.params.seed
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	_level._unhandled_input(enter)
	await _frames(2)
	_check(_level.is_playing() and heat.heat < 1.0 and _level.params.seed == seed, "Enter reintenta la misma seed")

	# Victoria al llegar al final de la última azotea.
	var last := data.roofs[-1]
	player.position = Vector2(last.end.x - 100.0, last.position.y - 4.0)
	await _frames(20)
	_check(_level.get("_match") == ZoneLevel.Match.VICTORY, "llegar a la salida gana")
	_level.queue_free()
	await _frames(2)


func _place(type: StringName, feet: Vector2) -> Enemy:
	var rng := RandomNumberGenerator.new()
	var enemy := EnemyRoster.make(type, _level.combat, rng)
	_level.spawn_enemy(enemy, feet, feet.x - 300.0, feet.x + 300.0)
	return enemy


func _roof_index(data: AzoteaMapData, x: float) -> int:
	for i in data.roofs.size():
		if x >= data.roofs[i].position.x and x <= data.roofs[i].end.x:
			return i
	return -1


func _wait_on_floor(player: PlayerPrototype) -> void:
	for _i in 120:
		if player.is_on_floor():
			return
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)
