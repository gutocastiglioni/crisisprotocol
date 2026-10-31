class_name KeyItem
extends Node3D
## Chave escondida com alguém (TargetDummy.loot): some até ele morrer; aí cai no chão onde ele estava (`drop`) e fica
## brilhando (estrela de 4 pontas que pisca de tempos em tempos, com uma luzinha) para ser vista de longe. Ela chegando
## perto (PICK_RANGE), pega sozinha: a chave vai para o bolso (`Player.add_key(id)`) e o sinal `picked` faz o main
## mostrar o item na tela (Inspect.show_item). Abre o baú com `Chest.lock` igual ao `id`. Reinício: volta a ficar escondida.
## Na mão de um morto (`hold`, Corpse): aparece parada onde ele a segura e se pega igual; `shine` desligado = sem a
## estrela nem a luz (a do guerrilheiro só brilha depois que os raptors da emboscada morrem).

signal picked(key: KeyItem)

const PICK_RANGE := 1.2
const WORLD_SCALE := 1.6  # maior que a de verdade: no chão do galpão escuro precisa aparecer
const FALL_TIME := 0.45
const TWINKLE := 1.3  # s entre uma piscada e outra
const BRASS := Color(0.85, 0.66, 0.26)
const TAG := Color(0.75, 0.12, 0.1)
const TAG_INK := Color(0.08, 0.04, 0.03)
const CARD_BLUE := Color(0.12, 0.22, 0.38)  # azul tático (cartão do galpão)
const SPARKLE := preload("res://shaders/sparkle.gdshader")

@export var id := "container"
@export var kind := "key"  # "key" ou "keycard"
@export var display_name := "CHAVE DO CONTAINER"
@export var description := "Chave de latão com etiqueta vermelha.\nAbre o cadeado de algum container."
## escrito na etiqueta vermelha da chave (vazio = etiqueta lisa)
@export var tag := ""
## cor do plástico do cartão (keycard)
@export var card_color := CARD_BLUE

## "hidden" (com o dono), "dropping" (caindo), "dropped" (no chão, brilhando), "held" (na mão de um morto) ou "taken"
var state := "hidden"
## brilha (estrela e luz) no chão ou na mão; desligado, fica só a chave
var shine := true:
	set(v):
		shine = v
		if _light:
			_show(visible)
var _model: Node3D
var _sparkle: MeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0


## Malha da chave ou keycard (deitada no plano XZ), usada no chão e na tela do item. `tag_text` vai escrito na etiqueta
## da chave; `color` é o plástico do cartão.
static func build_model(parent: Node3D, item_kind := "key", tag_text := "", color := CARD_BLUE) -> Node3D:
	if item_kind == "keycard":
		return build_keycard_model(parent, color)
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
	if tag_text != "":
		tb.size = Vector3(0.036, 0.003, 0.02)  # escrita: cabe o texto
		tag.position = Vector3(-0.066, 0, 0.004)
		var ink := Label3D.new()
		ink.text = tag_text
		ink.font_size = 32
		ink.outline_size = 0
		ink.pixel_size = 0.00042
		ink.modulate = TAG_INK
		ink.shaded = true
		ink.rotation.x = -PI * 0.5  # deitado na face de cima da etiqueta
		ink.position.y = 0.0016
		tag.add_child(ink)
	return root


## Malha 3D do cartão de acesso por aproximação (Keycard magnético/RFID), com o plástico na cor `color`.
static func build_keycard_model(parent: Node3D, color := CARD_BLUE) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	# Corpo plástico do cartão (proporção ID-1: 85,6 x 54 mm)
	var card_mat := StandardMaterial3D.new()
	card_mat.albedo_color = color
	card_mat.roughness = 0.45
	var card := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.086, 0.003, 0.054)
	card.mesh = cb
	card.material_override = card_mat
	root.add_child(card)

	# Faixa magnética escura
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.08, 0.08, 0.08)
	stripe_mat.roughness = 0.3
	var stripe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.0862, 0.0032, 0.011)
	stripe.mesh = sb
	stripe.material_override = stripe_mat
	stripe.position = Vector3(0, 0, -0.015)
	root.add_child(stripe)

	# Faixa vermelha de nível de acesso (Level 1 Clearance)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.85, 0.16, 0.14)
	bar_mat.roughness = 0.4
	var bar := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.0862, 0.0032, 0.007)
	bar.mesh = bb
	bar.material_override = bar_mat
	bar.position = Vector3(0, 0, 0.02)
	root.add_child(bar)

	# Chip de contato dourado
	var chip_mat := StandardMaterial3D.new()
	chip_mat.albedo_color = Color(0.88, 0.74, 0.24)
	chip_mat.metallic = 0.8
	chip_mat.roughness = 0.25
	var chip := MeshInstance3D.new()
	var chip_box := BoxMesh.new()
	chip_box.size = Vector3(0.014, 0.0033, 0.012)
	chip.mesh = chip_box
	chip.material_override = chip_mat
	chip.position = Vector3(-0.018, 0, 0.002)
	root.add_child(chip)

	# Painel de identificação / foto
	var id_mat := StandardMaterial3D.new()
	id_mat.albedo_color = Color(0.82, 0.86, 0.9)
	id_mat.roughness = 0.6
	var id_box := MeshInstance3D.new()
	var ib := BoxMesh.new()
	ib.size = Vector3(0.022, 0.0033, 0.02)
	id_box.mesh = ib
	id_box.material_override = id_mat
	id_box.position = Vector3(0.022, 0, 0.002)
	root.add_child(id_box)

	return root


func _ready() -> void:
	add_to_group("keys")
	_model = build_model(self, kind, tag, card_color)
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


## Estrela de 4 pontas (o clarão de shot_fx.png) virada para a câmera, somando luz. Parede ou caixa na frente esconde
## (sparkle.gdshader puxa só a profundidade um pouco para a câmera: não corta no chão nem some sob o corpo caído).
func _star(size: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SPARKLE
	m.set_shader_parameter("sprites", Fx.SPRITES)
	m.set_shader_parameter("color", color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.12
	add_child(mi)
	return mi


func _show(on: bool) -> void:
	visible = on
	_light.visible = on and state in ["dropped", "held"] and shine


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


## Na mão de um morto, em `xf` (no tamanho do chão: precisa aparecer no punho fechado).
func hold(xf: Transform3D) -> void:
	state = "held"
	global_transform = xf
	_model.scale = Vector3.ONE * WORLD_SCALE
	_model.rotation.y = 0.0
	_model.position.y = 0.0
	_t = 0.0
	_show(true)


## Brilho da estrela (0..1) agora: uma piscada forte a cada TWINKLE s.
func twinkle() -> float:
	return pow(maxf(0.0, sin(_t * TAU / TWINKLE)), 6.0)


func _process(delta: float) -> void:
	if not state in ["dropped", "held"] or not shine:
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


## Está ao alcance de quem está em `pos` para pegar com o botão de interação.
func can_pick(pos: Vector3) -> bool:
	if not state in ["dropped", "held"]:
		return false
	var d := pos - global_position
	return Vector2(d.x, d.z).length() < PICK_RANGE and absf(d.y) < 1.4


## Ela pegou: some do chão, vai para o bolso dela e avisa (`picked`).
func take(p: Player) -> void:
	state = "taken"
	_show(false)
	p.add_key(id)
	picked.emit(self)


## Reinício: volta a ficar com o dono.
func reset() -> void:
	state = "hidden"
	global_basis = Basis.IDENTITY
	_model.scale = Vector3.ONE * WORLD_SCALE
	_model.position.y = 0.006
	_show(false)
