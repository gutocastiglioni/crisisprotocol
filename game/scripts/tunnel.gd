class_name Tunnel
extends Node3D
## Túnel da mina entre o portão do pátio (o do teclado) e a pedreira: galeria escavada na rocha com escoras de madeira,
## trilho no chão e lâmpadas penduradas. Sala 2 (`Level.room_of`); a pedreira passou a ser a 3 e foi empurrada `LENGTH`
## para oeste (`Arena.DX`). Três trechos largos ligados por corredores (`SECTIONS`):
## - boca (logo depois do portão do teclado);
## - câmara do meio: caixas para se esconder, itens para repor (`Pickup.LAYOUT`) e 2 guardas de sentinela (`GUARDS`
##   0 e 1) olhando para a boca: ela abre o portão longe da vista deles e só é vista chegando perto;
## - câmara do fundo: pilhas de caixotes de explosivos (`STACKS`, os mesmos `ExplosiveCrate` do galpão) encostadas nas
##   paredes até o portão da pedreira e 4 guardas (`GUARDS` 2..5) mexendo nos caixotes de trabalho (animação Console,
##   distraídos como o 7 do galpão), se preparando para levar tudo para a pedreira.
## A galeria abafa (`SOUND_REACH`): tiro, grito e alarme de dentro dela só chegam a quem está a até essa distância, então a
## briga com os do meio não chega aos do fundo (a não ser que ela leve a briga até eles).
## Chegando ao fundo sem ser vista, `talk_speakers` = os dois que falam na cena curta (Cutscene.play_talk).
## O caixote de trabalho do primeiro (`DETONATOR`) tem o detonador: E nele (`can_arm`/`arm`, o guarda dali tem que estar
## fora do caminho) arma `FUSE` s de contagem (`tick`) e aí todas as pilhas explodem; a M79 também detona de longe. Caixote
## das pilhas do portão (`BREACH_RADIUS`) explodindo arromba o portão da pedreira (`gate`, `Door.blow`, sinal `breached`);
## ele não abre de outro jeito (`Door.sealed`). Passando pelo portão arrombado, `lair_ready` = a cena do alossauro
## (Cutscene.play_lair). R (`reset`): caixotes de volta, portão inteiro e as duas cenas valem de novo.

signal tick(left: int)
signal breached

const X_NEAR := -56.6  # boca, do lado do pátio (a parede do portão do teclado)
const LENGTH := 60.0
const X_FAR := X_NEAR - LENGTH  # a pedreira começa aqui (Arena.X_NEAR)
const Z := -3.0  # eixo da galeria = fim da estrada do pátio (Yard.ROAD)
const H := 4.2  # pé-direito
const ROCK_T := 2.0
## trechos da galeria: [x de, x até, meia largura]
const SECTIONS := [[X_NEAR, -74.0, 3.0], [-74.0, -90.0, 5.0], [-90.0, -100.0, 3.0], [-100.0, X_FAR, 6.0]]
const SOUND_REACH := 16.0  # m: dentro da galeria o barulho/alarme não vai mais longe que isto
const FUSE := 10.0  # s de contagem do detonador
const BREACH_RADIUS := 5.5  # caixote explodindo até aqui do meio do portão (a 1 m do chão) o arromba: as pilhas dos dois lados do vão
const GATE_GAP := Yard.GATE_GAP
const GATE_H := Yard.GATE_H
const GATE_X := X_FAR + 0.4  # no paredão da pedreira (Arena: lado leste)
const TALK_X := -94.5  # passou daqui (vindo da boca) sem ser vista: a cena dos guardas do fundo
const LAIR_X := X_FAR - 1.5  # passou daqui pelo portão arrombado: a cena do alossauro
const ARM_REACH := 1.3
## lâmpadas penduradas (x)
const LAMPS := [-62.0, -77.5, -86.0, -95.0, -103.5, -112.0]
## caixas da câmara do meio (cobertura): [tamanho, centro no chão]
const COVER := [
	[Vector3(1.2, 1.5, 1.2), Vector3(-78.5, 0, Z + 3.6)],
	[Vector3(1.0, 1.0, 1.0), Vector3(-79.7, 0, Z + 3.8)],
	[Vector3(1.2, 1.5, 1.2), Vector3(-81.5, 0, Z - 3.5)],
	[Vector3(2.0, 1.0, 1.0), Vector3(-84.0, 0, Z + 2.0)],
	[Vector3(1.2, 1.5, 1.2), Vector3(-88.0, 0, Z - 3.4)],
]
## pilhas de explosivos da câmara do fundo: [centro (x, z), caixotes, giro, de trabalho]; as de trabalho têm o guarda na
## frente, do lado de dentro da câmara. Cada lado encadeia até as pilhas do portão.
const STACKS := [
	[Vector2(-102.5, Z - 5.4), 2, 0.03, false],
	[Vector2(-102.5, Z + 5.4), 2, -0.03, false],
	[Vector2(-105.5, Z - 5.4), 1, 0.0, true],
	[Vector2(-105.5, Z + 5.4), 1, 0.0, true],
	[Vector2(-108.5, Z - 5.4), 2, 0.02, false],
	[Vector2(-108.5, Z + 5.4), 2, -0.02, false],
	[Vector2(-111.5, Z - 5.4), 1, 0.0, true],
	[Vector2(-111.5, Z + 5.4), 1, 0.0, true],
	[Vector2(-114.6, Z - 4.6), 2, 0.03, false],
	[Vector2(-114.6, Z + 4.6), 2, -0.03, false],
]
const DETONATOR := 2  # índice em STACKS do caixote com o detonador (o do primeiro guarda do fundo)
## Guardas (mesmo formato de Soldier.GUARDS): 0 e 1 sentinelas da câmara do meio, de olho na boca; 2..5 no fundo, um em
## cada caixote de trabalho ("work"), de costas para a câmara.
const GUARDS := [
	{"pos": Vector3(-86.6, 0, Z - 1.6), "rot_y": -PI * 0.5, "route": []},
	{"pos": Vector3(-86.6, 0, Z + 0.6), "rot_y": -PI * 0.5, "route": []},
	{"stack": 2}, {"stack": 3}, {"stack": 6}, {"stack": 7},
]
const TALKERS := [2, 3]  # índices em GUARDS de quem fala na cena (o do detonador e o da frente dele)

