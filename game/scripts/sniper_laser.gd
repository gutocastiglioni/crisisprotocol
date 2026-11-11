class_name SniperLaser
extends Node3D
## Mira laser do sniper (jeito Syphon Filter): feixe vermelho do cano até onde bate, com um ponto brilhante lá e um
## brilho no cano. O feixe (`shaders/sniper_laser.gdshader`) é uma fita virada para a câmera que nunca fica mais fina que
## alguns pixels da tela (a caixa de 1,5 cm de antes sumia na resolução interna), com núcleo claro e halo; o ponto
## (`shaders/laser_dot.gdshader`) também tem tamanho mínimo na tela e acende uma luzinha vermelha no que bate (o corpo
## dela). `point(cano, alvo, força)` pinta o feixe até `alvo` ou até o primeiro cenário no caminho (camada 1); `off()`
## apaga. Fica fora da árvore de transformação de quem o usa (`top_level`): tudo em coordenadas do mundo.

const BEAM := preload("res://shaders/sniper_laser.gdshader")
const DOT := preload("res://shaders/laser_dot.gdshader")
const COLOR := Color(1.0, 0.08, 0.05)
const DOT_LIGHT := 0.35  # energia da luzinha no ponto (força 1)
const DOT_RANGE := 0.3  # só a roupa em volta do ponto (mais que isto pintava o rosto dela de vermelho)

var beam: MeshInstance3D
var dot: MeshInstance3D
var glint: MeshInstance3D  # brilho na boca do cano
var light: OmniLight3D
var end := Vector3.ZERO  # onde o feixe bateu (mundo)
var hit_body: Object  # o que estava no caminho (null = chegou ao alvo)
var exclude: Array[RID] = []  # corpos que o feixe atravessa (os mesmos do tiro: Sniper.see_through)
var _beam_mat: ShaderMaterial
var _dot_mat: ShaderMaterial
var _glint_mat: ShaderMaterial


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_beam_mat = _mat(BEAM)
	beam = _quad(_beam_mat)
	_dot_mat = _mat(DOT)
	dot = _quad(_dot_mat)
	_glint_mat = _mat(DOT)
	_glint_mat.set_shader_parameter("size", 0.03)
	_glint_mat.set_shader_parameter("min_px", 4.0)
	_glint_mat.set_shader_parameter("lift", 0.0)
	glint = _quad(_glint_mat)
	light = OmniLight3D.new()
	light.light_color = COLOR
	light.omni_range = DOT_RANGE
	light.shadow_enabled = false
	add_child(light)
	off()


func _mat(sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", COLOR)
	return m


func _quad(m: ShaderMaterial) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mi)
	return mi


## Feixe do cano `from` até `to` (ou até o cenário no meio), com força 0..1 (acender, pisca-pisca do tiro). `short` =
## m antes de `to` em que o feixe para quando chega lá (`to` no meio do peito: o ponto fica na frente da roupa).
func point(from: Vector3, to: Vector3, strength := 1.0, short := 0.0) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = exclude
	var block := space.intersect_ray(q)
	end = block.position if not block.is_empty() else to - (to - from).normalized() * short
	hit_body = block.collider if not block.is_empty() else null
	if from.distance_to(end) < 0.05:
		off()
		return
	visible = true
	_beam_mat.set_shader_parameter("start", from)
	_beam_mat.set_shader_parameter("end", end)
	_beam_mat.set_shader_parameter("strength", strength)
	# a fita é montada no shader: a caixa de corte precisa cobrir do cano ao fim (com folga para a largura)
	var box := AABB(from, Vector3.ZERO).expand(end).grow(0.3)
	beam.custom_aabb = box
	dot.global_position = end
	_dot_mat.set_shader_parameter("strength", strength)
	glint.global_position = from
	_glint_mat.set_shader_parameter("strength", strength * 0.8)
	var back := (from - end).normalized()
	light.global_position = end + back * 0.12
	light.light_energy = DOT_LIGHT * strength


func off() -> void:
	visible = false
	hit_body = null
