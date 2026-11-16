class_name PropUtils
extends RefCounted
## Shared mesh measuring, grounding, collision, and material tinting.


static func merged_local_aabb(root: Node3D) -> AABB:
	var found := false
	var box := AABB()
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mesh_instance.global_transform
		var local: AABB = xf * mesh_instance.mesh.get_aabb()
		if not found:
			box = local
			found = true
		else:
			box = box.merge(local)
	return box


static func global_aabb(root: Node3D) -> AABB:
	var found := false
	var box := AABB()
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var world: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if not found:
			box = world
			found = true
		else:
			box = box.merge(world)
	return box


static func fit_height(root: Node3D, height: float) -> void:
	var box := merged_local_aabb(root)
	if box.size.y < 0.001:
		return
	root.scale *= height / box.size.y


static func fit_longest(root: Node3D, length: float) -> void:
	var box := merged_local_aabb(root)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest < 0.001:
		return
	root.scale *= length / longest


static func align_feet(root: Node3D) -> void:
	var box := merged_local_aabb(root)
	root.position.y -= box.position.y


static func plant(root: Node3D, ground_y: float) -> void:
	var box := global_aabb(root)
	if box.size.length_squared() < 0.00001:
		root.global_position.y = ground_y
		return
	root.global_position.y += ground_y - box.position.y


static func add_static_collision(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	root.add_child(body)
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = body.global_transform.affine_inverse() * mesh_instance.global_transform
		body.add_child(col)
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func tint(root: Node, albedo: Color, emission_energy: float) -> void:
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var mesh: Mesh = mesh_instance.mesh.duplicate()
		mesh_instance.mesh = mesh
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface)
			if mat == null:
				mat = StandardMaterial3D.new()
			else:
				mat = mat.duplicate()
			if mat is BaseMaterial3D:
				mat.albedo_color = albedo
				if emission_energy > 0.0:
					mat.emission_enabled = true
					mat.emission = albedo
					mat.emission_energy_multiplier = emission_energy
			mesh.surface_set_material(surface, mat)


static func boost_emission(root: Node, color: Color, energy: float) -> void:
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var mesh: Mesh = mesh_instance.mesh.duplicate()
		mesh_instance.mesh = mesh
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface)
			if mat == null:
				continue
			mat = mat.duplicate()
			if mat is BaseMaterial3D:
				mat.emission_enabled = true
				mat.emission = color
				mat.emission_energy_multiplier = energy
			mesh.surface_set_material(surface, mat)


static func play_first_animation(root: Node) -> void:
	for player in root.find_children("*", "AnimationPlayer", true, false):
		var names := player.get_animation_list()
		if names.is_empty():
			return
		var pick := names[0]
		for anim_name in names:
			if "idle" in anim_name.to_lower():
				pick = anim_name
				break
		var anim := player.get_animation(pick)
		anim.loop_mode = Animation.LOOP_LINEAR
		player.play(pick)
		return
