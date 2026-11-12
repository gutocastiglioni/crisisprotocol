class_name Shed
extends Node
## Galpão em seções furtivas (jeito Syphon Filter), separadas por grade de alambrado do chão até `FENCE_H` (na
## `Yard.GRATE_LAYER`: segura ela e os guardas, deixa passar tiro, vista e som). Cada passagem abre por um objetivo:
##   1 labirinto  →  2 faixa do painel (o guarda do painel, Soldier.GUARDS 12; o sniper no mezanino com o cartão)
##   2 → 3 meio + ala da M16: a grade `MID_GATE` destrava quando ela usa o computador do painel (`Terminal`, `PANEL_USE`)
##   3 → 4 sala dos clones (doca, portão de enrolar): guardas examinando o tanque vazio do alossauro e mexendo no
##       computador do laboratório (`LAB_GUARDS`)
##   4 → 5 canto da porta do pátio: a grade `CORNER_GATE` (no vão leste das caixas do canto) destrava pelo computador do
##       laboratório (`LAB_USE`); os outros vãos do canto ficam fechados por grade (`CORNER_FENCES`) e as caixas das paredes
##       do canto não se escalam (`sealed_crate`: meta "no_climb", não dá para subir e pular para dentro).
## Com o portão do canto fechado, o canto é outro lugar para quem está nele (`apart`): os guardas de dentro não a veem lá
## fora nem ouvem tiro/grito/alarme de fora (e vice-versa); o tiroteio no meio ou na ala da M16 não chega até eles.
## Portões (`grate_gate`): grade pintada de amarelo com moldura, faixa de perigo e lampião (vermelho travado / verde).
## Guarda andando até um portão fechado (busca, volta ao posto) o abre, travado ou não (`GUARD_OPEN`), e ele fecha
## sozinho `AUTO_CLOSE` s depois de o vão ficar livre; travado continua travado. Destravado pelo computador, fica destravado.
## Reforços (só nas duas últimas, 4 e 5): com alarme vermelho na seção (alguém dela em luta com ela ali), entra uma leva de
## `WAVE` guardas pela porta de serviço da seção (`SERVICE`: uma saleta fechada atrás da parede) `WAVE_DELAY` s depois; se
## o alarme vermelho seguir (ela ainda na seção, alguém dela em luta com ela) `SECOND_AFTER` s depois da primeira, entra a
## segunda (2 levas por seção). Quem chega
## corre para onde ela foi vista e fica na seção procurando.
## `Shed.build` monta a geometria (chamado pelo Level); o nó (criado pelo main) cuida dos objetivos e dos reforços.

signal objective(id: String)  # "panel" (grade do meio destravou), "lab" (o canto da porta do pátio destravou)

const FENCE_H := 3.6  # acima do alcance do pulo de qualquer pilha que ela escala perto das grades (2,4 m + 0,65)
const BAR_STEP := 0.14  # alambrado: uma barra fina a cada BAR_STEP m
const FENCE_A_Z := 3.0  # grade entre a faixa do painel (2) e o meio (3), de parede a parede
const MID_GATE := Vector3(7.0, 0, FENCE_A_Z)  # vão da grade do meio (na frente da ronda 8)
const GATE_W := 1.8
const GATE_H := 2.6
## Canto da porta do pátio: grade nos vãos das paredes de caixas (o do sul e a quina perto da coluna (-5; -4): da caixa
## baixa da ponta da parede do sul até a coluna e da coluna até a caixa da ponta da parede leste, por fora da rota da ronda
## 8); o vão leste (z = -8,4) vira o portão `CORNER_GATE`.
const CORNER_FENCES := [[Vector2(-9.19, 0.4), Vector2(-7.61, 0.4)], [Vector2(-6.41, -0.21), Vector2(-5.45, -3.6)],
	[Vector2(-5.4, -4.45), Vector2(-4.36, -5.5)]]
