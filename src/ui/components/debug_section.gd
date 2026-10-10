class_name DebugSection
extends ScrollContainer
## Una pestaña del menú de debug: controles enlazados a propiedades de cualquier Object
## y, opcionalmente, una barra para cargar/exportar presets (.tres) de un Resource.
## Los controles no toman foco de teclado (salvo los campos de texto) para no robar teclas al juego.

signal preset_loaded(path: String)

const PRESETS_ROOT := "res://src/shared/resources/presets/"
const USER_PRESETS_ROOT := "user://presets/"

var _box: VBoxContainer
## Callables que releen el valor actual de su propiedad en el control (ver `refresh`).
var _refreshers: Array[Callable] = []


func _init(title: String) -> void:
	name = title
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)


## Vuelve a leer todas las propiedades enlazadas (tras cargar un preset, por ejemplo).
func refresh() -> void:
	for refresher in _refreshers:
		refresher.call()


func add_group(title: String) -> void:
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_color_override("font_color", FreneticPalette.YELLOW)
	label.add_theme_font_size_override("font_size", 15)
	if _box.get_child_count() > 0:
		_box.add_child(HSeparator.new())
	_box.add_child(label)


## Slider con campo numérico editable; ambos quedan sincronizados con la propiedad.
func add_slider(target: Object, property: StringName, title: String, min_value: float,
		max_value: float, step: float) -> HSlider:
	var is_int := typeof(target.get(property)) == TYPE_INT
	var slider := HSlider.new()
	var spin := SpinBox.new()
	for range_control: Range in [slider, spin]:
		range_control.min_value = min_value
		range_control.max_value = max_value
		range_control.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = "Rango: %s – %s" % [_format(min_value, step), _format(max_value, step)]
	spin.custom_minimum_size.x = 104.0
	spin.select_all_on_focus = true
	spin.get_line_edit().text_submitted.connect(func(_text: String) -> void:
		spin.get_line_edit().release_focus())

	var apply := func(value: float) -> void:
		target.set(property, int(value) if is_int else value)
	slider.value_changed.connect(func(value: float) -> void:
		spin.set_value_no_signal(value)
		apply.call(value))
	spin.value_changed.connect(func(value: float) -> void:
		slider.set_value_no_signal(value)
		apply.call(value))
	var refresher := func() -> void:
		slider.set_value_no_signal(target.get(property))
		spin.set_value_no_signal(target.get(property))
	refresher.call()
	_refreshers.append(refresher)

	_box.add_child(_labeled_row(title, spin))
	_box.add_child(slider)
	return slider


func add_color(target: Object, property: StringName, title: String) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.edit_alpha = false
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(110.0, 26.0)
	picker.color_changed.connect(func(color: Color) -> void: target.set(property, color))
	var refresher := func() -> void:
		picker.color = target.get(property)
		picker.tooltip_text = "#" + picker.color.to_html(false)
	picker.color_changed.connect(func(_color: Color) -> void: refresher.call())
	refresher.call()
	_refreshers.append(refresher)
	_box.add_child(_labeled_row(title, picker))
	return picker


func add_toggle(target: Object, property: StringName, title: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_color_override("font_color", FreneticPalette.CREAM)
	toggle.toggled.connect(func(pressed: bool) -> void: target.set(property, pressed))
	var refresher := func() -> void: toggle.set_pressed_no_signal(target.get(property))
	refresher.call()
	_refreshers.append(refresher)
	_box.add_child(toggle)
	return toggle


## `buttons`: pares [texto, Callable].
func add_buttons(buttons: Array) -> void:
	var row := HBoxContainer.new()
	for entry in buttons:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(entry[1])
		row.add_child(button)
	_box.add_child(row)


func add_text(text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", FreneticPalette.CREAM)
	label.add_theme_font_size_override("font_size", 13)
	_box.add_child(label)
	return label


## Barra de presets: lista los .tres de `presets/<folder>/` (proyecto y usuario),
## los carga sobre `target` sin reemplazarlo y exporta su estado actual con un nombre.
func add_preset_bar(target: Resource, folder: String) -> void:
	add_group("Presets")
	var list := OptionButton.new()
	list.focus_mode = Control.FOCUS_NONE
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status := add_text()
	var name_field := LineEdit.new()
	name_field.placeholder_text = "nombre_del_preset"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.text_submitted.connect(func(_text: String) -> void: name_field.release_focus())

	var rescan := func() -> void:
		list.clear()
		for path in _list_presets(folder):
			list.add_item(path.get_file().get_basename())
			list.set_item_metadata(list.item_count - 1, path)
	rescan.call()

	var load_selected := func() -> void:
		if list.selected < 0:
			return
		var path: String = list.get_item_metadata(list.selected)
		var preset := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
		if preset == null or preset.get_script() != target.get_script():
			status.text = "No se pudo cargar: " + path
			return
		copy_into(preset, target)
		refresh()
		status.text = "Cargado: " + path
		preset_loaded.emit(path)

	var export_current := func() -> void:
		var preset_name := name_field.text.strip_edges().to_snake_case().validate_filename()
		if preset_name.is_empty():
			status.text = "Escribe un nombre para el preset."
			return
		var dir := _export_dir(folder)
		DirAccess.make_dir_recursive_absolute(dir)
		var path := dir + preset_name + ".tres"
		var error := ResourceSaver.save(target.duplicate(), path)
		status.text = ("Exportado: " + path) if error == OK else ("Error %d al exportar" % error)
		rescan.call()

	var load_row := HBoxContainer.new()
	load_row.add_child(list)
	_box.add_child(load_row)
	add_buttons([["Cargar", load_selected], ["Recargar lista", rescan]])
	var export_row := HBoxContainer.new()
	export_row.add_child(name_field)
	var export_button := Button.new()
	export_button.text = "Exportar sección"
	export_button.focus_mode = Control.FOCUS_NONE
	export_button.pressed.connect(export_current)
	export_row.add_child(export_button)
	_box.add_child(export_row)
	_box.move_child(status, -1)


## Copia las variables de script guardables de `source` sobre `target` (mismo tipo).
static func copy_into(source: Resource, target: Resource) -> void:
	for property in target.get_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			target.set(property.name, source.get(property.name))


## En el editor se exporta dentro del proyecto (para versionar presets); en builds, a user://.
static func _export_dir(folder: String) -> String:
	return (PRESETS_ROOT if OS.has_feature("editor") else USER_PRESETS_ROOT) + folder + "/"


static func _list_presets(folder: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for root in [PRESETS_ROOT, USER_PRESETS_ROOT]:
		var dir: String = root + folder + "/"
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			# En builds exportados los .tres aparecen como .tres.remap.
			file = file.trim_suffix(".remap")
			if file.ends_with(".tres") and not paths.has(dir + file):
				paths.append(dir + file)
	return paths


func _labeled_row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", FreneticPalette.CREAM)
	row.add_child(label)
	row.add_child(control)
	return row


static func _format(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(value))
	var decimals := maxi(0, ceili(-log(step) / log(10.0) - 0.0001))
	return String.num(value, decimals)
