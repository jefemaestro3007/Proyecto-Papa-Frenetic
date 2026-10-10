extends SceneTree
## Genera los frames del jugador a partir de los dibujos originales de `assets_src/sprites/player/`.
## Para cada imagen: quita el fondo (si no es transparente), separa las poses, las escala a un
## tamaño común usando la gorra roja como referencia y guarda un PNG por frame en
## `assets/textures/sprites/player/`, con el ancla (los pies) abajo al centro.
## Ejecutar (y después `--import` para que Godot los importe):
##   godot --headless --path . --script res://tools/scripts/build_player_sprites.gd

const SOURCE := "res://assets_src/sprites/player/"
const OUTPUT := "res://assets/textures/sprites/player/"
## Imagen → nombres de los frames que contiene, de izquierda a derecha.
const SHEETS := {
	"salto_aterrizaje.png": ["aire", "aterrizaje"],
	"correr.jpg": ["correr_0", "correr_1", "correr_2", "correr_3"],
	"dash.png": ["dash"],
	"guardia.png": ["guardia_izquierda", "guardia_derecha"],
	"ataque_aereo.png": ["ataque_aereo"],
}
## Frame de referencia y la altura en pantalla que debe tener (el personaje mide 88 de colisión).
const REFERENCE := "guardia_derecha"
const REFERENCE_HEIGHT := 128.0
## Los frames se guardan al doble para que se vean nítidos con zoom; el jugador los dibuja a 0,5.
const SUPERSAMPLE := 2.0
const ALPHA_SOLID := 16