const CORNER_GATE := Vector3(-3.75, 0, -8.4)
## Pilhas altas (2 caixas) dentro do canto, na frente do portão: tapam a vista dos guardas do canto pelo portão até a ala
## da M16; passa-se por cima (norte) ou por baixo (sul) delas.
const CORNER_SCREEN := [Vector2(-6.2, -7.8), Vector2(-6.2, -9.02)]
## Contorno do canto (x, z): parede de caixas do sul, grades da quina passando pela coluna, parede leste com o portão e o
## fundo do galpão (com a saleta de serviço).
const CORNER_AREA := [Vector2(-13.5, 0.4), Vector2(-6.41, 0.4), Vector2(-6.41, -0.21), Vector2(-5.45, -3.6),
	Vector2(-5.0, -4.0), Vector2(-4.36, -5.5), Vector2(-3.75, -5.5), Vector2(-3.75, -16.0), Vector2(-13.5, -16.0)]
const GUARD_OPEN := 1.3  # guarda a até isto do meio do portão fechado, andando para ele: abre
const AUTO_CLOSE := 3.0  # aberto por guarda: fecha isto depois de ninguém estar no vão
const DOORWAY := 1.1  # alguém a até isto do meio do portão = no vão (não fecha)
const GATE_PAINT := Color(2.2, 1.6, 0.25)  # tinta amarela dos portões (tint do material, acima de 1: a textura base é cinza escuro)
const CORNER_GATE_W := 1.58
## Onde ela fica para usar cada computador: [ponto no chão, giro dela de frente para a tela].
const PANEL_USE := [Vector3(Level.CONSOLE.x + 0.75, 0, Level.CONSOLE.z), PI * 0.5]
const LAB_USE := [Vector3(0.0, CloneLab.FLOOR_Y, CloneLab.Z_FAR + 1.75), 0.0]
## Guardas da sala dos clones (mesmo formato de Soldier.GUARDS): 2 examinando o tanque vazio e 1 no computador do fundo,
## distraídos (de costas, não veem nada até o barulho os tirar dali), e 1 de ronda no corredor do meio.
const LAB_GUARDS := [
	{"pos": Vector3(0.0, CloneLab.FLOOR_Y, CloneLab.Z_FAR + 1.75), "rot_y": 0.0, "route": [], "console": true, "weapon": "pistol"},
	{"pos": Vector3(-2.35, CloneLab.FLOOR_Y, -27.7), "rot_y": 0.95, "route": [], "console": true},
	{"pos": Vector3(-4.6, CloneLab.FLOOR_Y, -26.7), "rot_y": 0.0, "route": [], "console": true},
	{"route": [Vector3(0.6, CloneLab.FLOOR_Y, -26.6), Vector3(0.6, CloneLab.FLOOR_Y, -21.2), Vector3(-0.6, CloneLab.FLOOR_Y, -21.2),
		Vector3(-0.6, CloneLab.FLOOR_Y, -26.6)]},
]
## Portas de serviço dos reforços: [pé da porta, giro (0 = a porta no plano x, abre para +x), dentro da saleta].
## 0 = sala dos clones (parede leste), 1 = canto da porta do pátio (parede do fundo do galpão).
const SERVICE := [
	{"door": Vector3(CloneLab.HALF_W, CloneLab.FLOOR_Y, -27.6), "yaw": 0.0, "room": Vector3(CloneLab.HALF_W + 1.4, CloneLab.FLOOR_Y, -27.6)},
	{"door": Vector3(-10.5, 0, -Level.SIZE * 0.5), "yaw": PI * 0.5, "room": Vector3(-10.5, 0, -Level.SIZE * 0.5 - 1.4)},
]
const SERVICE_W := 1.2
const SERVICE_H := 2.3
const WAVE := 3
const WAVES := 2
const WAVE_DELAY := 1.5
const WAVE_STAGGER := 0.5
const SECOND_AFTER := 10.0

