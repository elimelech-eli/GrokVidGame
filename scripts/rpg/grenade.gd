extends Node3D

var _velocity := Vector3.ZERO
var _life := 0.7
var _owner: Node


func setup(origin: Vector3, direction: Vector3, source: Node) -> void:
	global_position = origin
	_velocity = direction * 16.0 + Vector3.UP * 4.0
	_owner = source
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffb15a")
	mat.emission_enabled = true
	mat.emission = Color("ff7a2a")
	mat.emission_energy_multiplier = 3.0
	sphere.material = mat
	mesh.mesh = sphere
	add_child(mesh)


func _physics_process(delta: float) -> void:
	_velocity.y -= 12.0 * delta
	global_position += _velocity * delta
	_life -= delta
	if _life > 0.0:
		return
	_explode()
	queue_free()


func _explode() -> void:
	CombatVfx.impact(get_tree().current_scene, global_position, Vector3.UP, Color("ff8844"), true)
	AudioDirector.play_at("lowFrequency_explosion_000", global_position, 0.05, 2.0)
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 3.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = Layers.ENEMY
	var hits := space.intersect_shape(query, 12)
	var seen := {}
	var scale := Stats.get_value("weapon_damage") if has_node("/root/Stats") else 1.0
	for hit in hits:
		var body := hit.collider as Node
		while body and not body.is_in_group("enemy"):
			body = body.get_parent()
		if body == null or seen.has(body):
			continue
		seen[body] = true
		if body.has_node("Health"):
			body.get_node("Health").apply_damage(42.0 * scale, global_position, Vector3.UP, _owner)
			EventBus.hit_confirm.emit()