var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var frames := {}
	for file: String in SHEETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + file))
		if image == null:
			_fail("no se pudo leer " + file)
			continue
		image.convert(Image.FORMAT_RGBA8)
		if not image.detect_alpha():
			_remove_checkerboard(image)
		var names: Array = SHEETS[file]
		var parts := _split_columns(image, names.size())
		if parts.size() != names.size():
			_fail("%s: se esperaban %d poses y salieron %d" % [file, names.size(), parts.size()])
			continue
		for i in names.size():
			frames[names[i]] = parts[i]
	if not frames.has(REFERENCE):
		_fail("falta el frame de referencia " + REFERENCE)
		quit(1)
		return
	var reference: Image = frames[REFERENCE]
	var scale := REFERENCE_HEIGHT * SUPERSAMPLE / reference.get_height()
	var cap_reference := _cap_size(reference) * scale
	for frame_name: String in frames:
		var image: Image = frames[frame_name]
		var cap := _cap_size(image)
		var frame_scale := cap_reference / cap if cap > 0.0 else scale
		var out := _anchor_and_scale(image, frame_scale)
		out.save_png(ProjectSettings.globalize_path(OUTPUT + frame_name + ".png"))
		print("  %s: %dx%d (escala %.3f)" % [frame_name, out.get_width(), out.get_height(), frame_scale])
	print("build_player_sprites: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


## Fondo de cuadriculado pintado (sin transparencia): se borra con un relleno desde los bordes que
## se detiene en el contorno negro del dibujo. Los huecos encerrados (entre piernas, bajo el brazo)
## se borran si mezclan los tonos claro y oscuro del cuadriculado; el pantalón y las botas, que son
## grises parejos, se conservan.
func _remove_checkerboard(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	_flood(image, stack, seen, true)
	# Huecos encerrados.
	for start in w * h:
		if seen[start] != 0 or not _is_backdrop(image.get_pixel(start % w, start / w)):
			continue
		var component := _flood(image, PackedInt32Array([start]), seen, false)
		var dark := 0
		var light := 0
		for index in component:
			var v := image.get_pixel(index % w, index / w).v
			if v < 0.30:
				dark += 1
			elif v > 0.43:
				light += 1
		var total := component.size()
		if total > 120 and dark > total * 0.15 and light > total * 0.15:
			for index in component:
				image.set_pixel(index % w, index / w, Color.TRANSPARENT)
	_remove_specks(image)


## Borra manchas opacas sueltas (restos de compresión del fondo) que correrían el recorte y el ancla.
func _remove_specks(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if seen[start] != 0 or image.get_pixel(start % w, start / w).a8 <= ALPHA_SOLID:
			continue
		var component := PackedInt32Array()
		var stack := PackedInt32Array([start])
		seen[start] = 1
		while not stack.is_empty():
			var index := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			component.append(index)
			var x := index % w
			var y := index / w
			for next: int in [index - 1 if x > 0 else -1, index + 1 if x < w - 1 else -1,
					index - w if y > 0 else -1, index + w if y < h - 1 else -1]:
				if next >= 0 and seen[next] == 0 and image.get_pixel(next % w, next / w).a8 > ALPHA_SOLID:
					seen[next] = 1
					stack.append(next)
		if component.size() < 400:
			for index in component:
				image.set_pixel(index % w, index / w, Color.TRANSPARENT)


## Grises del cuadriculado (y el borde de compresión JPEG): poco saturados, ni negros ni blancos.
func _is_backdrop(color: Color) -> bool:
	var spread := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
	return spread < 0.07 and color.v > 0.17 and color.v < 0.64


## Rellena desde `stack` por píxeles de fondo (4 vecinos). Si `clear`, los vuelve transparentes.
func _flood(image: Image, stack: PackedInt32Array, seen: PackedByteArray, clear: bool) -> PackedInt32Array:
	var w := image.get_width()
	var h := image.get_height()
	var out := PackedInt32Array()
	while not stack.is_empty():
		var index := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if seen[index] != 0:
			continue
		var x := index % w
		var y := index / w
		if not _is_backdrop(image.get_pixel(x, y)):
			continue
		seen[index] = 1
		out.append(index)
		if clear:
			image.set_pixel(x, y, Color.TRANSPARENT)
		if x > 0:
			stack.append(index - 1)
		if x < w - 1:
			stack.append(index + 1)
		if y > 0:
			stack.append(index - w)
		if y < h - 1:
			stack.append(index + w)
	return out


## Separa las poses por columnas vacías y recorta cada una a su contenido. Si los dibujos se tocan,
## las columnas se reparten en partes iguales.
func _split_columns(image: Image, count: int) -> Array[Image]:
	var w := image.get_width()
	var h := image.get_height()
	var filled := PackedByteArray()
	filled.resize(w)
	for x in w:
		for y in range(0, h, 2):
			if image.get_pixel(x, y).a8 > ALPHA_SOLID:
				filled[x] = 1
				break
	var spans: Array[Vector2i] = []
	var start := -1
	for x in w + 1:
		var on := x < w and filled[x] != 0
		if on and start < 0:
			start = x
		elif not on and start >= 0:
			if x - start > 20:
				spans.append(Vector2i(start, x))
			start = -1
	# Une los fragmentos (puntas de espada, estelas) a la pose más cercana hasta quedar `count`.
	while spans.size() > count:
		var best := 0
		var best_gap := INF
		for i in spans.size() - 1:
			var gap := spans[i + 1].x - spans[i].y
			if gap < best_gap:
				best_gap = gap
				best = i
		spans[best] = Vector2i(spans[best].x, spans[best + 1].y)
		spans.remove_at(best + 1)
	if spans.size() < count:
		spans.clear()
		for i in count:
			spans.append(Vector2i(w * i / count, w * (i + 1) / count))
	var out: Array[Image] = []
	for span in spans:
		var part := image.get_region(Rect2i(span.x, 0, span.y - span.x, h))
		var used := part.get_used_rect()
		out.append(part.get_region(used))
	return out


## Tamaño de la gorra (raíz del área de rojo opaco): misma referencia en todas las poses.
func _cap_size(image: Image) -> float:
	var count := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			if c.a8 > 220 and c.r > 0.55 and c.g < 0.25 and c.b < 0.25:
				count += 1
	return sqrt(count * 4.0)


## Escala la pose y la centra en el eje de la gorra con los pies abajo: el ancla queda en el centro
## del borde inferior del PNG.
func _anchor_and_scale(image: Image, frame_scale: float) -> Image:
	var size := Vector2i(roundi(image.get_width() * frame_scale), roundi(image.get_height() * frame_scale))
	var scaled := image.duplicate() as Image
	scaled.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var anchor_x := roundi(_cap_center_x(image) * frame_scale)
	var half := maxi(anchor_x, size.x - anchor_x)
	var out := Image.create_empty(half * 2, size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(scaled, Rect2i(Vector2i.ZERO, size), Vector2i(half - anchor_x, 0))
	return out


func _cap_center_x(image: Image) -> float:
	var sum := 0.0
	var count := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			if c.a8 > 220 and c.r > 0.55 and c.g < 0.25 and c.b < 0.25:
				sum += x
				count += 1
	return sum / count if count > 0 else image.get_width() * 0.5


func _fail(message: String) -> void:
	_failures += 1
	printerr("  FALLO: ", message)
