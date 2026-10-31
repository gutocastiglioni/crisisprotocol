class_name Door
extends StaticBody3D
## Porta fechada entre duas salas (galpão -> pátio, pátio -> pedreira). Fechada, bloqueia o corpo (camada 1: tiro,
## visão e passo dos inimigos) e o barulho/alarme não passa (ver Level.connected). Ela chega perto e aperta interagir
## (E / triângulo, `Player.pick_door`): as folhas (`add_panel`) se movem e a colisão some. `room` = a sala de baixo da
## porta (a porta liga `room` e `room + 1`; 0 = galpão, 1 = pátio, 2 = pedreira).

const OPEN_TIME := 0.9
const REACH := 2.6  # distância no chão até o centro da porta para poder abrir
const REACH_DY := 1.5  # diferença de altura máxima entre os pés dela e o pé da porta

var room := 0
var opened := false
var verb := "ABRIR PORTA"
var lock := ""  # id da chave/keycard necessária para abrir
var is_locked_door := false
var code := ""  # código do teclado (add_keypad); vazio = abre só com a chave/cartão
var _col: CollisionShape3D
var _panels: Array[Dictionary] = []
var _tween: Tween
var _reader: Node3D
var _reader_led: MeshInstance3D
var _reader_mat: StandardMaterial3D
var _reader_light: OmniLight3D
var _keypad: Node3D
var _keypad_screen: StandardMaterial3D


## Porta com o vão de tamanho `size`, com o centro do pé do vão em `pos` (as folhas, filhas dela, partem do chão).
static func create(parent: Node, pos: Vector3, size: Vector3, of_room: int, text: String) -> Door:
	var d := Door.new()
	d.room = of_room
	d.verb = text
	d.collision_layer = 1
	d.collision_mask = 0
	d.set_meta("surface", "metal")
	d.set_meta("no_decals", true)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y * 0.5
	d._col = col
	d.add_child(col)
	d.add_to_group("doors")
	parent.add_child(d)
	d.position = pos
	return d


## Adiciona um leitor de cartão de acesso por aproximação (RFID) junto à porta/portão.
func add_card_reader(local_pos: Vector3, rot_y: float = 0.0) -> void:
	_reader = Node3D.new()
	_reader.position = local_pos
	_reader.rotation.y = rot_y
	add_child(_reader)

	# Gabinete do leitor
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.08, 0.22, 0.14)
	body.mesh = bb
	var m_body := StandardMaterial3D.new()
	m_body.albedo_color = Color(0.18, 0.2, 0.24)
	m_body.roughness = 0.5
	body.material_override = m_body
	_reader.add_child(body)

	# Placa do sensor RFID (área de toque do cartão)
	var sensor := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.084, 0.12, 0.11)
	sensor.mesh = sb
	var m_sensor := StandardMaterial3D.new()
	m_sensor.albedo_color = Color(0.08, 0.09, 0.12)
	m_sensor.roughness = 0.2
	sensor.material_override = m_sensor
	sensor.position = Vector3(0, -0.02, 0)
	_reader.add_child(sensor)

	# Barra de LED de status (vermelho trancado / verde liberado)
	_reader_led = MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.086, 0.024, 0.09)
	_reader_led.mesh = lb
	_reader_mat = StandardMaterial3D.new()
	_reader_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reader_mat.albedo_color = Color(1.0, 0.15, 0.15) if is_locked_door else Color(0.2, 1.0, 0.3)
	_reader_led.material_override = _reader_mat
	_reader_led.position = Vector3(0, 0.07, 0)
	_reader.add_child(_reader_led)

	# Luz emitida pelo LED
	_reader_light = OmniLight3D.new()
	_reader_light.light_color = Color(1.0, 0.15, 0.15) if is_locked_door else Color(0.2, 1.0, 0.3)
	_reader_light.light_energy = 0.8
	_reader_light.omni_range = 1.2
	_reader_light.position = local_pos + Vector3(0.05, 0.07, 0)
	add_child(_reader_light)


## Teclado numérico com leitor de cartão ao lado do vão (`local_pos` no espaço da porta; +Z local do painel = para quem
## digita): caixa de aço, visor (apagado até o cartão ligar o painel), 12 teclas, fenda do cartão e o LED de trancado/aberto.
func add_keypad(local_pos: Vector3, rot_y: float = 0.0) -> void:
	_keypad = Node3D.new()
	_keypad.position = local_pos
	_keypad.rotation.y = rot_y
	add_child(_keypad)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.34, 0.36)
	steel.metallic = 0.5
	steel.roughness = 0.5
	_kp_box(Vector3(0.26, 0.38, 0.06), Vector3.ZERO, steel)
	_keypad_screen = StandardMaterial3D.new()
	_keypad_screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_keypad_screen.albedo_color = Color(0.05, 0.08, 0.06)
	_kp_box(Vector3(0.18, 0.06, 0.01), Vector3(0, 0.13, 0.032), _keypad_screen)
	var key_mat := StandardMaterial3D.new()
	key_mat.albedo_color = Color(0.75, 0.75, 0.7)
	key_mat.roughness = 0.6
	for row in 4:
		for col in 3:
			_kp_box(Vector3(0.045, 0.035, 0.016), Vector3((col - 1) * 0.06, 0.055 - row * 0.05, 0.034), key_mat)
	# leitor de cartão: moldura escura com a fenda (o cartão entra de pé)
	var slot := StandardMaterial3D.new()
	slot.albedo_color = Color(0.1, 0.11, 0.12)
	slot.roughness = 0.4
	_kp_box(Vector3(0.05, 0.075, 0.016), Vector3(0.09, -0.13, 0.034), slot)
	var slit := StandardMaterial3D.new()
	slit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slit.albedo_color = Color(0.01, 0.01, 0.01)
	_kp_box(Vector3(0.008, 0.058, 0.004), Vector3(0.09, -0.13, 0.043), slit)
	_reader_mat = StandardMaterial3D.new()
	_reader_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reader_mat.albedo_color = Color(1.0, 0.15, 0.15) if is_locked_door else Color(0.2, 1.0, 0.3)
	_reader_led = _kp_box(Vector3(0.03, 0.03, 0.01), Vector3(-0.1, -0.13, 0.034), _reader_mat)
	_reader_light = OmniLight3D.new()
	_reader_light.light_color = _reader_mat.albedo_color
	_reader_light.light_energy = 0.35
	_reader_light.omni_range = 0.6
	_reader_light.position = Vector3(-0.1, -0.13, 0.08)  # na frente do LED: tinge o pilar, não o painel todo
	_keypad.add_child(_reader_light)


