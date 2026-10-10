class_name OficinasLayout
extends RefCounted
## Topología del edificio de oficinas: grilla pisos × módulos con lo que hay en cada celda y
## entre celdas, y el grafo de movimiento que se deriva de ella. Es puro: sin nodos ni geometría.
## Los nodos son Vector2i(piso, módulo).
##
## Elementos:
## - Escaleras de fondo (W al pie sube, S arriba baja); se apilan como núcleos reales.
## - Ascensores de fondo, cerrados: W frente a la puerta los llama (llegan en ≤ 2 s), adentro
##   W/S eligen el piso y el viaje es rápido. El módulo se sigue caminando normal.
## - Huecos pequeños (saltables, sirven para bajar) y derrumbes (se cae, uno o más pisos).
## - Muros entre módulos: abiertos, con puerta, con puerta con llave o bloqueados.
## - Puertas al fondo: habitaciones (sin salida, pueden guardar llaves) o pasillos-atajo
##   enlazados con otra puerta al fondo, en el mismo u otro piso.
##
## Generación: núcleos de escaleras/ascensores, ruta principal aleatoria con desvíos, rutas
## alternativas, extras, muros, reparación (desde CUALQUIER lugar se llega a la salida y, si se
## pide, todo es alcanzable; lo que no tiene arreglo se sella) y por último cerraduras con llaves,
## validadas sobre el espacio de estados (lugar × llaves que se tienen): nunca hay atasco.

enum Cell { NORMAL, SHAFT, GAP, COLLAPSE, SEALED }
enum Wall { UNSET = -1, OPEN, DOOR, LOCKED, BLOCKED }
enum Lift { LOCAL, EXPRESS, CALL, FAULTY }
enum Link { WALK, STAIRS, LIFT, FALL, DEPTH }
enum Depth { NONE, ROOM, CORRIDOR }

const MAX_ROUTE_STEPS := 64
const MAX_REPAIRS := 600
const BUILD_ATTEMPTS := 12
const MAX_KEYS := 3
const ALL_KEYS := (1 << MAX_KEYS) - 1


class Shaft:
	extends RefCounted
	var column: int
	var low: int
	var high: int
	var kind: Lift

	func _init(p_column: int, p_low: int, p_high: int, p_kind: Lift) -> void:
		column = p_column
		low = p_low
		high = p_high
		kind = p_kind

	## Pisos con puerta (en los demás solo pasa el hueco por el fondo).
	func stops() -> PackedInt32Array:
		if kind == Lift.EXPRESS:
			return PackedInt32Array([low, high])
		var all := PackedInt32Array()
		for f in range(low, high + 1):
			all.append(f)
		return all


class DepthDoor:
	extends RefCounted
	var floor: int
	var module: int
	var kind: Depth
	## Puerta enlazada (pasillos) o -1.
	var partner := -1
	## Llave guardada dentro (habitaciones) o -1.
	var key := -1

	func _init(p_floor: int, p_module: int, p_kind: Depth) -> void:
		floor = p_floor
		module = p_module
		kind = p_kind


class KeyItem:
	extends RefCounted
	var id: int
	var node: Vector2i
	## Puerta al fondo (habitación) que la guarda, o -1 si está tirada en el piso.
	var door := -1

	func _init(p_id: int, p_node: Vector2i, p_door: int) -> void:
		id = p_id
		node = p_node
		door = p_door


var floors: int
var modules: int
var cells := PackedInt32Array()
## Dirección (±1) de la escalera que sube desde (f, c) a (f + 1, c); 0 = no hay.
var stair_up := PackedInt32Array()
var shaft_of := PackedInt32Array()
var walls := PackedInt32Array()
## Llave que abre cada muro con cerradura (o -1).
var wall_key := PackedInt32Array()
var depth_at := PackedInt32Array()
var elevators: Array[Shaft] = []
var depth_doors: Array[DepthDoor] = []
var keys: Array[KeyItem] = []
var protected := PackedByteArray()
var start: Vector2i
var end: Vector2i
var valid := false
var main_transitions := 0
var repairs := 0
var sealed_count := 0
## Columnas preferidas para escaleras y ascensores (núcleos del edificio).
var stair_cores := PackedInt32Array()
var lift_core := -1

var _params: OficinasParams
var _rng := RandomNumberGenerator.new()
var _relax := 0
var _safe := false


