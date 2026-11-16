class_name UiStyle
extends RefCounted

const ACCENT := Color("3ee6cf")
const AMBER := Color("ff9a45")
const INK := Color(0.93, 0.96, 0.97)
const MUTED := Color(0.68, 0.76, 0.8)
const PANEL := Color(0.03, 0.05, 0.07, 0.82)
const SHIELD := Color("3ec6ff")
const HEALTH := Color("ff5a4a")


static func font(size: int) -> Font:
	var face := load("res://assets/fonts/Orbitron.ttf") as Font
	if face == null:
		return ThemeDB.fallback_font
	return face


static func label(text: String, size: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font(size))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(280, 48)
	node.add_theme_font_override("font", font(20))
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", ACCENT)
	node.add_theme_stylebox_override("normal", _box(Color(0.05, 0.08, 0.1, 0.9), Color(0.25, 0.4, 0.42)))
	node.add_theme_stylebox_override("hover", _box(Color(0.08, 0.16, 0.16, 0.95), ACCENT))
	node.add_theme_stylebox_override("pressed", _box(Color(0.12, 0.28, 0.26, 1.0), ACCENT))
	node.add_theme_stylebox_override("focus", _box(Color(0.08, 0.16, 0.16, 0.95), ACCENT))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(func(): AudioDirector.play_ui("confirmation_001"))
	node.mouse_entered.connect(func(): AudioDirector.play_ui("click_001", 0.0))
	return node


static func panel() -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", _box(PANEL, Color(ACCENT, 0.35), 18))
	return node


static func _box(fill: Color, border: Color, margin := 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(margin)
	return box
