extends Node
## Vista previa de las papas vestidas de Bienestar U: cada enemigo sin vestir, vestido, atacando y
## usando su habilidad (compras en el piso, carrito lanzado, muestras en llamas y fuego, globos a
## punto de explotar), sobre el rojo del cielo y el azul de un interior. Guarda una captura y sale.
## Ejecutar con ventana (headless no dibuja):
##   godot --path . --quit-after 600 res://tests/test_scenes/costume_preview.tscn -- --out=/ruta/vista.png
## Sin `--out` se queda abierta para mirarla.

const COLUMN := 300.0
const ROW := 300.0
const SCALE := 1.35
const ROWS: Array[String] = ["SIN VESTIR", "VESTIDO", "ATAQUE", "HABILIDAD"]
const SIZE := Vector2i(1640, 1120)
const NAMES := {
	&"cliente": "COMÚN · CLIENTE",
	&"reponedor": "EMBESTIDORA · REPONEDOR",
	&"guardia": "TANQUE · GUARDIA",
	&"promotora": "TIRADORA · PROMOTORA",
	&"globos": "VOLADORA · GLOBOS",
}

var _out := ""
var _frames := 0
## Se dibuja en un viewport de tamaño fijo: la captura no depende de la ventana.
var _viewport := SubViewport.new()
var _canvas := Node2D.new()


func _ready() -> void:
	Settings.use_defaults()
	Conductor.params.metronome_enabled = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container := SubViewportContainer.new()
	add_child(container)
	container.add_child(_viewport)
	_backdrop(Rect2(Vector2.ZERO, SIZE), FreneticPalette.SKY)
	# Mitad de abajo: interior (como se verían en el supermercado).
	var split := 70.0 + ROW * 1.86 * 0.86
	_backdrop(Rect2(0.0, split, SIZE.x, SIZE.y - split), FreneticPalette.NAVY)
	_viewport.add_child(_canvas)
	var style: ArtStyle = load("res://src/shared/resources/presets/estilo/default.tres")
	var params := CombatParams.new()
	var rng := RandomNumberGenerator.new()
	var column := 0
	for costume: StringName in EnemyCostume.COSTUMES:
		var x := 210.0 + column * COLUMN + (60.0 if column > 0 else 0.0)
		_label(NAMES[costume], Vector2(x - COLUMN * 0.5 + 10.0, 14.0), COLUMN - 20.0)
		for row in ROWS.size():
			var enemy := EnemyRoster.make(EnemyCostume.COSTUMES[costume], params, rng, row > 0)
			enemy.style = style
			enemy.position = Vector2(x, 70.0 + ROW * (row + 0.78) * 0.86)
			enemy.scale = Vector2.ONE * SCALE
			_canvas.add_child(enemy)
			enemy.set_physics_process(false)
			enemy.scale = Vector2.ONE * SCALE
			_pose(enemy, row, style)
		column += 1
	for row in ROWS.size():
		_label(ROWS[row], Vector2(8.0, 70.0 + ROW * (row + 0.3) * 0.86), 110.0)


func _pose(enemy: Enemy, row: int, style: ArtStyle) -> void:
	match row:
		2:
			# Pose de ataque: un objetivo cerca (la embestidora además cargando).
			var dummy := Node2D.new()
			dummy.position = enemy.position + Vector2(-60.0, 0.0)
			_canvas.add_child(dummy)
			enemy.target = dummy
			if enemy is ChargerEnemy:
				(enemy as ChargerEnemy).state = ChargerEnemy.State.CHARGE
			if enemy is ThrowerEnemy:
				(enemy as ThrowerEnemy).current_pattern = &"negra"
			if enemy is FlyingEnemy:
				enemy.set(&"_awake", true)
		3:
			_ability(enemy, style)


func _ability(enemy: Enemy, style: ArtStyle) -> void:
	if enemy is ShopperEnemy:
		# Murió: quedan sus compras en el piso.
		enemy.visible = false
		var hazards := FloorHazards.new()
		hazards.style = style
		_canvas.add_child(hazards)
		hazards.add_spill(enemy.global_position, 99999.0)
	elif enemy is StockerEnemy:
		# Ya lanzó el carrito y se lanza detrás.
		var stocker := enemy as StockerEnemy
		stocker.has_cart = false
		stocker.state = ChargerEnemy.State.CHARGE
		var cart := ShoppingCart.new()
		cart.direction = -1.0
		cart.style = style
		cart.position = enemy.position + Vector2(-90.0, 0.0)
		cart.scale = Vector2.ONE * SCALE
		_canvas.add_child(cart)
		cart.set_physics_process(false)
	elif enemy is PromoterEnemy:
		(enemy as ThrowerEnemy).current_pattern = &"negra"
		var sample := PotatoProjectile.new()
		sample.flaming = true
		sample.style = style
		sample.velocity = Vector2(-300.0, -150.0)
		sample.position = enemy.position + Vector2(-110.0, -150.0)
		sample.scale = Vector2.ONE * SCALE
		_canvas.add_child(sample)
		sample.set_physics_process(false)
		var hazards := FloorHazards.new()
		hazards.style = style
		_canvas.add_child(hazards)
		hazards.add_fire(enemy.global_position + Vector2(-150.0, 0.0), 99999.0)
	elif enemy is BalloonEnemy:
		enemy.set(&"_fuse_total", 1.0)
		enemy.set(&"_fuse_left", 0.3)


func _label(text: String, at: Vector2, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", MenuStyle.font())
	label.add_theme_font_size_override(&"font_size", 26)
	label.add_theme_color_override(&"font_color", MenuStyle.CREAM)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_color_override(&"font_outline_color", MenuStyle.INK)
	_viewport.add_child(label)


func _backdrop(rect: Rect2, color: Color) -> void:
	var back := ColorRect.new()
	back.color = color
	back.position = rect.position
	back.size = rect.size
	_viewport.add_child(back)


func _process(_delta: float) -> void:
	# El escalado del golpe y el latido se reponen solos; se fija la escala de la vista previa.
	for child in _canvas.get_children():
		if child is Enemy:
			child.scale = Vector2.ONE * SCALE
	_frames += 1
	if _out != "" and _frames == 20:
		_viewport.get_texture().get_image().save_png(_out)
		get_tree().quit()