static func build(params: OficinasParams) -> OficinasLayout:
	var layout: OficinasLayout
	for attempt in BUILD_ATTEMPTS:
		layout = OficinasLayout.new()
		layout._generate(params, params.seed + attempt * 7919, attempt)
		if layout.valid:
			return layout
	# Último recurso: ruta directa sin desvíos, sin daño extra, muros bloqueados ni cerraduras.
	layout = OficinasLayout.new()
	layout._safe = true
	layout._generate(params, params.seed, BUILD_ATTEMPTS)
	return layout


# --- Consultas ---------------------------------------------------------------------

func index(f: int, c: int) -> int:
	return f * modules + c


func cell(f: int, c: int) -> Cell:
	return cells[index(f, c)] as Cell


func in_range(f: int, c: int) -> bool:
	return f >= 0 and f < floors and c >= 0 and c < modules


## Muro entre el módulo `c` y `c + 1` del piso `f`.
func wall(f: int, c: int) -> Wall:
	return walls[f * (modules - 1) + c] as Wall


func set_wall(f: int, c: int, value: Wall, key_id: int = -1) -> void:
	walls[f * (modules - 1) + c] = value
	wall_key[f * (modules - 1) + c] = key_id


func lock_key(f: int, c: int) -> int:
	return wall_key[f * (modules - 1) + c]


func elevator_at(f: int, c: int) -> Shaft:
	var id := shaft_of[index(f, c)]
	return elevators[id] if id >= 0 else null


## Dirección de la escalera que sube desde (f, c), 0 si no hay.
func stairs_from(f: int, c: int) -> int:
	return stair_up[index(f, c)] if in_range(f, c) else 0


func has_stairs(f: int, c: int) -> bool:
	return stairs_from(f, c) != 0 or (f > 0 and stairs_from(f - 1, c) != 0)


func depth_door_at(f: int, c: int) -> DepthDoor:
	var id := depth_at[index(f, c)]
	return depth_doors[id] if id >= 0 else null


## Sin suelo: quien entra cae.
func is_void(f: int, c: int) -> bool:
	return cell(f, c) == Cell.COLLAPSE


## No se puede entrar ni cruzar (módulo sellado).
func is_barrier(f: int, c: int) -> bool:
	return cell(f, c) == Cell.SEALED


func is_sealed(f: int, c: int) -> bool:
	return cell(f, c) == Cell.SEALED


func is_node(f: int, c: int) -> bool:
	return in_range(f, c) and not is_void(f, c) and not is_barrier(f, c)


## Dónde termina quien entra en (f, c): baja mientras haya derrumbe. Piso -1 = fuera.
func landing(f: int, c: int) -> Vector2i:
	while f >= 0 and is_void(f, c):
		f -= 1
	return Vector2i(f, c)


func nodes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for f in floors:
		for c in modules:
			if is_node(f, c):
				out.append(Vector2i(f, c))
	return out


func _wall_passable(f: int, c: int, mask: int) -> bool:
	match wall(f, c):
		Wall.BLOCKED:
			return false
		Wall.LOCKED:
			return mask & (1 << lock_key(f, c)) != 0
	return true


## Movimientos posibles desde un nodo con las llaves `mask`: pares [destino, Link].
func successors(node: Vector2i, mask: int = ALL_KEYS) -> Array:
	var f := node.x
	var c := node.y
	var out := []
	for d in [-1, 1]:
		var nc: int = c + d
		if nc < 0 or nc >= modules or not _wall_passable(f, mini(c, nc), mask) or is_barrier(f, nc):
			continue
		var target := landing(f, nc)
		if target.x >= 0 and is_node(target.x, target.y):
			out.append([target, Link.WALK if target.x == f else Link.FALL])
	if stairs_from(f, c) != 0:
		out.append([Vector2i(f + 1, c), Link.STAIRS])
	if f > 0 and stairs_from(f - 1, c) != 0:
		out.append([Vector2i(f - 1, c), Link.STAIRS])
	match cell(f, c):
		Cell.GAP:
			var below := landing(f - 1, c)
			if below.x >= 0 and is_node(below.x, below.y):
				out.append([below, Link.FALL])
		Cell.SHAFT:
			var stops := elevator_at(f, c).stops()
			if stops.has(f):
				for stop in stops:
					if stop != f:
						out.append([Vector2i(stop, c), Link.LIFT])
	var door := depth_door_at(f, c)
	if door != null and door.partner >= 0:
		var other := depth_doors[door.partner]
		out.append([Vector2i(other.floor, other.module), Link.DEPTH])
	# Un destino puede haber quedado sellado (p. ej. una parada de ascensor): se descarta.
	return out.filter(func(pair: Array) -> bool: return is_node(pair[0].x, pair[0].y))


