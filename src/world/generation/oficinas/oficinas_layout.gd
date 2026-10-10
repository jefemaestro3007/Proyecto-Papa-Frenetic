class_name OficinasLayout
extends RefCounted
## Topología del edificio de oficinas: grilla pisos × módulos con lo que hay en cada celda
## y entre celdas, y el grafo dirigido de movimiento que se deriva de ella (caer es de un
## solo sentido). Es puro: sin nodos ni geometría. Los nodos del grafo son Vector2i(piso, módulo).
##
## Generación: una ruta principal aleatoria (con desvíos) de la entrada a la salida, rutas
## alternativas que parten de ella, extras y daño fuera de las rutas, y por último una
## reparación que garantiza que desde CUALQUIER lugar del edificio se pueda llegar a la salida
## (sin trampas, ni siquiera llegando por saltos potenciados) y, si se pide, que todo sea
## alcanzable. Lo que no se puede conectar se sella (módulo tapiado y lleno de escombros).

enum Cell { NORMAL, STAIR_LOW, STAIR_VOID, SHAFT, GAP, COLLAPSE, SEALED }
enum Wall { UNSET = -1, OPEN, DOOR, BLOCKED }
enum Lift { LOCAL, EXPRESS, CALL, FAULTY }
enum Link { WALK, STAIRS, LIFT, FALL }

const MAX_ROUTE_STEPS := 64
const MAX_REPAIRS := 400
const BUILD_ATTEMPTS := 8


class Elevator:
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

	## Pisos donde se detiene (los demás pisos del hueco son vacío).
	func stops() -> PackedInt32Array:
		if kind == Lift.EXPRESS or kind == Lift.CALL:
			return PackedInt32Array([low, high])
		var all := PackedInt32Array()
		for f in range(low, high + 1):
			all.append(f)
		return all


var floors: int
var modules: int
var cells := PackedInt32Array()
var stair_dirs := PackedInt32Array()
var shaft_of := PackedInt32Array()
var walls := PackedInt32Array()
var elevators: Array[Elevator] = []
var protected := PackedByteArray()
var start: Vector2i
var end: Vector2i
var valid := false
## Para depurar y para los tests.
var main_transitions := 0
var repairs := 0

var _params: OficinasParams
var _rng := RandomNumberGenerator.new()
## Intentos fallidos previos: se relajan las exigencias (menos cambios de piso, sin desvíos)
## para que configuraciones imposibles (p. ej. 2 pisos × 3 módulos con 3 cambios) igual generen.
var _relax := 0


static func build(params: OficinasParams) -> OficinasLayout:
	var layout: OficinasLayout
	for attempt in BUILD_ATTEMPTS:
		layout = OficinasLayout.new()
		layout._generate(params, params.seed + attempt * 7919, attempt)
		if layout.valid:
			return layout
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


func set_wall(f: int, c: int, value: Wall) -> void:
	walls[f * (modules - 1) + c] = value


func elevator_at(f: int, c: int) -> Elevator:
	var id := shaft_of[index(f, c)]
	return elevators[id] if id >= 0 else null


## Celdas sin suelo donde no se puede estar: se cae al piso de abajo.
func is_void(f: int, c: int) -> bool:
	match cell(f, c):
		Cell.STAIR_VOID, Cell.COLLAPSE:
			return true
		Cell.SHAFT:
			return not elevator_at(f, c).stops().has(f)
	return false


## Dónde termina quien entra en (f, c): baja mientras haya vacío. Piso -1 = fuera del edificio.
func landing(f: int, c: int) -> Vector2i:
	while f >= 0 and is_void(f, c):
		f -= 1
	return Vector2i(f, c)


func is_sealed(f: int, c: int) -> bool:
	return cell(f, c) == Cell.SEALED


func nodes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for f in floors:
		for c in modules:
			if not is_void(f, c) and not is_sealed(f, c):
				out.append(Vector2i(f, c))
	return out


