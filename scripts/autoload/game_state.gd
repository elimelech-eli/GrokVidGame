extends Node

const SkillCatalog = preload("res://scripts/rpg/skill_catalog.gd")
## Session state. The capital ship is the headquarters: rooms, crew, and
## followers live on GameState.ship / crew / followers. There is no ground base.

enum Phase { MENU, PLAYING, PAUSED, DEAD }

var phase: Phase = Phase.MENU
var zone_id := "vesper_9_aether_reach"
var world_time_scale := 1.0

var health := 100.0
var max_health := 100.0
var shield := 60.0
var max_shield := 60.0
var magazine := 30
var reserve := 120
var reloading := false

var progression := {}
var quests := {}
var world := {}
var ship := {}
var crew: Array = []
var followers: Array = []
var kills := 0
var auto_start := false
var pending_player: Dictionary = {}
var landmarks: Dictionary = {}


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	kills = 0
	world_time_scale = 1.0
	progression = {
		"level": 1,
		"xp": 0,
		"skill_points": 1,
		"skills": {},
	}
	quests = {
		"survey_pool": {"title": "The mineral pool", "detail": "Visit the teal pool.", "state": "active"},
		"break_camp": {"title": "Break the camp", "detail": "Drop four hostiles at the outpost.", "state": "active", "need": 4, "have": 0},
		"inspect_ship": {"title": "Your headquarters", "detail": "Use the boarding ramp on the capital ship.", "state": "active"},
	}
	world = {"dead_enemies": [], "looted": [], "discovered": []}
	ship = default_ship()
	crew = []
	followers = []
	pending_player = {}


func default_ship() -> Dictionary:
	return {
		"id": "aether_capital",
		"class": "capital",
		"name": "Aether",
		"role": "headquarters",
		"rooms": {
			"bridge": {"name": "Bridge", "unlocked": true, "cost": 0, "stat": "", "add": 0.0, "mul": 0.0, "blurb": "Helm and pilot station."},
			"cargo": {"name": "Cargo", "unlocked": true, "cost": 0, "stat": "credits_find", "add": 0.0, "mul": 0.1, "blurb": "Hold and trade. Already online."},
			"med_bay": {"name": "Med bay", "unlocked": false, "cost": 80, "stat": "shield_regen", "add": 6.0, "mul": 0.0, "blurb": "Faster shield recovery."},
			"armory": {"name": "Armory", "unlocked": false, "cost": 100, "stat": "weapon_damage", "add": 0.0, "mul": 0.08, "blurb": "Bench, racks, and a damage bonus."},
			"research_lab": {"name": "Research lab", "unlocked": false, "cost": 120, "stat": "loot_quality", "add": 0.25, "mul": 0.0, "blurb": "Better finds in the field."},
			"crew_quarters": {"name": "Crew quarters", "unlocked": false, "cost": 90, "stat": "follower_affinity", "add": 1.0, "mul": 0.0, "blurb": "Bunks for a crew."},
			"galaxy_map": {"name": "Galaxy map", "unlocked": false, "cost": 150, "stat": "piloting", "add": 1.0, "mul": 0.0, "blurb": "Chart the next jump."},
		},
	}


func set_vitals(h: float, max_h: float, s: float, max_s: float) -> void:
	health = h
	max_health = max_h
	shield = s
	max_shield = max_s
	EventBus.player_vitals_changed.emit(health, max_health, shield, max_shield)


func set_ammo(mag: int, res: int, is_reloading: bool) -> void:
	magazine = mag
	reserve = res
	reloading = is_reloading
	EventBus.player_ammo_changed.emit(magazine, reserve, reloading)


func register_kill(kind: String) -> void:
	kills += 1
	var quest: Dictionary = quests.get("break_camp", {})
	if quest.get("state", "") == "active":
		quest["have"] = int(quest.get("have", 0)) + 1
		quests["break_camp"] = quest
		if int(quest["have"]) >= int(quest.get("need", 4)):
			complete_quest("break_camp")
	var xp := 20
	if kind == "drone":
		xp = 16
	elif kind == "trilobite":
		xp = 36
	grant_xp(xp, kind)
	EventBus.enemy_killed.emit(kind)


func skill_rank(id: String) -> int:
	var skills: Dictionary = progression.get("skills", {})
	return int(skills.get(id, 0))


func xp_for_level(level: int) -> int:
	return 70 + (level - 1) * 35


func grant_xp(amount: int, reason: String) -> void:
	var xp := int(progression.get("xp", 0)) + amount
	var level := int(progression.get("level", 1))
	var points := int(progression.get("skill_points", 0))
	var raised := false
	while xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		points += 1
		raised = true
	progression["xp"] = xp
	progression["level"] = level
	progression["skill_points"] = points
	EventBus.xp_changed.emit(level, xp, xp_for_level(level))
	EventBus.toast.emit("+%d XP  (%s)" % [amount, reason])
	if raised:
		EventBus.level_up.emit(level)
		EventBus.toast.emit("Level %d  —  skill point gained" % level)
		if has_node("/root/Stats"):
			Stats.rebuild()
		if has_node("/root/SaveGame"):
			SaveGame.write_autosave()


func try_buy_skill(id: String) -> bool:
	var skill := SkillCatalog.by_id(id)
	if skill.is_empty():
		return false
	var rank := skill_rank(id)
	if rank >= int(skill["max_rank"]):
		return false
	if int(progression.get("skill_points", 0)) < 1:
		return false
	var skills: Dictionary = progression.get("skills", {})
	skills[id] = rank + 1
	progression["skills"] = skills
	progression["skill_points"] = int(progression.get("skill_points", 0)) - 1
	Stats.rebuild()
	EventBus.skills_changed.emit()
	return true


func discover(id: String) -> void:
	var found: Array = world.get("discovered", [])
	if id in found:
		return
	found.append(id)
	world["discovered"] = found
	grant_xp(30, id)
	if id == "pool":
		complete_quest("survey_pool")


func complete_quest(id: String) -> void:
	if not quests.has(id):
		return
	var quest: Dictionary = quests[id]
	if quest.get("state", "") == "done":
		return
	quest["state"] = "done"
	quests[id] = quest
	grant_xp(45, quest.get("title", id))
	Inventory.grant_credits(30)
	EventBus.quest_updated.emit(id)
	EventBus.toast.emit("Quest complete  " + String(quest.get("title", id)))


func mark_enemy_dead(id: String) -> void:
	if id == "":
		return
	var dead: Array = world.get("dead_enemies", [])
	if id not in dead:
		dead.append(id)
		world["dead_enemies"] = dead


func is_enemy_dead(id: String) -> bool:
	return id in world.get("dead_enemies", [])


func mark_looted(id: String) -> void:
	if id == "":
		return
	var looted: Array = world.get("looted", [])
	if id not in looted:
		looted.append(id)
		world["looted"] = looted


func is_looted(id: String) -> bool:
	return id in world.get("looted", [])


func try_unlock_room(room_id: String) -> bool:
	var rooms: Dictionary = ship.get("rooms", {})
	if not rooms.has(room_id):
		return false
	var room: Dictionary = rooms[room_id]
	if bool(room.get("unlocked", false)):
		return false
	var cost := int(room.get("cost", 0))
	if not Inventory.try_spend(cost):
		EventBus.toast.emit("Need %d credits" % cost)
		return false
	room["unlocked"] = true
	rooms[room_id] = room
	ship["rooms"] = rooms
	Stats.rebuild()
	EventBus.ship_changed.emit()
	EventBus.toast.emit(String(room.get("name", room_id)) + " online")
	return true