func reachable_from(origin: Vector2i, mask: int = ALL_KEYS) -> Dictionary:
	var seen := {origin: true}
	var queue: Array[Vector2i] = [origin]
	var head := 0
	while head < queue.size():
		var node: Vector2i = queue[head]
		head += 1
		for pair in successors(node, mask):
			if not seen.has(pair[0]):
				seen[pair[0]] = true
				queue.append(pair[0])
	return seen


## Nodos desde los que se puede llegar a `target` con las llaves `mask`.
func can_reach(target: Vector2i, mask: int = ALL_KEYS) -> Dictionary:
	var reverse := {}
	for node in nodes():
		for pair in successors(node, mask):
			if not reverse.has(pair[0]):
				reverse[pair[0]] = []
			reverse[pair[0]].append(node)
	var seen := {target: true}
	var queue: Array[Vector2i] = [target]
	var head := 0
	while head < queue.size():
		var node: Vector2i = queue[head]
		head += 1
		for previous in reverse.get(node, []):
			if not seen.has(previous):
				seen[previous] = true
				queue.append(previous)
	return seen


## Camino más corto (BFS) con las llaves `mask`, como lista de pares [nodo, Link].
func shortest_path(origin: Vector2i, target: Vector2i, mask: int = ALL_KEYS) -> Array:
	var came := {origin: null}
	var queue: Array[Vector2i] = [origin]
	var head := 0
	while head < queue.size():
		var node: Vector2i = queue[head]
		head += 1
		if node == target:
			break
		for pair in successors(node, mask):
			if not came.has(pair[0]):
				came[pair[0]] = [node, pair[1]]
				queue.append(pair[0])
	if not came.has(target):
		return []
	var path := []
	var node := target
	while came[node] != null:
		path.push_front([node, came[node][1]])
		node = came[node][0]
	path.push_front([origin, Link.WALK])
	return path


## Llaves que se recogen al estar en `node` (en el piso o dentro de su habitación).
func keys_at(node: Vector2i) -> int:
	var mask := 0
	for key in keys:
		if key.node == node:
			mask |= 1 << key.id
	return mask


## Plan en el espacio de estados (nodo, llaves) hasta la salida: lista de [nodo, llaves, Link];
## el primer elemento es el estado actual. Recoger una llave ocurre al estar en su nodo.
func plan(origin: Vector2i, mask: int) -> Array:
	var first := [origin, mask | keys_at(origin)]
	var came := {first: null}
	var queue := [first]
	var goal = null
	var head := 0
	while head < queue.size():
		var state: Array = queue[head]
		head += 1
		if state[0] == end:
			goal = state
			break
		for pair in successors(state[0], state[1]):
			var next := [pair[0], state[1] | keys_at(pair[0])]
			if not came.has(next):
				came[next] = [state, pair[1]]
				queue.append(next)
	if goal == null:
		return []
	var path := []
	var state = goal
	while came[state] != null:
		path.push_front([state[0], state[1], came[state][1]])
		state = came[state][0]
	path.push_front([first[0], first[1], Link.WALK])
	return path


## Lugares (cualquiera) desde los que, aun con todas las llaves, no se llega a la salida.
func traps() -> Array[Vector2i]:
	var good := can_reach(end)
	var out: Array[Vector2i] = []
	for node in nodes():
		if not good.has(node):
			out.append(node)
	return out


## Estados (lugar, llaves) alcanzables desde el inicio desde los que no se puede terminar.
func state_traps() -> Array:
	var initial := [start, keys_at(start)]
	var seen := {initial: true}
	var order := [initial]
	var reverse := {}
	var i := 0
	while i < order.size():
		var state: Array = order[i]
		i += 1
		for pair in successors(state[0], state[1]):
			var next := [pair[0], state[1] | keys_at(pair[0])]
			if not reverse.has(next):
				reverse[next] = []
			reverse[next].append(state)
			if not seen.has(next):
				seen[next] = true
				order.append(next)
	var finished := {}
	var queue := []
	for state in order:
		if state[0] == end:
			finished[state] = true
			queue.append(state)
	var head := 0
	while head < queue.size():
		var state: Array = queue[head]
		head += 1
		for previous in reverse.get(state, []):
			if not finished.has(previous):
				finished[previous] = true
				queue.append(previous)
	var out := []
	for state in order:
		if not finished.has(state):
			out.append(state)
	return out