var player: Player
var mid_gate: Door
var corner_gate: Door
var service_doors: Array[Door] = []
var panel: Terminal
var lab_panel: Terminal
var lab_guards: Array[Soldier] = []
var corner_guards: Array[Enemy] = []  # os de Soldier.GUARDS que ficam no canto da porta do pátio (seção 5)
var reinforcements: Array = [[], []]  # Array[Soldier] por seção (0 = sala dos clones, 1 = canto da porta do pátio)
var waves_sent: Array[int] = [0, 0]
var _red_t: Array[float] = [-1.0, -1.0]  # >= 0: contando para a primeira leva
var _wave_at: Array[float] = [-INF, -INF]  # relógio da última leva
var _pending: Array[Dictionary] = []  # {"s": Soldier, "t": s até entrar, "at": onde ela foi vista}
var _clock := 0.0
var _guard_opened := {}  # Door -> s desde que o vão ficou livre (aberto por guarda; fecha em AUTO_CLOSE)


# ------------------------------------------------------------------ geometria
## Grades, portões e saletas de serviço (o Level chama depois das caixas). Devolve {"mid", "corner", "service"}.
static func build(parent: Node) -> Dictionary:
	var g0 := MID_GATE
	var hw := GATE_W * 0.5 + 0.12
	fence(parent, Vector2(-Level.SIZE * 0.5 + 0.2, FENCE_A_Z), Vector2(g0.x - hw, FENCE_A_Z), 0.0)
	fence(parent, Vector2(g0.x + hw, FENCE_A_Z), Vector2(Level.SIZE * 0.5 - 0.2, FENCE_A_Z), 0.0)
	var mid := grate_gate(parent, MID_GATE, GATE_W, PI * 0.5)
	for f: Array in CORNER_FENCES:
		fence(parent, f[0], f[1], 0.0)
	for c: Vector2 in CORNER_SCREEN:
		for k in [0, 1]:
			var crate := Level.block(parent, Vector3(1.22, 1.22, 1.22), Vector3(c.x, 0.61 + k * 1.22, c.y), "crate", 1.0 / 1.22, 0.02 - k * 0.05)
			crate.set_meta("no_climb", true)
	var corner := grate_gate(parent, CORNER_GATE, CORNER_GATE_W, 0.0)
	var doors: Array[Door] = []
	for sv: Dictionary in SERVICE:
		doors.append(_service(parent, sv))
	return {"mid": mid, "corner": corner, "service": doors}


