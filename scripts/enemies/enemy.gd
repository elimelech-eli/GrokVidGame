extends CharacterBody3D
## Patrol, notice, chase, and shoot. Drones float; the others walk the terrain.
## Sensing is radius plus line of sight, which is enough for this outpost and
## easy to replace with a navigation agent later.

enum State { PATROL, CHASE, ATTACK, DEAD }

const MODEL := {
	"quad": "res://assets/models/essentials/Enemy_QuadShell.gltf",
	"drone": "res://assets/models/essentials/Enemy_EyeDrone.gltf",
	"trilobite": "res://assets/models/essentials/Enemy_Trilobite.gltf",
}

@export var kind := "quad"
@export var max_health := 70.0
@export var sight_range := 18.0
@export var attack_range := 11.0
@export var leash := 36.0
@export var move_speed := 3.4
@export var bolt_damage := 9.0
@export var bolt_speed := 28.0
@export var fire_interval := 1.25
@export var flying := false
@export var patrol: PackedVector3Array = PackedVector3Array()

var health: HealthComponent
var animator: ActorAnimator
var _state := State.PATROL
var _home := Vector3.ZERO
var _patrol_index := 0
var _wait := 0.0
var _fire_cd := 0.6
var _windup := 0.0
var _lost := 0.0
var _muzzle: Marker3D
var _player: Node3D
var _hit_flash := 0.0
var _overlay: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMY
	floor_snap_length = 0.4
	_home = global_position
	if flying:
		motion_mode = MOTION_MODE_FLOATING
	_apply_kind_defaults()
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = max_health
	health.max_shield = 0.0
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build_body()
	_overlay = StandardMaterial3D.new()
	_overlay.albedo_color = Color(1, 0.35, 0.25, 1)
	_overlay.emission_enabled = true
	_overlay.emission = Color(1, 0.3, 0.2)
	_overlay.emission_energy_multiplier = 2.5
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color.a = 0.0


func configure(spawn: Vector3, points: PackedVector3Array) -> void:
	global_position = spawn
	_home = spawn
	patrol = points


func _physics_process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			_set_overlay(false)
	if health == null or not health.alive or GameState.phase != GameState.Phase.PLAYING:
		if not flying and health and health.alive:
			if not is_on_floor():
				velocity.y -= 22.0 * delta
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			move_and_slide()
		if animator:
			animator.notify_locomotion(0.0, false, true, 0.0)
		return
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_player = get_tree().get_first_node_in_group("player")
	var see := _can_see_player()
	if see:
		_lost = 0.0
	else:
		_lost += delta
	match _state:
		State.PATROL:
			if see:
				_state = State.CHASE
			else:
				_patrol(delta)
		State.CHASE:
			if not see and _lost > 2.4:
				_state = State.PATROL
			elif see and _distance_to_player() < attack_range:
				_state = State.ATTACK
			elif _distance_home() > leash:
				_state = State.PATROL
			else:
				_chase(delta)
		State.ATTACK:
			if not see and _lost > 0.8:
				_state = State.CHASE
			elif _distance_to_player() > attack_range * 1.25:
				_state = State.CHASE
			else:
				_attack(delta)
		State.DEAD:
			return
	_separate()
	if not flying:
		if not is_on_floor():
			velocity.y -= 22.0 * delta
		else:
			velocity.y = -0.5
	move_and_slide()
	var planar := Vector2(velocity.x, velocity.z).length()
	if animator:
		animator.notify_locomotion(planar, _state == State.CHASE, true, 0.0)


func _patrol(delta: float) -> void:
	if patrol.size() < 2:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return
	if _wait > 0.0:
		_wait -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target := patrol[_patrol_index]
	target.y = global_position.y
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.7:
		_patrol_index = (_patrol_index + 1) % patrol.size()
		_wait = 0.9
		return
	_move_toward(offset.normalized(), move_speed * 0.72, delta)
	_face(offset, delta)


func _chase(delta: float) -> void:
	if _player == null:
		return
	var aim := _player.global_position
	if flying:
		aim.y = _ground_height(aim.x, aim.z) + 2.5
	var offset := aim - global_position
	if not flying:
		offset.y = 0.0
	if offset.length_squared() < 0.04:
		return
	_move_toward(offset.normalized(), move_speed, delta)
	_face(offset, delta)


func _attack(delta: float) -> void:
	if _player == null:
		return
	var aim := _player.global_position + Vector3.UP * 1.1
	var offset := aim - _muzzle_position()
	_face(Vector3(offset.x, 0.0, offset.z), delta)
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if flying:
		var hover := _ground_height(global_position.x, global_position.z) + 2.6
		velocity.y = clampf(hover - global_position.y, -2.0, 2.0) * 2.0
	if _fire_cd > 0.0:
		return
	if _windup <= 0.0:
		_windup = 0.28
		if animator:
			animator.trigger("attack")
		return
	_windup -= delta
	if _windup > 0.0:
		return
	_windup = 0.0
	_fire_cd = fire_interval
	_shoot(offset.normalized())