func isolated() -> Array[Vector2i]:
	var reach := reachable_from(start)
	var out: Array[Vector2i] = []
	for node in nodes():
		if not reach.has(node):
			out.append(node)
	return out


## Conexiones no horizontales útiles; si superan a las de la ruta principal, hay alternativas.
func useful_vertical_links() -> int:
	var reach := reachable_from(start)
	var good := can_reach(end)
	var count := 0
	for node in reach:
		if not good.has(node):
			continue
		for pair in successors(node):
			if pair[1] != Link.WALK and good.has(pair[0]):
				count += 1
	return count


# --- Generación --------------------------------------------------------------------

func _generate(params: OficinasParams, seed_value: int, relax: int) -> void:
	_params = params
	_relax = relax
	_rng.seed = seed_value
	floors = maxi(params.floors, 2)
	modules = maxi(params.modules, 3)
	var size := floors * modules
	for array in [cells, stair_up, shaft_of, depth_at]:
		array.resize(size)
	cells.fill(Cell.NORMAL)
	stair_up.fill(0)
	shaft_of.fill(-1)
	depth_at.fill(-1)
	protected.resize(size)
	protected.fill(0)
	walls.resize(floors * (modules - 1))
	walls.fill(Wall.UNSET)
	wall_key.resize(walls.size())
	wall_key.fill(-1)

	var floors_pair := params.start_and_end_floor()
	start = Vector2i(floors_pair.x, 0)
	end = Vector2i(floors_pair.y, modules - 1)
	_protect(start)
	_protect(end)
	_pick_cores()

	var main_nodes: Array[Vector2i] = []
	var min_transitions := params.min_transitions if relax < 3 else maxi(0, params.min_transitions - (relax - 2))
	if not _route(start, min_transitions, main_nodes):
		return
	main_transitions = main_nodes.size() - 1
	if not _safe:
		for b in params.branches:
			var from: Vector2i = main_nodes[_rng.randi_range(0, maxi(main_nodes.size() - 2, 0))]
			_route(from, _rng.randi_range(1, 2), [])
		_add_extras()
	_assign_free_walls()
	if not _repair():
		return
	if not _safe:
		_add_locks()
	valid = true


## Núcleos: columnas donde preferentemente van escaleras y ascensores (como un edificio real).
func _pick_cores() -> void:
	stair_cores.clear()
	stair_cores.append(1 + _rng.randi_range(0, maxi(modules / 3 - 1, 0)))
	if modules >= 6:
		stair_cores.append(modules - 2 - _rng.randi_range(0, maxi(modules / 4 - 1, 0)))
	lift_core = clampi(modules / 2 + _rng.randi_range(-1, 1), 1, modules - 2)


func _core_bonus(kind: String, column: int) -> float:
	if kind == "stairs" and stair_cores.has(column):
		return 1.0 + _params.realism * 6.0
	if kind == "elevator" and column == lift_core:
		return 1.0 + _params.realism * 6.0
	return 1.0


func _protect(node: Vector2i) -> void:
	protected[index(node.x, node.y)] = 1


func _is_protected(f: int, c: int) -> bool:
	return protected[index(f, c)] == 1


func _free(f: int, c: int) -> bool:
	return in_range(f, c) and cell(f, c) == Cell.NORMAL and not _is_protected(f, c)


## Entrada y salida son siempre módulos normales sin nada encima.
func _reserved(f: int, c: int) -> bool:
	return Vector2i(f, c) == start or Vector2i(f, c) == end


## Ruta aleatoria desde `from` hasta la salida. Guarda en `visited` el nodo tras cada cambio.
func _route(from: Vector2i, min_transitions: int, visited: Array[Vector2i]) -> bool:
	var cur := from
	var transitions := 0
	visited.append(cur)
	for step in MAX_ROUTE_STEPS:
		if cur.x == end.x and transitions >= min_transitions and _walk(cur.x, cur.y, end.y):
			return true
		var dir := signi(end.x - cur.x)
		if dir == 0:
			dir = 1 if _rng.randf() < 0.5 else -1
		elif _relax < 5 and _rng.randf() < _params.detour_chance:
			dir = -dir
		if cur.x + dir < 0 or cur.x + dir >= floors:
			dir = -dir
		var next := _transition(cur, dir)
		if next.x < 0:
			next = _transition(cur, -dir)
		if next.x < 0:
			return false
		cur = next
		transitions += 1
		visited.append(cur)
	return false