## Movimientos posibles desde un nodo: pares [destino, Link].
func successors(node: Vector2i) -> Array:
	var f := node.x
	var c := node.y
	var out := []
	for d in [-1, 1]:
		var nc: int = c + d
		if nc < 0 or nc >= modules or wall(f, mini(c, nc)) == Wall.BLOCKED or is_sealed(f, nc):
			continue
		var target := landing(f, nc)
		if target.x >= 0:
			out.append([target, Link.WALK if target.x == f else Link.FALL])
	match cell(f, c):
		Cell.STAIR_LOW:
			out.append([Vector2i(f + 1, c + stair_dirs[index(f, c)]), Link.STAIRS])
		Cell.GAP:
			var below := landing(f - 1, c)
			if below.x >= 0:
				out.append([below, Link.FALL])
		Cell.SHAFT:
			for stop in elevator_at(f, c).stops():
				if stop != f:
					out.append([Vector2i(stop, c), Link.LIFT])
	return out


func reachable_from(origin: Vector2i) -> Dictionary:
	var seen := {origin: true}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var node: Vector2i = queue.pop_front()
		for pair in successors(node):
			if not seen.has(pair[0]):
				seen[pair[0]] = true
				queue.append(pair[0])
	return seen


## Nodos desde los que se puede llegar a `target`.
func can_reach(target: Vector2i) -> Dictionary:
	var reverse := {}
	for node in nodes():
		for pair in successors(node):
			if not reverse.has(pair[0]):
				reverse[pair[0]] = []
			reverse[pair[0]].append(node)
	var seen := {target: true}
	var queue: Array[Vector2i] = [target]
	while not queue.is_empty():
		var node: Vector2i = queue.pop_front()
		for previous in reverse.get(node, []):
			if not seen.has(previous):
				seen[previous] = true
				queue.append(previous)
	return seen


## Camino más corto (BFS) como lista de pares [nodo, Link con el que se llegó].
func shortest_path(origin: Vector2i, target: Vector2i) -> Array:
	var came := {origin: null}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var node: Vector2i = queue.pop_front()
		if node == target:
			break
		for pair in successors(node):
			if not came.has(pair[0]):
				came[pair[0]] = [node, pair[1]]
				queue.append(pair[0])
	if not came.has(target):
		return []
	var path := []
	var node := target
	var link := Link.WALK
	while came[node] != null:
		path.push_front([node, came[node][1]])
		node = came[node][0]
	path.push_front([origin, link])
	return path


## Lugares (cualquiera, no solo los alcanzables) desde los que ya no se puede llegar a la salida.
func traps() -> Array[Vector2i]:
	var good := can_reach(end)
	var out: Array[Vector2i] = []
	for node in nodes():
		if not good.has(node):
			out.append(node)
	return out


## Lugares transitables a los que no se llega desde la entrada.
func isolated() -> Array[Vector2i]:
	var reach := reachable_from(start)
	var out: Array[Vector2i] = []
	for node in nodes():
		if not reach.has(node):
			out.append(node)
	return out


## Conexiones verticales útiles (ambos extremos en rutas que llegan a la salida).
## Si supera a los cambios de piso de la ruta principal, hay alternativas para elegir.
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
	cells.resize(floors * modules)
	cells.fill(Cell.NORMAL)
	stair_dirs.resize(floors * modules)
	stair_dirs.fill(0)
	shaft_of.resize(floors * modules)
	shaft_of.fill(-1)
	protected.resize(floors * modules)
	protected.fill(0)
	walls.resize(floors * (modules - 1))
	walls.fill(Wall.UNSET)

	var floors_pair := params.start_and_end_floor()
	start = Vector2i(floors_pair.x, 0)
	end = Vector2i(floors_pair.y, modules - 1)
	_protect(start)
	_protect(end)

	var main_nodes: Array[Vector2i] = []
	var min_transitions := params.min_transitions if relax < 3 else maxi(0, params.min_transitions - (relax - 2))
	if not _route(start, min_transitions, main_nodes):
		return
	main_transitions = main_nodes.size() - 1
	for b in params.branches:
		var from: Vector2i = main_nodes[_rng.randi_range(0, maxi(main_nodes.size() - 2, 0))]
		_route(from, _rng.randi_range(1, 2), [])

	_add_extras()
	_assign_free_walls()
	valid = _repair()


