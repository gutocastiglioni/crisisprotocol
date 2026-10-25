class_name Pickup
extends Node3D
## Item largado pelo cenário (só no perfil "survival" de GameMode; no "arcade" fica escondido): caixa de munição de uma
## arma ou kit de vida. Pega-se passando por cima (PICK_RANGE), sem animação; se a munição já está no máximo ou a vida
## cheia, fica onde está para depois. O item gira e balança devagar e a faixa colorida é acesa (aparece no escuro).
## `LAYOUT` diz onde cada um fica e quanto dá: pouco, de propósito.

const PICK_RANGE := 0.9
const BODY_SCALE := 1.5  # maiores que o real: no pátio escuro precisam aparecer de longe
const BOX := Vector3(0.36, 0.2, 0.24)
const KIT := Vector3(0.38, 0.24, 0.28)
## Modelos 3D das armas para drops de armas no chão
const WEAPON_SCENES := {
	"m16": preload("res://assets/characters/m16.glb"),
	"shotgun": preload("res://assets/characters/shotgun.glb"),
	"m79": preload("res://assets/characters/m79.glb"),
	"sniper": preload("res://assets/characters/sniper.glb"),
}
const ATLAS := preload("res://assets/characters/heroine_atlas.png")
const GLOW := preload("res://shaders/item_glow.gdshader")
## faixa de cada tipo (a cor diz a arma de longe)
const COLORS := {
	"pistol": Color(1.0, 0.85, 0.25), "m16": Color(1.0, 0.5, 0.15), "shotgun": Color(1.0, 0.25, 0.2),
	"m79": Color(0.45, 1.0, 0.3), "sniper": Color(0.2, 0.8, 1.0),
	"health": Color(1.0, 0.15, 0.12),
}
## onde ficam: galpão (as armas dos baús já trazem a munição delas), pátio da mata (na beira da estrada, longe das árvores)
## e pedreira (chão livre entre as ruínas). `kind` = nome da arma (caixa de munição dela) ou "health".
const LAYOUT := [
	{"pos": Vector3(10.4, 0, 10.4), "kind": "pistol", "amount": 6},  # no meio de um corredor do labirinto (Level.MAZE)
	{"pos": Vector3(-11.5, 0, 3.0), "kind": "health", "amount": 35},
	{"pos": Vector3(-18.0, 0, -3.4), "kind": "shotgun", "amount": 3},
	{"pos": Vector3(-39.0, 0, -8.2), "kind": "pistol", "amount": 8},
	{"pos": Vector3(-47.5, 0, -6.25), "kind": "m16", "amount": 10},
	{"pos": Vector3(-52.0, 0, -3.0), "kind": "health", "amount": 35},
	{"pos": Vector3(-61.0, 0, -1.0), "kind": "pistol", "amount": 8},
	{"pos": Vector3(-72.0, 0, 0.5), "kind": "m16", "amount": 15},
	{"pos": Vector3(-82.0, 0, -5.5), "kind": "health", "amount": 35},
	{"pos": Vector3(-83.5, 0, -5.5), "kind": "m79", "amount": 3},
	{"pos": Vector3(-98.0, 0, 5.5), "kind": "shotgun", "amount": 5},
]

var kind := "pistol"
var amount := 6
var taken := false
var is_weapon := false
var is_drop := false
var _home := Vector3.ZERO
var _body: Node3D
var _t := 0.0


## Cria um item dropado de inimigo no mundo com queda suave até o chão.
static func spawn_drop(parent: Node, from_pos: Vector3, item_kind: String, item_amount: int, as_weapon: bool = false) -> Pickup:
	var p := Pickup.new()
	p.kind = item_kind
	p.amount = item_amount
	p.is_weapon = as_weapon
	p.is_drop = true
	p.position = from_pos
	parent.add_child(p)
	p.fall_to_ground(from_pos)
	return p


## Põe todos os itens de `LAYOUT` em `parent`.
static func build(parent: Node) -> Array[Pickup]:
	var out: Array[Pickup] = []
	for e in LAYOUT:
		var p := Pickup.new()
		p.kind = e.kind
		p.amount = e.amount
		p.position = e.pos
		parent.add_child(p)
		out.append(p)
	return out


func _ready() -> void:
	assert(kind == "health" or kind in GameMode.AMMO_CAP, "item desconhecido: " + kind)
	add_to_group("pickups")
	_home = position
	_t = fposmod(position.x * 1.7 + position.z * 0.9, TAU)  # cada um balança numa fase
	_body = Node3D.new()
	_body.scale = Vector3.ONE * (1.15 if is_weapon else BODY_SCALE)
	add_child(_body)
	if is_weapon and kind in WEAPON_SCENES:
		_build_weapon()
	elif kind == "health":
		_build_kit()
	else:
		_build_box()