func _walk(f: int, from_c: int, to_c: int) -> bool:
	if not _can_walk(f, from_c, to_c):
		return false
	var step := signi(to_c - from_c)
	var c := from_c
	_protect(Vector2i(f, c))
	while c != to_c:
		_open_wall(f, mini(c, c + step))
		c += step
		_protect(Vector2i(f, c))
	return true


func _can_walk(f: int, from_c: int, to_c: int) -> bool:
	var step := signi(to_c - from_c)
	var c := from_c
	while true:
		if not is_node(f, c):
			return false
		if c == to_c:
			return true
		var w := wall(f, mini(c, c + step))
		if w == Wall.BLOCKED or w == Wall.LOCKED:
			return false
		c += step
	return false


func _open_wall(f: int, c: int) -> void:
	if wall(f, c) == Wall.UNSET or wall(f, c) == Wall.BLOCKED:
		set_wall(f, c, Wall.OPEN if _rng.randf() < 0.4 else Wall.DOOR)


## Cambia de piso en la dirección `dir` (o pasa a otro lugar por un pasillo al fondo).
## Recorre todas las combinaciones en orden aleatorio ponderado (pesos × núcleos).
func _transition(cur: Vector2i, dir: int) -> Vector2i:
	var weights := {
		"stairs": _params.stairs_weight, "elevator": _params.elevator_weight,
		"corridor": _params.corridor_weight,
	}
	if dir < 0:
		weights["fall"] = _params.fall_weight
	var candidates := []
	for kind in weights:
		var weight: float = maxf(weights[kind], 0.0001)
		for column in modules:
			for variant in 2:
				var bias := weight * _core_bonus(kind, column)
				candidates.append([pow(_rng.randf(), 1.0 / bias), kind, column, variant])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for candidate in candidates:
		var result := Vector2i(-1, -1)
		match candidate[1]:
			"stairs":
				result = _place_stairs(cur, dir, candidate[2], 1 if candidate[3] == 0 else -1)
			"elevator":
				result = _place_elevator(cur, dir, candidate[2])
			"fall":
				result = _place_fall(cur, candidate[2], candidate[3] == 0)
			"corridor":
				result = _place_corridor(cur, dir, candidate[2])
		if result.x >= 0:
			return result
	return Vector2i(-1, -1)


## Escalera de fondo entre (f, c) y (f + 1, c): ambos módulos deben ser normales.
func _stairs_fit(f: int, c: int) -> bool:
	return in_range(f, c) and in_range(f + 1, c) and cell(f, c) == Cell.NORMAL \
			and cell(f + 1, c) == Cell.NORMAL and depth_at[index(f, c)] < 0 and depth_at[index(f + 1, c)] < 0


func _place_stairs(cur: Vector2i, dir: int, column: int, d: int) -> Vector2i:
	var f := cur.x
	var low := f if dir > 0 else f - 1
	if low < 0 or not (stairs_from(low, column) != 0 or _stairs_fit(low, column)):
		return Vector2i(-1, -1)
	if not _can_walk(f, cur.y, column):
		return Vector2i(-1, -1)
	_walk(f, cur.y, column)
	_apply_stairs(low, column, d)
	var exit := Vector2i(f + dir, column)
	_protect(exit)
	return exit


## En una pila de escaleras se alterna el sentido (tramos en zigzag, como un núcleo real).
func _apply_stairs(f: int, c: int, d: int) -> void:
	if stairs_from(f, c) != 0:
		return
	var below := stairs_from(f - 1, c) if f > 0 else 0
	stair_up[index(f, c)] = -below if below != 0 else d
	_protect(Vector2i(f, c))
	_protect(Vector2i(f + 1, c))


func _place_elevator(cur: Vector2i, dir: int, column: int) -> Vector2i:
	var room := (floors - 1 - cur.x) if dir > 0 else cur.x
	if room <= 0 or not _can_walk(cur.x, cur.y, column):
		return Vector2i(-1, -1)
	var span := _rng.randi_range(1, mini(_params.elevator_max_span, room))
	while span > 0 and not _elevator_fits(column, mini(cur.x, cur.x + dir * span), maxi(cur.x, cur.x + dir * span)):
		span -= 1
	if span == 0:
		return Vector2i(-1, -1)
	var target := cur.x + dir * span
	_walk(cur.x, cur.y, column)
	_apply_elevator(column, mini(cur.x, target), maxi(cur.x, target), _pick_lift())
	return Vector2i(target, column)


