extends Control
## Commission rooms on the capital ship. This is the headquarters.
## The walkable decks replace this board in the next phase.

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
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var ship_name := String(GameState.ship.get("name", "Aether"))
	root.add_child(UiStyle.label(ship_name.to_upper() + "  ·  HEADQUARTERS", 24, UiStyle.ACCENT))
	root.add_child(UiStyle.label("The ship is your only base. Credits commission a room. You will walk these decks later. %d credits." % Inventory.credits, 13, UiStyle.MUTED))
	var rooms: Dictionary = GameState.ship.get("rooms", {})
	for room_id in ["bridge", "cargo", "med_bay", "armory", "research_lab", "crew_quarters", "galaxy_map"]:
		if not rooms.has(room_id):
			continue
		root.add_child(_room_row(room_id, rooms[room_id]))
	var close := UiStyle.button("Leave the ramp")
	close.pressed.connect(func(): EventBus.open_panel.emit("close"))
	root.add_child(close)


func _room_row(room_id: String, room: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var unlocked := bool(room.get("unlocked", false))
	var state := "ONLINE" if unlocked else "%d cr" % int(room.get("cost", 0))
	var label := UiStyle.label("%s  —  %s\n%s" % [room.get("name", room_id), state, room.get("blurb", "")], 14, UiStyle.INK if unlocked else UiStyle.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	if not unlocked:
		var button := Button.new()
		button.text = "Commission"
		button.pressed.connect(func():
			if GameState.try_unlock_room(room_id):
				refresh()
		)
		row.add_child(button)
	return row
