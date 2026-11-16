extends RefCounted
## Four branches. Piloting and Persuasion write stats that later phases read.
## Actives are unlocked at rank 1; extra ranks shorten the cooldown.


static func all() -> Array:
	return [
		_passive("weapon_training", "Weapon Training", "Combat", 3, "+8% weapon damage per rank.", [{"stat": "weapon_damage", "mul": 0.08}]),
		_passive("vanguard", "Vanguard", "Combat", 3, "+15 max health per rank.", [{"stat": "max_health", "add": 15.0}]),
		_active("shield_burst", "Shield Burst", "Combat", "Restore shields. Hotkey 1.", 14.0),
		_active("grenade", "Plasma Grenade", "Combat", "Lob an explosive. Hotkey 2.", 12.0),
		_passive("shield_weave", "Shield Weave", "Tech", 3, "+12 max shield per rank.", [{"stat": "max_shield", "add": 12.0}]),
		_passive("overclock", "Overclock", "Tech", 3, "Abilities recharge 8% faster per rank.", [{"stat": "cooldown_rate", "mul": 0.08}]),
		_active("combat_drone", "Combat Drone", "Tech", "A drone covers you for a few seconds. Hotkey 3.", 22.0),
		_active("slow_dash", "Tactical Slide", "Tech", "The world slows while you move. Hotkey 4.", 16.0),
		_passive("helm_sense", "Helm Sense", "Piloting", 3, "+1 piloting. The bridge will use this.", [{"stat": "piloting", "add": 1.0}]),
		_passive("gunnery", "Gunnery", "Piloting", 3, "+ship weapon rating for later ship combat.", [{"stat": "ship_weapon", "add": 1.0}]),
		_passive("engine_tuning", "Engine Tuning", "Piloting", 2, "+ship speed rating for the capital ship.", [{"stat": "ship_speed", "add": 1.0}]),
		_passive("silver_tongue", "Silver Tongue", "Persuasion", 3, "+1 persuasion for later dialogue.", [{"stat": "persuasion", "add": 1.0}]),
		_passive("appraiser", "Appraiser", "Persuasion", 3, "More credits from loot.", [{"stat": "credits_find", "mul": 0.12}]),
		_passive("commander", "Commander", "Persuasion", 2, "Follower affinity, used when crew arrives.", [{"stat": "follower_affinity", "add": 1.0}]),
	]


static func by_id(id: String) -> Dictionary:
	for skill in all():
		if skill["id"] == id:
			return skill
	return {}


static func branches() -> PackedStringArray:
	return PackedStringArray(["Combat", "Tech", "Piloting", "Persuasion"])


static func in_branch(branch: String) -> Array:
	var found: Array = []
	for skill in all():
		if skill["branch"] == branch:
			found.append(skill)
	return found


static func cooldown(id: String, rank: int) -> float:
	var skill := by_id(id)
	var base := float(skill.get("cooldown", 10.0))
	return base * (1.0 - 0.12 * maxi(rank - 1, 0))


static func _passive(id: String, title: String, branch: String, max_rank: int, desc: String, stats: Array) -> Dictionary:
	return {
		"id": id,
		"name": title,
		"branch": branch,
		"kind": "passive",
		"max_rank": max_rank,
		"desc": desc,
		"stats": stats,
		"cooldown": 0.0,
	}


static func _active(id: String, title: String, branch: String, desc: String, cooldown_s: float) -> Dictionary:
	return {
		"id": id,
		"name": title,
		"branch": branch,
		"kind": "active",
		"max_rank": 3,
		"desc": desc,
		"stats": [],
		"cooldown": cooldown_s,
	}