## El ascensor ocupa la pared del fondo de toda la columna: sin escaleras ni puertas al fondo.
## Los módulos se siguen caminando, así que pueden ser celdas de ruta.
func _elevator_fits(c: int, low: int, high: int) -> bool:
	for f in range(low, high + 1):
		if not in_range(f, c) or cell(f, c) != Cell.NORMAL or _reserved(f, c) or has_stairs(f, c) \
				or depth_at[index(f, c)] >= 0:
			return false
	return true


func _apply_elevator(c: int, low: int, high: int, kind: Lift) -> void:
	elevators.append(Shaft.new(c, low, high, kind))
	for f in range(low, high + 1):
		cells[index(f, c)] = Cell.SHAFT
		shaft_of[index(f, c)] = elevators.size() - 1
		_protect(Vector2i(f, c))


func _pick_lift() -> Lift:
	return _weighted({
		Lift.LOCAL: _params.elevator_local_weight, Lift.EXPRESS: _params.elevator_express_weight,
		Lift.CALL: _params.elevator_call_weight, Lift.FAULTY: _params.elevator_faulty_weight,
	})


## Una celda puede volverse hueco o derrumbe: libre, sin escaleras ni puerta al fondo.
func _breakable(f: int, c: int) -> bool:
	return f > 0 and _free(f, c) and not has_stairs(f, c) and depth_at[index(f, c)] < 0


## ¿Caer desde (f, c) termina en un módulo normal o hueco (no en un ascensor ni sellado)?
func _safe_landing(f: int, c: int) -> bool:
	var land := landing(f, c)
	return land.x >= 0 and cell(land.x, land.y) in [Cell.NORMAL, Cell.GAP]


func _place_fall(cur: Vector2i, column: int, gap: bool) -> Vector2i:
	var f := cur.x
	if f <= 0:
		return Vector2i(-1, -1)
	var depth := 1 if gap else _rng.randi_range(1, mini(_params.collapse_max_depth, f))
	for h in range(f - depth + 1, f + 1):
		if not _breakable(h, column):
			return Vector2i(-1, -1)
	var land := Vector2i(f - depth, column)
	if land.x < 0 or cell(land.x, land.y) != Cell.NORMAL:
		return Vector2i(-1, -1)
	if gap:
		if not _can_walk(f, cur.y, column):
			return Vector2i(-1, -1)
		_walk(f, cur.y, column)
		cells[index(f, column)] = Cell.GAP
		_protect(Vector2i(f, column))
	else:
		var side := column - 1 if cur.y < column else column + 1
		if not in_range(f, side) or not _can_walk(f, cur.y, side):
			return Vector2i(-1, -1)
		_walk(f, cur.y, side)
		_open_wall(f, mini(side, column))
		for h in range(f - depth + 1, f + 1):
			cells[index(h, column)] = Cell.COLLAPSE
			_protect(Vector2i(h, column))
	_protect(land)
	return land


## Pasillo al fondo: puerta en (f, column) enlazada con otra puerta en otro módulo,
## en el mismo piso o hasta 2 pisos más arriba o abajo (escalera de incendios).
func _place_corridor(cur: Vector2i, dir: int, column: int) -> Vector2i:
	var f := cur.x
	if not _can_walk(f, cur.y, column) or not _depth_free(f, column):
		return Vector2i(-1, -1)
	var span := _rng.randi_range(0, mini(2, _params.corridor_max_floors))
	var target_floor := clampi(f + dir * span, 0, floors - 1)
	var options := range(modules)
	_shuffle(options)
	for target_column: int in options:
		var target := Vector2i(target_floor, target_column)
		if target_floor == f and absi(target_column - column) < 2:
			continue
		if not _depth_free(target.x, target.y):
			continue
		_walk(f, cur.y, column)
		_link_corridor(Vector2i(f, column), target)
		return target
	return Vector2i(-1, -1)


func _depth_free(f: int, c: int) -> bool:
	return in_range(f, c) and cell(f, c) == Cell.NORMAL and depth_at[index(f, c)] < 0 and not has_stairs(f, c) \
			and not _reserved(f, c)


func _link_corridor(a: Vector2i, b: Vector2i) -> void:
	var first := _add_depth_door(a, Depth.CORRIDOR)
	var second := _add_depth_door(b, Depth.CORRIDOR)
	depth_doors[first].partner = second
	depth_doors[second].partner = first
	_protect(a)
	_protect(b)