func _kp_box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	_keypad.add_child(mi)
	return mi


## Câmera da tela do teclado: de frente para o painel, um pouco acima.
func keypad_view() -> Transform3D:
	var c := _keypad.global_position
	var n := _keypad.global_basis.z
	var eye := c + n * 0.95 + Vector3.UP * 0.05
	# um pouco mais longe e olhando abaixo do meio: o painel inteiro (visor no alto, fenda do cartão embaixo) fica acima da
	# caixa de texto
	return Transform3D(Basis.looking_at(c + Vector3.DOWN * 0.1 - eye), eye)


## Visor do teclado aceso (o cartão ligou o painel) ou apagado.
func keypad_power(on: bool) -> void:
	if _keypad_screen:
		_keypad_screen.albedo_color = Color(0.3, 1.0, 0.45) if on else Color(0.05, 0.08, 0.06)


func is_locked() -> bool:
	return is_locked_door and not opened and lock != ""


func unlock(_p: Player = null) -> void:
	if not is_locked():
		open()
		return
	is_locked_door = false
	if _reader_mat:
		_reader_mat.albedo_color = Color(0.2, 1.0, 0.3)
	if _reader_light:
		_reader_light.light_color = Color(0.2, 1.0, 0.3)
	if is_inside_tree() and code == "":
		Sfx.ui(self, "unlock")  # o teclado já tocou o dele (keypad_ok)
	open()


func deny(_p: Player = null) -> void:
	if is_inside_tree():
		Sfx.ui(self, "lock_rattle")
	if _reader_mat:
		var tw := create_tween()
		tw.tween_property(_reader_mat, "albedo_color", Color(1.0, 0.9, 0.9), 0.08)
		tw.tween_property(_reader_mat, "albedo_color", Color(1.0, 0.15, 0.15), 0.15)


## Folha que se move ao abrir: `node` (filho da porta, na pose fechada) vai para `open_pos` / `open_rot_y` (locais).
func add_panel(node: Node3D, open_pos: Vector3, open_rot_y: float) -> void:
	add_child(node)
	_panels.append({"node": node, "pos": node.position, "rot": node.rotation.y, "open_pos": open_pos, "open_rot": open_rot_y})


## Está ao alcance de quem está em `p` (para o aviso e para abrir).
func can_open(p: Vector3) -> bool:
	if opened:
		return false
	var d := p - global_position
	if absf(d.y) > REACH_DY:
		return false  # em outro andar (no telhado, em cima da porta)
	d.y = 0.0
	return d.length() < REACH


func open() -> void:
	if opened:
		return
	opened = true
	collision_layer = 0
	_col.set_deferred("disabled", true)
	if _reader_mat:
		_reader_mat.albedo_color = Color(0.2, 1.0, 0.3)
	if _reader_light:
		_reader_light.light_color = Color(0.2, 1.0, 0.3)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for pn in _panels:
		_tween.tween_property(pn.node, "position", pn.open_pos, OPEN_TIME)
		_tween.tween_property(pn.node, "rotation:y", pn.open_rot, OPEN_TIME)
	if is_inside_tree():
		Sfx.play(self, "chest_open", global_position + Vector3.UP * 1.2, 2.0, 0.6)


## Fecha de novo, de uma vez (ao reiniciar).
func reset() -> void:
	if _tween:
		_tween.kill()
	opened = false
	if lock != "":
		is_locked_door = true
		if _reader_mat:
			_reader_mat.albedo_color = Color(1.0, 0.15, 0.15)
		if _reader_light:
			_reader_light.light_color = Color(1.0, 0.15, 0.15)
	keypad_power(false)
	collision_layer = 1
	_col.set_deferred("disabled", false)
	for pn in _panels:
		pn.node.position = pn.pos
		pn.node.rotation.y = pn.rot


## A porta que liga a sala `a` à sala `a + 1` está aberta?
static func is_open(tree: SceneTree, a: int) -> bool:
	for d: Door in tree.get_nodes_in_group("doors"):
		if d.room == a:
			return d.opened
	return true  # sem porta nessa divisa (cena de teste): aberto