func _protect(node: Vector2i) -> void:
	protected[index(node.x, node.y)] = 1


func _is_protected(f: int, c: int) -> bool:
	return protected[index(f, c)] == 1


func _free(f: int, c: int) -> bool:
	return in_range(f, c) and cell(f, c) == Cell.NORMAL and not _is_protected(f, c)


## Entrada y salida son siempre módulos normales: ninguna conexión las reemplaza.
func _reserved(f: int, c: int) -> bool:
	return Vector2i(f, c) == start or Vector2i(f, c) == end


## Ruta aleatoria desde `from` hasta la salida. Guarda en `visited` el nodo tras cada cambio de piso.
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


## Camina por el piso `f` de `from_c` a `to_c` si no hay vacío en medio; protege y abre muros.
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
		if is_void(f, c) or is_sealed(f, c):
			return false
		if c == to_c:
			return true
		if wall(f, mini(c, c + step)) == Wall.BLOCKED:
			return false
		c += step
	return false


## Abre un muro sin decidir aún si es pasillo abierto o puerta.
func _open_wall(f: int, c: int) -> void:
	if wall(f, c) == Wall.UNSET or wall(f, c) == Wall.BLOCKED:
		set_wall(f, c, Wall.OPEN if _rng.randf() < 0.45 else Wall.DOOR)


## Intenta cambiar de piso en la dirección `dir`. Recorre todas las combinaciones
## (tipo de conexión × columna × variante) en un orden aleatorio ponderado por los pesos,
## así nunca falla si existe alguna colocación válida. Devuelve el nodo de llegada o (-1, -1).
func _transition(cur: Vector2i, dir: int) -> Vector2i:
	var weights := {"stairs": _params.stairs_weight, "elevator": _params.elevator_weight}
	if dir < 0:
		weights["fall"] = _params.fall_weight
	var candidates := []
	for kind in weights:
		var weight: float = maxf(weights[kind], 0.0001)
		for column in modules:
			for variant in 2:
				# Clave de orden aleatoria sesgada por el peso (muestreo ponderado sin reemplazo).
				candidates.append([pow(_rng.randf(), 1.0 / weight), kind, column, variant])
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
		if result.x >= 0:
			return result
	return Vector2i(-1, -1)


func _place_stairs(cur: Vector2i, dir: int, column: int, d: int) -> Vector2i:
	var f := cur.x
	if dir > 0:
		# Pie de la escalera en (f, column); llega al lado alto (f + 1, column + d).
		if not _stairs_fit(f, column, d) or not _can_walk(f, cur.y, column):
			return Vector2i(-1, -1)
		_walk(f, cur.y, column)
		return _apply_stairs(f, column, d)
	# Bajando: se entra por el rellano (f, column + d) y se cae al pie (f - 1, column).
	if not _stairs_fit(f - 1, column, d) or not _can_walk(f, cur.y, column + d):
		return Vector2i(-1, -1)
	_walk(f, cur.y, column + d)
	_apply_stairs(f - 1, column, d)
	return Vector2i(f - 1, column)


## Escalera con pie en (f, c) y rellano en (f + 1, c + d); su hueco es (f + 1, c).
func _stairs_fit(f: int, c: int, d: int) -> bool:
	return in_range(f, c) and in_range(f + 1, c + d) and cell(f, c) == Cell.NORMAL \
			and not _reserved(f, c) and _free(f + 1, c) and cell(f + 1, c + d) == Cell.NORMAL


