class_name SettingsScreen
extends PsdScreen
## Pantalla de configuración (no hay PSD: se dibuja en código con MenuStyle, en coordenadas del
## diseño 1440×1024). Pestañas AUDIO, VIDEO, CONTROLS, GAME y DIFFICULTY; cada opción es una
## SettingsRow que lee y escribe en `Settings` y lo aplica al instante. Se abre desde START y
## desde la pausa; BACK o Esc emiten `action(&"volver")`. Q/E cambian de pestaña.

const TABS: Array[String] = ["AUDIO", "VIDEO", "CONTROLS", "GAME", "DIFFICULTY"]
const TAB_SIZE := Vector2(196.0, 52.0)
const TAB_GAP := 14.0
const TAB_Y := 206.0
const PANEL := Rect2(202.0, 292.0, 1036.0, 520.0)
const BACK_BUTTON := Rect2(438.0, 902.0, 278.0, 58.0)
const DEFAULTS_BUTTON := Rect2(725.0, 902.0, 281.0, 58.0)
const STYLE_NAMES: Array[String] = ["Level's own", "Default", "Pixel", "Isaac"]
const FPS_NAMES: Array[String] = ["Unlimited", "30", "60", "120", "144", "240"]
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Normal", "Hard"]

var tab := 0
var _tabs: Array[DrawnButton] = []
var _rows: VBoxContainer
var _art: SettingsArt


func _init(background: Color = PsdScreen.BACKDROP) -> void:
	super("", background)
	escape_action = &"volver"
	_art = SettingsArt.new()
	_art.screen = self
	add_art(_art)
	for i in TABS.size():
		var button: DrawnButton = DrawnButton.new(TABS[i])
		button.position = Vector2(PANEL.position.x + i * (TAB_SIZE.x + TAB_GAP), TAB_Y)
		button.size = TAB_SIZE
		button.pressed.connect(show_tab.bind(i))
		add_control(button)
		_tabs.append(button)
	_rows = VBoxContainer.new()
	_rows.position = PANEL.position + Vector2(20.0, 22.0)
	_rows.size = Vector2(PANEL.size.x - 40.0, PANEL.size.y - 44.0)
	_rows.add_theme_constant_override("separation", 6)
	add_control(_rows)
	var back: DrawnButton = DrawnButton.new("BACK")
	back.position = BACK_BUTTON.position
	back.size = BACK_BUTTON.size
	back.pressed.connect(func() -> void: action.emit(&"volver"))
	add_control(back)
	var defaults: DrawnButton = DrawnButton.new("DEFAULTS", MenuStyle.YELLOW, MenuStyle.INK)
	defaults.position = DEFAULTS_BUTTON.position
	defaults.size = DEFAULTS_BUTTON.size
	defaults.pressed.connect(_reset_tab)
	add_control(defaults)
	show_tab(0)


## El foco empieza en la primera opción de la pestaña.
func focus_first() -> void:
	var first := first_row()
	if first != null:
		first.grab_focus()


func first_row() -> SettingsRow:
	return _rows.get_child(0) as SettingsRow if _rows.get_child_count() > 0 else null


func rows() -> Array[SettingsRow]:
	var out: Array[SettingsRow] = []
	for child in _rows.get_children():
		if child is SettingsRow and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Texto de ayuda de la opción con foco (o vacío).
func focused_help() -> String:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return focused.help if focused is SettingsRow else ""


func show_tab(index: int) -> void:
	tab = posmod(index, TABS.size())
	for i in _tabs.size():
		_tabs[i].selected = i == tab
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row in _build_rows(TABS[tab]):
		row.value_changed.connect(Settings.commit)
		row.key_chosen.connect(_on_key_chosen)
		_rows.add_child(row)
	_link_focus()


## Arriba/abajo recorren pestaña → opciones → botones; las filas usan ←/→ para su valor.
func _link_focus() -> void:
	var list := rows()
	var tab_button := _tabs[tab]
	for button in _tabs:
		button.focus_neighbor_bottom = button.get_path_to(list[0]) if not list.is_empty() else NodePath()
	for i in list.size():
		var row := list[i]
		row.focus_neighbor_top = row.get_path_to(list[i - 1] if i > 0 else tab_button)
		row.focus_neighbor_bottom = row.get_path_to(list[i + 1]) if i + 1 < list.size() else NodePath()
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row)