func _shoot(direction: Vector3) -> void:
	var origin := _muzzle_position()
	CombatVfx.muzzle(get_tree().current_scene, origin, direction, Color(1.0, 0.55, 0.28))
	AudioDirector.play_at("laserRetro_001", origin, 0.06, -3.0)
	var bolt := Node3D.new()
	bolt.set_script(load("res://scripts/combat/projectile.gd"))
	get_tree().current_scene.add_child(bolt)
	bolt.speed = bolt_speed
	bolt.damage = bolt_damage
	bolt.color = Color(1.0, 0.58, 0.28)
	bolt.mask = Layers.WORLD | Layers.PLAYER
	bolt.source = self
	bolt.life = 2.4
	bolt.heavy = true
	bolt.setup(origin, direction)


func _move_toward(direction: Vector3, speed: float, delta: float) -> void:
	var dir := direction
	if flying:
		velocity = velocity.move_toward(dir * speed, 18.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, dir.x * speed, 16.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 16.0 * delta)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.001:
		return
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var target := atan2(flat.x, flat.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target, 1.0 - exp(-8.0 * delta))


func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var origin := _muzzle_position()
	var target: Vector3 = _player.global_position + Vector3.UP * 1.15
	var to := target - origin
	var dist := to.length()
	if dist > sight_range:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	var model: Node3D = null
	if $Visual.get_child_count() > 0:
		model = $Visual.get_child(0) as Node3D
	var facing := Vector3(0, 0, -1)
	if model:
		facing = -model.global_basis.z
	facing.y = 0.0
	if flat.length() > 0.1 and facing.length() > 0.1 and facing.normalized().dot(flat.normalized()) < 0.1 and dist > 4.0:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, target, Layers.WORLD | Layers.PLAYER)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var node := hit.collider as Node
	while node:
		if node.is_in_group("player"):
			return true
		node = node.get_parent()
	return false


func _separate() -> void:
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var dist := away.length()
		if dist < 1.35 and dist > 0.05:
			velocity += away.normalized() * 1.6


func _distance_to_player() -> float:
	if _player == null:
		return 999.0
	return global_position.distance_to(_player.global_position)


func _distance_home() -> float:
	return Vector2(global_position.x - _home.x, global_position.z - _home.z).length()


func _muzzle_position() -> Vector3:
	if _muzzle:
		return _muzzle.global_position
	return global_position + Vector3.UP * (1.6 if flying else 1.0)


func _ground_height(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -30.0, z), Layers.WORLD)
	var hit := space.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else global_position.y


func _on_damaged(_amount: float, _pos: Vector3, _normal: Vector3, _source: Node) -> void:
	_hit_flash = 0.09
	_set_overlay(true)
	if animator:
		animator.trigger("hit")
	if _state == State.PATROL:
		_state = State.CHASE
	AudioDirector.play_at("impactMetal_002", global_position, 0.08, -4.0)


func _on_died() -> void:
	_state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	if animator:
		animator.trigger("death")
	GameState.register_kill(kind)
	AudioDirector.play_at("lowFrequency_explosion_000", global_position, 0.04, -6.0)
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(self, "global_position:y", global_position.y - 1.4, 1.2)
	tween.tween_callback(queue_free)


func _set_overlay(enabled: bool) -> void:
	for mesh_instance in find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_overlay = _overlay if enabled else null


func _apply_kind_defaults() -> void:
	match kind:
		"drone":
			flying = true
			max_health = 45.0
			move_speed = 4.2
			attack_range = 13.0
			sight_range = 22.0
			bolt_damage = 8.0
			fire_interval = 1.45
		"trilobite":
			flying = false
			max_health = 140.0
			move_speed = 2.8
			attack_range = 12.0
			bolt_damage = 14.0
			fire_interval = 1.6
		_:
			kind = "quad"
			flying = false
			max_health = 70.0
			move_speed = 3.6


func _build_body() -> void:
	var shape := $CollisionShape3D as CollisionShape3D
	var capsule := CapsuleShape3D.new()
	if flying:
		capsule.radius = 0.45
		capsule.height = 0.95
		shape.position.y = 1.3
	elif kind == "trilobite":
		capsule.radius = 0.7
		capsule.height = 1.5
		shape.position.y = 0.75
	else:
		capsule.radius = 0.48
		capsule.height = 1.25
		shape.position.y = 0.62
	shape.shape = capsule
	var packed := load(MODEL.get(kind, MODEL["quad"]))
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	$Visual.add_child(model)
	var target_height := 0.95 if flying else (1.7 if kind == "trilobite" else 1.25)
	PropUtils.fit_height(model, target_height)
	PropUtils.align_feet(model)
	model.rotation.y = PI
	animator = ActorAnimator.new()
	animator.name = "ActorAnimator"
	add_child(animator)
	animator.setup(model, "creature")
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	$Visual.add_child(_muzzle)
	_muzzle.position = Vector3(0, target_height * 0.62, -target_height * 0.45)
