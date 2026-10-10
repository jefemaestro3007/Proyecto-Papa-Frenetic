extends Node
## Efectos de sonido: grupos cargados, WAV recortados y qué evento de la partida pide cada sonido.
## Corre como escena (necesita el autoload Conductor). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/sfx.tscn

const SCENE := "res://src/world/levels/azotea/azotea.tscn"
const GROUPS := {&"hurt": 2, &"hit": 2, &"stomp": 2, &"miss": 1}
const MISS := ConductorClock.Judgment.MISS
const PERFECT := ConductorClock.Judgment.PERFECT

var _failures := 0


func _ready() -> void:
	Conductor.params.metronome_enabled = false
	var level: ZoneLevel = load(SCENE).instantiate()
	level.set("_hide_menu", true)
	add_child(level)
	await _frames(2)
	var sfx: SfxPlayer = level.get("_sfx")
	var tracker: RhythmTracker = level.get("_tracker")
	var combat: CombatController = level.get("_combat")
	var player: PlayerPrototype = level.get("_player")

	for group: StringName in GROUPS:
		var effects: Array = sfx.groups.get(group, [])
		_check(effects.size() == GROUPS[group], "%s tiene %d variantes: %d" % [group, GROUPS[group], effects.size()])
		for effect: SoundEffect in effects:
			# Los WAV duran 3,4 s con silencio; recortados quedan en menos de 1 s.
			_check(effect.stream.get_length() < 1.0, "%s recortado: %.2f s" % [effect.stream.resource_path, effect.stream.get_length()])

	_expect(sfx, [&"hit"], func() -> void:
		var enemy := _place(level, player.position + Vector2(40.0, 0.0))
		combat.stomp(PERFECT)
		_check(not enemy.active, "el stomp derrota a la papa"))
	_expect(sfx, [&"stomp"], func() -> void: level.call("_on_slam"), true)
	_expect(sfx, [&"hurt"], func() -> void:
		combat.player_hurt.emit(_place(level, player.position + Vector2(600.0, 0.0))))
	_expect(sfx, [&"hurt"], func() -> void: combat.projectile_hit.emit(player.position))
	_expect(sfx, [&"miss"], func() -> void: tracker.register_judgment(&"attack", MISS))
	_expect(sfx, [&"miss"], func() -> void: tracker.register_move_judgment(&"jump", MISS))
	_expect(sfx, [], func() -> void: tracker.register_move_judgment(&"land", MISS, false))
	_expect(sfx, [], func() -> void: tracker.register_move_judgment(&"jump", PERFECT))

	level.queue_free()
	await _frames(2)
	print("test_sfx: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## Corre `action` y comprueba qué grupos pidió. Con `contains`, basta con que estén (el stomp
## puede además pedir golpe o fallo según el beat en que cae).
func _expect(sfx: SfxPlayer, groups: Array, action: Callable, contains := false) -> void:
	var before := sfx.history.size()
	action.call()
	var played := sfx.history.slice(before)
	var ok := played == groups
	if contains:
		ok = groups.all(func(g: StringName) -> bool: return g in played)
	_check(ok, "se esperaba %s y sonó %s" % [groups, played])


func _place(level: ZoneLevel, feet: Vector2) -> Enemy:
	var enemy := EnemyRoster.make(&"normal", level.combat, RandomNumberGenerator.new())
	level.spawn_enemy(enemy, feet, feet.x - 300.0, feet.x + 300.0)
	return enemy


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)