## Queda suave até o chão ao dropar de um inimigo.
func fall_to_ground(from: Vector3) -> void:
	global_position = from
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var floor_y := maxf(0.0, from.y - 1.0)
	if space:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.2, from + Vector3.DOWN * 4.0, 1))
		if hit:
			floor_y = hit.position.y
	_home = Vector3(from.x, floor_y, from.z)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", floor_y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		global_position.y = floor_y
		Sfx.play(self, "casing_brass", global_position))


## Malha 3D da arma girando, com halo suave no chão e feixe de luz da cor da arma.
func _build_weapon() -> void:
	var scene: PackedScene = WEAPON_SCENES[kind]
	var inst: Node3D = scene.instantiate()
	var holder := Node3D.new()
	holder.add_child(inst)
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new()
		m.shader = Gfx.shader()
		m.set_shader_parameter("albedo_tex", ATLAS)
		m.set_shader_parameter("rim", 0.4)
		mi.material_override = m
		var maabb := mi.get_aabb()
		if first:
			aabb = maabb
			first = false
		else:
			aabb = aabb.merge(maabb)
	inst.position = -aabb.get_center() + Vector3(0, 0.08, 0)
	_body.add_child(holder)
	var c: Color = COLORS.get(kind, Color.WHITE)
	# brilho fora do _body: fica no chão sem girar nem balançar
	var halo := _soft(Vector2(1.1, 1.1), c, false)
	halo.rotation_degrees.x = -90.0
	halo.position.y = 0.015
	for yaw in [0.0, 90.0]:
		var beam := _soft(Vector2(0.28, 1.1), c * Color(1, 1, 1, 0.45), true)
		beam.rotation_degrees.y = yaw
		beam.position.y = 0.55


## Quadro de brilho suave (item_glow.gdshader) preso ao item, não ao corpo que gira.
func _soft(size: Vector2, color: Color, beam: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("beam", beam)
	m.set_shader_parameter("phase", _t)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, tex: String, tint: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m := Level.material(tex, 1.0 / maxf(size.x, 0.3))
	m.set_shader_parameter("tint", tint)
	mi.material_override = m
	mi.position = pos
	_body.add_child(mi)


func _glow(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)


## Caixa verde-oliva de munição com a faixa da cor da arma na tampa e na frente.
func _build_box() -> void:
	_box(BOX, Vector3(0, BOX.y * 0.5, 0), "crate", Color(0.7, 0.85, 0.5))
	var c: Color = COLORS[kind]
	_glow(Vector3(BOX.x * 0.55, 0.012, BOX.z * 0.35), Vector3(0, BOX.y + 0.004, 0), c)
	_glow(Vector3(BOX.x * 0.55, BOX.y * 0.3, 0.012), Vector3(0, BOX.y * 0.5, BOX.z * 0.5 + 0.002), c)


## Maleta branca com a cruz vermelha acesa.
func _build_kit() -> void:
	_box(KIT, Vector3(0, KIT.y * 0.5, 0), "concrete", Color(1.8, 1.8, 1.8))
	var c: Color = COLORS.health
	for face in [1.0, -1.0]:
		_glow(Vector3(0.16, 0.05, 0.012), Vector3(0, KIT.y * 0.5, face * (KIT.z * 0.5 + 0.002)), c)
		_glow(Vector3(0.05, 0.16, 0.012), Vector3(0, KIT.y * 0.5, face * (KIT.z * 0.5 + 0.002)), c)
	_glow(Vector3(0.16, 0.012, 0.05), Vector3(0, KIT.y + 0.004, 0), c)
	_glow(Vector3(0.05, 0.012, 0.16), Vector3(0, KIT.y + 0.004, 0), c)


func _physics_process(delta: float) -> void:
	# no arcade só armas aparecem; no survival caixas e armas
	visible = (is_weapon or GameMode.pickups()) and not taken
	if not visible:
		return
	_t += delta
	_body.rotation.y += delta * 0.9
	_body.position.y = 0.06 + sin(_t * 2.0) * 0.03
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var d := player.global_position - global_position
	if Vector2(d.x, d.z).length() < PICK_RANGE and absf(d.y) < 1.2:
		var ok := false
		if is_weapon:
			ok = player.collect_weapon(kind, amount)
		else:
			ok = player.collect(kind, amount)
		if ok:
			taken = true
			visible = false
			Sfx.play(self, "weapon_pickup", global_position + Vector3.UP * 0.3)
			if is_drop:
				queue_free()


## Volta ao lugar, de novo para pegar (reinício) ou limpa se for drop de inimigo.
func reset() -> void:
	if is_drop:
		queue_free()
		return
	taken = false
	position = _home
