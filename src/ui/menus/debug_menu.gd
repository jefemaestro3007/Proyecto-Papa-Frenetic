class_name DebugMenu
extends PanelContainer
## Menú de debug lateral con pestañas (una DebugSection por pestaña).

const WIDTH := 400.0


func _init() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(FreneticPalette.INK, 0.9)
	style.border_color = FreneticPalette.SKY
	style.border_width_left = 4
	style.content_margin_left = 12.0
	style.content_margin_right = 10.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)

	var tabs := TabContainer.new()
	tabs.name = "Tabs"
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	add_child(tabs)


func add_section(title: String) -> DebugSection:
	var section := DebugSection.new(title)
	get_node("Tabs").add_child(section)
	return section
