extends Control

var _list: ItemList
var _detail: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("inventory"):
		return
	if GameState.phase == GameState.Phase.MENU:
		return
	EventBus.open_panel.emit("close" if visible else "inventory")
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
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -280
	panel.offset_bottom = 280
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(UiStyle.label("INVENTORY    %d credits" % Inventory.credits, 24, UiStyle.ACCENT))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(860, 420)
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(420, 400)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_list)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	_detail = UiStyle.label("Select a piece of gear.", 14, UiStyle.INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_detail)
	var equip := UiStyle.button("Equip")
	equip.pressed.connect(_equip_selected)
	side.add_child(equip)
	side.add_child(_equipped_summary())
	for item in Inventory.items:
		var mark := ""
		if String(Inventory.equipped.get(item["slot"], "")) == String(item["uid"]):
			mark = "  [worn]"
		_list.add_item("%s  %s%s" % [String(item["rarity"]).to_upper(), item["name"], mark])
		_list.set_item_metadata(_list.item_count - 1, item["uid"])
	_list.item_selected.connect(func(idx): _show_item(idx))
	var close := UiStyle.button("Close")
	close.pressed.connect(func(): EventBus.open_panel.emit("close"))
	root.add_child(close)


func _show_item(index: int) -> void:
	var uid := String(_list.get_item_metadata(index))
	var item := Inventory.item_by_uid(uid)
	if item.is_empty():
		return
	var lines := "%s\n%s  ·  %s\n" % [item["name"], String(item["rarity"]).capitalize(), item["slot"]]
	var stats: Dictionary = item.get("stats", {})
	for stat in stats.keys():
		var spec: Dictionary = stats[stat]
		if float(spec.get("add", 0.0)) != 0.0:
			lines += "%s %+0.0f\n" % [stat, spec["add"]]
		if absf(float(spec.get("mul", 1.0)) - 1.0) > 0.001:
			lines += "%s x%0.2f\n" % [stat, spec["mul"]]
	_detail.text = lines


func _equip_selected() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return
	Inventory.equip(String(_list.get_item_metadata(selected[0])))
	refresh()


func _equipped_summary() -> Label:
	var text := "Equipped\n"
	for slot in ["weapon", "chest", "head", "mod"]:
		var item := Inventory.equipped_item(slot)
		var name := String(item.get("name", "—")) if not item.is_empty() else "—"
		text += "%s: %s\n" % [slot, name]
	var label := UiStyle.label(text, 14, UiStyle.MUTED)
	return label
