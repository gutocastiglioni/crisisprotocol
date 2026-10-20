class_name KeyItem
extends Node3D
## Chave escondida com alguém (TargetDummy.loot): some até ele morrer; aí cai no chão onde ele estava (`drop`) e fica
## brilhando (estrela de 4 pontas que pisca de tempos em tempos, com uma luzinha) para ser vista de longe. Ela chegando
## perto (PICK_RANGE), pega sozinha: a chave vai para o bolso (`Player.add_key(id)`) e o sinal `picked` faz o main
## mostrar o item na tela (Inspect.show_item). Abre o baú com `Chest.lock` igual ao `id`. Reinício: volta a ficar escondida.

signal picked(key: KeyItem)

const PICK_RANGE := 1.0
const WORLD_SCALE := 1.6  # maior que a de verdade: no chão do galpão escuro precisa aparecer
const FALL_TIME := 0.45
const TWINKLE := 1.3  # s entre uma piscada e outra
const BRASS := Color(0.85, 0.66, 0.26)
const TAG := Color(0.75, 0.12, 0.1)

@export var id := "container"
@export var display_name := "CHAVE DO CONTAINER"
@export var description := "Chave de latao com etiqueta vermelha.
Abre o cadeado de algum container."

## "hidden" (com o dono), "dropping" (caindo), "dropped" (no chão, brilhando) ou "taken"
var state := "hidden"
var _model: Node3D
var _sparkle: MeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0


## Malha da chave (deitada no plano XZ, ~7 cm, argola em -X), usada no chão e na tela do item.
static func build_model(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.7
	brass.roughness = 0.35
	var bow := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.009
	torus.outer_radius = 0.017
	torus.rings = 12
	torus.ring_segments = 6
	bow.mesh = torus
	bow.material_override = brass
	bow.position.x = -0.03
	root.add_child(bow)
	for part in [
		[Vector3(0.048, 0.006, 0.007), Vector3(0.01, 0, 0)],  # haste
		[Vector3(0.005, 0.006, 0.013), Vector3(0.026, 0, 0.009)],  # dentes
		[Vector3(0.005, 0.006, 0.009), Vector3(0.017, 0, 0.007)],
		[Vector3(0.004, 0.006, 0.012), Vector3(0.032, 0, 0.009)],
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mi.mesh = box
		mi.material_override = brass
		mi.position = part[1]
		root.add_child(mi)
	# etiqueta vermelha pendurada na argola
	var tag := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.028, 0.003, 0.018)
	tag.mesh = tb
	var tm := StandardMaterial3D.new()
	tm.albedo_color = TAG
	tm.roughness = 0.8
	tag.material_override = tm
	tag.position = Vector3(-0.062, 0, 0.004)
	tag.rotation.y = 0.35
	root.add_child(tag)
	return root


func _ready() -> void:
	add_to_group("keys")
	_model = build_model(self)
	_model.scale = Vector3.ONE * WORLD_SCALE
	_model.position.y = 0.006
	_model.rotation.y = randf() * TAU
	_sparkle = _star(0.4, Color(1.0, 0.95, 0.7))
	_glow = _star(0.14, Color(1.0, 0.85, 0.45))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.5)
	_light.omni_range = 1.4
	_light.position.y = 0.15
	add_child(_light)
	_show(false)


## Estrela de 4 pontas (o clarão de shot_fx.png) virada para a câmera, somando luz.
func _star(size: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Fx.SPRITES
	m.uv1_scale = Vector3(1.0 / 3.0, 1.0, 1.0)
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = true  # o brilho aparece mesmo com a chave atrás do corpo caído
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.12
	add_child(mi)
	return mi


func _show(on: bool) -> void:
	visible = on
	_light.visible = on and state == "dropped"


## O dono morreu: a chave cai de `from` até o chão embaixo e começa a brilhar.
func drop(from: Vector3) -> void:
	if state != "hidden":
		return
	state = "dropping"
	global_position = from
	_show(true)
	var floor_y := from.y - 3.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1))
	if hit:
		floor_y = hit.position.y
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", floor_y, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		state = "dropped"
		_t = 0.0
		_light.visible = true
		Sfx.play(self, "key_drop", global_position))


## Brilho da estrela (0..1) agora: uma piscada forte a cada TWINKLE s.
func twinkle() -> float:
	return pow(maxf(0.0, sin(_t * TAU / TWINKLE)), 6.0)


func _process(delta: float) -> void:
	if state != "dropped":
		_sparkle.visible = false
		_glow.visible = false
		return
	_t += delta
	var k := twinkle()
	_sparkle.visible = k > 0.02
	_sparkle.scale = Vector3.ONE * (0.3 + k)
	_glow.visible = true
	_glow.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 5.0))
	_light.light_energy = 0.25 + 0.9 * k


func _physics_process(_delta: float) -> void:
	if state != "dropped":
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.dead or p.grabbed or p.moves.busy():
		return
	var d := p.global_position - global_position
	if Vector2(d.x, d.z).length() < PICK_RANGE and absf(d.y) < 1.2:
		take(p)


## Ela pegou: some do chão, vai para o bolso dela e avisa (`picked`).
func take(p: Player) -> void:
	state = "taken"
	_show(false)
	p.add_key(id)
	picked.emit(self)


## Reinício: volta a ficar com o dono.
func reset() -> void:
	state = "hidden"
	_show(false)
