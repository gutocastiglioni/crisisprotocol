class_name Shed
extends Node
## Galpão em salas (jeito Syphon Filter), comprido no sentido do avanço (a frente da fase é -z, Level.SOUTH..NORTH): paredes
## sólidas até o teto separam as salas, então ela só vê e alcança quem está numa sala abrindo a porta dela ou espiando por
## um portão de grade. Do fundo para a frente:
##   labirinto (Level.MAZE, furtivo; o atirador de M16 no mezanino quadrado, Catwalk): o computador do painel (`PANEL_USE`,
##       guarda 12) destrava o portão de grade `MID_GATE` na parede da frente do labirinto (Level.MAZE_FRONT)
##   escritório (furtivo, laje baixa a `OFFICE_CEIL` sem acesso por cima): corredor do meio (`HALL_X`) com o bloqueio
##       (`BLOCKADE`), descanso e arquivo a oeste, escritório e arsenal a leste (`ROOMS_Z`), vãos de porta (`ROOM_DOORS`). Na
##       parede da frente (`OFFICE_Z0`) três portas: a do arquivo (`EXIT_DOOR`) é a única que abre, travada até o
##       computador da mesa (`OFFICE_USE`, guarda 11, objetivo "office"); as outras (`BARRED_DOORS`) nunca abrem
##       (`Door.locked_text`).
##   estantes (`RACKS`, sólidas até RACK_H) + doca (plataforma a CloneLab.FLOOR_Y, `DOCK_Z`), uma sala só: a escada
##       (`STAIR`) à direita sobe para a doca; cabine (`BOOTH`, piso `BOOTH_Y`, escadinha `BOOTH_LADDER`) na ponta oeste.
##       O computador da cabine (`BOOTH_USE`, guarda 13) destrava o portão de enrolar da sala dos clones (objetivo "control").
##   sala dos clones (CloneLab, `LAB_GUARDS`): o computador do laboratório (`LAB_USE`) abre a porta enorme
##       (`HUGE_DOOR`, objetivo "lab") para o pátio descoberto. Porta falsa (`FAKE_DOOR`) na parede leste.
##   pátio descoberto (o fim, sem teto; "corner" no código): caminhão sendo carregado (`TRUCK`, com a escopeta), container
##       (`CONTAINER`), pilhas altas (`CORNER_SCREEN`) e o portão da mata (Yard.west_wall).
## Som (`muffled`): entre áreas (`zone_of`) só passa pelas portas abertas (`LINKS`). Com a porta enorme fechada, o pátio
## descoberto é outro lugar também para a vista (`apart`).
## Portões (`grate_gate`): grade pintada de amarelo com moldura, faixa de perigo e lampião (vermelho travado / verde).
## Guarda andando até uma porta do galpão que ele pode abrir (`guard_gates`: o portão do labirinto, a porta do arquivo e a
## porta enorme) a abre, travada ou não (`GUARD_OPEN`), e ela fecha sozinha `AUTO_CLOSE` s depois de o vão ficar livre.
## Reforços (estantes, sala dos clones e pátio descoberto): com alarme vermelho na seção (alguém dela em luta com ela ali),
## entra uma leva de `WAVE` guardas pela porta de serviço da seção (`SERVICE`: uma saleta fechada fora da parede leste)
## `WAVE_DELAY` s depois; se o alarme vermelho seguir `SECOND_AFTER` s depois da primeira, entra a segunda (2 levas).
## Quem chega corre para onde ela foi vista e fica na seção procurando.
## `Shed.build` monta a geometria (chamado pelo Level); o nó (criado pelo main) cuida dos objetivos e dos reforços.

## "panel" (portão do labirinto), "office" (porta do arquivo), "control" (portão dos clones), "lab" (porta enorme)
signal objective(id: String)

const FENCE_H := 3.6  # alambrado em cima dos portões de grade soltos (tutorial)
const BAR_STEP := 0.14  # alambrado: uma barra fina a cada BAR_STEP m
const WALL_T := 0.3  # espessura das paredes de dentro
const SLAB := 0.25  # laje do escritório
const GATE_W := 1.4
const GATE_H := 2.6
const DOOR_W := 1.2
const DOOR_H := 2.3
## Portão de grade do labirinto para o corredor do escritório (célula da coluna 5 na parede da frente do labirinto).
const MID_GATE := Vector3(-4.2, 0, Level.MAZE_FRONT)
## Escritório: de OFFICE_Z0 (parede da frente, com as três portas) a OFFICE_Z1 (parede do labirinto), laje a OFFICE_CEIL.
const OFFICE_Z0 := 43.0
const OFFICE_Z1 := Level.MAZE_FRONT
const OFFICE_CEIL := 3.0
const HALL_X := [-5.7, -2.7]  # paredes do corredor do meio
const ROOMS_Z := 49.5  # descanso | arquivo (oeste) e escritório | arsenal (leste)
## Vãos de porta de dentro (sem folha): [meio do vão, giro (0 = vão ao longo de z)].
const ROOM_DOORS := [[Vector3(-5.7, 0, 53.0), 0.0], [Vector3(-5.7, 0, 46.0), 0.0], [Vector3(-2.7, 0, 47.0), 0.0],
	[Vector3(-10.0, 0, ROOMS_Z), PI * 0.5], [Vector3(0.0, 0, ROOMS_Z), PI * 0.5]]
