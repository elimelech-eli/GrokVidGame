extends Control

var _settings: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func bind_settings(panel: Control) -> void:
	_settings = panel


func _build() -> void:
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_wash.gdshader")
	wash.material = mat
	add_child(wash)
	var column := VBoxContainer.new()
	column.position = Vector2(72, 120)
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var kicker := UiStyle.label("VESPER-9 SURVEY", 14, UiStyle.ACCENT)
	column.add_child(kicker)
	var title := UiStyle.label("STARWAKE", 64)
	column.add_child(title)
	var sub := UiStyle.label("AETHER REACH", 22, UiStyle.AMBER)
	column.add_child(sub)
	column.add_child(UiStyle.label("Your capital ship is home. The outpost is not.", 14, UiStyle.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	column.add_child(spacer)
	if SaveGame.has_autosave():
		var cont := UiStyle.button("Continue")
		cont.pressed.connect(func():
			var data := SaveGame.read_slot("autosave")
			if data.is_empty():
				return
			SaveGame.queue(data)
			GameState.auto_start = true
			get_tree().reload_current_scene()
		)
		column.add_child(cont)
	var launch := UiStyle.button("New expedition")
	launch.pressed.connect(func(): EventBus.request_launch.emit())
	column.add_child(launch)
	var loads := UiStyle.button("Load game")
	loads.pressed.connect(func(): EventBus.open_panel.emit("saves"))
	column.add_child(loads)
	var settings := UiStyle.button("Settings")
	settings.pressed.connect(_open_settings)
	column.add_child(settings)
	var quit := UiStyle.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	column.add_child(quit)
	var footer := UiStyle.label("Phase 2  ·  the ship is headquarters", 13, UiStyle.MUTED)
	footer.position = Vector2(72, 980)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 72
	footer.offset_bottom = -36
	footer.offset_top = -64
	add_child(footer)


func _open_settings() -> void:
	if _settings:
		_settings.show_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") and _settings and _settings.visible:
		_settings.hide()
		get_viewport().set_input_as_handled()