## Alambrado de `a` até `b` (no chão), de `from_y` até `to_y` (FENCE_H se não der): barras finas (MultiMesh), travessas e o
## corpo na camada da grade.
static func fence(parent: Node, a: Vector2, b: Vector2, from_y: float, to_y := FENCE_H) -> StaticBody3D:
	var d := b - a
	var length := d.length()
	var h := to_y - from_y
	var body := StaticBody3D.new()
	body.collision_layer = Yard.GRATE_LAYER
	body.collision_mask = 0
	body.set_meta("surface", "metal")
	body.set_meta("no_decals", true)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, h, 0.12)
	col.shape = shape
	body.add_child(col)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.03, h, 0.03)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bar
	var n := maxi(int(length / BAR_STEP), 1)
	mm.instance_count = n + 1
	for i in n + 1:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(-length * 0.5 + length * i / float(n), 0, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Level.material("wall", 4.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mmi)
	for y in [-h * 0.5 + 0.06, 0.0, h * 0.5 - 0.06]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(length, 0.05, 0.05)
		rail.mesh = rm
		rail.material_override = Level.material("wall", 2.0)
		rail.position.y = y
		body.add_child(rail)
	parent.add_child(body)
	body.position = Vector3((a.x + b.x) * 0.5, from_y + h * 0.5, (a.y + b.y) * 0.5)
	body.rotation.y = -atan2(d.y, d.x)
	return body


## Portão de grade no alambrado (`yaw` 0 = vão ao longo de z), travado (`Door.held`) com o lampião em cima; fora da
## corrente de salas (room -1). Para achar de longe no meio do alambrado cinza: folhas e batentes pintados de amarelo
## (`GATE_PAINT`), chapa com faixa de perigo embaixo das folhas e na travessa de cima. Acima da travessa, alambrado até FENCE_H.
static func grate_gate(parent: Node, at: Vector3, width: float, yaw: float) -> Door:
	var door := Door.create(parent, at, Vector3(0.2, GATE_H, width), -1, "ABRIR GRADE")
	door.rotation.y = yaw
	door.solid_layer = Yard.GRATE_LAYER
	door.collision_layer = Yard.GRATE_LAYER
	door.held = true
	door.add_status_lamp(Vector3(0.0, GATE_H + 0.42, 0.0))
	var along := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	var a := at - along * (width * 0.5 + 0.12)
	var b := at + along * (width * 0.5 + 0.12)
	fence(parent, Vector2(a.x, a.z), Vector2(b.x, b.z), GATE_H + 0.3)
	var paint := Level.material("wall", 2.0)
	paint.set_shader_parameter("tint", GATE_PAINT)
	var stripes := Level.material("hazard", 1.0)
	stripes.set_shader_parameter("world_uv", false)
	var hw := width * 0.5
	# batentes e travessa de cima (pintados), com a faixa de perigo dos dois lados da travessa
	for s in [-1, 1]:
		_gate_box(door, Vector3(0.12, GATE_H + 0.3, 0.1), Vector3(0, (GATE_H + 0.3) * 0.5, s * (hw + 0.07)), paint)
	_gate_box(door, Vector3(0.12, 0.3, width + 0.24), Vector3(0, GATE_H + 0.15, 0), paint)
	for f in [-1, 1]:
		_gate_box(door, Vector3(0.01, 0.22, width + 0.1), Vector3(f * 0.065, GATE_H + 0.15, 0), stripes)
	var w := hw - 0.02
	for s in [-1, 1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(0, 0, s * hw)
		for y in [0.1, GATE_H * 0.5, GATE_H - 0.06]:
			_gate_box(leaf, Vector3(0.06, 0.06, w), Vector3(0, y, -s * w * 0.5), paint)
		for k in [0, 1]:
			_gate_box(leaf, Vector3(0.06, GATE_H - 0.1, 0.06), Vector3(0, GATE_H * 0.5, -s * w * k), paint)
		var n := int(w / BAR_STEP)
		for k in range(1, n):
			_gate_box(leaf, Vector3(0.03, GATE_H - 0.1, 0.03), Vector3(0, GATE_H * 0.5, -s * w * k / float(n)), paint)
		# chapa com a faixa de perigo embaixo da folha (baixa: não tapa a vista)
		_gate_box(leaf, Vector3(0.04, 0.32, w), Vector3(0, 0.27, -s * w * 0.5), stripes)
		door.add_panel(leaf, leaf.position, s * deg_to_rad(-95.0))
	return door


static func _gate_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## Caixa do divisor (Level.DIVIDERS) que faz parede do canto da porta do pátio (ou encosta nela por fora): não se escala
## (sem a grade por cima, de cima dela ela pularia para dentro do canto).
static func sealed_crate(at: Vector2) -> bool:
	var south := absf(at.y - 0.4) < 0.05 and at.x < -5.0
	var east := absf(at.x + 3.75) < 0.05 and at.y < -5.0
	return south or east or at.distance_to(Vector2(-6.0, 1.6)) < 0.05


## `a` e `b` estão separados pelo portão do canto fechado (um dentro do canto da porta do pátio, o outro fora): nem
## vista nem som nem alarme passa (Enemy._reaches / _sees_target).
static func apart(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
	if Level.room_of(a.x) != 0 or Level.room_of(b.x) != 0:
		return false  # fora do galpão (pátio pela porta do canto, túnel...): vale a corrente de salas e portas
	if in_corner(a) == in_corner(b):
		return false
	var sh := tree.get_first_node_in_group("shed") as Shed
	return sh != null and sh.corner_gate != null and not sh.corner_gate.opened


## Porta de serviço de aço (selada para ela: `Door.sealed`) com a saleta fechada atrás, onde os reforços esperam.
static func _service(parent: Node, sv: Dictionary) -> Door:
	var at: Vector3 = sv.door
	var yaw: float = sv.yaw
	var room: Vector3 = sv.room
	var out := (room - at).normalized()
	var side := out.cross(Vector3.UP)
	# saleta: piso, duas paredes, fundo e teto (2 x 2,4 m)
	var c := at + out * 1.3
	var room_bodies: Array[StaticBody3D] = [Level.block(parent, Vector3(2.6, 0.3, 2.6), c + Vector3(0, -0.15, 0), "concrete", 0.35, yaw)]
	for s in [-1, 1]:
		room_bodies.append(Level.block(parent, Vector3(0.2, SERVICE_H + 0.4, 2.6), c + side * s * 1.3 + Vector3.UP * (SERVICE_H + 0.4) * 0.5, "wall", 0.5, yaw + PI * 0.5))
	room_bodies.append(Level.block(parent, Vector3(2.6, SERVICE_H + 0.4, 0.2), c + out * 1.3 + Vector3.UP * (SERVICE_H + 0.4) * 0.5, "wall", 0.5, yaw + PI * 0.5))
	room_bodies.append(Level.block(parent, Vector3(2.8, 0.2, 2.8), c + Vector3.UP * (SERVICE_H + 0.5), "concrete", 0.35, yaw))
	var door := Door.create(parent, at, Vector3(0.3, SERVICE_H, SERVICE_W), -1, "PORTA")
	# a saleta fica do lado de fora do galpão: de cima do telhado ela aparecia como um bloco cinza solto. Só é
	# desenhada com a porta aberta (`_show_rooms`); a colisão fica sempre (segura os reforços lá dentro).
	var room_meshes: Array[MeshInstance3D] = []
	for b in room_bodies:
		var mi := b.get_child(0) as MeshInstance3D
		mi.visible = false
		room_meshes.append(mi)
	door.set_meta("room_meshes", room_meshes)
	door.rotation.y = yaw
	door.sealed = true
	var slab := Node3D.new()
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, SERVICE_H, SERVICE_W - 0.04)
	m.mesh = bm
	m.material_override = Level.material("wall", 1.5)
	m.position = Vector3(0, SERVICE_H * 0.5, SERVICE_W * 0.5)
	slab.add_child(m)
	slab.position = Vector3(0, 0, -SERVICE_W * 0.5)
	door.add_panel(slab, slab.position, deg_to_rad(-100.0))
	return door


func _ready() -> void:
	add_to_group("shed")


# ------------------------------------------------------------------ objetivos e reforços
## Liga o que o Level montou (`built`), os computadores e os guardas. `spawn` = Callable(Dictionary) -> Soldier do main.
func setup(built: Dictionary, panel_guard: Enemy, corner: Array[Enemy], spawn: Callable) -> void:
	mid_gate = built.mid
	corner_gate = built.corner
	service_doors.assign(built.service)
	corner_guards = corner
	panel = Terminal.new()
	panel.guard = panel_guard
	panel.verb = "USAR COMPUTADOR"
	add_child(panel)
	panel.global_position = PANEL_USE[0]
	panel.rotation.y = PANEL_USE[1]
	panel.used.connect(func() -> void: _unlock(mid_gate, "panel"))
	for g: Dictionary in LAB_GUARDS:
		lab_guards.append(spawn.call(g))
	lab_panel = Terminal.new()
	lab_panel.guard = lab_guards[0]
	add_child(lab_panel)
	lab_panel.global_position = LAB_USE[0]
	lab_panel.rotation.y = LAB_USE[1]
	lab_panel.used.connect(func() -> void: _unlock(corner_gate, "lab"))
	for i in SERVICE.size():
		for k in WAVE * WAVES:
			var room: Vector3 = SERVICE[i].room
			var at := room + Vector3((k % 3 - 1) * 0.55, 0, (k / 3 - 0.5) * 0.6).rotated(Vector3.UP, SERVICE[i].yaw)
			var sd: Soldier = spawn.call({"pos": at, "rot_y": SERVICE[i].yaw + PI * 0.5, "route": []})
			reinforcements[i].append(sd)
	reset()


func _unlock(gate: Door, id: String) -> void:
	gate.set_held(false)
	objective.emit(id)


func _hide(sd: Soldier) -> void:
	sd.lurking = true
	sd.visible = false
	sd.collision_layer = 0
	sd.velocity = Vector3.ZERO
	sd.process_mode = Node.PROCESS_MODE_DISABLED


## Saleta de serviço só aparece com a porta dela aberta (de fora do galpão ela é um bloco solto).
func _show_rooms() -> void:
	for door in service_doors:
		var show := door.opened
		for mi: MeshInstance3D in door.get_meta("room_meshes", []):
			mi.visible = show


## R / do zero: grades travadas, computadores sem uso, reforços na saleta, portas de serviço fechadas.
func reset() -> void:
	_pending.clear()
	_clock = 0.0
	for i in waves_sent.size():
		waves_sent[i] = 0
		_red_t[i] = -1.0
		_wave_at[i] = -INF
	_guard_opened.clear()
	mid_gate.set_held(true, true)
	corner_gate.set_held(true, true)
	panel.load_done(false)
	lab_panel.load_done(false)
	for list: Array in reinforcements:
		for sd: Soldier in list:
			if not sd.cleared:
				_hide(sd)


func save_state() -> Dictionary:
	return {"panel": panel.done, "lab": lab_panel.done}


## Checkpoint (depois do restore dos inimigos): computadores como estavam, grades pelo uso deles; reforço vivo volta para a
## saleta e a leva dele conta como não mandada (morto segue fora do jogo).
func load_state(s: Dictionary) -> void:
	_pending.clear()
	_guard_opened.clear()
	panel.load_done(s.panel)
	lab_panel.load_done(s.lab)
	mid_gate.set_held(not s.panel, true)
	corner_gate.set_held(not s.lab, true)
	for i in reinforcements.size():
		var sent := 0
		for w in WAVES:
			var wave: Array = reinforcements[i].slice(w * WAVE, (w + 1) * WAVE)
			if wave.all(func(sd: Soldier) -> bool: return sd.dead):
				sent += 1
		waves_sent[i] = sent
		_red_t[i] = -1.0
		_wave_at[i] = -INF
		for sd: Soldier in reinforcements[i]:
			if not sd.dead:
				_hide(sd)


## Ela está na seção `i` (0 = sala dos clones, 1 = canto da porta do pátio)?
## Dentro do canto da porta do pátio de verdade (por dentro das paredes de caixas, das grades da quina e do portão; a
## saleta de serviço dele conta), no chão.
static func in_corner(p: Vector3) -> bool:
	return p.y < 2.0 and p.x > -Level.SIZE * 0.5 - 0.3 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), PackedVector2Array(CORNER_AREA))


