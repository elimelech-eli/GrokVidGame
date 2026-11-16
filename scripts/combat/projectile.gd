extends Node3D
## Fast bolt. Moves in _physics_process and raycasts the step so it cannot
## tunnel through the terrain or a body.

var speed := 80.0
var damage := 16.0
var color := Color(0.65, 0.95, 1.0)
var mask := Layers.WORLD | Layers.ENEMY
var source: Node
var life := 1.8
var heavy := false
var _dir := Vector3.FORWARD


func setup(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	_dir = direction.normalized()
	if _dir.length_squared() < 0.001:
		_dir = Vector3.FORWARD
	look_at(global_position + _dir, Vector3.UP)


func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	sphere.material = mat
	mesh_instance.mesh = sphere
	mesh_instance.scale = Vector3(1.0, 1.0, 4.2)
	add_child(mesh_instance)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 2.2
	add_child(light)


func _physics_process(delta: float) -> void:
	var time_scale := 1.0
	if source == null or not source.is_in_group("player"):
		time_scale = GameState.world_time_scale
	var step := _dir * speed * delta * time_scale
	var from := global_position
	var to := from + step
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	if source and is_instance_valid(source):
		query.exclude = [source.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_impact(hit)
		queue_free()
		return
	global_position = to
	life -= delta
	if life <= 0.0:
		queue_free()


func _impact(hit: Dictionary) -> void:
	var pos: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	CombatVfx.impact(get_tree().current_scene, pos, normal, color, heavy)
	AudioDirector.play_at("impactMetal_002" if not heavy else "impactPlate_light_002", pos, 0.08, -2.0)
	var collider := hit.collider as Node
	if collider == null:
		return
	var body := collider
	while body and not body.has_node("Health"):
		body = body.get_parent()
	if body and body.has_node("Health"):
		var health := body.get_node("Health") as HealthComponent
		if health:
			health.apply_damage(damage, pos, normal, source)
			if source and source.is_in_group("player") and body.is_in_group("enemy"):
				EventBus.hit_confirm.emit()
