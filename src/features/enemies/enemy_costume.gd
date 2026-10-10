class_name EnemyCostume
extends RefCounted
## Vestuarios de zona: accesorios dibujados en código sobre el sprite de un enemigo existente, sin
## cambiar su comportamiento (no hay enemigos nuevos: en Bienestar U la embestidora es el reponedor
## con su carrito, la voladora cuelga de globos de oferta...).
## Se dibujan en el espacio del sprite: `rect` es el rectángulo del dibujo con los pies abajo al
## centro y la cara hacia la izquierda (el enemigo ya espejó la transformación al mirar a la
## derecha). Las posiciones van en fracciones del rectángulo: u de izquierda a derecha y v desde
## los pies hacia arriba, así sirven para las tres poses y para la papa provisional.

enum Layer { BACK, FRONT }

## Vestuario → tipo de enemigo que lo usa (lo que se ve en la vista previa y en el roster).
const COSTUMES := {
	&"cliente": &"normal",
	&"reponedor": &"charger",
	&"guardia": &"tank",
	&"promotora": &"thrower",
	&"globos": &"flyer",
}

const INK := FreneticPalette.INK
const CREAM := FreneticPalette.CREAM
const YELLOW := FreneticPalette.YELLOW
const NAVY := FreneticPalette.NAVY
const NAVY_DARK := FreneticPalette.NAVY_DARK
const NAVY_LIGHT := FreneticPalette.NAVY_LIGHT
const METAL := Color("c9c3d6")
const BALLOONS: Array[Color] = [FreneticPalette.YELLOW, FreneticPalette.CREAM, Color("4fb3c9")]


static func draw(enemy: Enemy, costume: StringName, rect: Rect2, layer: Layer) -> void:
	var ink := enemy._outline()
	var width := clampf(enemy._outline_width(), 2.0, 4.0)
	match costume:
		&"cliente":
			if layer == Layer.FRONT:
				_bag(enemy, rect, ink, width)
		&"reponedor":
			if layer == Layer.FRONT:
				_stocker(enemy, rect, ink, width)
		&"guardia":
			if layer == Layer.FRONT:
				_guard(enemy, rect, ink, width)
		&"promotora":
			if layer == Layer.FRONT:
				_promoter(enemy, rect, ink, width)
		&"globos":
			if layer == Layer.BACK:
				_balloons(enemy, rect, ink, width)
			else:
				_sale_sticker(enemy, rect, Vector2(0.62, 0.42), 0.2, ink, width)


## Cuánto sobresale el vestuario por arriba del dibujo (fracción de su alto): ahí suben los avisos
## y la vida para no taparlo.
static func top_extra(costume: StringName) -> float:
	match costume:
		&"guardia":
			return 0.14
		&"reponedor":
			return 0.06
	return 0.0


## Punto del rectángulo del sprite: u de izquierda a derecha, v desde los pies.
static func at(rect: Rect2, u: float, v: float) -> Vector2:
	return Vector2(rect.position.x + rect.size.x * u, rect.end.y - rect.size.y * v)


static func _shape(item: CanvasItem, points: PackedVector2Array, fill: Color, ink: Color, width: float) -> void:
	item.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	item.draw_polyline(closed, ink, width, true)


static func _rect(item: CanvasItem, box: Rect2, fill: Color, ink: Color, width: float) -> void:
	item.draw_rect(box, fill)
	item.draw_rect(box, ink, false, width)


## Balanceo de los accesorios colgantes: va y vuelve en dos beats.
static func _sway(enemy: Enemy, amount: float) -> float:
	return sin(Conductor.beat_position() * PI + enemy.get_instance_id() % 7) * amount


# --- Cliente: bolsa de compras en la mano ------------------------------------------------

