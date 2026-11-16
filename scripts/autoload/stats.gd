extends Node

const SkillCatalog = preload("res://scripts/rpg/skill_catalog.gd")
## Final character numbers. Level, perks, and gear add modifiers here.
## Piloting and persuasion are real stats even though their scenes arrive later.

signal changed

const BASE := {
	"max_health": 100.0,
	"max_shield": 60.0,
	"move_speed": 1.0,
	"weapon_damage": 1.0,
	"fire_rate": 1.0,
	"cooldown_rate": 1.0,
	"melee_damage": 1.0,
	"shield_regen": 16.0,
	"credits_find": 1.0,
	"loot_quality": 0.0,
	"piloting": 0.0,
	"persuasion": 0.0,
	"ship_weapon": 0.0,
	"ship_speed": 0.0,
	"follower_affinity": 0.0,
}

var _sources: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_sources.clear()
	_apply_level()
	_apply_skills()
	_apply_ship_rooms()
	if has_node("/root/Inventory"):
		_sources["gear"] = Inventory.gear_modifier_map()
	changed.emit()
	EventBus.stats_changed.emit()


func get_value(stat: String) -> float:
	var add := 0.0
	var mul := 1.0
	for source in _sources.values():
		if not source.has(stat):
			continue
		var entry: Dictionary = source[stat]
		add += float(entry.get("add", 0.0))
		mul *= float(entry.get("mul", 1.0))
	return (float(BASE.get(stat, 0.0)) + add) * mul


func set_source(source_id: String, mods: Dictionary) -> void:
	if mods.is_empty():
		_sources.erase(source_id)
	else:
		_sources[source_id] = mods
	changed.emit()
	EventBus.stats_changed.emit()


func _apply_level() -> void:
	var level := int(GameState.progression.get("level", 1))
	var ranks := maxi(level - 1, 0)
	_sources["level"] = {
		"max_health": {"add": 8.0 * ranks},
		"max_shield": {"add": 4.0 * ranks},
		"weapon_damage": {"mul": 1.0 + 0.02 * ranks},
	}


func _apply_skills() -> void:
	var ranks: Dictionary = GameState.progression.get("skills", {})
	for skill in SkillCatalog.all():
		var rank := int(ranks.get(skill["id"], 0))
		if rank <= 0:
			continue
		var mods := {}
		for bonus in skill.get("stats", []):
			var stat: String = bonus["stat"]
			var entry: Dictionary = mods.get(stat, {"add": 0.0, "mul": 1.0})
			entry["add"] = float(entry["add"]) + float(bonus.get("add", 0.0)) * rank
			entry["mul"] = float(entry["mul"]) * (1.0 + float(bonus.get("mul", 0.0)) * rank)
			mods[stat] = entry
		if not mods.is_empty():
			_sources["skill:" + skill["id"]] = mods


func _apply_ship_rooms() -> void:
	var rooms: Dictionary = GameState.ship.get("rooms", {})
	var mods := {}
	for room_id in rooms.keys():
		var room: Dictionary = rooms[room_id]
		if not bool(room.get("unlocked", false)):
			continue
		var stat := String(room.get("stat", ""))
		if stat == "":
			continue
		var entry: Dictionary = mods.get(stat, {"add": 0.0, "mul": 1.0})
		entry["add"] = float(entry["add"]) + float(room.get("add", 0.0))
		entry["mul"] = float(entry["mul"]) * (1.0 + float(room.get("mul", 0.0)))
		mods[stat] = entry
	if not mods.is_empty():
		_sources["ship_rooms"] = mods
