extends Control

var _settings: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func bind_settings(panel: Control) -> void:
	_settings = panel


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.02, 0.55)
	add_child(dim)
	var panel := UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -180
	panel.offset_bottom = 180
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiStyle.label("PAUSED", 28, UiStyle.ACCENT))
	var resume := UiStyle.button("Resume")
	resume.pressed.connect(func(): EventBus.request_resume.emit())
	box.add_child(resume)
	var settings := UiStyle.button("Settings")
	settings.pressed.connect(func():
		if _settings:
			_settings.show_panel()
	)
	box.add_child(settings)
	var menu := UiStyle.button("Main menu")
	menu.pressed.connect(func(): EventBus.request_menu.emit())
	box.add_child(menu)
	var quit := UiStyle.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _settings and _settings.visible:
		_settings.hide()
		get_viewport().set_input_as_handled()
		return
	if GameState.phase == GameState.Phase.PLAYING:
		EventBus.request_pause.emit()
		get_viewport().set_input_as_handled()
	elif GameState.phase == GameState.Phase.PAUSED:
		EventBus.request_resume.emit()
		get_viewport().set_input_as_handled()