var gate: Door
var crates: Array[ExplosiveCrate] = []
var guards: Array[Soldier] = []  # o main põe aqui os de GUARDS, na mesma ordem
var talk_armed := true
var lair_armed := true
var is_breached := false
var fuse := -1.0  # contagem do detonador (< 0 = desarmado)
var _det_led: StandardMaterial3D


## Lugar e giro do guarda de `GUARDS[i]` (os de trabalho na frente do caixote deles, virados para ele).
static func guard_spot(i: int) -> Dictionary:
	var g: Dictionary = GUARDS[i]
	if not g.has("stack"):
		return g
	var s: Array = STACKS[g.stack]
	var c := Vector3(s[0].x, 0, s[0].y)
	var inward := Vector3(0, 0, signf(Z - c.z))
	var pos := c + inward * (ExplosiveCrate.SIZE * 0.5 + ExplosiveCrate.WORK_GAP)
	return {"pos": pos, "rot_y": atan2(inward.x, inward.z), "route": [], "work": true}


## Onde ela fica para armar o detonador (na frente do caixote dele).
static func detonator_point() -> Vector3:
	return guard_spot(TALKERS[0]).pos


static func gate_center() -> Vector3:
	return Vector3(GATE_X, 0, Z)


static func build(parent: Node) -> Tunnel:
	var t := Tunnel.new()
	parent.add_child(t)
	t._rock()
	t._props()
	t._stacks()
	t._gate()
	return t


func _ready() -> void:
	add_to_group("tunnels")


## Chão, paredes e teto de rocha de cada trecho, e a parede de pedra da boca (com o vão do portão do teclado).
func _rock() -> void:
	var len_x := X_NEAR - X_FAR
	Yard._box(self, Vector3(len_x, 0.4, 16.0 + ROCK_T * 2.0), Vector3((X_NEAR + X_FAR) * 0.5, -0.2, Z), "dirt", 0.5)
	Yard._box(self, Vector3(len_x, 1.0, 12.0 + ROCK_T * 2.0), Vector3((X_NEAR + X_FAR) * 0.5, H + 0.5, Z), "rock", 0.35)
	var prev := -1.0
	for s in SECTIONS:
		var x0: float = s[0]
		var x1: float = s[1]
		var hw: float = s[2]
		for side in [-1, 1]:
			Yard._box(self, Vector3(x0 - x1, H, ROCK_T), Vector3((x0 + x1) * 0.5, H * 0.5, Z + side * (hw + ROCK_T * 0.5)), "rock", 0.35)
			if prev > 0.0 and absf(prev - hw) > 0.01:
				# degrau entre um trecho e o outro (a parede do mais largo fecha até a do mais estreito)
				var a := minf(prev, hw)
				var b := maxf(prev, hw)
				var into := -0.4 if hw > prev else 0.4  # para dentro do trecho mais largo
				Yard._box(self, Vector3(0.8, H, b - a), Vector3(x0 + into, H * 0.5, Z + side * (a + b) * 0.5), "rock", 0.35)
		prev = hw
	# boca: a parede de pedra do lado do pátio, alta como os paredões, só com o vão do portão
	var x := X_NEAR + 0.4
	var g0 := Z - GATE_GAP * 0.5
	var g1 := Z + GATE_GAP * 0.5
	var zh := Arena.Z_HALF
	Yard._box(self, Vector3(0.8, Arena.CLIFF_H, g0 + zh), Vector3(x, Arena.CLIFF_H * 0.5, (g0 - zh) * 0.5), "rock", 0.35)
	Yard._box(self, Vector3(0.8, Arena.CLIFF_H, zh - g1), Vector3(x, Arena.CLIFF_H * 0.5, (g1 + zh) * 0.5), "rock", 0.35)