func _apply_stairs(f: int, c: int, d: int) -> Vector2i:
	cells[index(f, c)] = Cell.STAIR_LOW
	stair_dirs[index(f, c)] = d
	cells[index(f + 1, c)] = Cell.STAIR_VOID
	for node in [Vector2i(f, c), Vector2i(f + 1, c), Vector2i(f + 1, c + d)]:
		_protect(node)
	set_wall(f + 1, mini(c, c + d), Wall.OPEN)
	return Vector2i(f + 1, c + d)


func _place_elevator(cur: Vector2i, dir: int, column: int) -> Vector2i:
	var room := (floors - 1 - cur.x) if dir > 0 else cur.x
	if room <= 0:
		return Vector2i(-1, -1)
	if not _can_walk(cur.x, cur.y, column):
		return Vector2i(-1, -1)
	# Alcance aleatorio (dinámico); si no entra, se prueban alcances menores.
	var span := _rng.randi_range(1, mini(_params.elevator_max_span, room))
	while span > 0 and not _elevator_fits(column, mini(cur.x, cur.x + dir * span), maxi(cur.x, cur.x + dir * span)):
		span -= 1
	if span == 0:
		return Vector2i(-1, -1)
	var target := cur.x + dir * span
	_walk(cur.x, cur.y, column)
	_apply_elevator(column, mini(cur.x, target), maxi(cur.x, target), _pick_lift())
	return Vector2i(target, column)


## Los extremos pueden ser celdas de ruta (siguen siendo transitables); el medio debe estar libre.
func _elevator_fits(c: int, low: int, high: int) -> bool:
	for f in range(low, high + 1):
		if not in_range(f, c) or cell(f, c) != Cell.NORMAL or _reserved(f, c):
			return false
		if f != low and f != high and _is_protected(f, c):
			return false
	return true


func _apply_elevator(c: int, low: int, high: int, kind: Lift) -> void:
	elevators.append(Elevator.new(c, low, high, kind))
	for f in range(low, high + 1):
		cells[index(f, c)] = Cell.SHAFT
		shaft_of[index(f, c)] = elevators.size() - 1
		_protect(Vector2i(f, c))


func _pick_lift() -> Lift:
	return _weighted({
		Lift.LOCAL: _params.elevator_local_weight, Lift.EXPRESS: _params.elevator_express_weight,
		Lift.CALL: _params.elevator_call_weight, Lift.FAULTY: _params.elevator_faulty_weight,
	})


## Bajar cayendo: hueco pequeño (un piso) o derrumbe (uno o más pisos en cadena).
func _place_fall(cur: Vector2i, column: int, gap: bool) -> Vector2i:
	var f := cur.x
	if f <= 0:
		return Vector2i(-1, -1)
	var depth := 1 if gap else _rng.randi_range(1, mini(_params.collapse_max_depth, f))
	for h in range(f - depth + 1, f + 1):
		if not _free(h, column):
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
		# Se llega por un vecino y se entra al derrumbe.
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


## Escaleras, ascensores, huecos y derrumbes fuera de las rutas.
func _add_extras() -> void:
	var order := range(floors * modules)
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i: int in order:
		var f := i / modules
		var c := i % modules
		if not _free(f, c):
			continue
		var roll := _rng.randf()
		var threshold := 0.0
		threshold += _params.collapse_chance
		if roll < threshold:
			if f > 0:
				cells[i] = Cell.COLLAPSE
			continue
		threshold += _params.gap_chance
		if roll < threshold:
			if f > 0:
				cells[i] = Cell.GAP
			continue
		threshold += _params.extra_stairs
		if roll < threshold:
			var d := 1 if _rng.randf() < 0.5 else -1
			if _stairs_fit(f, c, d):
				_apply_stairs(f, c, d)
			continue
		threshold += _params.extra_elevators
		if roll < threshold and f < floors - 1:
			var high := mini(floors - 1, f + _rng.randi_range(1, _params.elevator_max_span))
			if _elevator_fits(c, f, high) and _free(high, c):
				_apply_elevator(c, f, high, _pick_lift())


