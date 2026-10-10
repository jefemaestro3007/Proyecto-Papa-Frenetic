class_name EnemyRoster
extends RefCounted
## Qué enemigos aparece en cada zona y en qué orden se presentan: al inicio solo la papa zombi
## común y, a medida que se avanza, se suma un tipo nuevo por tramo (idea del prototipo).
## `progress` va de 0 (inicio de la zona) a 1 (salida). Todo es determinista con el rng dado.

## Azotea (abierta): común → voladora → tiradora → embestidora.
const AZOTEA: Array[StringName] = [&"normal", &"flyer", &"thrower", &"charger"]
## Oficinas (cerrada): común → tanque → embestidora → tiradora.
const OFICINAS: Array[StringName] = [&"normal", &"tank", &"charger", &"thrower"]
## Antes de este avance solo hay papas comunes; después, cada tipo nuevo ocupa un tramo igual.
const FIRST_NEW_TYPE_AT := 0.2
## Probabilidad de que un enemigo sea el tipo recién presentado en su tramo.
const NEWEST_WEIGHT := 0.5


## Tipos disponibles a un avance dado (siempre al menos la papa común).
static func unlocked(order: Array[StringName], progress: float) -> Array[StringName]:
	var count := 1
	if order.size() > 1 and progress >= FIRST_NEW_TYPE_AT:
		var step := (1.0 - FIRST_NEW_TYPE_AT) / (order.size() - 1)
		count = mini(order.size(), 2 + floori((progress - FIRST_NEW_TYPE_AT) / step))
	return order.slice(0, count)


## Elige un tipo: la mitad de las veces el recién presentado (para que se note), si no cualquiera.
static func pick(order: Array[StringName], progress: float, rng: RandomNumberGenerator) -> StringName:
	var types := unlocked(order, progress)
	if types.size() > 1 and rng.randf() < NEWEST_WEIGHT:
		return types[-1]
	return types[rng.randi_range(0, types.size() - 1)]


## Crea un enemigo del tipo pedido con los valores de la pestaña Combate.
static func make(type: StringName, params: CombatParams, rng: RandomNumberGenerator) -> Enemy:
	var enemy: Enemy
	match type:
		&"tank":
			enemy = TankEnemy.new()
			enemy.move_speed = params.tank_speed
			enemy.max_health = params.tank_health
		&"flyer":
			var flyer := FlyingEnemy.new()
			flyer.fly_speed = params.flyer_speed
			enemy = flyer
		&"charger":
			var charger := ChargerEnemy.new()
			charger.charge_speed = params.charger_speed
			charger.recover_seconds = params.charger_recover
			enemy = charger
		&"thrower":
			var thrower := ThrowerEnemy.new()
			thrower.rng.seed = rng.randi()
			thrower.bars_between_volleys = params.thrower_bars_between
			thrower.pattern_weights = PackedFloat32Array([1.0, params.thrower_eighths, params.thrower_sixteenths])
			enemy = thrower
		_:
			enemy = Enemy.new()
			enemy.move_speed = params.potato_speed
			enemy.max_health = params.potato_health
	enemy.same_level_tolerance = maxf(params.same_level_tolerance, enemy.body_radius * 1.5)
	return enemy