const ROOM_GAP := 1.2
## Pilha alta atravessando o corredor (tapa a vista da ronda 6 e obriga a passar pelo descanso e o arquivo): x0, z0, x1, z1.
const BLOCKADE := [HALL_X[0] + WALL_T * 0.5, 51.0, HALL_X[1] - WALL_T * 0.5, 52.4]
## Porta do arquivo para as estantes: a única da frente que abre (travada até o computador da mesa do escritório).
const EXIT_DOOR := Vector3(-10.0, 0, OFFICE_Z0)
## Portas da frente do corredor e do arsenal: trancadas para sempre (E = BARRED_TEXT).
const BARRED_DOORS := [Vector3(-4.2, 0, OFFICE_Z0), Vector3(0.6, 0, OFFICE_Z0)]
const BARRED_TEXT := "Trancada pelo outro lado.\nVou ter que achar outra saída."
## Computador da mesa do escritório (o guarda 11 mexe nele): painel na parede leste, virado para oeste.
const DESK_CONSOLE := Vector3(Level.EAST - Level.WALL_T * 0.5, 0, 53.0)
const DESK_YAW := PI
## Estantes porta-paletes cheias de caixas: [centro (x, z), tamanho (x, z)], RACK_H de alto (sólidas: tapam vista e tiro).
## A faixa entre a parede oeste e a primeira é o corredor escondido.
const RACKS := [
	[Vector2(-10.1, 37.0), Vector2(1.2, 8.0)], [Vector2(-5.6, 37.0), Vector2(1.2, 8.0)], [Vector2(-1.1, 37.0), Vector2(1.2, 8.0)],
]
const RACK_H := 4.6
## Escada das estantes para a doca, encostada na parede leste: x0, x1, z do pé (chão), z do alto (beira da doca).
const STAIR := [0.4, Level.EAST - Level.WALL_T * 0.5, 36.0, 31.0]
## Doca: plataforma a CloneLab.FLOOR_Y de z DOCK_Z (parede da sala dos clones) até a beira.
const DOCK_Z := [27.0, 31.0]
## Cabine na ponta oeste da doca: x0, x1, z0, z1, piso a BOOTH_Y; escadinha (Ladder) da doca até ela, na quina leste.
const BOOTH := [Level.WEST, -9.0, 27.0, 31.4]
const BOOTH_Y := 4.0
const BOOTH_WALL_H := 1.1  # mureta da cabine
const BOOTH_LADDER := Vector3(-9.0, 1.3, 27.7)  # pé da escadinha (quem sobe olha para oeste)
## Painel da cabine (na mureta da frente, virado para a doca) e onde ela fica para usá-lo.
const BOOTH_CONSOLE := Vector3(-11.0, BOOTH_Y, 31.2)
const BOOTH_YAW := PI * 0.5
## Onde ela fica para usar cada computador: [ponto no chão, giro dela de frente para a tela].
const PANEL_USE := [Vector3(-2.6, 0, Level.MAZE_FRONT + 0.15 + 0.75), 0.0]
const OFFICE_USE := [Vector3(DESK_CONSOLE.x - 0.75, 0, DESK_CONSOLE.z), -PI * 0.5]
const BOOTH_USE := [Vector3(BOOTH_CONSOLE.x, BOOTH_Y, BOOTH_CONSOLE.z - 0.75), PI]
const LAB_USE := [Vector3(CloneLab.CONSOLE.x, CloneLab.FLOOR_Y, CloneLab.CONSOLE.z + 0.75), 0.0]
## Porta enorme da sala dos clones para o pátio descoberto (folha de aço que corre para oeste, do lado do pátio): meio do
## pé do vão; a rampa desce dela até o pátio (`RAMP_Z`).
const HUGE_DOOR := Vector3(-0.1, CloneLab.FLOOR_Y, Level.ROOF_Z)
const HUGE_W := 5.8
const HUGE_H := 4.5
const RAMP_Z := 5.0
## Porta falsa da sala dos clones na parede leste (pé do vão): não abre (E = FAKE_TEXT).
const FAKE_DOOR := Vector3(Level.EAST, CloneLab.FLOOR_Y, 20.0)
const FAKE_TEXT := "INCUBAÇÃO - ACESSO RESTRITO.\nTrancada. O leitor não aceita nada."
## Marcas de arrasto do tanque vazio até a porta enorme e pelo pátio até o portão da mata (o alossauro foi levado por ali).
const DRAG := [Vector3(-6.2, CloneLab.FLOOR_Y, 10.6), Vector3(-3.0, CloneLab.FLOOR_Y, 9.0), Vector3(-0.1, CloneLab.FLOOR_Y, Level.ROOF_Z),
	Vector3(-0.1, 0.0, RAMP_Z), Vector3(-6.0, 0.0, -3.0), Vector3(-12.6, 0.0, -8.5)]
## Pátio descoberto: caminhão sendo carregado (caçamba fechada x0, x1, z0, z1, piso a TRUCK_BED; a traseira, a leste,
## aberta) e o container de carga (x0, x1, z0, z1, altura).
const TRUCK := [-11.0, -6.4, 2.0, 4.8]
const TRUCK_BED := 1.0
const TRUCK_TOP := 3.4
const TRUCK_CHEST := Vector3(-8.7, TRUCK_BED, 3.4)  # baú da escopeta na caçamba, boca para a traseira (main)
const CONTAINER := [-4.9, -2.2, 2.3, 4.0, 2.6]
## Pilhas altas (2 caixas) no pátio descoberto, na frente do portão da mata: tapam a vista dos postos; passa-se pelos lados.
const CORNER_SCREEN := [Vector2(-6.2, -7.8), Vector2(-6.2, -9.02)]
## Luzes de parede do pátio descoberto (não tem teto para luminária): ponto na face da parede.
const YARD_LAMPS := [Vector3(-6.0, 4.6, Level.SOUTH + 0.3), Vector3(Level.EAST - 0.3, 4.6, 0.0), Vector3(Level.WEST + 0.3, 4.6, 2.0)]
const GUARD_OPEN := 1.3  # guarda a até isto do meio do portão fechado, andando para ele: abre
const AUTO_CLOSE := 3.0  # aberto por guarda: fecha isto depois de ninguém estar no vão
const DOORWAY := 1.1  # alguém a até isto do meio do portão = no vão (não fecha)
const GATE_PAINT := Color(2.2, 1.6, 0.25)  # tinta amarela dos portões (tint do material, acima de 1: a textura base é cinza escuro)
const DOOR_PAINT := Color(1.7, 0.62, 0.3)  # folha das portas de aço: laranja de segurança gasto, longe do cinza azulado das paredes
const STEEL_TINT := Color(0.78, 0.8, 0.84)  # aço sem pintura (batente, visor, maçaneta, chapa de chute, caixa das placas)
## Placas acesas em cima das portas (`door_signs`): fundo pelo destino (SAÍDA verde, área restrita vermelha, sala escura),
## texto claro. Fonte em pixels e tamanho do pixel no mundo (linha de ~0,17 m).
const SIGN_ROOM := Color(0.08, 0.32, 0.5)  # azul de placa de indicação
const SIGN_EXIT := Color(0.12, 0.62, 0.28)
const SIGN_RESTRICTED := Color(0.62, 0.1, 0.08)
const SIGN_TEXT := Color(0.95, 0.95, 0.9)
const SIGN_FONT := 48
const SIGN_PX := 0.0036
const EXIT_SIGN := "SAÍDA"
const RESTRICTED_SIGN := "ÁREA RESTRITA"
## Móveis do escritório (`_furniture`): aço pintado (tint do material da parede, acima de 1) e tampo de madeira das mesas.
const CABINET_TINT := Color(1.15, 1.25, 0.85)  # verde-oliva de arquivo de aço
const DESK_TINT := Color(0.85, 0.85, 0.8)
## [tipo, tamanho, centro no chão (x, z), giro (0 = frente para +z)]. "desk" = mesa com tampo de madeira, "cabinet" =
## arquivo de gavetas (os de `Level.LOW_CRATE_H`, soltos, escondem ela agachada), "locker" = armário de vestiário, "chair" =
## cadeira (sem corpo). Esconderijos: a ilha de arquivos do descanso e o arquivo baixo junto da parede oeste do arquivo.
const FURNITURE := [
	["cabinet", Vector3(1.2, Level.LOW_CRATE_H, 1.2), Vector2(-9.6, 53.6), 0.0],
	["locker", Vector3(2.4, 2.0, 0.5), Vector2(-12.55, 54.4), PI * 0.5],
	["desk", Vector3(1.6, 0.76, 0.8), Vector2(-8.0, 55.1), PI],
	["cabinet", Vector3(4.0, Level.LOW_CRATE_H, 0.8), Vector2(-12.4, 46.0), PI * 0.5],
	["cabinet", Vector3(2.0, 2.0, 0.5), Vector2(-7.6, ROOMS_Z - 0.4), PI],
	["locker", Vector3(1.7, 2.0, 0.6), Vector2(1.55, 49.9), 0.0],
	["chair", Vector3(0.5, 0.9, 0.5), Vector2(-1.4, 54.45), 0.0],
	["locker", Vector3(2.4, 2.0, 0.5), Vector2(2.5, 46.6), -PI * 0.5],
]
## Guardas da sala dos clones (mesmo formato de Soldier.GUARDS): 1 de pistola no computador da parede da frente e 2
## examinando o tanque vazio, distraídos (de costas, não veem nada até o barulho os tirar dali), e 1 de ronda no corredor do
## meio.
const LAB_GUARDS := [
	{"pos": Vector3(CloneLab.CONSOLE.x, CloneLab.FLOOR_Y, CloneLab.CONSOLE.z + Level.CONSOLE_GUARD), "rot_y": 0.0, "route": [], "console": true,
		"weapon": "pistol"},
	{"pos": Vector3(-5.2, CloneLab.FLOOR_Y, 13.6), "rot_y": 1.086, "route": [], "console": true},
	{"pos": Vector3(-12.2, CloneLab.FLOOR_Y, 15.6), "rot_y": -0.675, "route": [], "console": true},
	{"route": [Vector3(CloneLab.CX, CloneLab.FLOOR_Y, 25.4), Vector3(CloneLab.CX, CloneLab.FLOOR_Y, 14.6)]},
]
## Portas de serviço dos reforços, na parede leste: [pé da porta, giro (0 = a porta no plano x, abre para +x), dentro da
## saleta]. 0 = sala dos clones, 1 = pátio descoberto, 2 = estantes.
const SERVICE := [
	{"door": Vector3(Level.EAST, CloneLab.FLOOR_Y, 12.0), "yaw": 0.0, "room": Vector3(Level.EAST + 1.4, CloneLab.FLOOR_Y, 12.0)},
	{"door": Vector3(Level.EAST, 0, -6.0), "yaw": 0.0, "room": Vector3(Level.EAST + 1.4, 0, -6.0)},
	{"door": Vector3(Level.EAST, 0, 39.0), "yaw": 0.0, "room": Vector3(Level.EAST + 1.4, 0, 39.0)},
]
const SERVICE_W := 1.2
const SERVICE_H := 2.3
const WAVE := 3
const WAVES := 2
const WAVE_DELAY := 1.5
const WAVE_STAGGER := 0.5
const SECOND_AFTER := 10.0
## O que liga uma área (`zone_of`) à outra para o som: [área, área, chave da porta em `gates`].
const LINKS := [["strip", "office", "mid"], ["office", "dock", "exit"], ["dock", "lab", "lab"], ["lab", "corner", "corner"]]

