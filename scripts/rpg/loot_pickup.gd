extends Area3D

var _item: Dictionary = {}
var _credits := 0


func setup(item: Dictionary, credits: int, where: Vector3) -> void:
	_item = item
	_credits = credits
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.18, 0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(item.get("color", "#ffffff")))
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.8
	box.material = mat
	mesh.mesh = box
	mesh.position.y = 0.2
	add_child(mesh)
	global_position = where
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	rotate_y(delta * 1.4)


func _on_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	Inventory.add_item(_item)
	if _credits > 0:
		Inventory.grant_credits(_credits)
	queue_free()
