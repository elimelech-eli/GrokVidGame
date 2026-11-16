extends Node3D

var _owner: Node3D
var _life := 8.0
var _shot := 0.4


func setup(player: Node3D) -> void:
	_owner = player
	global_position = player.global_position + Vector3(0.8, 1.8, 0.4)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("9af6ff")
	mat.emission_enabled = true
	mat.emission = Color("3ee6cf")
	mat.emission_energy_multiplier = 2.4
	sphere.material = mat
	mesh.mesh = sphere
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color("7ef0e4")
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)


func _physics_process(delta: float) -> void:
	if _owner == null or not is_instance_valid(_owner):
		queue_free()
		return
	var goal: Vector3 = _owner.global_position + _owner.global_basis * Vector3(0.9, 1.7, -0.2)
	global_position = global_position.lerp(goal, 1.0 - exp(-6.0 * delta))
	_life -= delta
	_shot -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _shot > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_shot = 0.45
	var dir: Vector3 = (target.global_position + Vector3.UP) - global_position
	CombatVfx.muzzle(get_tree().current_scene, global_position, dir.normalized(), Color("9af6ff"))
	var bolt := Node3D.new()
	bolt.set_script(load("res://scripts/combat/projectile.gd"))
	get_tree().current_scene.add_child(bolt)
	bolt.speed = 48.0
	bolt.damage = 10.0 * Stats.get_value("weapon_damage")
	bolt.color = Color("8ef6ff")
	bolt.mask = Layers.WORLD | Layers.ENEMY
	bolt.source = _owner
	bolt.life = 1.2
	bolt.setup(global_position, dir.normalized())


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := 18.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var body := enemy as Node3D
		var dist := global_position.distance_to(body.global_position)
		if dist < best_d:
			best_d = dist
			best = body
	return best