static func _bag(enemy: Enemy, rect: Rect2, ink: Color, width: float) -> void:
	var h := rect.size.y
	# La mano (adelante, a media altura) sostiene las asas; la bolsa cuelga y se balancea.
	var hand := at(rect, 0.2, 0.42)
	var xform := Transform2D(_sway(enemy, 0.18), hand)
	var w := h * 0.2
	var top := h * 0.1
	var bottom := h * 0.3
	# Lo que asoma: una baguette.
	_shape(enemy, xform * PackedVector2Array([Vector2(-w * 0.35, top + 2.0), Vector2(-w * 0.5, top - h * 0.1),
			Vector2(-w * 0.15, top - h * 0.12), Vector2(0.0, top + 2.0)]), Color("e7b765"), ink, maxf(width - 1.0, 1.5))
	var bag := xform * PackedVector2Array([Vector2(-w * 0.5, top), Vector2(w * 0.5, top),
			Vector2(w * 0.58, bottom), Vector2(-w * 0.58, bottom)])
	_shape(enemy, bag, CREAM, ink, width)
	_letter_u(enemy, xform * Vector2(0.0, (top + bottom) * 0.5), h * 0.045, ink)
	# Asas desde la bolsa hasta la mano.
	for side: float in [-1.0, 1.0]:
		enemy.draw_polyline(xform * PackedVector2Array([Vector2(side * w * 0.3, top), Vector2(side * w * 0.12, 0.0)]),
				ink, maxf(width - 1.0, 1.5), true)
	enemy.draw_circle(hand, h * 0.045, Color("b98a4e"))
	enemy.draw_arc(hand, h * 0.045, 0.0, TAU, 14, ink, maxf(width - 1.0, 1.5), true)


# --- Reponedor: gorra de uniforme y carrito ----------------------------------------------

## Gorra de visera; `center` es la coronilla (u, v) y `size` el ancho en fracción del sprite. La
## visera mira hacia la cara (izquierda).
static func _cap(enemy: Enemy, rect: Rect2, center: Vector2, size: float, color: Color, ink: Color, width: float,
		logo: bool) -> void:
	var w := rect.size.x * size
	var base := at(rect, center.x, center.y)
	var crown := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * i / 12.0
		crown.append(base + Vector2(cos(angle) * w * 0.5, sin(angle) * w * 0.42))
	_shape(enemy, crown, color, ink, width)
	var brim := PackedVector2Array([base + Vector2(-w * 0.45, -1.0), base + Vector2(-w * 0.95, w * 0.06),
			base + Vector2(-w * 0.9, w * 0.16), base + Vector2(-w * 0.3, w * 0.1)])
	_shape(enemy, brim, color.darkened(0.35), ink, width)
	if logo:
		_letter_u(enemy, base + Vector2(-w * 0.05, -w * 0.2), w * 0.2, ink)


## La "U" de Bienestar U: amarilla con contorno.
static func _letter_u(item: CanvasItem, center: Vector2, size: float, ink: Color) -> void:
	item.draw_circle(center, size, YELLOW)
	item.draw_arc(center, size, 0.0, TAU, 20, ink, 1.5, true)
	var r := size * 0.5
	item.draw_polyline(PackedVector2Array([center + Vector2(-r, -r), center + Vector2(-r, r * 0.3),
			center + Vector2(0.0, r), center + Vector2(r, r * 0.3), center + Vector2(r, -r)]), ink, maxf(size * 0.28, 2.0))


static func _stocker(enemy: Enemy, rect: Rect2, ink: Color, width: float) -> void:
	var h := rect.size.y
	var charger := enemy as ChargerEnemy
	var charging := charger != null and charger.state == ChargerEnemy.State.CHARGE
	_cap(enemy, rect, Vector2(0.62, 0.86), 0.46, NAVY, ink, width, true)
	var stocker := enemy as StockerEnemy
	if stocker == null or stocker.has_cart:
		# El carrito va adelante (a la izquierda); al cargar se inclina un poco.
		cart(enemy, at(rect, 0.18, 0.0), h, ink, width, -0.05 if charging else 0.0, enemy.global_position.x / (h * 0.06))
	if charging:
		# Líneas de velocidad detrás.
		for i in 3:
			var y := -h * (0.3 + i * 0.15)
			enemy.draw_line(at(rect, 1.0, 0.0) + Vector2(h * 0.05, y), at(rect, 1.0, 0.0) + Vector2(h * 0.35, y),
					Color(CREAM, 0.7), 3.0)


