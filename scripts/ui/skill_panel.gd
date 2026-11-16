extends Control

const SkillCatalog = preload("res://scripts/rpg/skill_catalog.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("skills"):
		return
	if GameState.phase == GameState.Phase.MENU:
		return
	EventBus.open_panel.emit("close" if visible else "skills")
	get_viewport().set_input_as_handled()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	var panel := UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48
	panel.offset_top = 36
	panel.offset_right = -48
	panel.offset_bottom = -36
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var points := int(GameState.progression.get("skill_points", 0))
	var level := int(GameState.progression.get("level", 1))
	root.add_child(UiStyle.label("SKILLS    Lv %d    %d point%s" % [level, points, "" if points == 1 else "s"], 26, UiStyle.ACCENT))
	root.add_child(UiStyle.label("Piloting and Persuasion feed the capital ship and later crew. They do nothing on the ground yet.", 13, UiStyle.MUTED))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	for branch in SkillCatalog.branches():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		columns.add_child(col)
		col.add_child(UiStyle.label(String(branch).to_upper(), 16, UiStyle.AMBER))
		for skill in SkillCatalog.in_branch(String(branch)):
			col.add_child(_skill_button(skill))
	var close := UiStyle.button("Close")
	close.pressed.connect(func(): EventBus.open_panel.emit("close"))
	root.add_child(close)


func _skill_button(skill: Dictionary) -> Button:
	var id := String(skill["id"])
	var rank := GameState.skill_rank(id)
	var max_rank := int(skill["max_rank"])
	var kind := "Active" if skill["kind"] == "active" else "Passive"
	var button := Button.new()
	button.text = "%s  %s  %d/%d\n%s" % [kind, skill["name"], rank, max_rank, skill["desc"]]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 72)
	button.disabled = rank >= max_rank or int(GameState.progression.get("skill_points", 0)) < 1
	button.pressed.connect(func():
		if GameState.try_buy_skill(id):
			refresh()
	)
	return button
