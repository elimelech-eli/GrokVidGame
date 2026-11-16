extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("quests"):
		return
	if GameState.phase == GameState.Phase.MENU:
		return
	EventBus.open_panel.emit("close" if visible else "quests")
	get_viewport().set_input_as_handled()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	var panel := UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -220
	panel.offset_bottom = 220
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(UiStyle.label("QUESTS", 24, UiStyle.ACCENT))
	for id in GameState.quests.keys():
		var quest: Dictionary = GameState.quests[id]
		var state := String(quest.get("state", "active")).to_upper()
		var extra := ""
		if quest.has("have"):
			extra = "  %d/%d" % [int(quest.get("have", 0)), int(quest.get("need", 0))]
		root.add_child(UiStyle.label("%s  %s%s\n%s" % [state, quest.get("title", id), extra, quest.get("detail", "")], 15, UiStyle.INK if state == "ACTIVE" else UiStyle.MUTED))
	var close := UiStyle.button("Close")
	close.pressed.connect(func(): EventBus.open_panel.emit("close"))
	root.add_child(close)