var player: Player
var mid_gate: Door
var exit_door: Door  # porta do arquivo para as estantes
var corner_gate: Door  # porta enorme da sala dos clones para o pátio descoberto
var barred: Array[Door] = []
var fake_door: Door
var gates := {}  # chave de LINKS -> Door (o som atravessa as abertas)
var guard_gates: Array[Door] = []  # as que os guardas abrem sozinhos
var service_doors: Array[Door] = []
var panel: Terminal
var office_panel: Terminal
var booth_panel: Terminal
var lab_panel: Terminal
var lab_gate: Door  # portão de enrolar da sala dos clones (CloneLab.gate): travado até a cabine
var lab_guards: Array[Soldier] = []
var corner_guards: Array[Enemy] = []  # os de Soldier.GUARDS do pátio descoberto (seção 1)
var racks_guards: Array[Enemy] = []  # os de Soldier.GUARDS das estantes e da doca (seção 2)
var reinforcements: Array = [[], [], []]  # Array[Soldier] por seção (SERVICE)
var waves_sent: Array[int] = [0, 0, 0]
var _red_t: Array[float] = [-1.0, -1.0, -1.0]  # >= 0: contando para a primeira leva
var _wave_at: Array[float] = [-INF, -INF, -INF]  # relógio da última leva
var _pending: Array[Dictionary] = []  # {"s": Soldier, "t": s até entrar, "at": onde ela foi vista}
var _clock := 0.0
var _guard_opened := {}  # Door -> s desde que o vão ficou livre (aberto por guarda; fecha em AUTO_CLOSE)


# ------------------------------------------------------------------ geometria
## Paredes de dentro, portas, escritório, estantes, doca, pátio descoberto e saletas de serviço (o Level chama depois das
## caixas). Devolve as portas.
static func build(parent: Node) -> Dictionary:
	var top := Level.WALL_H
	var w := Level.WEST
	var e := Level.EAST
	var gate_hw := GATE_W * 0.5 + 0.14
	# labirinto | escritório: até o teto, com o portão de grade (o painel fica do lado do labirinto)
	wall(parent, Vector2(w, OFFICE_Z1), Vector2(e, OFFICE_Z1), 0.0, top, [[MID_GATE.x - w - gate_hw, MID_GATE.x - w + gate_hw, 0.0, GATE_H + 0.3]])
	var mid := grate_gate(parent, MID_GATE, GATE_W, PI * 0.5, 1, false)
	# escritório | estantes: até o teto, com as três portas
	var holes := []
	for d: Vector3 in [EXIT_DOOR] + BARRED_DOORS:
		holes.append([d.x - w - DOOR_W * 0.5, d.x - w + DOOR_W * 0.5, 0.0, DOOR_H])
	wall(parent, Vector2(w, OFFICE_Z0), Vector2(e, OFFICE_Z0), 0.0, top, holes)
	var exit := _solid_door(parent, EXIT_DOOR, PI * 0.5, DOOR_H)
	exit.held = true
	exit.add_status_lamp(Vector3(0.25, DOOR_H + 0.1, 0.0))
	var barred_doors: Array[Door] = []
	for d: Vector3 in BARRED_DOORS:
		var bd := _solid_door(parent, d, PI * 0.5, DOOR_H)
		bd.locked_text = BARRED_TEXT
		barred_doors.append(bd)
	_office(parent)
	# estantes e doca (uma sala só), com a cabine
	for r: Array in RACKS:
		_rack(parent, r[0], r[1])
	_dock(parent)
	# sala dos clones | pátio descoberto: até o teto, com a porta enorme; a rampa desce para o pátio
	var hx: float = HUGE_DOOR.x - w
	wall(parent, Vector2(w, Level.ROOF_Z), Vector2(e, Level.ROOF_Z), 0.0, top,
		[[hx - HUGE_W * 0.5, hx + HUGE_W * 0.5, HUGE_DOOR.y, HUGE_DOOR.y + HUGE_H]])
	var corner := _huge_door(parent)
	_ramp(parent, HUGE_DOOR.x - HUGE_W * 0.5, HUGE_DOOR.x + HUGE_W * 0.5, RAMP_Z, Level.ROOF_Z, CloneLab.FLOOR_Y)
	var fake := _solid_door(parent, FAKE_DOOR, 0.0, DOOR_H)
	fake.locked_text = FAKE_TEXT
	_yard(parent)
	_drag_marks(parent)
	# placas de cada porta com o destino e batente pintado nas de aço (de longe se vê onde é a porta e a saída)
	door_signs(parent, MID_GATE, PI * 0.5, GATE_W, GATE_H, WALL_T, "DEPÓSITO", "ESCRITÓRIO", false, top, 0.85)
	door_signs(parent, EXIT_DOOR, PI * 0.5, DOOR_W, DOOR_H, WALL_T, "ESCRITÓRIO", "DOCA", true, OFFICE_CEIL - SLAB, 0.295)
	for d: Vector3 in BARRED_DOORS:
		door_signs(parent, d, PI * 0.5, DOOR_W, DOOR_H, WALL_T, "", "", true)
	door_signs(parent, FAKE_DOOR, 0.0, DOOR_W, DOOR_H, Level.WALL_T, "", "INCUBAÇÃO", true)
	door_signs(parent, Vector3(Level.WEST, 0, Yard.DOOR_Z), 0.0, Yard.DOOR_W, Yard.DOOR_H, Level.WALL_T, EXIT_SIGN, "", false)
	door_signs(parent, CloneLab.GATE, PI * 0.5, CloneLab.GATE_W, CloneLab.GATE_TOP - CloneLab.FLOOR_Y, WALL_T, "", RESTRICTED_SIGN, false)
	door_signs(parent, HUGE_DOOR, PI * 0.5, HUGE_W, HUGE_H, WALL_T, "", EXIT_SIGN, false)
	var doors: Array[Door] = []
	for sv: Dictionary in SERVICE:
		doors.append(_service(parent, sv))
	return {"mid": mid, "exit": exit, "barred": barred_doors, "fake": fake, "corner": corner, "service": doors}