## Carrito de supermercado con la manija en `origin` (abajo) y el canasto hacia la izquierda; `h`
## es la escala (alto de la papa que lo empuja), `lean` lo inclina y `spin` gira las ruedas.
static func cart(item: CanvasItem, origin: Vector2, h: float, ink: Color, width: float, lean := 0.0,
		spin := 0.0) -> void:
	var xform := Transform2D(lean, origin)
	var basket := xform * PackedVector2Array([Vector2(-h * 0.92, -h * 0.62), Vector2(-h * 0.02, -h * 0.62),
			Vector2(-h * 0.1, -h * 0.26), Vector2(-h * 0.72, -h * 0.26)])
	# Manija.
	item.draw_line(xform * Vector2(-h * 0.02, -h * 0.62), xform * Vector2(h * 0.14, -h * 0.66), ink, width + 3.0, true)
	item.draw_line(xform * Vector2(-h * 0.02, -h * 0.62), xform * Vector2(h * 0.14, -h * 0.66), YELLOW, width, true)
	_shape(item, basket, Color(METAL, 0.35), ink, width)
	# Rejilla de alambre.
	for i in range(1, 6):
		var t := i / 6.0
		item.draw_line(basket[0].lerp(basket[1], t), basket[3].lerp(basket[2], t), Color(CREAM, 0.85), 1.5, true)
	for i in range(1, 3):
		var t := i / 3.0
		item.draw_line(basket[0].lerp(basket[3], t), basket[1].lerp(basket[2], t), Color(CREAM, 0.85), 1.5, true)
	# Chasis y ruedas.
	item.draw_line(xform * Vector2(-h * 0.08, -h * 0.26), xform * Vector2(-h * 0.08, -h * 0.07), ink, width + 1.0, true)
	item.draw_line(xform * Vector2(-h * 0.7, -h * 0.26), xform * Vector2(-h * 0.66, -h * 0.07), ink, width + 1.0, true)
	item.draw_line(xform * Vector2(-h * 0.7, -h * 0.07), xform * Vector2(-h * 0.04, -h * 0.07), ink, width + 1.0, true)
	for x: float in [-0.64, -0.1]:
		var hub := xform * Vector2(h * x, -h * 0.05)
		item.draw_circle(hub, h * 0.05, INK)
		item.draw_circle(hub, h * 0.025, METAL)
		item.draw_line(hub, hub + Vector2.from_angle(spin) * h * 0.045, METAL, 1.5)
	# Cartel de la tienda en el frente del canasto.
	var plate := Rect2(basket[0].lerp(basket[3], 0.35) + Vector2(h * 0.1, 0.0), Vector2(h * 0.34, h * 0.13))
	_rect(item, plate, FreneticPalette.SKY, ink, width - 1.0)
	_letter_u(item, plate.get_center(), h * 0.05, ink)


# --- Guardia: gorra con placa, banda reflectante y radio ---------------------------------

