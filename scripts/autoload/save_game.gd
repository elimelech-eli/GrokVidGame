extends Node
## Versioned JSON saves. Ship, crew, and followers have keys even when empty
## so phase 3 and 5 can extend the same files.

const FORMAT := 2
const DIR := "user://saves/"

var pending: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIR)


func has_autosave() -> bool:
	return FileAccess.file_exists(DIR + "autosave.json")


func queue(data: Dictionary) -> void:
	pending = data


func peek_pending() -> Dictionary:
	return pending


func consume_pending() -> Dictionary:
	var data := pending
	pending = {}
	return data


func capture() -> Dictionary:
	var body := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var pos := Vector3.ZERO
	var yaw := 0.0
	var health := 100.0
	var shield := 60.0
	var magazine := 30
	var reserve := 120
	if body:
		pos = body.global_position
		var rig := body.get_node_or_null("CameraRig")
		if rig:
			yaw = float(rig._yaw)
		var vitals := body.get_node_or_null("Health")
		if vitals:
			health = vitals.health
			shield = vitals.shield
		var gun := body.get_node_or_null("Weapon")
		if gun:
			magazine = int(gun.magazine)
			reserve = int(gun.reserve)
	return {
		"format": FORMAT,
		"zone_id": GameState.zone_id,
		"kills": GameState.kills,
		"player": {
			"position": [pos.x, pos.y, pos.z],
			"yaw": yaw,
			"health": health,
			"shield": shield,
			"magazine": magazine,
			"reserve": reserve,
		},
		"progression": GameState.progression.duplicate(true),
		"inventory": Inventory.capture(),
		"ship": GameState.ship.duplicate(true),
		"quests": GameState.quests.duplicate(true),
		"world": GameState.world.duplicate(true),
		"crew": GameState.crew.duplicate(true),
		"followers": GameState.followers.duplicate(true),
	}


func write_slot(slot: String) -> bool:
	var data := capture()
	return _write(slot, data)


func write_autosave() -> void:
	_write("autosave", capture())


func read_slot(slot: String) -> Dictionary:
	return _read(slot)


func apply(data: Dictionary) -> void:
	if data.is_empty():
		return
	GameState.zone_id = String(data.get("zone_id", GameState.zone_id))
	GameState.kills = int(data.get("kills", 0))
	GameState.progression = data.get("progression", GameState.progression)
	GameState.ship = data.get("ship", GameState.ship)
	GameState.quests = data.get("quests", GameState.quests)
	GameState.world = data.get("world", GameState.world)
	GameState.crew = data.get("crew", [])
	GameState.followers = data.get("followers", [])
	if data.has("inventory"):
		Inventory.restore(data["inventory"])
	Stats.rebuild()
	GameState.pending_player = data.get("player", {})


func _write(slot: String, data: Dictionary) -> bool:
	var path := DIR + slot + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _read(slot: String) -> Dictionary:
	var path := DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