## Escoras de madeira, trilho, lâmpadas e as caixas da câmara do meio.
func _props() -> void:
	for s in SECTIONS:
		var x0: float = s[0]
		var x1: float = s[1]
		var hw: float = s[2]
		# na câmara do fundo as escoras ficam nos vãos entre as pilhas de explosivos (não atravessam os caixotes)
		var x := x0 - (4.0 if hw >= SECTIONS[3][2] else 2.0)
		while x > x1 + 1.0:
			for side in [-1, 1]:
				Yard._box(self, Vector3(0.28, H, 0.28), Vector3(x, H * 0.5, Z + side * (hw - 0.16)), "bark", 0.8)
			Yard._box(self, Vector3(0.3, 0.3, hw * 2.0), Vector3(x, H - 0.15, Z), "bark", 0.8)
			x -= 6.0
	# trilho (só enfeite, sem colisão): dois perfis e dormentes
	for side in [-1, 1]:
		Yard._prop(self, Yard._bm(Vector3(X_NEAR - X_FAR, 0.06, 0.07)), Vector3((X_NEAR + X_FAR) * 0.5, 0.03, Z + side * 0.5), "wall", 2.0)
	var sx := X_NEAR - 1.0
	while sx > X_FAR + 1.0:
		Yard._prop(self, Yard._bm(Vector3(0.22, 0.04, 1.4)), Vector3(sx, 0.02, Z), "bark", 1.0)
		sx -= 1.1
	for lx: float in LAMPS:
		_lamp(Vector3(lx, H - 0.05, Z))
	for c in COVER:
		Level.block(self, c[0], c[1] + Vector3.UP * c[0].y * 0.5, "crate", 1.0 / c[0].x)


## Lâmpada pendurada num fio, com luz quente (grupo "lamps": sombra no PS2).
func _lamp(top: Vector3) -> void:
	var cord := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.02, 0.6, 0.02)
	cord.mesh = cb
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.08)
	cord.material_override = dark
	cord.position = top + Vector3.DOWN * 0.3
	add_child(cord)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 8
	sm.rings = 4
	bulb.mesh = sm
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.55)
	bulb.material_override = glow
	bulb.position = top + Vector3.DOWN * 0.66
	add_child(bulb)
	var light := OmniLight3D.new()
	light.position = bulb.position
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.omni_attenuation = 1.1
	light.add_to_group("lamps")
	add_child(light)


## Pilhas de explosivos da câmara do fundo; os de trabalho com o detonador virado para o guarda.
func _stacks() -> void:
	for i in STACKS.size():
		var s: Array = STACKS[i]
		for k in int(s[1]):
			var c := ExplosiveCrate.new()
			c.rotation.y = float(s[2]) * (1.0 if k == 0 else -1.5)
			c.work_dir = Vector3(0, 0, signf(Z - s[0].y))
			add_child(c)
			c.position = Vector3(s[0].x, ExplosiveCrate.SIZE * (k + 0.5), s[0].y)
			if s[3]:
				c._add_detonator()
			crates.append(c)
	# o detonador de verdade: luz que pisca durante a contagem
	var det := crate_of(DETONATOR)
	_det_led = StandardMaterial3D.new()
	_det_led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_det_led.albedo_color = Color(0.3, 0.05, 0.03)
	var led := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.05, 0.03, 0.05)
	led.mesh = lb
	led.material_override = _det_led
	led.position = Vector3(0, ExplosiveCrate.SIZE * 0.5 + 0.075, 0) + det.work_dir * 0.36 + det.work_dir.cross(Vector3.UP) * 0.08
	det.add_child(led)


## O caixote de baixo da pilha `i` de STACKS.
func crate_of(i: int) -> ExplosiveCrate:
	var p: Vector2 = STACKS[i][0]
	for c in crates:
		if Vector2(c.position.x, c.position.z).distance_to(p) < 0.05:
			return c
	return null


