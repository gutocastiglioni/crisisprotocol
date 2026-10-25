class_name Hatch
extends Node3D
## Alçapão no telhado do galpão (canto do fundo à direita), por onde ela entra na fase: moldura baixa em volta do
## buraco, tampa de aço com alça e dobradiça do lado da parede, e a escada (Ladder) que desce até o chão do galpão.
## A escada fica na beira do furo do lado de quem chega (sem vão entre ela e onde ela ajoelha), afastada da parede do
## fundo e presa nela por suportes: na escada ela fica entre a escada e a parede, de frente para os degraus.
## Fechado, a escada não deixa montar pelo topo. Ela ajoelha na frente (`kneel_point`, interagir: PlayerMoves.start_hatch)
## e a animação HatchOpen levanta a tampa (`open`, de GRAB a UP da animação, ver art/heroine_cutscene.py).
## O nó fica no canto do furo junto à parede, no chão; o furo vai de z local -HOLE.y até 0 (a parede).

const HOLE := Vector2(1.1, 1.05)  # largura (X) e fundo (Z) do furo
const CURB_H := 0.12  # rebordo baixo: ela passa por cima com um passo, sem pular
const CURB_T := 0.12
const LID_T := 0.06
const OPEN_ANGLE := 88.0  # em pé, encostada no parapeito
const FPS := 30.0
const GRAB_FRAME := 26.0  # = heroine_cutscene.HATCH_GRAB
const UP_FRAME := 50.0  # = heroine_cutscene.HATCH_UP
const LET_GO_FRAME := 38.0  # = heroine_cutscene.HATCH_LET_GO (até aqui as mãos seguem a alça)
const ANIM_FRAMES := 66.0  # = heroine_cutscene.HATCH_FRAMES
const LADDER_INSET := 0.07  # da beira do furo (lado de quem chega) até a escada
const KNEEL_DIST := 0.5  # da escada até onde ela ajoelha (e sai ao subir), no telhado
const BRACKETS := [2.2, 3.6, 4.8]  # alturas dos suportes até a parede (acima da cabeça de quem passa embaixo)
const REACH := 0.8
const HANDLE := Vector3(0, LID_T * 0.5 + 0.03, -(HOLE.y + CURB_T) + 0.08)  # centro da alça, em relação à dobradiça
const HIDDEN_RUNGS := 3  # degraus que ela desce, depois de agarrar a escada, antes de o mezanino poder vê-la

var ladder: Ladder
var opened := false
var _hinge: Node3D
var _tween: Tween


func _ready() -> void:
	add_to_group("hatches")
	ladder = Ladder.new()
	ladder.height = Roof.Y
	ladder.top_exit = KNEEL_DIST
	ladder.top_open = false
	ladder.handrail = CURB_H - 0.05
	ladder.top_lip = CURB_H
	ladder.hidden_top = HIDDEN_RUNGS * Ladder.RUNG_SPACING
	# degraus virados para a parede: quem desce fica entre a escada e a parede
	ladder.position = Vector3(0, 0, -HOLE.y + LADDER_INSET)
	ladder.rotation.y = PI
	add_child(ladder)
	_build_brackets()
	_build_frame()
	_build_lid()
	_build_light()


## Moldura em volta do furo nos três lados abertos (o quarto é o parapeito da parede).
func _build_frame() -> void:
	var y := Roof.Y + CURB_H * 0.5
	var near_z := -HOLE.y - CURB_T * 0.5  # o furo vai de -HOLE.y até a parede (z local 0)
	var side_x := HOLE.x * 0.5 + CURB_T * 0.5
	Level.block(self, Vector3(HOLE.x + CURB_T * 2.0, CURB_H, CURB_T), Vector3(0, y, near_z), "wall", 1.0)
	for s in [-1, 1]:
		Level.block(self, Vector3(CURB_T, CURB_H, HOLE.y), Vector3(s * side_x, y, -HOLE.y * 0.5), "wall", 1.0)


func _build_lid() -> void:
	# dobradiça na beira do lado da parede; a tampa deita na direção de quem chega (-Z)
	_hinge = Node3D.new()
	_hinge.position = Vector3(0, Roof.Y + CURB_H + LID_T * 0.5, 0)
	add_child(_hinge)
	var lid := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(HOLE.x + CURB_T * 2.0, LID_T, HOLE.y + CURB_T)
	lid.mesh = box
	# UV da própria malha: a tampa gira e as listras vão junto
	var paint := Level.material("hazard", 1.2)
	paint.set_shader_parameter("world_uv", false)
	lid.material_override = paint
	lid.position = Vector3(0, 0, -(HOLE.y + CURB_T) * 0.5)
	_hinge.add_child(lid)
	# alça na beira de quem chega (a animação HatchOpen segura nela: heroine_cutscene.handle_at)
	var handle := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.36, 0.05, 0.05)
	handle.mesh = hb
	handle.material_override = Level.material("wall", 2.0)
	handle.position = HANDLE
	_hinge.add_child(handle)


## Suportes das longarinas até a parede do fundo (só desenho: ficam acima da cabeça dela).
func _build_brackets() -> void:
	var mat := Level.material("wall", 2.0)
	var reach := HOLE.y - LADDER_INSET
	for y in BRACKETS:
		for s in [-1, 1]:
			var bar := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.05, 0.05, reach)
			bar.mesh = b
			bar.material_override = mat
			bar.position = Vector3(s * ladder.width * 0.5, y, -reach * 0.5)
			add_child(bar)


## Lâmpada fraca num poste ao lado: o único ponto claro do telhado.
func _build_light() -> void:
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.035
	c.height = 1.6
	pole.mesh = c
	pole.material_override = Level.material("wall", 2.0)
	pole.position = Vector3(-HOLE.x * 0.5 - 0.5, Roof.Y + 0.8, -0.2)
	add_child(pole)
	var cage := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.18, 0.12, 0.18)
	cage.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.5)
	cage.material_override = m
	cage.position = pole.position + Vector3.UP * 0.86
	add_child(cage)
	var o := OmniLight3D.new()
	o.position = cage.position + Vector3(0, -0.05, -0.3)
	o.light_color = Color(1.0, 0.78, 0.5)
	o.light_energy = 1.4
	o.omni_range = 6.0
	o.add_to_group("lamps")
	add_child(o)


## Onde ela ajoelha para abrir (no telhado, na beira do furo onde está a escada) e a direção em que olha (para o furo).
func kneel_point() -> Vector3:
	return ladder.top_stand


## Centro da alça no mundo (gira com a tampa).
func handle_point() -> Vector3:
	return _hinge.global_transform * HANDLE


func facing() -> Vector3:
	return ladder.ladder_out


func can_open(p: Vector3) -> bool:
	if opened:
		return false
	var d := p - kneel_point()
	return absf(d.y) < 0.5 and Vector2(d.x, d.z).length() < REACH


## Levanta a tampa (o tempo é o da animação entre pegar a alça e a tampa ficar em pé) e libera a escada.
func open(duration := (UP_FRAME - GRAB_FRAME) / FPS) -> void:
	if opened:
		return
	opened = true
	ladder.top_open = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_hinge, "rotation:x", deg_to_rad(OPEN_ANGLE), duration)
	if is_inside_tree():
		Sfx.play(self, "chest_open", _hinge.global_position, 0.0, 0.7)


func is_open_fully() -> bool:
	return opened and (_tween == null or not _tween.is_running())


## Fecha de novo (reinício: ela volta para o telhado).
func reset() -> void:
	if _tween:
		_tween.kill()
	opened = false
	ladder.top_open = false
	_hinge.rotation.x = 0.0
