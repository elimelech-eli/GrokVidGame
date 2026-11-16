extends Node
## Gear, credits, and drops. Equipped items become Stats modifiers.
## The save file stores this whole bag so later phases can add cargo aboard the ship.

signal changed

var credits := 40
var items: Array = []
var equipped := {"weapon": "", "chest": "", "head": "", "mod": ""}
var _serial := 1


func _ready() -> void:
	if items.is_empty():
		reset_new_game()


func reset_new_game() -> void:
	credits = 40
	items.clear()
	equipped = {"weapon": "", "chest": "", "head": "", "mod": ""}
	_serial = 1
	var starter := make_item("rifle", "common")
	starter["name"] = "Survey Rifle"
	items.append(starter)
	equipped["weapon"] = starter["uid"]
	changed.emit()
	EventBus.inventory_changed.emit()


func capture() -> Dictionary:
	return {
		"credits": credits,
		"items": items.duplicate(true),
		"equipped": equipped.duplicate(true),
		"serial": _serial,
	}


func restore(data: Dictionary) -> void:
	credits = int(data.get("credits", 0))
	items = data.get("items", [])
	equipped = data.get("equipped", equipped)
	_serial = int(data.get("serial", items.size() + 1))
	for key in ["weapon", "chest", "head", "mod"]:
		if not equipped.has(key):
			equipped[key] = ""
	changed.emit()
	EventBus.inventory_changed.emit()


func gear_modifier_map() -> Dictionary:
	var mods := {}
	for slot in equipped.keys():
		var item := item_by_uid(String(equipped[slot]))
		if item.is_empty():
			continue
		var stats: Dictionary = item.get("stats", {})
		for stat in stats.keys():
			var spec: Dictionary = stats[stat]
			var entry: Dictionary = mods.get(stat, {"add": 0.0, "mul": 1.0})
			entry["add"] = float(entry["add"]) + float(spec.get("add", 0.0))
			entry["mul"] = float(entry["mul"]) * float(spec.get("mul", 1.0))
			mods[stat] = entry
	return mods


func item_by_uid(uid: String) -> Dictionary:
	if uid == "":
		return {}
	for item in items:
		if String(item.get("uid", "")) == uid:
			return item
	return {}


func equipped_item(slot: String) -> Dictionary:
	return item_by_uid(String(equipped.get(slot, "")))


func equipped_color(slot: String) -> Color:
	var item := equipped_item(slot)
	if item.is_empty():
		return Color("2a3340")
	return Color(String(item.get("color", "#8aa0b3")))


func add_item(item: Dictionary) -> void:
	items.append(item)
	changed.emit()
	EventBus.inventory_changed.emit()
	EventBus.toast.emit("Loot  " + String(item.get("name", "gear")))


func grant_credits(amount: int) -> void:
	var bonus := 1.0
	if has_node("/root/Stats"):
		bonus = Stats.get_value("credits_find")
	var gained := int(round(amount * bonus))
	credits += gained
	changed.emit()
	EventBus.inventory_changed.emit()
	if gained > 0:
		EventBus.toast.emit("+%d credits" % gained)


func try_spend(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	changed.emit()
	EventBus.inventory_changed.emit()
	return true


func equip(uid: String) -> void:
	var item := item_by_uid(uid)
	if item.is_empty():
		return
	var slot := String(item.get("slot", ""))
	if slot == "" or not equipped.has(slot):
		return
	equipped[slot] = uid
	changed.emit()
	EventBus.inventory_changed.emit()
	if has_node("/root/Stats"):
		Stats.rebuild()


func make_item(template: String, rarity: String) -> Dictionary:
	var spec := _template(template)
	var band := _rarity_band(rarity)
	var stats := {}
	for stat in spec["stats"].keys():
		var base: Dictionary = spec["stats"][stat]
		var rolled := {
			"add": float(base.get("add", 0.0)) * band,
			"mul": 1.0 + (float(base.get("mul", 1.0)) - 1.0) * band,
		}
		stats[stat] = rolled
	_serial += 1
	return {
		"uid": "item_%d" % _serial,
		"template": template,
		"name": "%s %s" % [_rarity_name(rarity), spec["name"]],
		"kind": spec["kind"],
		"slot": spec["slot"],
		"rarity": rarity,
		"stats": stats,
		"color": spec["color"],
	}


func roll_drop(bias: String) -> Dictionary:
	var quality := 0.0
	if has_node("/root/Stats"):
		quality = Stats.get_value("loot_quality")
	var roll := randf() - clampf(quality, 0.0, 0.6) * 0.15
	var rarity := "common"
	if roll > 0.97:
		rarity = "epic"
	elif roll > 0.86:
		rarity = "rare"
	elif roll > 0.62:
		rarity = "uncommon"
	var pool: Array = _pool(bias)
	var template: String = pool[randi() % pool.size()]
	return make_item(template, rarity)


func drop_in_world(at: Vector3, bias: String) -> void:
	var item := roll_drop(bias)
	var credits_n := randi_range(6, 18) * _rarity_credits(String(item["rarity"]))
	var pickup := Area3D.new()
	pickup.set_script(load("res://scripts/rpg/loot_pickup.gd"))
	var host := get_tree().current_scene
	if host:
		host.add_child(pickup)
	pickup.setup(item, credits_n, at + Vector3(0, 0.4, 0))


func _pool(bias: String) -> Array:
	match bias:
		"weapon":
			return ["rifle", "scatter", "rifle"]
		"armor":
			return ["vest", "helm", "vest"]
		"tech":
			return ["capacitor", "scope", "helm"]
		_:
			return ["rifle", "scatter", "vest", "helm", "capacitor", "scope"]


func _template(id: String) -> Dictionary:
	match id:
		"scatter":
			return {"name": "Scattergun", "kind": "weapon", "slot": "weapon", "color": "#e3a15a", "stats": {"weapon_damage": {"mul": 1.18}, "fire_rate": {"mul": 0.86}}}
		"vest":
			return {"name": "Plated Vest", "kind": "armor", "slot": "chest", "color": "#3d4c5c", "stats": {"max_health": {"add": 12.0}}}
		"helm":
			return {"name": "Survey Helm", "kind": "armor", "slot": "head", "color": "#7d8c9a", "stats": {"max_shield": {"add": 10.0}}}
		"capacitor":
			return {"name": "Capacitor", "kind": "mod", "slot": "mod", "color": "#3ee6cf", "stats": {"cooldown_rate": {"mul": 1.1}}}
		"scope":
			return {"name": "Coil Sight", "kind": "mod", "slot": "mod", "color": "#8ec6ff", "stats": {"weapon_damage": {"mul": 1.08}}}
		_:
			return {"name": "Carbine", "kind": "weapon", "slot": "weapon", "color": "#9ad7ff", "stats": {"weapon_damage": {"mul": 1.1}, "fire_rate": {"mul": 1.04}}}


func _rarity_band(rarity: String) -> float:
	match rarity:
		"uncommon":
			return 1.15
		"rare":
			return 1.35
		"epic":
			return 1.6
		_:
			return 1.0


func _rarity_credits(rarity: String) -> int:
	match rarity:
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 5
		_:
			return 1


func _rarity_name(rarity: String) -> String:
	return rarity.capitalize()