func _assign_free_walls() -> void:
	for i in walls.size():
		if walls[i] == Wall.UNSET:
			walls[i] = _weighted({
				Wall.OPEN: _params.wall_open_weight, Wall.DOOR: _params.wall_door_weight,
				Wall.BLOCKED: _params.wall_blocked_weight,
			})


## Elimina trampas (y, si se pide, zonas inalcanzables) abriendo muros o agregando
## conexiones; lo que no tiene arreglo y está fuera de la ruta se sella.
var sealed_count := 0


func _repair() -> bool:
	for iteration in MAX_REPAIRS:
		var reach := reachable_from(start)
		if not reach.has(end):
			return false
		var good := can_reach(end)
		var trapped := traps()
		if not trapped.is_empty():
			# Primero las trampas alcanzables: son las que de verdad podría pisar el jugador.
			trapped.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return reach.has(a) and not reach.has(b))
			var node: Vector2i = trapped[0]
			if _rescue(node, good):
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
		if _connect_isolated(lost, reach):
			repairs += 1
		else:
			_seal(lost[0])
	return false


func _seal(node: Vector2i) -> void:
	cells[index(node.x, node.y)] = Cell.SEALED
	sealed_count += 1


## Tramo horizontal transitable que contiene a `node`: [primer módulo, último módulo].
func _segment(node: Vector2i) -> Vector2i:
	var f := node.x
	var lo := node.y
	while lo > 0 and wall(f, lo - 1) != Wall.BLOCKED and not is_void(f, lo - 1) and not is_sealed(f, lo - 1):
		lo -= 1
	var hi := node.y
	while hi < modules - 1 and wall(f, hi) != Wall.BLOCKED and not is_void(f, hi + 1) and not is_sealed(f, hi + 1):
		hi += 1
	return Vector2i(lo, hi)


## Saca a un nodo atrapado: abre un muro del borde de su tramo o le agrega una conexión
## hacia un lugar desde el que sí se llega a la salida.
func _rescue(node: Vector2i, good: Dictionary) -> bool:
	return _open_segment_wall(node) or _link_segment(node, good)


## Une una zona aislada con lo alcanzable.
func _connect_isolated(isolated: Array[Vector2i], reach: Dictionary) -> bool:
	for node in isolated:
		if _open_segment_wall(node) or _link_segment(node, reach):
			return true
	return false


func _open_segment_wall(node: Vector2i) -> bool:
	var seg := _segment(node)
	for c in [seg.x - 1, seg.y]:
		if c >= 0 and c < modules - 1 and wall(node.x, c) == Wall.BLOCKED:
			set_wall(node.x, c, Wall.DOOR)
			return true
	return false


## Conecta el tramo de `node` con algún nodo de `targets` mediante una escalera (hacia
## arriba o hacia abajo) o un ascensor local. Escaleras y ascensores son de doble sentido.
func _link_segment(node: Vector2i, targets: Dictionary) -> bool:
	var f := node.x
	var seg := _segment(node)
	for c in range(seg.x, seg.y + 1):
		for d in [1, -1]:
			# Pie en el tramo, rellano arriba en el destino.
			if cell(f, c) == Cell.NORMAL and _stairs_fit(f, c, d) and targets.has(Vector2i(f + 1, c + d)):
				_apply_stairs(f, c, d)
				return true
			# Pie abajo en el destino, rellano en el tramo (el hueco también queda en el tramo).
			if f > 0 and c + d >= seg.x and c + d <= seg.y and _stairs_fit(f - 1, c, d) \
					and targets.has(Vector2i(f - 1, c)):
				_apply_stairs(f - 1, c, d)
				return true
	for c in range(seg.x, seg.y + 1):
		if cell(f, c) != Cell.NORMAL:
			continue
		for g in floors:
			if g != f and targets.has(Vector2i(g, c)) and _elevator_fits(c, mini(f, g), maxi(f, g)):
				_apply_elevator(c, mini(f, g), maxi(f, g), Lift.LOCAL)
				return true
	return false


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
