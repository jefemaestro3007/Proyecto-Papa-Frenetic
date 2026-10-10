class_name PsdScreen
extends Control
## Pantalla de menú armada con una imagen del diseño (exportada de los PSD por
## `tools/scripts/build_menu_screens.gd`, 1440×1024) escalada para entrar en la ventana y centrada,
## sobre un fondo. Los botones son zonas en las mismas coordenadas del PSD: se resaltan al pasar
## el mouse o al elegirlos con el teclado, y Enter, Espacio, J o el clic los activan.

signal action(name: StringName)

const DESIGN_SIZE := Vector2(1440.0, 1024.0)
const TEXTURES := "res://assets/textures/ui/menu/"
## Fondo de las pantallas (el gris del diseño).
const BACKDROP := Color("222222")

var _background: ColorRect
var _canvas: Control
## Acción que dispara Esc (vacía = Esc no hace nada en esta pantalla).
var escape_action := &""
var _buttons: Array[MenuHotspot] = []


## `background` puede ser translúcido (p. ej. para mostrar el juego detrás).
func _init(texture_name: String, background: Color = BACKDROP) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background = ColorRect.new()
	_background.color = background
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_canvas = Control.new()
	_canvas.size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	add_layer(texture_name)
	resized.connect(_fit)


func _ready() -> void:
	_fit()


## Agrega una imagen encima (del mismo tamaño de diseño). Devuelve el TextureRect para animarlo.
func add_layer(texture_name: String) -> TextureRect:
	var layer := TextureRect.new()
	var path := TEXTURES + texture_name + ".png"
	if ResourceLoader.exists(path):
		layer.texture = load(path)
	layer.size = DESIGN_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(layer)
	return layer


## Zona clicable en coordenadas del PSD. La primera que se agrega toma el foco del teclado.
func add_button(rect: Rect2, action_name: StringName) -> MenuHotspot:
	var button := MenuHotspot.new()
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(func() -> void: action.emit(action_name))
	_canvas.add_child(button)
	_buttons.append(button)
	return button


## Imagen de fondo que cubre toda la ventana (recortada para no deformarse), con un velo oscuro
## encima para que se lea lo de adelante.
func set_backdrop_image(texture: Texture2D, dim: float = 0.3) -> void:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture = texture
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	move_child(image, _background.get_index() + 1)
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.0, dim)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	move_child(veil, image.get_index() + 1)


## Agrega algo dibujado en coordenadas del diseño (para pantallas que no tienen PSD).
func add_art(art: Control) -> void:
	art.size = DESIGN_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(art)


func focus_first() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if escape_action != &"" and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		action.emit(escape_action)


func _fit() -> void:
	var scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_canvas.scale = Vector2.ONE * scale
	_canvas.position = (size - DESIGN_SIZE * scale) * 0.5