static func _guard(enemy: Enemy, rect: Rect2, ink: Color, width: float) -> void:
	var h := rect.size.y
	# Banda reflectante cruzada.
	var band := PackedVector2Array([at(rect, 0.5, 0.86), at(rect, 0.62, 0.88), at(rect, 0.8, 0.2), at(rect, 0.68, 0.16)])
	_shape(enemy, band, YELLOW, ink, width)
	for i in range(1, 4):
		var t := i / 4.0
		var a := band[0].lerp(band[3], t)
		var b := band[1].lerp(band[2], t)
		enemy.draw_line(a, a.lerp(b, 0.85), Color(INK, 0.8), maxf(h * 0.03, 3.0))
	# Placa con estrella.
	var badge := at(rect, 0.46, 0.3)
	_star(enemy, badge, h * 0.07, h * 0.035, 5, Color("e8c15a"), ink, width - 1.0)
	# Radio colgando del cinturón (se balancea).
	var hook := at(rect, 0.62, 0.3)
	var radio := Transform2D(_sway(enemy, 0.15), hook)
	enemy.draw_line(radio * Vector2(h * 0.02, -h * 0.02), radio * Vector2(h * 0.02, -h * 0.12), ink, 2.0)
	_shape(enemy, radio * PackedVector2Array([Vector2(-h * 0.03, 0.0), Vector2(h * 0.05, 0.0),
			Vector2(h * 0.05, h * 0.14), Vector2(-h * 0.03, h * 0.14)]), NAVY_DARK, ink, width - 1.0)
	enemy.draw_circle(radio * Vector2(h * 0.01, h * 0.04), h * 0.012,
			Color("ff5a4a") if Conductor.pulse(6.0) > 0.5 else Color("5a1a1a"))
	# Gorra de guardia (plato alto con visera y placa).
	var top := at(rect, 0.58, 0.9)
	var w := rect.size.x * 0.46
	var crown := PackedVector2Array([top + Vector2(-w * 0.55, -h * 0.02), top + Vector2(-w * 0.62, -h * 0.13),
			top + Vector2(w * 0.55, -h * 0.17), top + Vector2(w * 0.5, -h * 0.02)])
	_shape(enemy, crown, NAVY, ink, width)
	_rect(enemy, Rect2(top + Vector2(-w * 0.52, -h * 0.05), Vector2(w * 1.02, h * 0.05)), INK, ink, 1.0)
	var brim := PackedVector2Array([top + Vector2(-w * 0.5, -h * 0.01), top + Vector2(-w * 0.95, h * 0.03),
			top + Vector2(-w * 0.85, h * 0.07), top + Vector2(-w * 0.2, h * 0.02)])
	_shape(enemy, brim, INK, ink, 1.0)
	_star(enemy, top + Vector2(-w * 0.1, -h * 0.1), h * 0.035, h * 0.018, 5, Color("e8c15a"), ink, 1.5)


static func _star(item: CanvasItem, center: Vector2, outer: float, inner: float, tips: int, fill: Color, ink: Color,
		width: float) -> void:
	var points := PackedVector2Array()
	for i in tips * 2:
		var angle := -PI * 0.5 + PI * i / tips
		points.append(center + Vector2.from_angle(angle) * (outer if i % 2 == 0 else inner))
	_shape(item, points, fill, ink, maxf(width, 1.5))


# --- Promotora de degustación: delantal y bandeja con muestras ---------------------------

static func _promoter(enemy: Enemy, rect: Rect2, ink: Color, width: float) -> void:
	var h := rect.size.y
	var font := MenuStyle.font()
	# Delantal crema sobre la mitad de abajo, con bolsillo.
	var apron := PackedVector2Array([at(rect, 0.4, 0.5), at(rect, 0.74, 0.52), at(rect, 0.8, 0.06), at(rect, 0.36, 0.05)])
	_shape(enemy, apron, CREAM, ink, width)
	enemy.draw_line(apron[0], at(rect, 0.47, 0.68), ink, 2.0)
	enemy.draw_line(apron[1], at(rect, 0.7, 0.72), ink, 2.0)
	var pocket := Rect2(at(rect, 0.48, 0.3), Vector2(rect.size.x * 0.22, h * 0.12))
	enemy.draw_rect(pocket, Color(ink, 0.6), false, 2.0)
	var size := int(h * 0.11)
	var label := "PRUEBE"
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	enemy.draw_string(font, Vector2(lerpf(apron[0].x, apron[1].x, 0.5) - text_width * 0.5, at(rect, 0.0, 0.36).y),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, FreneticPalette.SKY)
	# Bandeja adelante con vasitos de muestra y el cartel "GRATIS" en un palito.
	var tray_y := at(rect, 0.0, 0.42).y + _sway(enemy, 2.0)
	var tray := Rect2(Vector2(at(rect, -0.12, 0.0).x, tray_y), Vector2(rect.size.x * 0.42, h * 0.04))
	enemy.draw_line(at(rect, 0.3, 0.38), Vector2(tray.end.x - 4.0, tray.get_center().y), ink, width + 1.0, true)
	for i in 3:
		var cup := Vector2(tray.position.x + tray.size.x * (0.2 + i * 0.28), tray.position.y)
		_shape(enemy, PackedVector2Array([cup + Vector2(-h * 0.035, -h * 0.07), cup + Vector2(h * 0.035, -h * 0.07),
				cup + Vector2(h * 0.025, 0.0), cup + Vector2(-h * 0.025, 0.0)]), CREAM, ink, 1.5)
		enemy.draw_line(cup + Vector2(-h * 0.01, -h * 0.07), cup + Vector2(h * 0.005, -h * 0.13), Color("f2c14e"), 3.0)
	_rect(enemy, tray, METAL, ink, width - 1.0)
	var stick := Vector2(tray.position.x + 3.0, tray.position.y)
	enemy.draw_line(stick, stick + Vector2(0.0, -h * 0.3), ink, 2.0)
	var flag := Rect2(stick + Vector2(-h * 0.02, -h * 0.34), Vector2(h * 0.36, h * 0.12))
	_rect(enemy, flag, YELLOW, ink, width - 1.0)
	var flag_size := int(h * 0.1)
	var flag_text := "GRATIS"
	var flag_width := font.get_string_size(flag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, flag_size).x
	enemy.draw_string(font, Vector2(flag.get_center().x - flag_width * 0.5, flag.end.y - flag.size.y * 0.2), flag_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, flag_size, INK)