## Escritório: paredes de dentro (até a laje), a laje (teto baixo, sem acesso), o bloqueio do corredor, os móveis, o
## computador da mesa do guarda 11 e a luz de cada sala (a laje tapa as lâmpadas do galpão).
static func _office(parent: Node) -> void:
	var w := Level.WEST
	var e := Level.EAST
	var low := OFFICE_CEIL - SLAB
	var gap := func(at: float) -> Array: return [at - ROOM_GAP * 0.5, at + ROOM_GAP * 0.5, 0.0, DOOR_H]
	for x: float in HALL_X:
		var hs := []
		for rd: Array in ROOM_DOORS:
			if is_equal_approx(rd[0].x, x) and rd[1] == 0.0:
				hs.append(gap.call(rd[0].z - OFFICE_Z0))
		wall(parent, Vector2(x, OFFICE_Z0), Vector2(x, OFFICE_Z1), 0.0, low, hs)
	for side: Array in [[w, HALL_X[0]], [HALL_X[1], e]]:
		var hs := []
		for rd: Array in ROOM_DOORS:
			if rd[1] != 0.0 and rd[0].x > side[0] and rd[0].x < side[1]:
				hs.append(gap.call(rd[0].x - side[0]))
		wall(parent, Vector2(side[0], ROOMS_Z), Vector2(side[1], ROOMS_Z), 0.0, low, hs)
	var c := Vector3((w + e) * 0.5, OFFICE_CEIL - SLAB * 0.5, (OFFICE_Z0 + OFFICE_Z1) * 0.5)
	Level.block(parent, Vector3(e - w, SLAB, OFFICE_Z1 - OFFICE_Z0), c, "concrete", 0.35)
	# bloqueio: duas fileiras de caixas até a laje, de parede a parede do corredor
	var bx := (BLOCKADE[0] + BLOCKADE[2]) * 0.5
	var bz := (BLOCKADE[1] + BLOCKADE[3]) * 0.5
	var bw: float = BLOCKADE[2] - BLOCKADE[0]
	var bd: float = BLOCKADE[3] - BLOCKADE[1]
	Level.block(parent, Vector3(bw, 1.4, bd), Vector3(bx, 0.7, bz), "crate", 1.0 / 1.4, 0.0).set_meta("no_climb", true)
	Level.block(parent, Vector3(bw - 0.04, low - 1.4, bd - 0.04), Vector3(bx, 1.4 + (low - 1.4) * 0.5, bz), "crate", 1.0 / 1.4, 0.0).set_meta("no_climb", true)
	Level.console_at(parent, DESK_CONSOLE, DESK_YAW, false)
	for f: Array in FURNITURE:
		_furniture(parent, f[0], f[1], f[2], f[3])
	for p: Vector2 in [Vector2(-9.3, 52.7), Vector2(-9.3, 46.2), Vector2(-4.2, 47.5), Vector2(0.15, 52.7), Vector2(0.15, 46.2)]:
		var o := OmniLight3D.new()
		o.position = Vector3(p.x, low - 0.25, p.y)
		o.light_color = Color(0.95, 0.95, 0.8)
		o.light_energy = 1.0
		o.omni_range = 5.5
		parent.add_child(o)
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 0.3)
		glow.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.97, 0.85)
		glow.material_override = m
		glow.rotation_degrees.x = 90.0
		glow.position = Vector3(p.x, low - 0.01, p.y)
		parent.add_child(glow)


## Doca (plataforma a CloneLab.FLOOR_Y da parede da sala dos clones até a beira, aberta para as estantes), a escada das
## estantes, a cabine na ponta oeste (piso, pilares, mureta, painel) e a escadinha dela.
static func _dock(parent: Node) -> void:
	var fy := CloneLab.FLOOR_Y
	var w := Level.WEST
	var e := Level.EAST
	Level.block(parent, Vector3(e - w, fy, DOCK_Z[1] - DOCK_Z[0]), Vector3((w + e) * 0.5, fy * 0.5, (DOCK_Z[0] + DOCK_Z[1]) * 0.5), "concrete", 0.35)
	Level.block(parent, Vector3(STAIR[0] - w, 0.02, 0.5), Vector3((w + STAIR[0]) * 0.5, 0.01, DOCK_Z[1] + 0.35), "hazard", 1.0)
	_ramp(parent, STAIR[0], STAIR[1], STAIR[2], STAIR[3], fy)
	# degraus (só desenho) e o corrimão do lado aberto
	var n := 8
	for i in n:
		var k := (i + 0.5) / n
		var z: float = lerpf(STAIR[2], STAIR[3], k)
		var step := Level._prop(parent, BoxMesh.new(), Vector3(STAIR[1] - STAIR[0], 0.04, 0.06), Vector3((STAIR[0] + STAIR[1]) * 0.5, fy * k + 0.02, z), "wall", 2.0)
		step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Level._pipe(parent, Vector3(STAIR[0] + 0.05, 1.0, STAIR[2]), Vector3(STAIR[0] + 0.05, fy + 1.0, STAIR[3]), 0.03)
	Level._pipe(parent, Vector3(STAIR[0] + 0.05, 0.0, STAIR[2]), Vector3(STAIR[0] + 0.05, 1.0, STAIR[2]), 0.03)
	# cabine
	var b0: float = BOOTH[0]
	var b1: float = BOOTH[1]
	var bz0: float = BOOTH[2]
	var bz1: float = BOOTH[3]
	Level.block(parent, Vector3(b1 - b0, SLAB, bz1 - bz0), Vector3((b0 + b1) * 0.5, BOOTH_Y - SLAB * 0.5, (bz0 + bz1) * 0.5), "concrete", 0.35)
	for p: Vector2 in [Vector2(b1 - 0.15, bz1 - 0.15), Vector2(b0 + 0.35, bz1 - 0.15)]:
		Level.block(parent, Vector3(0.22, BOOTH_Y - SLAB, 0.22), Vector3(p.x, (BOOTH_Y - SLAB) * 0.5, p.y), "wall", 1.5)
	var lz := BOOTH_LADDER.z
	_booth_rail(parent, Vector2(b0, bz1), Vector2(b1, bz1))
	_booth_rail(parent, Vector2(b1, bz1), Vector2(b1, lz + 0.5))
	Level.console_at(parent, BOOTH_CONSOLE, BOOTH_YAW, true)
	var ladder := Ladder.new()
	ladder.height = BOOTH_Y - fy
	ladder.position = BOOTH_LADDER
	ladder.rotation.y = -PI * 0.5  # quem sobe olha para oeste (a cabine)
	parent.add_child(ladder)


## Mureta da cabine de `a` a `b` (sólida: segura o corpo e dá para mirar por cima).
static func _booth_rail(parent: Node, a: Vector2, b: Vector2) -> void:
	var d := b - a
	var m := (a + b) * 0.5
	Level.block(parent, Vector3(d.length(), BOOTH_WALL_H, 0.08), Vector3(m.x, BOOTH_Y + BOOTH_WALL_H * 0.5, m.y), "wall", 1.0, -atan2(d.y, d.x))