func _build_rows(name: String) -> Array[SettingsRow]:
	var s := Settings
	var out: Array[SettingsRow] = []
	match name:
		"AUDIO":
			out.append(SettingsRow.slider("Master volume", func() -> float: return s.master_volume,
					func(v: float) -> void: s.master_volume = v).with_help("Volume of everything."))
			out.append(SettingsRow.slider("Music", func() -> float: return s.music_volume,
					func(v: float) -> void: s.music_volume = v).with_help("Volume of the songs."))
			out.append(SettingsRow.slider("Effects", func() -> float: return s.sfx_volume,
					func(v: float) -> void: s.sfx_volume = v)
					.with_help("Hits, stomps, damage, misses and the metronome."))
			out.append(SettingsRow.toggle("Mute all", func() -> bool: return s.muted,
					func(v: bool) -> void: s.muted = v).with_help("Silence the game without losing the volumes."))
		"VIDEO":
			out.append(SettingsRow.toggle("Fullscreen", func() -> bool: return s.fullscreen,
					func(v: bool) -> void: s.fullscreen = v))
			out.append(SettingsRow.toggle("VSync", func() -> bool: return s.vsync,
					func(v: bool) -> void: s.vsync = v).with_help("Avoids tearing. Turn off for lower input delay."))
			out.append(SettingsRow.choice("FPS limit", FPS_NAMES,
					func() -> int: return maxi(GameSettings.FPS_LIMITS.find(s.fps_limit), 0),
					func(i: int) -> void: s.fps_limit = GameSettings.FPS_LIMITS[i])
					.with_help("Maximum frames per second (with VSync on, the screen also limits it)."))
		"CONTROLS":
			for pair in GameSettings.ACTIONS:
				var action_name: StringName = pair[0]
				out.append(SettingsRow.keys(pair[1], action_name,
						func() -> Array: return s.bindings[action_name])
						.with_help("Enter or click a key box, then press the new key. Esc cancels, Backspace clears."))
		"GAME":
			out.append(SettingsRow.choice("Graphic style", STYLE_NAMES,
					func() -> int: return maxi(GameSettings.STYLES.find(s.style), 0),
					func(i: int) -> void: s.style = GameSettings.STYLES[i])
					.with_help("\"Level's own\" keeps the look each level was designed with."))
			out.append(SettingsRow.slider("Screen shake", func() -> float: return s.screen_shake,
					func(v: float) -> void: s.screen_shake = v).with_help("Camera shake and zoom on hits and heat."))
			out.append(SettingsRow.slider("Rhythm offset", func() -> float: return s.input_offset_ms,
					func(v: float) -> void: s.input_offset_ms = roundi(v), -200.0, 200.0, 5.0,
					func(v: float) -> String: return "%+d ms" % roundi(v))
					.with_help("If your hits are judged late, move it to +. If early, to −."))
		"DIFFICULTY":
			out.append(SettingsRow.choice("Difficulty", DIFFICULTY_NAMES,
					func() -> int: return maxi(GameSettings.DIFFICULTIES.find(s.difficulty), 0),
					func(i: int) -> void: s.difficulty = GameSettings.DIFFICULTIES[i])
					.with_help("Applies right away, also in the middle of a level."))
	return out


func _on_key_chosen(action_name: StringName, slot: int, keycode: int) -> void:
	if keycode == KEY_NONE:
		Settings.clear_key(action_name, slot)
	else:
		Settings.bind_key(action_name, slot, keycode)


## DEFAULTS: vuelve a los valores por defecto solo las opciones de esta pestaña.
func _reset_tab() -> void:
	var fresh: GameSettings = GameSettings.new()
	fresh._default_bindings = Settings._default_bindings
	fresh._reset_values()
	var s := Settings
	match TABS[tab]:
		"AUDIO":
			s.master_volume = fresh.master_volume
			s.music_volume = fresh.music_volume
			s.sfx_volume = fresh.sfx_volume
			s.muted = fresh.muted
		"VIDEO":
			s.fullscreen = fresh.fullscreen
			s.vsync = fresh.vsync
			s.fps_limit = fresh.fps_limit
		"CONTROLS":
			s.bindings = fresh.bindings
		"GAME":
			s.style = fresh.style
			s.screen_shake = fresh.screen_shake
			s.input_offset_ms = fresh.input_offset_ms
		"DIFFICULTY":
			s.difficulty = fresh.difficulty
	fresh.free()
	s.commit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode in [KEY_Q, KEY_E]:
		get_viewport().set_input_as_handled()
		show_tab(tab + (1 if key.physical_keycode == KEY_E else -1))
		focus_first()
		return
	super(event)


## Lo fijo de la pantalla: título, panel, ayuda de la opción con foco y, en DIFFICULTY, qué
## cambia cada nivel de dificultad.
class SettingsArt extends Control:
	var screen: SettingsScreen

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var center := size.x * 0.5
		MenuStyle.text(self, "SETTINGS", Vector2(center, 160.0), 110, MenuStyle.CREAM, 16)
		MenuStyle.tag(self, Vector2(center + 250.0, 100.0), "OwO")
		MenuStyle.box(self, PANEL, MenuStyle.PANEL, 3.0)
		if TABS[screen.tab] == "DIFFICULTY":
			_draw_difficulty()
		MenuStyle.text(self, screen.focused_help(), Vector2(center, 858.0), 26, Color(MenuStyle.CREAM, 0.85))
		MenuStyle.text(self, "Q / E  change tab     ←/→  change value     Esc  back", Vector2(center, 1000.0), 22,
				Color(MenuStyle.CREAM, 0.5))

	## Tabla con lo que cambia la dificultad elegida respecto de Normal.
	func _draw_difficulty() -> void:
		var factors: Dictionary = GameSettings.DIFFICULTY[Settings.difficulty]
		var lines := [
			["Heat you gain", factors["heat"], false],
			["Fuse before exploding", factors["fuse"], true],
			["PERFECT / GOOD timing windows", factors["windows"], true],
			["Potato speed", factors["enemy_speed"], false],
		]
		var top := PANEL.position.y + 120.0
		for i in lines.size():
			var row := Rect2(PANEL.position.x + 60.0, top + i * 58.0, PANEL.size.x - 120.0, 50.0)
			var factor: float = lines[i][1]
			var percent := roundi((factor - 1.0) * 100.0)
			var easier: bool = (factor > 1.0) == lines[i][2]
			var color := MenuStyle.CREAM if percent == 0 else (MenuStyle.YELLOW if easier else MenuStyle.TAG.lightened(0.25))
			MenuStyle.text_left(self, lines[i][0], row, 28, Color(MenuStyle.CREAM, 0.85))
			var value := "same as Normal" if percent == 0 else "%+d%%" % percent
			var width := MenuStyle.font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			MenuStyle.text_left(self, value, Rect2(row.end.x - width, row.position.y, width, row.size.y), 28, color)
			draw_line(Vector2(row.position.x, row.end.y + 4.0), Vector2(row.end.x, row.end.y + 4.0),
					Color(MenuStyle.CREAM, 0.12), 2.0)