# --- Globos de oferta ---------------------------------------------------------------------

static func _balloons(enemy: Enemy, rect: Rect2, ink: Color, width: float) -> void:
	var h := rect.size.y
	var knot := at(rect, 0.66, 0.9)
	var bob := Conductor.pulse(8.0) * h * 0.06
	# A punto de explotar se inflan y titilan en rojo.
	var balloon := enemy as BalloonEnemy
	var armed := balloon != null and balloon.is_armed()
	var swell := 1.0 + (0.45 * balloon.arm_progress() if armed else 0.0)
	var flash := armed and Conductor.pulse(4.0) > 0.4
	var offsets: Array[Vector2] = [Vector2(-0.42, -1.05), Vector2(0.05, -1.3), Vector2(0.45, -0.98)]
	var font := MenuStyle.font()
	for i in offsets.size():
		var sway := _sway(enemy, h * 0.08) * (1.0 if i % 2 == 0 else -1.0)
		var center := knot + Vector2(offsets[i].x * h + sway, offsets[i].y * h - bob)
		var radius := h * (0.3 if i == 1 else 0.24) * swell
		enemy.draw_line(knot, center + Vector2(0.0, radius * 1.15), Color(ink, 0.9), 1.5, true)
		var shape := PackedVector2Array()
		for k in 20:
			var angle := TAU * k / 20.0
			shape.append(center + Vector2(cos(angle) * radius * 0.86, sin(angle) * radius * (1.12 if sin(angle) > 0.0 else 1.0)))
		_shape(enemy, shape, Color("ff5a4a") if flash else BALLOONS[i], ink, width)
		_shape(enemy, PackedVector2Array([center + Vector2(-radius * 0.12, radius * 1.1), center + Vector2(radius * 0.12, radius * 1.1),
				center + Vector2(0.0, radius * 1.22)]), BALLOONS[i].darkened(0.2), ink, 1.5)
		enemy.draw_circle(center + Vector2(-radius * 0.35, -radius * 0.4), radius * 0.14, Color(1.0, 1.0, 1.0, 0.7))
		if i == 1:
			var size := int(radius * 1.1)
			var width_text := font.get_string_size("%", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			enemy.draw_string(font, center + Vector2(-width_text * 0.5, radius * 0.38), "%", HORIZONTAL_ALIGNMENT_LEFT, -1,
					size, FreneticPalette.SKY)


## Etiqueta de oferta (estrella amarilla con "-50%").
static func _sale_sticker(enemy: Enemy, rect: Rect2, where: Vector2, size: float, ink: Color, width: float) -> void:
	var h := rect.size.y
	var center := at(rect, where.x, where.y)
	var r := h * size
	_star(enemy, center, r, r * 0.78, 12, YELLOW, ink, width - 1.0)
	var font := MenuStyle.font()
	var text_size := int(r * 0.85)
	var label := "-50%"
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	enemy.draw_string(font, center + Vector2(-text_width * 0.5, text_size * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			text_size, FreneticPalette.SKY)