## Rampa de x0 a x1 que sobe de y 0 em `z_low` até `h` em `z_high` (o lado de baixo é cheio até o chão: ninguém entra
## debaixo dela). Corpo de cenário (anda-se nela; a malha de navegação também).
static func _ramp(parent: Node, x0: float, x1: float, z_low: float, z_high: float, h: float) -> void:
	var length := absf(z_high - z_low)
	var dir := signf(z_high - z_low)
	var a := atan2(h, length)
	var th := -dir * a
	var t := h + 0.6
	var up := Vector3(0, cos(th), sin(th))
	var top := Vector3((x0 + x1) * 0.5, h * 0.5, (z_low + z_high) * 0.5)
	var body := Level.block(parent, Vector3(x1 - x0, t, sqrt(length * length + h * h)), top - up * t * 0.5, "concrete", 0.35)
	body.rotation.x = th


## Porta enorme (sala dos clones → pátio descoberto): folha de aço com faixas, do lado do pátio, que corre para oeste.
static func _huge_door(parent: Node) -> Door:
	var door := Door.create(parent, HUGE_DOOR, Vector3(HUGE_W, HUGE_H, 0.3), -1, "ABRIR PORTÃO")
	door.held = true
	door.add_status_lamp(Vector3(HUGE_W * 0.5 + 0.4, HUGE_H - 0.4, -0.25))
	var leaf := Node3D.new()
	var paint := Level.material("concrete", 1.4)
	paint.set_shader_parameter("tint", DOOR_PAINT * 0.85)
	var steel := Level.material("concrete", 2.0)
	steel.set_shader_parameter("tint", STEEL_TINT)
	var stripes := Level.material("hazard", 1.0)
	stripes.set_shader_parameter("world_uv", false)
	_gate_box(leaf, Vector3(HUGE_W + 0.2, HUGE_H + 0.1, 0.12), Vector3(0, (HUGE_H + 0.1) * 0.5, 0), paint)
	for k in 5:
		_gate_box(leaf, Vector3(HUGE_W + 0.2, 0.08, 0.16), Vector3(0, 0.5 + k * (HUGE_H - 0.8) / 4.0, 0), steel)
	_gate_box(leaf, Vector3(HUGE_W + 0.2, 0.3, 0.14), Vector3(0, 0.15, 0), stripes)
	leaf.position = Vector3(0, 0, -0.3)
	door.add_panel(leaf, Vector3(-HUGE_W - 0.15, 0, -0.3), 0.0)
	return door


## Pátio descoberto: caminhão sendo carregado (caçamba fechada com a traseira aberta, portas abertas para os lados),
## container de carga, as pilhas altas e as luzes de parede.
static func _yard(parent: Node) -> void:
	var t0: float = TRUCK[0]
	var t1: float = TRUCK[1]
	var tz0: float = TRUCK[2]
	var tz1: float = TRUCK[3]
	var cx := (t0 + t1) * 0.5
	var cz := (tz0 + tz1) * 0.5
	var olive := Level.material("wall", 1.0)
	olive.set_shader_parameter("tint", Color(0.75, 0.85, 0.55))
	var chassis := Level.block(parent, Vector3(t1 - t0, TRUCK_BED - 0.35, tz1 - tz0), Vector3(cx, 0.35 + (TRUCK_BED - 0.35) * 0.5, cz), "wall", 1.0)
	chassis.set_meta("surface", "metal")
	var hi := TRUCK_TOP - TRUCK_BED
	for z in [tz0 + 0.04, tz1 - 0.04]:
		var side := Level.block(parent, Vector3(t1 - t0, hi, 0.08), Vector3(cx, TRUCK_BED + hi * 0.5, z), "wall", 1.0)
		(side.get_child(0) as MeshInstance3D).material_override = olive
		side.set_meta("surface", "metal")
	var front := Level.block(parent, Vector3(0.08, hi, tz1 - tz0), Vector3(t0 + 0.04, TRUCK_BED + hi * 0.5, cz), "wall", 1.0)
	(front.get_child(0) as MeshInstance3D).material_override = olive
	var roof := Level.block(parent, Vector3(t1 - t0 + 0.1, 0.08, tz1 - tz0 + 0.1), Vector3(cx, TRUCK_TOP + 0.04, cz), "wall", 1.0)
	(roof.get_child(0) as MeshInstance3D).material_override = olive
	# portas da traseira abertas para os lados
	for s in [-1, 1]:
		var hinge := Vector2(t1, tz0 if s < 0 else tz1)
		var tip := hinge + Vector2(0.8, s * 0.4)
		var d := tip - hinge
		var m := (hinge + tip) * 0.5
		var leaf := Level.block(parent, Vector3(d.length() + 0.5, hi, 0.06), Vector3(m.x, TRUCK_BED + hi * 0.5, m.y), "wall", 1.0, -atan2(d.y, d.x))
		(leaf.get_child(0) as MeshInstance3D).material_override = olive
	# rodas e pés de apoio (só desenho)
	for x in [t0 + 0.8, t1 - 1.2, t1 - 0.4]:
		for z in [tz0 - 0.02, tz1 + 0.02]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.48
			wheel.bottom_radius = 0.48
			wheel.height = 0.3
			var mi := Level._prop(parent, wheel, Vector3.ZERO, Vector3(x, 0.48, z), "wall", 3.0)
			mi.rotation_degrees.x = 90.0
			(mi.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.2, 0.2, 0.22))
	# container de carga
	var c: Array = CONTAINER
	var box := Level.block(parent, Vector3(c[1] - c[0], c[4], c[3] - c[2]), Vector3((c[0] + c[1]) * 0.5, c[4] * 0.5, (c[2] + c[3]) * 0.5), "wall", 1.5)
	((box.get_child(0) as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("tint", Color(1.3, 0.6, 0.35))
	box.set_meta("surface", "metal")
	box.set_meta("no_climb", true)
	for sc: Vector2 in CORNER_SCREEN:
		for k in [0, 1]:
			var crate := Level.block(parent, Vector3(1.22, 1.22, 1.22), Vector3(sc.x, 0.61 + k * 1.22, sc.y), "crate", 1.0 / 1.22, 0.02 - k * 0.05)
			crate.set_meta("no_climb", true)
	for p: Vector3 in YARD_LAMPS:
		var out := Vector3(Level.CX - p.x, 0, -2.0 - p.z).normalized()
		var fixture := Level._prop(parent, BoxMesh.new(), Vector3(0.5, 0.2, 0.5), p, "wall", 2.0)
		fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var o := OmniLight3D.new()
		o.position = p + out * 0.5 + Vector3.DOWN * 0.2
		o.light_color = Color(1.0, 0.82, 0.55)
		o.light_energy = 1.6
		o.omni_range = 12.0
		o.omni_attenuation = 1.2
		parent.add_child(o)


## Marcas de arrasto (DRAG): duas faixas escuras e paralelas, rentes ao chão, sem colisão.
static func _drag_marks(parent: Node) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.05, 0.04, 0.03, 0.55)
	for i in DRAG.size() - 1:
		var a: Vector3 = DRAG[i] + Vector3.UP * 0.015
		var b: Vector3 = DRAG[i + 1] + Vector3.UP * 0.015
		var d := b - a
		var side := Vector3(d.z, 0, -d.x).normalized()
		for s in [-0.55, 0.55]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.22, 0.004, d.length() + 0.25)
			mi.mesh = bm
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			mi.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), (a + b) * 0.5 + side * s)


