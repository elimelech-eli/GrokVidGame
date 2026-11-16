extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	var panel := UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -240
	panel.offset_bottom = 240
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(UiStyle.label("SAVES", 24, UiStyle.ACCENT))
	root.add_child(UiStyle.label("Three slots plus an autosave. Ship, crew, and followers are already in the file.", 13, UiStyle.MUTED))
	for i in range(1, 4):
		root.add_child(_slot_row("slot%d" % i, "Slot %d" % i, true))
	root.add_child(_slot_row("autosave", "Autosave", false))
	var close := UiStyle.button("Close")
	close.pressed.connect(func(): EventBus.open_panel.emit("close"))
	root.add_child(close)


func _slot_row(slot: String, title: String, can_save: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiStyle.label(title, 16))
	if can_save and GameState.phase != GameState.Phase.MENU:
		var save := Button.new()
		save.text = "Save"
		save.pressed.connect(func():
			if SaveGame.write_slot(slot):
				EventBus.toast.emit(title + " saved")
		)
		row.add_child(save)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.disabled = SaveGame.read_slot(slot).is_empty()
	load_button.pressed.connect(func():
		var data := SaveGame.read_slot(slot)
		if data.is_empty():
			return
		SaveGame.queue(data)
		GameState.auto_start = true
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	row.add_child(load_button)
	return row