func _add_depth_door(node: Vector2i, kind: Depth) -> int:
	depth_doors.append(DepthDoor.new(node.x, node.y, kind))
	depth_at[index(node.x, node.y)] = depth_doors.size() - 1
	return depth_doors.size() - 1


## Extras fuera de las rutas. El daño se concentra en zonas (campo de ruido), como en un
## edificio real, en vez de repartirse uniforme.
func _add_extras() -> void:
	var damage := FastNoiseLite.new()
	damage.seed = _rng.randi()
	damage.frequency = 0.35
	var order := range(floors * modules)
	_shuffle(order)
	for i: int in order:
		var f := i / modules
		var c := i % modules
		if not _free(f, c):
			continue
		var zone := maxf(0.0, 1.0 + _params.realism * damage.get_noise_2d(c, f * 1.7) * 1.6)
		var roll := _rng.randf()
		var threshold := _params.collapse_chance * zone
		if roll < threshold:
			if _breakable(f, c) and _safe_landing(f - 1, c):
				cells[i] = Cell.COLLAPSE
			continue
		threshold += _params.gap_chance * zone
		if roll < threshold:
			if _breakable(f, c) and _safe_landing(f - 1, c):
				cells[i] = Cell.GAP
			continue
		threshold += _params.extra_stairs * _core_bonus("stairs", c)
		if roll < threshold:
			if f + 1 < floors and _stairs_fit(f, c):
				_apply_stairs(f, c, 1 if _rng.randf() < 0.5 else -1)
			continue
		threshold += _params.extra_elevators
		if roll < threshold and f < floors - 1:
			var high := mini(floors - 1, f + _rng.randi_range(1, _params.elevator_max_span))
			if _elevator_fits(c, f, high) and _free(high, c):
				_apply_elevator(c, f, high, _pick_lift())
			continue
		threshold += _params.room_chance
		if roll < threshold and _depth_free(f, c):
			_add_depth_door(Vector2i(f, c), Depth.ROOM)


## Muros libres. Con realismo, cada piso tiende a repetir la planta del de abajo, y se evitan
## tramos largos del mismo tipo de muro.
func _assign_free_walls() -> void:
	for f in floors:
		var run_type := -1
		var run_length := 0
		for c in modules - 1:
			var i := f * (modules - 1) + c
			if walls[i] == Wall.UNSET:
				var below: int = walls[i - (modules - 1)] if f > 0 else Wall.UNSET
				if below != Wall.UNSET and below != Wall.LOCKED and (not _safe or below != Wall.BLOCKED) \
						and _rng.randf() < _params.realism * 0.6:
					walls[i] = below
				else:
					var weights := {
						Wall.OPEN: _params.wall_open_weight, Wall.DOOR: _params.wall_door_weight,
						Wall.BLOCKED: 0.0 if _safe else _params.wall_blocked_weight,
					}
					if run_length >= 2 and weights.has(run_type):
						weights[run_type] *= 0.15
					walls[i] = _weighted(weights)
			if walls[i] == run_type:
				run_length += 1
			else:
				run_type = walls[i]
				run_length = 1


## Elimina trampas y, si se pide, zonas inalcanzables; lo que no tiene arreglo se sella.
func _repair() -> bool:
	for iteration in MAX_REPAIRS:
		var reach := reachable_from(start)
		if not reach.has(end):
			return false
		var good := can_reach(end)
		var trapped := traps()
		if not trapped.is_empty():
			trapped.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return reach.has(a) and not reach.has(b))
			var node: Vector2i = trapped[0]
			if _open_segment_wall(node) or _link_segment(node, good):
				repairs += 1
			elif reach.has(node):
				return false
			else:
				_seal(node)
			continue
		if not _params.reach_everything:
			return true
		var lost := isolated()
		if lost.is_empty():
			return true
		if _open_segment_wall(lost[0]) or _link_segment(lost[0], reach):
			repairs += 1
		else:
			_seal(lost[0])
	return false


func _seal(node: Vector2i) -> void:
	cells[index(node.x, node.y)] = Cell.SEALED
	if depth_at[index(node.x, node.y)] >= 0:
		_remove_depth_door(depth_at[index(node.x, node.y)])
	stair_up[index(node.x, node.y)] = 0
	if node.x > 0:
		stair_up[index(node.x - 1, node.y)] = 0
	# Un derrumbe encima caería sobre el bloque sellado: se repone ese suelo.
	var f := node.x + 1
	while f < floors and cell(f, node.y) == Cell.COLLAPSE:
		cells[index(f, node.y)] = Cell.NORMAL
		f += 1
	sealed_count += 1