static func in_section(i: int, p: Vector3) -> bool:
	if i == 0:
		return CloneLab.inside(p)
	return p.x < CORNER_GATE.x + 0.5 and p.z < 0.6 and p.x > -Level.SIZE * 0.5 and p.y < 2.0


func section_guards(i: int) -> Array:
	var out: Array = []
	out.append_array(lab_guards if i == 0 else corner_guards)
	out.append_array(reinforcements[i])
	return out


## Alarme vermelho na seção: ela ali dentro e alguém dela em luta com ela.
func red_alert(i: int) -> bool:
	if player == null or player.dead or not in_section(i, player.global_position):
		return false
	return section_guards(i).any(func(e: Enemy) -> bool: return not e.dead and not e.lurking and e.in_combat())


func _physics_process(delta: float) -> void:
	_clock += delta
	_show_rooms()
	_guards_at_gates(delta)
	for k in range(_pending.size() - 1, -1, -1):
		var pn: Dictionary = _pending[k]
		pn.t -= delta
		if pn.t <= 0.0:
			_pending.remove_at(k)
			_enter(pn.s, pn.at)
	if player == null or player.dead or player.cutscene:
		return
	for i in waves_sent.size():
		if waves_sent[i] >= WAVES:
			continue
		if waves_sent[i] == 0:
			if _red_t[i] < 0.0:
				if red_alert(i):
					_red_t[i] = WAVE_DELAY
				continue
			_red_t[i] -= delta
			if _red_t[i] <= 0.0:
				send_wave(i)
		elif _clock - _wave_at[i] >= SECOND_AFTER and red_alert(i):
			send_wave(i)


