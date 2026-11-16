extends Node
## Session state for the running game, plus the slots later phases will fill.
## Phase 2 writes progression/inventory/quests.
## Phase 3 writes ship modules and boards the ship_hub group.
## Phase 4 reads the same health/shield model for craft.
## Phase 5 appends followers and drives dialogue through EventBus.
## Phase 6 swaps zone_id and streams additional zones.

enum Phase { MENU, PLAYING, PAUSED, DEAD }

var phase: Phase = Phase.MENU
var zone_id := "vesper_9_aether_reach"

var health := 100.0
var max_health := 100.0
var shield := 60.0
var max_shield := 60.0
var magazine := 30
var reserve := 120
var reloading := false

# Reserved for later phases. Phase 1 does not simulate these.
var progression := {
	"level": 1,
	"xp": 0,
	"attributes": {},
}
var inventory: Array = []
var quests: Array = []
var ship := {
	"id": "aether_skiff",
	"modules": [],
}
var followers: Array = []
var kills := 0
var auto_start := false


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
	EventBus.enemy_killed.emit(kind)