func _remove_depth_door(id: int) -> void:
	var door := depth_doors[id]
	depth_at[index(door.floor, door.module)] = -1
	if door.partner >= 0:
		var other := depth_doors[door.partner]
		depth_at[index(other.floor, other.module)] = -1
		other.kind = Depth.NONE
	door.kind = Depth.NONE


func _segment(node: Vector2i) -> Vector2i:
	var f := node.x
	var lo := node.y
	while lo > 0 and wall(f, lo - 1) != Wall.BLOCKED and wall(f, lo - 1) != Wall.LOCKED and is_node(f, lo - 1):
		lo -= 1
	var hi := node.y
	while hi < modules - 1 and wall(f, hi) != Wall.BLOCKED and wall(f, hi) != Wall.LOCKED and is_node(f, hi + 1):
		hi += 1
	return Vector2i(lo, hi)


func _open_segment_wall(node: Vector2i) -> bool:
	var seg := _segment(node)
	for c in [seg.x - 1, seg.y]:
		if c >= 0 and c < modules - 1 and wall(node.x, c) == Wall.BLOCKED:
			set_wall(node.x, c, Wall.DOOR)
			return true
	return false


## Conecta el tramo de `node` con algún nodo de `targets`: escalera, ascensor local o, como
## último recurso, un pasillo al fondo (casi siempre cabe).
func _link_segment(node: Vector2i, targets: Dictionary) -> bool:
	var f := node.x
	var seg := _segment(node)
	for c in range(seg.x, seg.y + 1):
		if f + 1 < floors and targets.has(Vector2i(f + 1, c)) and _stairs_fit(f, c):
			_apply_stairs(f, c, 1 if _rng.randf() < 0.5 else -1)
			return true
		if f > 0 and targets.has(Vector2i(f - 1, c)) and _stairs_fit(f - 1, c):
			_apply_stairs(f - 1, c, 1 if _rng.randf() < 0.5 else -1)
			return true
	for c in range(seg.x, seg.y + 1):
		for g in floors:
			if g != f and targets.has(Vector2i(g, c)) and _elevator_fits(c, mini(f, g), maxi(f, g)):
				_apply_elevator(c, mini(f, g), maxi(f, g), Lift.LOCAL)
				return true
	for c in range(seg.x, seg.y + 1):
		if not _depth_free(f, c):
			continue
		for target in targets:
			if _depth_free(target.x, target.y) and target != Vector2i(f, c):
				_link_corridor(Vector2i(f, c), target)
				return true
	return false


## Cerraduras: puertas que piden llave. La llave se deja en un lugar alcanzable antes de la
## puerta (en una habitación al fondo o en el piso) y todo se valida en el espacio de estados.
func _add_locks() -> void:
	var count := mini(_params.locked_doors, MAX_KEYS)
	for key_id in count:
		var candidates := []
		for f in floors:
			for c in modules - 1:
				if wall(f, c) == Wall.DOOR:
					candidates.append(Vector2i(f, c))
		_shuffle(candidates)
		var placed := false
		for candidate: Vector2i in candidates.slice(0, 40):
			if _try_lock(candidate, key_id):
				placed = true
				break
		if not placed:
			return


func _try_lock(door: Vector2i, key_id: int) -> bool:
	var before_mask := (1 << key_id) - 1
	set_wall(door.x, door.y, Wall.LOCKED, key_id)
	var reach := reachable_from(start, before_mask)
	var spots: Array = reach.keys()
	_shuffle(spots)
	for spot: Vector2i in spots.slice(0, 12):
		if spot == start or spot == end or not is_node(spot.x, spot.y):
			continue
		var room := -1
		if _rng.randf() < _params.key_in_room_chance and _depth_free(spot.x, spot.y):
			room = _add_depth_door(spot, Depth.ROOM)
			depth_doors[room].key = key_id
		keys.append(KeyItem.new(key_id, spot, room))
		if state_traps().is_empty() and traps().is_empty():
			return true
		keys.pop_back()
		if room >= 0:
			depth_at[index(spot.x, spot.y)] = -1
			depth_doors.pop_back()
	set_wall(door.x, door.y, Wall.DOOR)
	return false


## Mezcla determinista (Array.shuffle usaría el azar global, sin seed).
func _shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp


func _weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return weights.keys()[0]
	var roll := _rng.randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0:
			return key
	return weights.keys().back()