## Parede sólida (camada do cenário: segura corpo, tiro e vista) de `a` a `b` no chão, de `y0` a `y1`, com os vãos
## `holes` = [[de, até (m a partir de `a`), y de baixo, y de cima]] (porta: do chão; janela: peitoril e verga).
static func wall(parent: Node, a: Vector2, b: Vector2, y0: float, y1: float, holes := [], thick := WALL_T) -> void:
	var d := b - a
	var length := d.length()
	var dir := d / length
	var yaw := -atan2(d.y, d.x)
	var cuts := holes.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var piece := func(s0: float, s1: float, h0: float, h1: float) -> void:
		h0 = maxf(h0, y0)
		h1 = minf(h1, y1)
		if s1 - s0 < 0.01 or h1 - h0 < 0.01:
			return
		var m := a + dir * (s0 + s1) * 0.5
		Level.block(parent, Vector3(s1 - s0, h1 - h0, thick), Vector3(m.x, (h0 + h1) * 0.5, m.y), "wall", 0.5, yaw)
	var s := 0.0
	for c: Array in cuts:
		piece.call(s, c[0], y0, y1)
		piece.call(c[0], c[1], y0, c[2])
		piece.call(c[0], c[1], c[3], y1)
		s = c[1]
	piece.call(s, length, y0, y1)


## Porta de aço de uma folha num vão da parede (`yaw` 0 = vão ao longo de z), abre com E; fora da corrente de salas.
static func _solid_door(parent: Node, at: Vector3, yaw: float, h: float) -> Door:
	var door := Door.create(parent, at, Vector3(0.2, h, DOOR_W), -1, "ABRIR PORTA")
	door.rotation.y = yaw
	var slab := _steel_leaf(h, DOOR_W - 0.04)
	slab.position = Vector3(0, 0, -DOOR_W * 0.5)
	door.add_panel(slab, slab.position, deg_to_rad(-100.0))
	return door


## Folha de porta de aço industrial (dobradiça em z = 0, folha até `w` + 0,02): chapa lisa pintada (`DOOR_PAINT` sobre o
## concreto = pintura gasta, sem as emendas de chapa da parede que pareciam tábuas), almofada embaixo, visor de vidro aramado
## na altura do olho, chapa de chute e maçaneta de alavanca dos dois lados e as três dobradiças.
static func _steel_leaf(h: float, w: float) -> Node3D:
	var leaf := Node3D.new()
	var paint := Level.material("concrete", 1.4)
	paint.set_shader_parameter("tint", DOOR_PAINT)
	var inset := Level.material("concrete", 1.4)
	inset.set_shader_parameter("tint", DOOR_PAINT * 0.78)
	var steel := Level.material("concrete", 2.0)
	steel.set_shader_parameter("tint", STEEL_TINT)
	var glass := Level.material("concrete", 3.0)
	glass.set_shader_parameter("tint", Color(0.16, 0.22, 0.27))
	var mid := w * 0.5 + 0.02
	_gate_box(leaf, Vector3(0.06, h, w), Vector3(0, h * 0.5, mid), paint)
	var win_y := minf(1.6, h - 0.45)
	for f in [-1, 1]:
		var x: float = f * 0.034
		_gate_box(leaf, Vector3(0.012, 0.75, w - 0.32), Vector3(x, 0.72, mid), inset)  # almofada
		_gate_box(leaf, Vector3(0.012, 0.22, w - 0.1), Vector3(x, 0.13, mid), steel)  # chapa de chute
		# visor: aro de aço, vidro escuro e o arame em cruz
		_gate_box(leaf, Vector3(0.014, 0.46, 0.34), Vector3(x, win_y, mid), steel)
		_gate_box(leaf, Vector3(0.016, 0.38, 0.26), Vector3(f * 0.036, win_y, mid), glass)
		_gate_box(leaf, Vector3(0.018, 0.38, 0.012), Vector3(f * 0.037, win_y, mid), steel)
		_gate_box(leaf, Vector3(0.018, 0.012, 0.26), Vector3(f * 0.037, win_y, mid), steel)
		# maçaneta de alavanca perto da beira livre: espelho, haste e alavanca virada para a dobradiça
		var hz := w - 0.08
		_gate_box(leaf, Vector3(0.014, 0.2, 0.06), Vector3(x, 1.05, hz), steel)
		_gate_box(leaf, Vector3(0.05, 0.03, 0.03), Vector3(f * 0.06, 1.1, hz), steel)
		_gate_box(leaf, Vector3(0.025, 0.03, 0.14), Vector3(f * 0.085, 1.1, hz - 0.06), steel)
	for y in [0.25, h * 0.5, h - 0.25]:
		_gate_box(leaf, Vector3(0.08, 0.14, 0.03), Vector3(0, y, 0.0), steel)
	return leaf


