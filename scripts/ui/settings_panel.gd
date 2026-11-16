extends Control
## Preferences, including the mature-content stub. The toggle is saved and
## does not unlock any scenes in this phase.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func show_panel() -> void:
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	add_child(dim)
	var panel := UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -280
	panel.offset_bottom = 280
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiStyle.label("SETTINGS", 26, UiStyle.ACCENT))
	box.add_child(_slider("Mouse sensitivity", 0.0008, 0.006, Settings.mouse_sensitivity, func(v):
		Settings.mouse_sensitivity = v
	))
	box.add_child(_slider("Gamepad look", 1.0, 5.0, Settings.gamepad_sensitivity, func(v):
		Settings.gamepad_sensitivity = v
	))
	box.add_child(_check("Invert look Y", Settings.invert_y, func(v): Settings.invert_y = v))
	box.add_child(_slider("Master volume", 0.0, 1.0, Settings.master_volume, func(v):
		Settings.master_volume = v
		Settings.apply()
	))
	box.add_child(_slider("Effects", 0.0, 1.0, Settings.sfx_volume, func(v):
		Settings.sfx_volume = v
		Settings.apply()
	))
	box.add_child(_slider("Ambience", 0.0, 1.0, Settings.ambience_volume, func(v):
		Settings.ambience_volume = v
		Settings.apply()
	))
	box.add_child(_check("Fullscreen", Settings.fullscreen, func(v):
		Settings.fullscreen = v
		Settings.apply()
	))
	box.add_child(_check("Screen shake", Settings.screen_shake, func(v): Settings.screen_shake = v))
	box.add_child(_check("Mature content (18+)", Settings.mature_content, func(v): Settings.mature_content = v))
	var note := UiStyle.label("Saved for a later phase. No mature scenes are in this build.", 12, UiStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var back := UiStyle.button("Back")
	back.pressed.connect(_close)
	box.add_child(back)


func _close() -> void:
	Settings.save_settings()
	hide()


func _slider(title: String, min_v: float, max_v: float, value: float, on_change: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	var caption := UiStyle.label(title, 14, UiStyle.MUTED)
	wrap.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = (max_v - min_v) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(460, 24)
	slider.value_changed.connect(func(v):
		caption.text = "%s   %0.2f" % [title, v]
		on_change.call(v)
	)
	caption.text = "%s   %0.2f" % [title, value]
	wrap.add_child(slider)
	return wrap


func _check(title: String, value: bool, on_change: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = title
	button.button_pressed = value
	button.add_theme_font_override("font", UiStyle.font(16))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UiStyle.INK)
	button.toggled.connect(on_change)
	return button