## Portão de chapa no paredão da pedreira, com viga de pedra por cima até o alto do paredão. Não tem fechadura nem
## teclado (`sealed`): só a explosão das pilhas o abre (`Door.blow`).
func _gate() -> void:
	var top := GATE_H + 0.1
	Yard._box(self, Vector3(0.8, Arena.CLIFF_H - top, GATE_GAP + 1.6), Vector3(GATE_X, (Arena.CLIFF_H + top) * 0.5, Z), "rock", 0.35)
	for s in [-1, 1]:
		Level.block(self, Vector3(0.9, top, 0.6), Vector3(GATE_X, top * 0.5, Z + s * (GATE_GAP * 0.5 + 0.3)), "concrete", 0.35)
	gate = Door.create(self, Vector3(GATE_X, 0, Z), Vector3(0.6, top, GATE_GAP + 0.4), 2, "PORTÃO")
	gate.sealed = true
	var w := GATE_GAP * 0.5 - 0.01
	for s in [-1, 1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(0, 0, s * GATE_GAP * 0.5)
		Yard._prop(leaf, Yard._bm(Vector3(0.1, GATE_H, w)), Vector3(0, GATE_H * 0.5, -s * w * 0.5), "wall", 1.0)
		for y in [0.55, 1.75, 2.95, 4.15]:
			Yard._prop(leaf, Yard._bm(Vector3(0.22, 0.16, w)), Vector3(0, y, -s * w * 0.5), "wall", 2.0)
		Yard._prop(leaf, Yard._bm(Vector3(0.14, 0.3, w)), Vector3(0, 0.15, -s * w * 0.5), "wall", 1.0).material_override = Level.material("hazard", 1.0)
		gate.add_panel(leaf, leaf.position, leaf.rotation.y)


## Ela está na frente do detonador, ele ainda não explodiu nem está contando.
func can_arm(pos: Vector3) -> bool:
	var det := crate_of(DETONATOR)
	if fuse >= 0.0 or det == null or det.exploded:
		return false
	var d := pos - detonator_point()
	return Vector2(d.x, d.z).length() < ARM_REACH and absf(d.y) < 1.2


func arm() -> void:
	if fuse >= 0.0:
		return
	fuse = FUSE
	Sfx.ui(self, "keypad_ok")
	tick.emit(int(ceil(FUSE)))


func _physics_process(delta: float) -> void:
	if fuse >= 0.0:
		var before := int(ceil(fuse))
		fuse -= delta
		var left := int(ceil(maxf(fuse, 0.0)))
		if _det_led:
			_det_led.albedo_color = Color(1.0, 0.15, 0.1) if fmod(fuse, 0.5) > 0.25 else Color(0.3, 0.05, 0.03)
		if left < before and left > 0:
			Sfx.ui(self, "keypad_beep")
			tick.emit(left)
		if fuse <= 0.0:
			fuse = -1.0
			_detonate_all()
	if not is_breached:
		var g := gate_center() + Vector3.UP
		for c in crates:
			if c.exploded and c.global_position.distance_to(g) < BREACH_RADIUS:
				_breach()
				break


## A contagem acabou: o caixote do detonador estoura e as pilhas vão pela distância dele.
func _detonate_all() -> void:
	var det := crate_of(DETONATOR)
	var from := det.global_position if det else gate_center()
	for c in crates:
		c.detonate(c.global_position.distance_to(from) * ExplosiveCrate.CHAIN_PER_M)


## O portão arromba: as folhas voam para dentro da pedreira e caem. Abre um passo de física depois do estouro, para o
## barulho da explosão não chegar à pedreira (a porta ainda estava fechada).
func _breach() -> void:
	is_breached = true
	await get_tree().physics_frame
	if not is_inside_tree() or not is_breached:
		return
	gate.blow(Vector3.LEFT)
	Fx.explosion(get_parent(), gate_center() + Vector3.UP * 2.0, Vector3.RIGHT)
	breached.emit()


## Chegou ao fundo vindo da boca e os dois que falam estão vivos e no trabalho (ninguém a viu): os dois, senão vazio.
func talk_speakers(p: Player) -> Array[Soldier]:
	var out: Array[Soldier] = []
	if not talk_armed or guards.size() < GUARDS.size() or p.global_position.x > TALK_X or p.global_position.x < X_FAR + 6.0:
		return out
	for i: int in TALKERS:
		var s := guards[i]
		if s.dead or not s.is_distracted():
			return out
		out.append(s)
	return out


## Passou pelo portão arrombado para dentro da pedreira, com o alossauro ainda calmo.
func lair_ready(p: Player, allo: Allosaurus) -> bool:
	return lair_armed and is_breached and p.global_position.x < LAIR_X and is_instance_valid(allo) and not allo.dead \
		and not allo.in_combat() and allo.alert_t <= 0.0


func reset() -> void:
	fuse = -1.0
	is_breached = false
	talk_armed = true
	lair_armed = true
	if _det_led:
		_det_led.albedo_color = Color(0.3, 0.05, 0.03)
	gate.reset()
	gate.sealed = true
