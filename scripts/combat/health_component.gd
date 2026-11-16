class_name HealthComponent
extends Node
## Shield-first vitality used by the player now and by ships in a later phase.

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal damaged(amount: float, hit_position: Vector3, hit_normal: Vector3, source: Node)
signal died

@export var max_health := 100.0
@export var max_shield := 0.0
@export var shield_regen := 18.0
@export var shield_delay := 3.0

var health := 0.0
var shield := 0.0
var alive := true
var invulnerable := false
var _regen_wait := 0.0


func _ready() -> void:
	health = max_health
	shield = max_shield
	health_changed.emit(health, max_health)
	shield_changed.emit(shield, max_shield)


func _process(delta: float) -> void:
	if not alive or max_shield <= 0.0 or shield >= max_shield:
		return
	_regen_wait = maxf(_regen_wait - delta, 0.0)
	if _regen_wait > 0.0:
		return
	shield = minf(max_shield, shield + shield_regen * delta)
	shield_changed.emit(shield, max_shield)


func apply_damage(amount: float, hit_position := Vector3.ZERO, hit_normal := Vector3.UP, source: Node = null) -> void:
	if not alive or invulnerable or amount <= 0.0:
		return
	var remaining := amount
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)
	if remaining > 0.0:
		health = maxf(0.0, health - remaining)
		health_changed.emit(health, max_health)
	_regen_wait = shield_delay
	damaged.emit(amount, hit_position, hit_normal, source)
	if health <= 0.0:
		alive = false
		died.emit()