## Guarda (vivo, em cena, fora de rotina parada) chegando a um portão fechado o abre, travado ou não; o portão que um
## guarda abriu fecha sozinho AUTO_CLOSE s depois de o vão ficar livre (o travado continua travado).
func _guards_at_gates(delta: float) -> void:
	for gate: Door in [mid_gate, corner_gate]:
		if gate == null:
			continue
		var c := gate.global_position
		if not gate.opened:
			for e: Node in get_tree().get_nodes_in_group("enemies"):
				var sd := e as Soldier
				if sd == null or sd.dead or sd.lurking or sd.process_mode == Node.PROCESS_MODE_DISABLED:
					continue
				var to := Vector3(c.x - sd.global_position.x, 0.0, c.z - sd.global_position.z)
				if to.length() < GUARD_OPEN and absf(c.y - sd.global_position.y) < 1.0 and _path_through(sd, gate):
					gate.open()
					_guard_opened[gate] = 0.0
					break
			continue
		if not _guard_opened.has(gate):
			continue
		if _someone_in(gate):
			_guard_opened[gate] = 0.0
			continue
		_guard_opened[gate] += delta
		if _guard_opened[gate] >= AUTO_CLOSE:
			_guard_opened.erase(gate)
			gate.close()


## O caminho que o guarda segue agora (os próximos pontos da malha) passa pelo vão do portão.
static func _path_through(sd: Enemy, gate: Door) -> bool:
	if Vector2(sd.velocity.x, sd.velocity.z).length() < 0.3 or sd._path.is_empty():
		return false
	var inv := gate.global_transform.affine_inverse()
	var half := (gate._col.shape as BoxShape3D).size.z * 0.5 + 0.3
	var a := inv * sd.global_position
	for k in range(sd._path_i, mini(sd._path_i + 3, sd._path.size())):
		var b := inv * sd._path[k]
		if signf(a.x) != signf(b.x) and absf(b.x - a.x) > 0.001:
			var z := lerpf(a.z, b.z, a.x / (a.x - b.x))
			if absf(z) < half:
				return true
		a = b
	return false


