class_name PauseArt
extends Control
## Pantalla de pausa dibujada en código (no hay PSD de pausa): título y botones con la misma
## forma, colores y sombra que los de YOU LOOSE / YOU WIN (MenuStyle), en coordenadas del diseño
## (1440×1024). Los botones clicables son MenuHotspot encima de estos rectángulos (ver
## ZoneLevel.pause).

## Mismos rectángulos que BACK MENU y TRY AGAIN? en las pantallas de fin de partida.
const MENU_BUTTON := Rect2(438, 702, 278, 58)
const CONTINUE_BUTTON := Rect2(725, 700, 281, 60)
## Debajo, centrado entre los dos.
const SETTINGS_BUTTON := Rect2(581, 786, 278, 58)


func _draw() -> void:
	var center := size.x * 0.5
	MenuStyle.text(self, "PAUSE", Vector2(center, 520.0), 150, MenuStyle.CREAM, 18)
	MenuStyle.tag(self, Vector2(860.0, 560.0), "ZzZ")
	MenuStyle.button(self, MENU_BUTTON, MenuStyle.BROWN, "BACK MENU", MenuStyle.CREAM)
	MenuStyle.button(self, CONTINUE_BUTTON, MenuStyle.YELLOW, "CONTINUE", MenuStyle.INK)
	MenuStyle.button(self, SETTINGS_BUTTON, MenuStyle.CREAM, "SETTINGS", MenuStyle.INK)
	MenuStyle.text(self, "Esc para continuar", Vector2(center, 900.0), 24, Color(MenuStyle.CREAM, 0.7), 6)
