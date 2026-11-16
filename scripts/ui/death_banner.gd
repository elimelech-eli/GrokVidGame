extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_died.connect(func(): visible = true)
	var panel := UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -120
	panel.offset_bottom = 120
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiStyle.label("SIGNAL LOST", 28, UiStyle.HEALTH))
	box.add_child(UiStyle.label("The surveyor is down.", 14, UiStyle.MUTED))
	var retry := UiStyle.button("Retry drop")
	retry.pressed.connect(func(): EventBus.request_retry.emit())
	box.add_child(retry)
	var menu := UiStyle.button("Main menu")
	menu.pressed.connect(func(): EventBus.request_menu.emit())
	box.add_child(menu)
