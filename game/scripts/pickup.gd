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
## faixa de cada tipo (a cor diz a arma de longe)
const COLORS := {
	"pistol": Color(1.0, 0.85, 0.25), "m16": Color(1.0, 0.5, 0.15), "shotgun": Color(1.0, 0.25, 0.2),
	"m79": Color(0.45, 1.0, 0.3),
	"health": Color(1.0, 0.15, 0.12),
}
## onde ficam: galpão (as armas dos baús já trazem a munição delas), pátio da mata (na beira da estrada, longe das árvores)
## e pedreira (chão livre entre as ruínas). `kind` = nome da arma (caixa de munição dela) ou "health".
const LAYOUT := [
	{"pos": Vector3(10.0, 0, 10.5), "kind": "pistol", "amount": 6},
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
var _home := Vector3.ZERO
var _body: Node3D
var _t := 0.0


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
	_body.scale = Vector3.ONE * BODY_SCALE
	add_child(_body)
	if kind == "health":
		_build_kit()
	else:
		_build_box()


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
	# só no jogo de sobrevivência (no arcade a munição não acaba e o item não existe)
	visible = GameMode.pickups() and not taken
	if not visible:
		return
	_t += delta
	_body.rotation.y += delta * 0.9
	_body.position.y = 0.06 + sin(_t * 2.0) * 0.03
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var d := player.global_position - global_position
	if Vector2(d.x, d.z).length() < PICK_RANGE and absf(d.y) < 1.2 and player.collect(kind, amount):
		taken = true
		visible = false
		Sfx.play(self, "weapon_pickup", global_position + Vector3.UP * 0.3)


## Volta ao lugar, de novo para pegar (reinício).
func reset() -> void:
	taken = false
	position = _home