## Móvel do escritório (ver FURNITURE): corpo sólido de aço pintado e os detalhes que dizem o que ele é (tampo de
## madeira, frestas e puxadores das gavetas, portas com respiro do armário), sem colisão.
static func _furniture(parent: Node, kind: String, size: Vector3, c: Vector2, yaw: float) -> void:
	if kind == "chair":
		# cadeira só de desenho (o guarda distraído fica encostado nela): assento de madeira, encosto e pés de aço
		var cb := Basis(Vector3.UP, yaw)
		var cp := Vector3(c.x, 0.0, c.y)
		var leg := Level.material("wall", 2.0)
		_steel(parent, Vector3(size.x, 0.05, size.z), cp + Vector3.UP * 0.46, cb, Level.material("planks", 1.0))
		_steel(parent, Vector3(size.x, size.y - 0.5, 0.05), cp + cb * Vector3(0, 0.5 + (size.y - 0.5) * 0.5, -size.z * 0.5), cb, Level.material("planks", 1.0))
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_steel(parent, Vector3(0.04, 0.45, 0.04), cp + cb * Vector3(sx * (size.x * 0.5 - 0.04), 0.225, sz * (size.z * 0.5 - 0.04)), cb, leg)
		return
	var body_h := size.y - (0.04 if kind == "desk" else 0.0)
	var body := Level.block(parent, Vector3(size.x, body_h, size.z), Vector3(c.x, body_h * 0.5, c.y), "wall", 2.0, yaw)
	((body.get_child(0) as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("tint",
		DESK_TINT if kind == "desk" else CABINET_TINT)
	var basis := Basis(Vector3.UP, yaw)
	var base := Vector3(c.x, 0.0, c.y)
	var face := size.z * 0.5 + 0.006
	var dark := Level.material("wall", 4.0)
	dark.set_shader_parameter("tint", Color(0.2, 0.2, 0.2))
	var at := func(x: float, y: float) -> Vector3: return base + basis * Vector3(x, y, face)
	if kind == "desk":
		_steel(parent, Vector3(size.x + 0.06, 0.04, size.z + 0.06), base + Vector3.UP * (size.y - 0.02), basis, Level.material("planks", 1.0))
		return
	var col_w := 0.6 if kind == "locker" else 0.5
	var cols := maxi(roundi(size.x / col_w), 1)
	var rows := 1 if kind == "locker" else maxi(roundi(size.y / 0.38), 1)
	var cw := size.x / cols
	for i in range(1, cols):
		_steel(parent, Vector3(0.015, size.y - 0.04, 0.012), at.call(-size.x * 0.5 + cw * i, size.y * 0.5), basis, dark)
	for r in range(1, rows):
		_steel(parent, Vector3(size.x - 0.04, 0.015, 0.012), at.call(0.0, size.y * r / rows), basis, dark)
	for i in cols:
		var x := -size.x * 0.5 + cw * (i + 0.5)
		if kind == "locker":
			for k in 3:  # respiro em cima e o puxador do lado
				_steel(parent, Vector3(cw * 0.5, 0.02, 0.012), at.call(x, size.y - 0.22 - k * 0.06), basis, dark)
			_steel(parent, Vector3(0.03, 0.14, 0.02), at.call(x + cw * 0.32, size.y * 0.5), basis, dark)
		else:
			for r in rows:
				_steel(parent, Vector3(cw * 0.4, 0.03, 0.025), at.call(x, size.y * (r + 1) / rows - 0.08), basis, dark)


## Placa acesa sobre o vão de uma porta ou portão e, com `frame`, o batente de faixa de perigo em volta (só desenho, sem
## colisão). `yaw` 0 = vão ao longo de z (como as portas); `plus` = texto do lado +x local, `minus` = do -x ("" = sem
## placa daquele lado). Sem espaço até o teto (`room_top`, no mundo) a placa vai ao lado do vão. `lift` = do alto do vão
## ao meio da placa (os portões de grade têm o lampião em cima).
static func door_signs(parent: Node, at: Vector3, yaw: float, width: float, h: float, wall_t: float, plus: String,
		minus: String, frame := true, room_top := Level.WALL_H, lift := 0.3) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	var steel := Level.material("concrete", 2.0)
	steel.set_shader_parameter("tint", STEEL_TINT)
	if frame:
		# batente de aço (perfil que abraça a parede) com a faixa amarela e preta na frente, listras de ~10 cm
		var stripes := Level.material("hazard", 2.5)
		var d := wall_t + 0.08
		var fw := 0.14
		for s in [-1, 1]:
			var z: float = s * (width * 0.5 + fw * 0.5)
			_gate_box(root, Vector3(d, h + fw, fw), Vector3(0, (h + fw) * 0.5, z), steel)
			for f in [-1, 1]:
				_gate_box(root, Vector3(0.01, h + fw - 0.03, fw - 0.03), Vector3(f * (d * 0.5 + 0.005), (h + fw) * 0.5, z), stripes)
		_gate_box(root, Vector3(d, fw, width + fw * 2.0), Vector3(0, h + fw * 0.5, 0), steel)
		for f in [-1, 1]:
			_gate_box(root, Vector3(0.01, fw - 0.03, width + fw * 2.0 - 0.03), Vector3(f * (d * 0.5 + 0.005), h + fw * 0.5, 0), stripes)
	var above := at.y + h + lift + 0.15 < room_top
	for side in [1, -1]:
		var text: String = plus if side == 1 else minus
		if text == "":
			continue
		# caixa de luz de aço presa na parede, com a face acesa e o texto
		var pw := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT).x * SIGN_PX + 0.16
		var out: float = side * (wall_t * 0.5 + 0.04)
		var pos := Vector3(out, h + lift, 0.0) if above else Vector3(out, minf(h - 0.3, 1.9), width * 0.5 + 0.3 + pw * 0.5)
		_gate_box(root, Vector3(0.08, 0.3, pw + 0.06), pos, steel)
		var panel := StandardMaterial3D.new()
		panel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		panel.albedo_color = SIGN_EXIT if text == EXIT_SIGN else (SIGN_RESTRICTED if text == RESTRICTED_SIGN else SIGN_ROOM)
		pos.x += side * 0.041
		_gate_box(root, Vector3(0.004, 0.24, pw), pos, panel)
		var l := Label3D.new()
		l.text = text
		l.font_size = SIGN_FONT
		l.pixel_size = SIGN_PX
		l.outline_size = 0
		l.modulate = SIGN_TEXT
		l.shaded = false
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.position = pos + Vector3(side * 0.004, 0.0, 0.0)
		l.rotation.y = side * PI * 0.5
		root.add_child(l)


## Estante porta-paletes cheia de caixas: miolo sólido (não se escala), colunas de aço nas pontas e a cada ~2,4 m e as
## longarinas de cada prateleira.
static func _rack(parent: Node, c: Vector2, size: Vector2) -> void:
	var core := Level.block(parent, Vector3(size.x, RACK_H, size.y), Vector3(c.x, RACK_H * 0.5, c.y), "crate", 0.8)
	core.set_meta("no_climb", true)
	var along_x := size.x > size.y
	var length: float = size.x if along_x else size.y
	var depth: float = size.y if along_x else size.x
	var n := maxi(roundi(length / 2.4), 1)
	var steel := Level.material("wall", 2.0)
	steel.set_shader_parameter("tint", Color(0.55, 0.62, 0.75))
	var basis := Basis() if along_x else Basis(Vector3.UP, PI * 0.5)
	for i in n + 1:
		var s := -length * 0.5 + length * i / float(n)
		for side in [-1, 1]:
			_steel(parent, Vector3(0.09, RACK_H + 0.05, 0.09), Vector3(c.x, RACK_H * 0.5, c.y) + basis * Vector3(s, 0, side * (depth * 0.5 + 0.03)), basis, steel)
	for y in [0.15, 1.6, 3.1, RACK_H - 0.05]:
		for side in [-1, 1]:
			_steel(parent, Vector3(length, 0.12, 0.05), Vector3(c.x, y, c.y) + basis * Vector3(0, 0, side * (depth * 0.5 + 0.04)), basis, steel)


static func _steel(parent: Node, size: Vector3, pos: Vector3, basis: Basis, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)


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
## `swing` = 1 abre as folhas para +X local (antes do giro), -1 para -X.
## `top_fence` falso = sem o alambrado acima da travessa (portão num vão de parede sólida).
static func grate_gate(parent: Node, at: Vector3, width: float, yaw: float, swing := 1, top_fence := true) -> Door:
	var door := Door.create(parent, at, Vector3(0.2, GATE_H, width), -1, "ABRIR GRADE")
	door.rotation.y = yaw
	door.solid_layer = Yard.GRATE_LAYER
	door.collision_layer = Yard.GRATE_LAYER
	door.held = true
	if top_fence:
		door.add_status_lamp(Vector3(0.0, GATE_H + 0.42, 0.0))
	else:  # num vão de parede: o lampião atravessa a parede e aparece dos dois lados, acima do vão
		door.add_status_lamp(Vector3(0.0, GATE_H + 0.45, 0.0), Vector3(WALL_T + 0.08, 0.16, 0.16))
	var along := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	var a := at - along * (width * 0.5 + 0.12)
	var b := at + along * (width * 0.5 + 0.12)
	if top_fence:
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
		door.add_panel(leaf, leaf.position, s * swing * deg_to_rad(-95.0))
	return door


static func _gate_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## `a` e `b` estão separados pela porta enorme fechada (um no pátio descoberto, o outro fora dele): nem vista nem som nem
## alarme passa (Enemy._reaches / _sees_target).
static func apart(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
	if Level.room_of(a.x) != 0 or Level.room_of(b.x) != 0:
		return false  # fora do galpão (pátio da mata pelo portão, túnel...): vale a corrente de salas e portas
	if in_corner(a) == in_corner(b):
		return false
	var sh := tree.get_first_node_in_group("shed") as Shed
	return sh != null and sh.corner_gate != null and not sh.corner_gate.opened


## Área do galpão de um ponto (para o som): "strip" (labirinto e mezanino), "office" (escritório), "dock" (estantes, doca e
## cabine), "lab" (sala dos clones), "corner" (pátio descoberto); "" fora do galpão (as saletas de serviço também).
static func zone_of(p: Vector3) -> String:
	if Level.room_of(p.x) != 0 or p.x > Level.EAST or p.z < Level.SOUTH - 0.2 or p.z > Level.NORTH + 0.2:
		return ""
	if p.z < Level.ROOF_Z:
		return "corner"
	if p.z < CloneLab.Z_NEAR:
		return "lab"
	if p.z < OFFICE_Z0:
		return "dock"
	if p.z < OFFICE_Z1:
		return "office"
	return "strip"


## Som de `a` não chega a `b`: estão em áreas do galpão diferentes e nenhum caminho de portas abertas as liga.
static func muffled(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
	var za := zone_of(a)
	var zb := zone_of(b)
	if za == "" or zb == "" or za == zb:
		return false
	var sh := tree.get_first_node_in_group("shed") as Shed
	if sh == null or sh.gates.is_empty():
		return false
	var reached := {za: true}
	var grew := true
	while grew:
		grew = false
		for l: Array in LINKS:
			var g: Door = sh.gates.get(l[2])
			if g == null or not g.opened:
				continue
			for k in [0, 1]:
				if reached.has(l[k]) and not reached.has(l[1 - k]):
					reached[l[1 - k]] = true
					grew = true
	return not reached.has(zb)


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
## Liga o que o Level montou (`built`), os computadores e os guardas. `guards` = {"panel", "office", "booth": Enemy (quem
## mexe em cada computador), "corner", "racks": Array[Enemy] (os de Soldier.GUARDS das seções 1 e 2)}; `spawn` =
## Callable(Dictionary) -> Soldier do main; `gate` = o portão da sala dos clones (travado até a cabine).
func setup(built: Dictionary, guards: Dictionary, spawn: Callable, gate: Door = null) -> void:
	mid_gate = built.mid
	exit_door = built.exit
	corner_gate = built.corner
	barred.assign(built.barred)
	fake_door = built.fake
	service_doors.assign(built.service)
	lab_gate = gate
	gates = {"mid": mid_gate, "exit": exit_door, "corner": corner_gate}
	if lab_gate:
		gates["lab"] = lab_gate
		lab_gate.held = true
		lab_gate.add_status_lamp(Vector3(CloneLab.GATE_W * 0.5 + 0.35, CloneLab.GATE_TOP - CloneLab.FLOOR_Y - 0.5, 0.3))
	guard_gates.assign([mid_gate, exit_door, corner_gate])
	corner_guards.assign(guards.get("corner", []))
	racks_guards.assign(guards.get("racks", []))
	panel = _terminal(PANEL_USE, guards.get("panel"), "USAR COMPUTADOR")
	panel.used.connect(func() -> void: _unlock(mid_gate, "panel"))
	office_panel = _terminal(OFFICE_USE, guards.get("office"))
	office_panel.used.connect(func() -> void: _unlock(exit_door, "office"))
	booth_panel = _terminal(BOOTH_USE, guards.get("booth"))
	booth_panel.used.connect(_control)
	for g: Dictionary in LAB_GUARDS:
		lab_guards.append(spawn.call(g))
	lab_panel = _terminal(LAB_USE, lab_guards[0])
	lab_panel.used.connect(_open_huge)
	for i in SERVICE.size():
		for k in WAVE * WAVES:
			var room: Vector3 = SERVICE[i].room
			var at := room + Vector3((k % 3 - 1) * 0.55, 0, (k / 3 - 0.5) * 0.6).rotated(Vector3.UP, SERVICE[i].yaw)
			var sd: Soldier = spawn.call({"pos": at, "rot_y": SERVICE[i].yaw + PI * 0.5, "route": []})
			reinforcements[i].append(sd)
	reset()


func _terminal(use: Array, guard: Enemy, verb := "") -> Terminal:
	var t := Terminal.new()
	t.guard = guard
	if verb != "":
		t.verb = verb
	add_child(t)
	t.global_position = use[0]
	t.rotation.y = use[1]
	return t


func _unlock(gate: Door, id: String) -> void:
	gate.set_held(false)
	objective.emit(id)


## Computador da cabine: destrava o portão de enrolar da sala dos clones.
func _control() -> void:
	if lab_gate:
		lab_gate.set_held(false)
	objective.emit("control")


## Computador do laboratório: a porta enorme corre e abre o caminho para o pátio descoberto.
func _open_huge() -> void:
	corner_gate.set_held(false, true)
	corner_gate.open()
	objective.emit("lab")


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


## R / do zero: portões e portas travados, computadores sem uso, reforços na saleta, portas de serviço fechadas.
func reset() -> void:
	_pending.clear()
	_clock = 0.0
	for i in waves_sent.size():
		waves_sent[i] = 0
		_red_t[i] = -1.0
		_wave_at[i] = -INF
	_guard_opened.clear()
	mid_gate.set_held(true, true)
	exit_door.set_held(true, true)
	corner_gate.set_held(true, true)
	if lab_gate:
		lab_gate.set_held(true, true)
	for t: Terminal in [panel, office_panel, booth_panel, lab_panel]:
		t.load_done(false)
	for list: Array in reinforcements:
		for sd: Soldier in list:
			if not sd.cleared:
				_hide(sd)


func save_state() -> Dictionary:
	return {"panel": panel.done, "office": office_panel.done, "control": booth_panel.done, "lab": lab_panel.done}


## Checkpoint (depois do restore dos inimigos): computadores como estavam, portas pelo uso deles; reforço vivo volta para a
## saleta e a leva dele conta como não mandada (morto segue fora do jogo).
func load_state(s: Dictionary) -> void:
	_pending.clear()
	_guard_opened.clear()
	panel.load_done(s.get("panel", false))
	office_panel.load_done(s.get("office", false))
	booth_panel.load_done(s.get("control", false))
	lab_panel.load_done(s.get("lab", false))
	mid_gate.set_held(not s.get("panel", false), true)
	exit_door.set_held(not s.get("office", false), true)
	if lab_gate:
		lab_gate.set_held(not s.get("control", false), true)
	corner_gate.set_held(not s.get("lab", false), true)
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


## No pátio descoberto (do lado de fora da parede da sala dos clones; a saleta de serviço dele conta), no chão ou na rampa.
static func in_corner(p: Vector3) -> bool:
	return p.y < 2.0 and p.x > Level.WEST - 0.3 and p.x < Level.EAST + 3.0 and p.z < Level.ROOF_Z - WALL_T * 0.5 and p.z > Level.SOUTH - 0.3


## Ela está na seção `i` (0 = sala dos clones, 1 = pátio descoberto, 2 = estantes e doca)?
static func in_section(i: int, p: Vector3) -> bool:
	if i == 0:
		return CloneLab.inside(p)
	if i == 1:
		return in_corner(p)
	return zone_of(p) == "dock"


func section_guards(i: int) -> Array:
	var out: Array = []
	out.append_array([lab_guards, corner_guards, racks_guards][i])
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


## Guarda (vivo, em cena, fora de rotina parada) chegando a uma porta que ele abre (`guard_gates`) fechada a abre,
## travada ou não; a que um guarda abriu fecha sozinha AUTO_CLOSE s depois de o vão ficar livre (a travada continua travada).
func _guards_at_gates(delta: float) -> void:
	for gate: Door in guard_gates:
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