func _someone_in(gate: Door) -> bool:
	var c := gate.global_position
	var near := func(n: Node3D) -> bool:
		return Vector2(n.global_position.x - c.x, n.global_position.z - c.z).length() < DOORWAY and absf(n.global_position.y - c.y) < 1.0
	if player and not player.dead and near.call(player):
		return true
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead and not en.lurking and near.call(en):
			return true
	return false


## Manda a próxima leva da seção `i`: a porta de serviço abre e os 3 entram um depois do outro, correndo para ela.
func send_wave(i: int) -> void:
	var w := waves_sent[i]
	if w >= WAVES:
		return
	waves_sent[i] = w + 1
	_wave_at[i] = _clock
	_red_t[i] = -1.0
	var door := service_doors[i]
	if not door.opened:
		door.open()
	var wave: Array = reinforcements[i].slice(w * WAVE, (w + 1) * WAVE)
	for k in wave.size():
		var sd: Soldier = wave[k]
		if not sd.dead:
			_pending.append({"s": sd, "t": WAVE_STAGGER * k, "at": player.global_position})


## Um reforço entra em cena na saleta e corre para onde ela foi vista, já alertado (busca ativa, vermelho).
func _enter(sd: Soldier, at: Vector3) -> void:
	if sd.dead:
		return
	sd.process_mode = Node.PROCESS_MODE_INHERIT
	sd.lurking = false
	sd.visible = true
	sd.collision_layer = 2
	sd.reset_physics_interpolation()
	sd._alert_self(at)
	sd.identified = true
	sd.start_hunt(at)
