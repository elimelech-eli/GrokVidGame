extends Node3D
## A crate or locker. The player ray finds this on a parent and calls try_loot.

var world_id := ""
var bias := "mixed"
var looted := false


func prompt() -> String:
	if looted or _already():
		return "Empty container"
	return "Search container"


func try_loot() -> void:
	if looted or _already():
		return
	looted = true
	GameState.mark_looted(world_id)
	var item := Inventory.roll_drop(bias)
	Inventory.add_item(item)
	Inventory.grant_credits(randi_range(10, 24))
	GameState.grant_xp(15, "search")
	AudioDirector.play_sfx("open_001", 0.02)


func _already() -> bool:
	return world_id != "" and GameState.is_looted(world_id)
