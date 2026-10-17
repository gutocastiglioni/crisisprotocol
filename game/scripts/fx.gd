class_name Fx
## Efeitos curtos do tiro: clarão no cano, traçante e faísca no impacto.


static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


static func _temp(parent: Node, node: Node3D, at: Vector3, life: float) -> void:
	parent.add_child(node)
	node.global_position = at
	parent.get_tree().create_timer(life).timeout.connect(node.queue_free)


static func muzzle_flash(parent: Node, at: Vector3) -> void:
	var root := Node3D.new()
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	quad.mesh = q
	quad.material_override = _unshaded(Color(1.0, 0.85, 0.35))
	root.add_child(quad)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.5
	light.omni_range = 5.0
	root.add_child(light)
	_temp(parent, root, at, 0.05)


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 0.3:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, len)
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.9, 0.6)
	mi.material_override = m
	_temp(parent, mi, (from + to) * 0.5, 0.04)
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)


static func impact(parent: Node, at: Vector3, flesh: bool) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	mi.mesh = q
	mi.material_override = _unshaded(Color(0.75, 0.08, 0.06) if flesh else Color(0.9, 0.85, 0.6))
	_temp(parent, mi, at, 0.08)
