class_name Soldier
extends Enemy
## Guerrilheiro inimigo (humano encapuzado com M16). Percepção, patrulha e alarme vêm de Enemy (o alarme também chama os raptors, e o
## grito de um raptor chama os soldados). Ao vê-la, ergue a arma ("alert", um instante para reagir) e entra em
## combate ("engage"): mira nela, atira em rajadas longas de tiro instantâneo com descanso curto (acerta menos de longe,
## se ela está agachada ou correndo, e cada tiro da rajada sobe mais que o anterior; rolar esquiva) e se mexe: avança se
## está longe, recua se ela chega perto e anda de lado no resto. Ela some atrás de algo: ainda despeja SUPPRESS_TIME de
## tiros onde ela estava, só com linha livre até lá (na caixa/parede em que ela se esconde ele não atira). Sem vê-la por LOSE_TIME vai ao último lugar onde a viu. Morre em ragdoll, como os alvos de treino.

signal killed
signal fired

# guerrilheiro encapuzado: o esqueleto e as animações da heroína, com corpo, capuz e textura próprios (art/build_guerrilla.py)
const BODY := preload("res://assets/characters/guerrilla.glb")
const ATLAS := preload("res://assets/characters/guerrilla_atlas.png")
const MAX_HEALTH := 60
const WEAPON := "m16"
const DROP_ASIDE := 0.9  # a arma largada cai a isto do lado do corpo (embaixo dele não se via)
const DAMAGE := 7
const FIRE_RANGE := 22.0  # alcance do tiro
const ENGAGE_DIST := 10.0  # mais longe que isto, avança
const KEEP_DIST := 5.0  # mais perto que isto, recua
## Entre vê-la e o primeiro tiro: pego de surpresa (rotina, busca amarela, correndo para a área) ergue a arma e só então
## atira (REACT_TIME); na busca ativa, já de arma em punho num ponto (`weapon_ready`), reage na hora (REACT_READY).
const REACT_TIME := 0.3
const REACT_READY := 0.1
const TIME_SCALE := 0.85  # busca ativa e alerta vermelho 15% mais curtos que os dos bichos (alert_time/lose_time/search_time)
const OBSERVE_DIST := 2.0  # busca amarela: para a esta distância do lugar suspeito e observa
const READY_TURN := 7.0  # busca ativa: giro do corpo (com a arma) de um ângulo ao outro, firme, sem a cabeça sozinha
const BURST_SHOTS := [4, 7]
const SHOT_GAP := 0.1
const REST_TIME := [0.3, 0.7]
const BURST_DECAY := 0.8  # chance de acerto de cada tiro da rajada = a do anterior vezes isto (o cano sobe)
const LOCK_TIME := 0.3  # mirando nela à vista por este tempo antes do primeiro acerto: o sensor de perigo sobe antes (aviso)
const SUPPRESS_TIME := 1.2  # depois de perdê-la de vista, continua atirando onde ela estava por este tempo
## Guarda de pistola (`weapon` "pistol", o do painel): tiros soltos mais espaçados e mais fortes, alcance menor.
const PISTOL := {"damage": 9, "burst": [1, 3], "gap": 0.4, "range": 16.0}
const COMBAT := ["alert", "engage", "roll"]
## Cambalhota de luta (a mesma da heroína, `heroine_moves.json` "roll", ~2,6 m em 1 s): ao entrar em luta (`ROLL_ENTER_CHANCE`,
## de lado e um pouco para a frente, em vez de parar na frente dela) e esquivando quando ela mira nele (`ROLL_AIM_CONE`, chance
## `ROLL_DODGE_RATE` por segundo), no máximo uma a cada `ROLL_COOLDOWN` s; só com o corpo livre até o fim e chão da malha lá.
const ROLL_ENTER_CHANCE := 0.6
const ROLL_DODGE_RATE := 0.9
const ROLL_COOLDOWN := 3.5
const ROLL_AIM_CONE := deg_to_rad(9.0)
const ROLL_DIST := 2.6
## Em luta com outros: cada um toma um ângulo em volta dela (`FLANK_STEP` do vizinho, a partir da direção média do grupo) e
## vai para lá atirando, em vez de chegarem todos pelo mesmo corredor, um atrás do outro (`_flank_goal`, refeito a cada
## `FLANK_REPLAN` s; vaga com caminho longo demais ou sem vista dela não serve).
const FLANK_STEP := deg_to_rad(50.0)
const FLANK_REPLAN := 1.2
const FLANK_ARRIVE := 1.0
## Atirando em movimento: mais longe que `RUN_GUN_FAR` do destino vai no trote atirando; a pontaria cai com a velocidade
## dele (`MOVING_AIM`: andando / correndo).
const RUN_GUN_FAR := 3.5
const MOVING_AIM := [0.85, 0.55]
const TAUNT_CHANCE := 0.3  ## chance de provocar (`Voice` "taunt") no começo de uma rajada com ela à vista
## Sem linha de tiro (caixa, quina ou parede entre o cano e ela) por PEEK_AFTER s: dá um passo de lado até a beirada mais
## perto de onde o cano a vê (PEEK_STEPS m, os dois lados) e se inclina para fora (PEEK_LEAN); nenhuma beirada serve,
## avança para cima dela pelo caminho (agressivo). Nunca atira com o cano dentro/atrás da cobertura (`_body_block`).
const PEEK_AFTER := 0.35
const PEEK_STEPS := [0.5, 0.9, 1.4, 2.0, 2.7]
const PEEK_LEAN := 0.2
const PEEK_REPLAN := 0.6
const CHAR_TIME := 4.0  # s até o corpo que pegou fogo ficar carbonizado
const VEST_PARTS := ["Spine", "Chest", ""]  # o colete cobre o tronco ("" = tiro na cápsula: o meio do corpo)
const VEST_MULT := 0.5  # colete comum: tiro no tronco tira metade (braços, pernas e cabeça sem proteção)
const FLAK_MULT := 0.12  # Flak Jacket: o tronco quase não sente, só a cabeça (ou braço/perna) resolve
const FLAK_TEXT := "FLAK JACKET"
## Guardas do galpão, sala por sala (Shed). Cada ronda tem um ponto cego (`BLIND_SPOTS`): corpo ali fica atrás de parede,
## estante ou pilha de caixas ou além de `Enemy.CORPSE_SIGHT` dos sentinelas, do atirador do mezanino e das outras
## rondas, então matá-la ali em silêncio não alerta ninguém (ai_tests `test_blind_spot_kills`). "console" = distraído
## (`Enemy.distracted`, animação Console: de costas, não vê nada até o barulho o tirar dali; abatível sem alarme).
## Labirinto (furtivo; de pistola):
## - 12: no painel da parede da frente (`Level.CONSOLE`), no nicho ao lado do portão de grade
## - 2: sentinela do baú da M16 no canto opcional do labirinto, olhando para o corredor que chega nele
## - 16 (P1): na bancada da face da pilha da linha 1, de costas para o corredor da linha 2
## - 17 (P2): na bancada da parede do fundo, debaixo do mezanino (ela passa nas costas dele)
## - 18 (P3): ronda no corredor da parede oeste; 19 (P4): ronda no corredor da linha 4
## Escritório (furtivo):
## - 6: ronda no trecho da frente do corredor (do bloqueio até a porta trancada); 0: ronda no descanso, de parede a parede
## - 11: no computador da mesa do escritório (`Shed.DESK_CONSOLE`); 20 (C): mexendo no armário; 21 (F): no celular, de
##   costas para o C
## - 22 (S): parado no canto do arsenal; 23, 24 (A): parados no arquivo, de frente para a porta de saída
## Estantes e doca (combate):
## - 15: mexendo na estante da direita; 1: ronda no corredor entre as duas primeiras estantes; 14: ronda no corredor da
##   direita; 8: ronda na frente (junto da beira da doca), de ponta a ponta, entrando no corredor escondido da parede oeste
##   (ponto cego atrás da primeira estante; ir até o pé da escada deixava o corpo à vista do 14 e vice-versa)
## - 9, 10: sentinelas de Flak Jacket ("flak") na doca, na frente do portão da sala dos clones
## - 13: na cabine da ponta oeste da doca, mexendo no computador dela (`Shed.booth_panel`)
## Pátio descoberto (o fim, combate direto):
## - 3, 4: postos olhando o portão da mata; 7: de posto ("hold" = `Enemy.hold_post`: só sai do lugar depois que alguém a
##   vê); 5: ronda (a ponta oeste fica atrás da caixa baixa, tapada dos postos 3 e 4); 25 (T): enchendo o caminhão; 26
##   (T2): no container
## Os fixos de um portão dividem o posto ("post" = `Enemy.post`): corpo, grito ou barulho tiram no máximo metade dele
## (3, 4, 7 = "patio": até 1; 9, 10 = "norte": 1); com ela vista (vermelho) saem todos.
const GUARDS := [
	{"route": [Vector3(-12.0, 0, 51.0), Vector3(-7.0, 0, 51.0)]},
	{"route": [Vector3(-7.85, 0, 40.5), Vector3(-7.85, 0, 33.5)]},
	{"pos": Vector3(0.6, 0, 57.2), "rot_y": PI, "route": [], "weapon": "pistol"},
	{"pos": Vector3(-11.4, 0, -6.6), "rot_y": PI * 0.5, "route": [], "post": "patio"},
	{"pos": Vector3(-11.4, 0, -9.6), "rot_y": PI * 0.5, "route": [], "post": "patio"},
	{"route": [Vector3(-10.4, 0, -0.5), Vector3(-0.6, 0, -1.0), Vector3(-0.6, 0, -4.0), Vector3(-0.6, 0, -1.0)]},
	{"route": [Vector3(-4.2, 0, 50.4), Vector3(-4.2, 0, 43.8)]},
	{"pos": Vector3(-1.5, 0, -8.0), "rot_y": PI * 0.5, "route": [], "hold": true, "post": "patio"},
	{"route": [Vector3(-11.9, 0, 35.6), Vector3(-11.9, 0, 32.2), Vector3(-0.1, 0, 32.2), Vector3(-11.9, 0, 32.2)]},
	{"pos": Vector3(-8.4, CloneLab.FLOOR_Y, 28.4), "rot_y": PI, "route": [], "flak": true, "post": "norte"},
	{"pos": Vector3(-1.6, CloneLab.FLOOR_Y, 28.4), "rot_y": PI, "route": [], "flak": true, "post": "norte"},
	{"pos": Vector3(Shed.DESK_CONSOLE.x - Level.CONSOLE_GUARD, 0, Shed.DESK_CONSOLE.z), "rot_y": -PI * 0.5, "route": [], "console": true},
	{"pos": Vector3(Level.CONSOLE.x, 0, Level.CONSOLE.z + Level.CONSOLE_GUARD), "rot_y": 0.0, "route": [], "weapon": "pistol", "console": true},
	{"pos": Vector3(Shed.BOOTH_CONSOLE.x, Shed.BOOTH_Y, Shed.BOOTH_CONSOLE.z - Level.CONSOLE_GUARD), "rot_y": PI, "route": [], "console": true},
	{"route": [Vector3(1.2, 0, 41.6), Vector3(1.2, 0, 36.8)]},
	{"pos": Vector3(-2.3, 0, 37.0), "rot_y": -PI * 0.5, "route": [], "console": true},
	# P1, P2, P3, P4 (labirinto, de pistola)
	{"pos": Vector3(-2.6, 0, P1_BENCH.z - Level.CONSOLE_GUARD), "rot_y": PI, "route": [], "weapon": "pistol", "console": true},
	{"pos": Vector3(-10.0, 0, 67.3), "rot_y": PI, "route": [], "weapon": "pistol", "console": true},
	{"route": [Vector3(-12.2, 0, 62.2), Vector3(-12.2, 0, 57.2)], "weapon": "pistol"},
	{"route": [Vector3(-7.4, 0, 60.29), Vector3(0.6, 0, 60.29)], "weapon": "pistol"},
	# C, F, S, A, A (escritório)
	{"pos": Vector3(1.5, 0, 50.8), "rot_y": 0.0, "route": [], "console": true},
	{"pos": Vector3(-1.4, 0, 55.0), "rot_y": PI, "route": [], "console": true},
	{"pos": Vector3(2.2, 0, 44.2), "rot_y": 0.0, "route": []},
	{"pos": Vector3(-11.6, 0, 45.1), "rot_y": 0.0, "route": []},
	{"pos": Vector3(-8.7, 0, 44.2), "rot_y": 0.0, "route": []},
	# T, T2 (pátio descoberto)
	{"pos": Vector3(-11.9, 0, 3.4), "rot_y": -PI * 0.5, "route": [], "console": true},
	{"pos": Vector3(-3.7, 0, 5.0), "rot_y": 0.0, "route": [], "console": true},
]
## Bancadas dos guardas distraídos do labirinto (ponto na face da pilha / parede, Level.console_at): a de P1 na face da
## pilha da linha 1 (quem digita fica ao sul), a de P2 na parede do fundo debaixo do mezanino.
const P1_BENCH := Vector3(-2.6, 0, 64.56)
const P2_BENCH := Vector3(-10.0, 0, Level.NORTH - Level.WALL_T * 0.5)
## Índices em GUARDS por sala (main: seções dos reforços do Shed).
const CORNER_GUARDS := [3, 4, 5, 7, 25, 26]
const RACKS_GUARDS := [1, 8, 9, 10, 13, 14, 15]
## Índice em GUARDS de cada ronda -> pontos da rota onde o corpo fica fora da vista de todos (testes).
const BLIND_SPOTS := {
	0: [Vector3(-12.0, 0, 51.0)], 1: [Vector3(-7.85, 0, 40.5)], 5: [Vector3(-10.4, 0, -0.5)], 6: [Vector3(-4.2, 0, 43.8)],
	8: [Vector3(-11.9, 0, 35.6)], 14: [Vector3(1.2, 0, 41.6)], 18: [Vector3(-12.2, 0, 62.2)], 19: [Vector3(-7.4, 0, 60.29)],
}

var model: HeroineModel
var health := MAX_HEALTH
var _shape: CollisionShape3D
var _burst := 0
var _burst_i := 0  # tiros já dados na rajada
var _shot_t := 0.0
var _lock_t := 0.0  # tempo mirando nela à vista (`LOCK_TIME`); travou, vale até ele esquecê-la (sumir/esquivar não zera)
var _rest := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var shots_fired := 0
var engage_dist := ENGAGE_DIST
var keep_dist := KEEP_DIST
var flak := false  # Flak Jacket no lugar do colete comum (antes de entrar na árvore)
var weapon := WEAPON  # "m16" ou "pistol" (antes de entrar na árvore)
var damage := DAMAGE
var fire_range := FIRE_RANGE
var burst_shots: Array = BURST_SHOTS
var shot_gap := SHOT_GAP
var _blocked_t := 0.0  # em luta, tempo vendo-a sem linha de tiro
var _peek: Variant = null  # ponto da beirada para onde vai se esgueirar (null = nenhum)
var _peek_t := 0.0
var _peek_side := 0.0  # lado (dele) para onde se inclina na beirada: 1 direita, -1 esquerda, 0 nada
var _lean := 0.0
var _react := REACT_TIME  # o desta reação (REACT_TIME ou REACT_READY, `start_alert`)
var _stowed: Node3D  # fuzil encostado no caixote enquanto ele mexe no detonador (guarda distraído de M16)
var burning := false  # morto pela explosão dos caixotes: o corpo pega fogo e carboniza (ignite)
var _char_tw: Tween
var _roll_cd := 0.0
var _roll_dir := Vector3.ZERO
var _roll_prev := 0.0
var _flank: Variant = null
var _flank_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | Yard.GRATE_LAYER  # grades do galpão (Shed) e da trilha seguram o corpo dele
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.72
	_shape.shape = cap
	_shape.position.y = 0.86
	add_child(_shape)
	model = HeroineModel.new()
	model.scene = BODY
	model.atlas = ATLAS
	add_child(model)
	model.set_weapon(weapon)
	if distracted and weapon == WEAPON:
		_stowed = _lean_rifle()
	sight_range = 23.0  # agachada atrás de algo: 7 m parada, 9 m andando; no aberto ~15 m
	fov_half = deg_to_rad(62.0)
	eye_height = 1.55
	marker_height = 2.2
	turn_rate = 8.0
	patrol_speed = Moves.speed("walk")
	investigate_speed = Player.RUN_SPEED * JOG_SCALE
	hunt_speed = Player.RUN_SPEED
	if weapon == "pistol":
		damage = PISTOL.damage
		fire_range = PISTOL.range
		burst_shots = PISTOL.burst
		shot_gap = PISTOL.gap
		if drop_kind == "":
			drop_kind = "pistol"  # larga a pistola dele (ela já tem uma: pegar dá um pente)
			drop_is_weapon = true
			drop_amount = 10
	if drop_kind == "":
		drop_kind = "m16"
		drop_is_weapon = true
		drop_amount = 15
	head_mult = 10.0  # tiro na cabeça mata na hora (até chumbo de escopeta de longe)
	armor_parts = VEST_PARTS
	armor = FLAK_MULT if flak else VEST_MULT
	armor_name = FLAK_TEXT if flak else ""
	can_stealth = true
	arrival_dist = 0.7
	# gente: só os 2 mais perto saem quando um dá o alarme (indo ver o lugar: alertados = busca ativa, correndo) e vasculham
	# mais pontos; quem só desconfiou vai andando e para perto para observar (busca amarela)
	alarm_responders = 2
	alarm_walks = true
	search_sweeps = 3
	shouts = true
	tactical = true
	voice = Voice.assign()
	alert_time = ALERT_TIME * TIME_SCALE
	lose_time = LOSE_TIME * TIME_SCALE
	search_time = SEARCH_TIME * TIME_SCALE
	observe_dist = OBSERVE_DIST
	guards_bodies = true
	engage_dist = ENGAGE_DIST + rng.randf_range(-1.0, 1.0)
	keep_dist = KEEP_DIST + rng.randf_range(-0.4, 0.4)
	_enemy_ready()


func _physics_process(delta: float) -> void:
	_tick(delta)
	_roll_cd = maxf(_roll_cd - delta, 0.0)
	if _stowed:
		_stowed.visible = is_distracted()
	if alert_t <= 0.0 and not in_combat():
		_lock_t = 0.0  # esqueceu dela: a próxima luta começa com o aviso de novo
	if not _calm_state(delta):
		head_yaw = 0.0
		head_pitch = 0.0
		if model:
			model.set_head_look(0.0, 0.0)
		match state:
			"alert":
				_stop(delta)
				_face(_to_target(), delta, turn_rate)
				_update_pitch(delta)
				if _t >= _react:
					# pego de surpresa: entra na luta rolando de lado (e um pouco para a frente) em vez de parar na frente dela
					if not (_react >= REACT_TIME and rng.randf() < ROLL_ENTER_CHANCE and _try_roll(_to_target(), 0.35)):
						start_engage()
			"roll":
				_roll(delta)
			"engage":
				_engage(delta)
			"dead":
				_stop(delta)
	else:
		if state == "patrol":
			head_yaw = lerpf(head_yaw, 0.0, 1.0 - exp(-5.0 * delta))
			if model:
				model.set_head_look(head_yaw, 0.0)
		elif state in ["look", "idle", "search", "guard"]:
			if model:
				# de arma em punho quem olha é o corpo com o fuzil (a cabeça acompanha a mira)
				var ready := weapon_ready()
				model.set_head_look(0.0 if ready else head_yaw, 0.0 if ready else head_pitch)
	if state != "engage" and model and absf(_lean) > 0.001:
		_lean = lerpf(_lean, 0.0, 1.0 - exp(-6.0 * delta))
		model.set_lean(_lean)
	if not in_combat() and model and model.aim_pitch:
		var want := head_pitch if weapon_ready() else 0.0
		if absf(model.aim_pitch.pitch - want) > 0.01:
			model.aim_pitch.pitch = lerpf(model.aim_pitch.pitch, want, 1.0 - exp(-6.0 * delta))

	if in_combat() and _is_target_elevated() and global_position.y < 1.2 and global_position.x < Catwalk.X1 + 0.6 and global_position.z >= Catwalk.FRONT_Z - 1.2:
		if velocity.z > 0.0:
			velocity.z = 0.0
	EnemyCrowd.apply_separation(self)
	move_and_slide()
	if not dead:
		_clamp_to_bounds()


## Trava física: soldados no chão nunca saem do mapa nem caem no vácuo; em combate com ela no mezanino não entram
## debaixo dele (perderiam a linha de tiro). Procurando, entram (corredor e pé da escada).
func _clamp_to_bounds() -> void:
	if global_position.y < 1.2:
		global_position.y = maxf(global_position.y, 0.0)
		if velocity.y < 0.0 and global_position.y <= 0.01:
			velocity.y = 0.0
		if global_position.x > Level.WEST + 0.4:
			# no galpão de verdade (com o Shed) não sai pelas paredes de fora; num mundo de teste só a trava do mezanino vale
			var in_shed := is_inside_tree() and get_tree().get_first_node_in_group("shed") != null
			if in_shed:
				global_position.x = clampf(global_position.x, Level.WEST + 0.6, Level.EAST - 0.6)
			# debaixo do mezanino (só ele)
			var under := global_position.x < Catwalk.X1 + 0.5
			var max_z := Catwalk.FRONT_Z - 1.0 if under and in_combat() and _is_target_elevated() else Level.NORTH - 0.4
			global_position.z = clampf(global_position.z, Level.SOUTH + 0.4 if in_shed else -INF, max_z)


## M16 de pé encostado no caixote, à direita dele (o `m16.glb` solto, de perfil: cano em +X, coronha no chão).
func _lean_rifle() -> Node3D:
	var holder := Node3D.new()
	var gun: Node3D = WeaponIcon.SCENES.m16.instantiate()
	holder.add_child(gun)
	var box := AABB()
	var first := true
	for mi in WeaponIcon._meshes(gun):
		var m := ShaderMaterial.new()
		m.shader = Gfx.shader()
		m.set_shader_parameter("albedo_tex", WeaponIcon.ATLAS)
		mi.material_override = m
		var rel := Transform3D.IDENTITY
		var n: Node = mi
		while n != holder:
			rel = (n as Node3D).transform * rel
			n = n.get_parent()
		var b := rel * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	gun.position -= Vector3(box.position.x, box.get_center().y, box.get_center().z)  # a coronha na origem
	# cano para cima, inclinado para o caixote (frente dele = -Z), a alça para fora
	var up := Vector3(0, 0.96, -0.24).normalized()
	var out := (Vector3.BACK - up * up.z).normalized()
	holder.basis = Basis(up, out, up.cross(out))
	holder.position = Vector3(0.48, 0.0, -0.1)
	holder.visible = false
	add_child(holder)
	return holder


func in_combat() -> bool:
	return state in COMBAT


## Nomes de animação do raptor ("Idle", "Walk", "Run", "Study") traduzidos para os estados do corpo dela
## (andar/correr pelo `HeroineModel.set_gait`, o mesmo critério da jogadora).
func _play(anim: String, _blend := 0.15, speed := 1.0, _restart := false) -> void:
	model.set_aim(in_combat() or weapon_ready())
	if distracted:
		# no painel a pistola fica guardada; qualquer outra coisa (até desconfiado) e ela vai para a mão
		var typing := anim == "Idle" and is_distracted()
		model.holster(typing)
		if typing:
			model.set_state("console")
			return
	match anim:
		"Walk", "Run":
			# `speed` vem em relação a _anim_speed: volta a m/s e escolhe andar/correr como a jogadora
			model.set_gait(speed * _anim_speed(anim == "Run"))
		_:
			model.set_state("idle")


func _anim_speed(run: bool) -> float:
	return Player.RUN_SPEED if run else Moves.speed("walk")


func _on_spotted() -> void:
	start_alert()


func start_alert() -> void:
	_react = REACT_READY if weapon_ready() else REACT_TIME
	_enter("alert", "Idle", 0.1)
	model.set_aim(true)


func start_engage() -> void:
	if not _has_target():
		_resume()
		return
	_enter("engage", "Idle", 0.1)
	model.set_aim(true)
	_burst = 0
	_rest = 0.1
	_strafe_t = 0.0
	_blocked_t = 0.0
	_peek = null
	_peek_t = 0.0
	_peek_side = 0.0


func _is_target_elevated() -> bool:
	if is_instance_valid(target):
		if target.global_position.y > 1.8 and Catwalk.covers(target.global_position + Vector3(0, 0, 0.5)):
			return true
	return _last_known.y > 1.8 and Catwalk.covers(_last_known + Vector3(0, 0, 0.5))


func _update_pitch(delta: float) -> void:
	if not model or not model.aim_pitch or not _has_target():
		return
	var eye_y := global_position.y + eye_height
	var target_y := target.global_position.y + (0.8 if target.crouching else 1.2)
	var horiz_d := _to_target().length()
	if horiz_d > 0.1:
		var target_pitch := atan2(target_y - eye_y, horiz_d)
		model.aim_pitch.pitch = lerpf(model.aim_pitch.pitch, target_pitch, 1.0 - exp(-10.0 * delta))


## Ela no mezanino ou em cima das caixas: Enemy._search_goal manda um ao pé da escada e os outros a pontos do chão de
## onde se vê o lugar.
func start_hunt(at: Vector3) -> void:
	if _has_target() and _sees_target():
		start_alert()
		return
	super.start_hunt(at)


func start_investigate(at: Vector3) -> void:
	if _has_target() and _sees_target():
		start_alert()
		return
	super.start_investigate(at)


## Combate: mira, atira em rajadas e se mexe (avança, recua ou anda de lado).
func _engage(delta: float) -> void:
	if not _has_target():
		_resume()
		return
	if _lost_t > lose_time:
		alert_t = alert_time
		start_hunt(_last_known)
		return
	var to := _to_target()
	var dist := to.length()
	var sees := _lost_t < 0.4
	if sees and _aimed_at_me(dist) and rng.randf() < ROLL_DODGE_RATE * delta and _try_roll(to, 0.0):
		return
	if sees and model.is_aimed() and not target.is_dodging():
		_lock_t += delta
	_face(to if sees else _last_known - global_position, delta, turn_rate)
	_update_pitch(delta)
	var dir := Vector3.ZERO
	var gait := "walk"
	var elevated := _is_target_elevated()
	if elevated and global_position.y < 1.2:
		# Alvo elevado (na passarela / mezanino): manter campo de visão aberto
		if not sees:
			# Perdeu de vista: se estiver perto da passarela, recua para abrir o ângulo de visada;
			# caso contrário, anda de lado e recua suavemente para tentar novo ângulo desobstruído
			if global_position.z > 5.0:
				dir = Vector3(0, 0, -1.0)
				gait = "walk"
			else:
				_strafe_t -= delta
				if _strafe_t <= 0.0:
					_strafe = EnemyCrowd.get_flank_strafe(self, target.global_position, 1.0 if rng.randf() < 0.5 else -1.0)
					_strafe_t = rng.randf_range(1.0, 2.2)
				dir = (to.normalized().cross(Vector3.UP) * _strafe - Vector3(0, 0, 0.3)).normalized()
				gait = "strafe"
				if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
					_strafe = -_strafe
					dir = Vector3(0, 0, -1.0)
		elif global_position.z > 6.0:
			# Perto demais do mezanino: a borda frontal/rodapé cortará a linha de tiro; recua
			dir = Vector3(0, 0, -1.0)
			gait = "walk"
		elif global_position.z < 1.0 and dist > 14.0:
			# Longe demais para tiro preciso: avança um pouco até a zona ideal de combate
			dir = Vector3(0, 0, 1.0)
			gait = "walk"
		else:
			# Posição ideal com visão desobstruída do mezanino: anda de lado atirando
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe = EnemyCrowd.get_flank_strafe(self, target.global_position, 1.0 if rng.randf() < 0.5 else -1.0)
				_strafe_t = rng.randf_range(1.2, 2.6)
			dir = to.normalized().cross(Vector3.UP) * _strafe
			gait = "strafe"
			if dir.z > 0.0 and global_position.z >= 5.2:
				dir.z = 0.0
			if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
				_strafe = -_strafe
				dir = Vector3.ZERO
	else:
		# sem linha de tiro (ela atrás da caixa/quina, ou o cano encostado nela): segura um instante (supressão onde ela
		# estava) e depois se esgueira até a beirada de onde a vê; sem beirada, vai para cima dela
		var blocked := not sees or not _clear_shot(target.sight_point())
		_blocked_t = _blocked_t + delta if blocked else 0.0
		if not blocked:
			_peek = null  # tem linha: atira dali (inclinado, se veio da beirada)
		_flank_t -= delta
		if _flank_t <= 0.0:
			_flank_t = FLANK_REPLAN
			var was: Variant = _flank
			_flank = _flank_goal(dist) if sees else null
			if _flank != null and (was == null or _flat(_flank - was).length() > 1.0):
				_repath_t = 0.0  # destino novo: o caminho da malha é refeito agora
		var off: Vector3 = _flat(_flank - global_position) if _flank != null else Vector3.ZERO
		if _blocked_t > PEEK_AFTER:
			dir = _peek_dir(to, sees, delta)
			gait = "strafe"
		elif blocked:
			dir = Vector3.ZERO
		elif _flank != null and off.length() > FLANK_ARRIVE:
			# vai para o ângulo dele em volta dela atirando: longe, no trote; perto, andando
			dir = _steer(_flank, off, delta)
			gait = "run" if off.length() > RUN_GUN_FAR else "walk"
		elif dist > engage_dist:
			dir = _avoid(to.normalized())
			gait = "run" if dist > engage_dist + RUN_GUN_FAR else "walk"
		elif dist < keep_dist:
			dir = _avoid(-to.normalized())
		else:
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe = EnemyCrowd.get_flank_strafe(self, target.global_position, 1.0 if rng.randf() < 0.5 else -1.0)
				_strafe_t = rng.randf_range(0.9, 2.0)
			dir = to.normalized().cross(Vector3.UP) * _strafe
			gait = "strafe"
			if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
				_strafe = -_strafe
				dir = to.normalized().cross(Vector3.UP) * _strafe
				if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
					# preso dos dois lados: um passo para a frente ou para trás em vez de ficar parado na frente dela
					dir = _avoid((to if dist > (keep_dist + engage_dist) * 0.5 else -to).normalized())
					gait = "walk"
	_move_aiming(dir, gait, delta)
	_lean = lerpf(_lean, _peek_side * PEEK_LEAN, 1.0 - exp(-6.0 * delta))
	model.set_lean(_lean)
	# tiro: rajadas longas e descanso curto com ela à vista; recém-sumida, fogo de supressão onde ela estava
	_shot_t -= delta
	_rest = maxf(_rest - delta, 0.0)
	var suppress := not sees and _lost_t < SUPPRESS_TIME
	if not (sees or suppress) or not model.is_aimed() or _rest > 0.0:
		return
	if _burst == 0:
		var reach := dist if sees else _flat(_last_known - global_position).length()
		if reach >= fire_range:
			return
		_burst = rng.randi_range(burst_shots[0], burst_shots[1])
		_burst_i = 0
		if sees and randf() < TAUNT_CHANCE:  # `randf` do jogo: o `rng` dele fica com a mesma sequência de antes
			Voice.say(self, "taunt")
	if _shot_t <= 0.0:
		var aim := _aim_point(sees)
		if not _clear_shot(aim):
			return  # caixa/parede no meio: sabe que ela está do outro lado, mas não gasta bala na cobertura
		_fire(sees, aim)
		_burst -= 1
		_burst_i += 1
		_shot_t = shot_gap
		if _burst == 0:
			_rest = rng.randf_range(REST_TIME[0], REST_TIME[1])


## Ela mira nele: virada para ele (o corpo dela segue a retícula mirando) dentro de `ROLL_AIM_CONE`.
func _aimed_at_me(dist: float) -> bool:
	if not target.aiming or dist > fire_range:
		return false
	var fwd := _flat(-target.global_basis.z)
	var to_me := _flat(global_position - target.global_position)
	return to_me.length() > 0.1 and absf(fwd.angle_to(to_me)) < ROLL_AIM_CONE + atan2(0.4, dist)


## Cambalhota de lado (`lead` = quanto vai para a frente, para ela): o lado do strafe primeiro, depois o outro. Só com o
## corpo livre até o fim, sem colega no caminho e chão da malha lá. Devolve true se rolou.
func _try_roll(to: Vector3, lead: float) -> bool:
	if _roll_cd > 0.0 or to.length() < 0.1 or not is_on_floor():
		return false
	var fwd := _flat(to).normalized()
	var side := fwd.cross(Vector3.UP)
	for sgn: float in [_strafe, -_strafe]:
		var dir := (side * sgn + fwd * lead).normalized()
		var end := global_position + dir * ROLL_DIST
		if not _clear_to(end) or EnemyCrowd.is_enemy_in_path(self, dir, ROLL_DIST):
			continue
		if _has_nav() and _floor_at(end) == null:
			continue
		_roll_dir = dir
		_roll_prev = 0.0
		_roll_cd = ROLL_COOLDOWN
		_strafe = sgn
		_enter("roll", "Idle", 0.0)
		model.set_aim(false)
		model.play("roll")
		return true
	return false


## Rolando: segue o caminho da cambalhota da heroína (`Moves.path_at`), virado para onde rola; no fim, de volta à luta.
func _roll(delta: float) -> void:
	var d: Dictionary = Moves.data().roll
	var f := _t * Moves.fps()
	var x := Moves.path_at(d.path, f).x
	var v := _roll_dir * (x - _roll_prev) / maxf(delta, 0.001)
	_roll_prev = x
	velocity.x = v.x
	velocity.z = v.z
	rotation.y = lerp_angle(rotation.y, atan2(-_roll_dir.x, -_roll_dir.z), 1.0 - exp(-14.0 * delta))
	if f >= float(d.frames):
		start_engage()


## Ângulo dele em volta dela quando há outros em luta com ela no mesmo andar: a partir da direção média do grupo (vista
## dela), o 1º fica nela, o 2º a +FLANK_STEP, o 3º a -FLANK_STEP... (ordem fixa pelo id). Ponto na malha a uma distância
## de luta, com caminho curto e vista dela de lá; senão null (luta como antes).
func _flank_goal(dist: float) -> Variant:
	var her := target.global_position
	var mates: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var o := n as Soldier
		if o == null or o.dead or not (o == self or o.in_combat()):
			continue
		if absf(o.global_position.y - global_position.y) < 1.2 and _flat(o.global_position - her).length() < fire_range:
			mates.append(o)
	if mates.size() < 2:
		return null
	mates.sort_custom(func(a: Soldier, b: Soldier) -> bool: return a.get_instance_id() < b.get_instance_id())
	var mean := Vector3.ZERO
	for o: Soldier in mates:
		mean += _flat(o.global_position - her).normalized()
	if mean.length() < 0.1:
		return null
	var i := mates.find(self)
	var a := atan2(mean.x, mean.z) + float((i + 1) / 2) * FLANK_STEP * (1.0 if i % 2 == 1 else -1.0)
	var r := clampf(dist, keep_dist + 1.0, engage_dist)
	var p := her + Vector3(sin(a), 0.0, cos(a)) * r
	p.y = global_position.y
	if _has_nav():
		p = NavigationServer3D.map_get_closest_point(_nav(), p)
		var path := NavigationServer3D.map_get_path(_nav(), global_position, p, true)
		var length := 0.0
		for k in range(path.size() - 1):
			length += _flat(path[k + 1] - path[k]).length()
		if path.is_empty() or length > 2.0 * _flat(p - global_position).length() + 3.0:
			return null
	if _flat(p - her).length() < keep_dist * 0.8:
		return null
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * eye_height, target.sight_point(), 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return null
	return p


## Sem linha de tiro: rumo à beirada de onde o cano a vê (ou, sumida, vê o lugar onde ela estava; `_find_peek`); sem
## beirada, avança para cima dela (ou até onde a viu) pelo caminho.
func _peek_dir(to: Vector3, sees: bool, delta: float) -> Vector3:
	var aim := target.sight_point() if sees else _last_known + Vector3.UP * 1.0
	var toward := to if sees else _flat(_last_known - global_position)
	_peek_t -= delta
	if _peek == null and _peek_t <= 0.0:
		_peek_t = PEEK_REPLAN
		_peek = _find_peek(toward, aim)
	if _peek != null:
		var off := _flat(_peek - global_position)
		if off.length() > 0.15:
			return off.normalized()
		_peek = null  # chegou e ainda não tem linha (ela se mexeu): procura outra depois do PEEK_REPLAN
		return Vector3.ZERO
	_peek_side = 0.0
	if not sees and toward.length() <= 1.0:
		return Vector3.ZERO  # já está onde ela estava: o LOSE_TIME manda procurar
	return _steer(target.global_position if sees else _last_known, toward, delta)


## Beirada mais perto, de lado (perpendicular à linha `to` até ela), com o corpo livre para chegar e o cano vendo `aim`.
func _find_peek(to: Vector3, aim: Vector3) -> Variant:
	if to.length() < 0.1:
		return null
	var side := to.normalized().cross(Vector3.UP)
	var m_off := model.muzzle_position() - global_position
	var space := get_world_3d().direct_space_state
	for d: float in PEEK_STEPS:
		for sgn: float in [_strafe, -_strafe]:
			var step := side * sgn
			var p := global_position + step * d
			if not _clear_to(p) or EnemyCrowd.is_enemy_in_path(self, step, d):
				continue
			if _has_nav() and _floor_at(p) == null:
				continue
			var at_h := p + Vector3.UP * m_off.y
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(at_h, p + m_off, 1)).is_empty() 					and space.intersect_ray(PhysicsRayQueryParameters3D.create(p + m_off, aim, 1)).is_empty():
				_peek_side = signf((global_basis.inverse() * step).x)
				return p
	return null


## O corpo dele até o cano: com ele colado na caixa o cano fica dentro/atrás dela (o raio que começa dentro da caixa não
## bate nela e o tiro a atravessaria). Devolve a batida (vazio = cano à mostra).
func _body_block(muzzle: Vector3) -> Dictionary:
	var from := global_position + Vector3.UP * (muzzle.y - global_position.y)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, muzzle, 1))


## Anda na direção `dir` sem virar o corpo (continua mirando): para a frente/de costas ou de lado, no ritmo da animação.
func _move_aiming(dir: Vector3, gait: String, _delta: float) -> void:
	if dir.length() < 0.1:
		velocity.x = 0.0
		velocity.z = 0.0
		model.set_state("idle")
		return
	var local := global_basis.inverse() * dir
	var side := absf(local.x) > absf(local.z)
	if gait == "run":
		# atirando no trote: para a frente corre; de lado, o passo lateral largo; para trás, andando
		if side:
			gait = "strafe_fast"
		elif local.z > 0.0:
			gait = "walk"
	var speed := Player.RUN_SPEED * JOG_SCALE if gait == "run" else Moves.speed(gait)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if gait == "run":
		model.set_state("run", speed / Player.RUN_SPEED)
	elif gait == "strafe_fast":
		model.set_state("strafe_fast_r" if local.x > 0.0 else "strafe_fast_l", 1.0)
	elif side:
		model.set_state("strafe_r" if local.x > 0.0 else "strafe_l", speed / Moves.speed("strafe"))
	else:
		model.set_state("walk", (1.0 if local.z < 0.0 else -1.0) * speed / Moves.speed("walk"))


## Chance de um tiro a `dist` m acertá-la sendo o `nth` da rajada (0 = o primeiro): cai com a distância, ao longo da
## rajada, agachada ou correndo; rolando, nunca.
func _hit_chance(dist: float, nth: int) -> float:
	var chance := clampf(0.8 - dist * 0.03, 0.15, 0.7) * pow(BURST_DECAY, nth)
	if target.crouching:
		chance *= 0.8
	if Vector2(target.velocity.x, target.velocity.z).length() > 3.0:
		chance *= 0.7
	if target.is_dodging():
		chance = 0.0
	var own := Vector2(velocity.x, velocity.z).length()
	if own > 2.0:
		chance *= MOVING_AIM[1]
	elif own > 0.5:
		chance *= MOVING_AIM[0]
	return chance


## Sensor de perigo: chance de pelo menos um tiro da rajada (a de agora ou a próxima) acertá-la. Sem vê-la a supressão
## não acerta; fora do alcance, nada; ainda erguendo a arma, um pouco menos. Não espera o `LOCK_TIME`: sobe durante ele,
## como aviso, e o primeiro acerto vem depois.
func _threat() -> float:
	if _lost_t >= 0.4:
		return 0.05
	var dist := muzzle_dist()
	if dist >= fire_range:
		return 0.0
	var first := _burst_i if _burst > 0 else 0
	var left: int = _burst if _burst > 0 else (burst_shots[0] + burst_shots[1]) / 2
	var miss := 1.0
	for i in left:
		miss *= 1.0 - _hit_chance(dist, first + i)
	return (1.0 - miss) * (1.0 if state == "engage" and model.is_aimed() else 0.6)


## Distância do cano ao peito dela (a mesma do sorteio do tiro).
func muzzle_dist() -> float:
	var chest := target.sight_point()
	return model.muzzle_position().distance_to(chest)


## Para onde vai o tiro: o peito dela ou, na supressão, um ponto sorteado em volta do último lugar onde a viu.
func _aim_point(at_her: bool) -> Vector3:
	if at_her:
		return target.sight_point()
	return _last_known + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.6, 1.3), rng.randf_range(-0.4, 0.4))


## Nada do cenário entre o cano e `aim`: só assim ele aperta o gatilho (não atira na caixa em que ela se esconde).
func _clear_shot(aim: Vector3) -> bool:
	var muzzle := model.muzzle_position()
	if not _body_block(muzzle).is_empty():
		return false
	var q := PhysicsRayQueryParameters3D.create(muzzle, aim, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Um tiro nela: acerta com a chance de `_hit_chance`, só depois de `LOCK_TIME` mirando nela (antes passa raspando: o
## sensor de perigo avisa antes do primeiro acerto; dali em diante, enquanto ele estiver alertado, acerta sem espera). Sem linha livre o tiro bate na parede. `at_her` = false:
## supressão, atira no último lugar onde a viu (não acerta; bate na cobertura ou passa).
func _fire(at_her := true, aim := Vector3.INF) -> void:
	shots_fired += 1
	model.shoot()
	var parent := get_parent()
	var muzzle := model.muzzle_position()
	var chest := aim if aim != Vector3.INF else _aim_point(at_her)
	var dir := (chest - muzzle).normalized()
	Fx.muzzle_flash(parent, muzzle, weapon, dir)
	var space := get_world_3d().direct_space_state
	var block := _body_block(muzzle)
	if block.is_empty():
		block = space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1))
	var dist := muzzle.distance_to(chest)
	var chance := _hit_chance(dist, _burst_i) if at_her and _lock_t >= LOCK_TIME else 0.0
	var end := chest
	var hit_her := false
	if block:
		end = block.position
		Fx.impact(parent, end, false, block.normal, str(block.collider.get_meta("surface", "concrete")))
	elif rng.randf() < chance:
		hit_her = true
	else:
		# errou: o tiro passa raspando e vai até o que houver atrás
		var side := dir.cross(Vector3.UP).normalized() * rng.randf_range(-1.0, 1.0)
		var miss := (chest + side * 0.9 + Vector3.UP * rng.randf_range(-0.4, 0.4) - muzzle).normalized()
		var far := space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, muzzle + miss * fire_range * 1.5, 1))
		end = far.position if far else muzzle + miss * fire_range
		if far:
			Fx.impact(parent, end, false, far.normal, str(far.collider.get_meta("surface", "concrete")))
	Fx.tracer(parent, muzzle, end, weapon)
	if hit_her:
		target.take_hit(GameMode.enemy_damage(damage), dir, chest)  # o sangue sai no take_hit dela
		if target.dead:
			Voice.say(self, "down")  # "Alvo abatido!"
	fired.emit()


# ------------------------------------------------------------------ dano
func take_hit(amount: int, dir: Vector3, at: Vector3, head := false) -> void:
	if dead:
		return
	health -= amount
	if health <= 0:
		die(dir, at, head)
		return
	model.hit(dir)  # tranco aditivo: o tiro não interrompe o que ele está fazendo
	if not in_combat():
		if _has_target():
			_alarm_from(target.global_position)  # levou tiro sem tê-la notado: sabe onde ela está e grita um instante depois
		start_alert()


## Tiro na cabeça de um humano é letal, qualquer arma e distância (a queda de dano com o alcance não salva ninguém).
func take_headshot(amount: int, dir: Vector3, at: Vector3) -> void:
	take_hit(maxi(amount, health), dir, at, true)


## Abate furtivo silencioso pelas costas: mata na hora (100% da vida), esguicha sangue e cai em ragdoll sem dar alarme.
func assassinate(dir := Vector3.ZERO, at: Variant = null) -> void:
	if dead:
		return
	stealth_lock(false)
	health = 0
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 1.3
	var d := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	Blood.splash(get_parent(), hit, d, -d, 1.2, true)
	die(d, hit, false, true)


func wound() -> float:
	return 1.0 - float(maxi(health, 0)) / MAX_HEALTH


## Onde largar a arma: `DROP_ASIDE` m de um lado do corpo, de través à queda (`dir`), pelo primeiro lado sem cenário até lá
## (senão para trás da queda; tudo fechado = embaixo dele).
func _drop_aside(dir: Vector3) -> Vector3:
	var fall := Vector3(dir.x, 0, dir.z).normalized()
	if fall == Vector3.ZERO:
		fall = -global_basis.z
	var side := Vector3(fall.z, 0, -fall.x)
	if not is_inside_tree():
		return side * DROP_ASIDE
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.3
	for s: Vector3 in [side, -side, -fall]:
		var q := PhysicsRayQueryParameters3D.create(from, from + s * (DROP_ASIDE + 0.3), 1)
		if space.intersect_ray(q).is_empty():
			return s * DROP_ASIDE
	return Vector3.ZERO


## Cai em ragdoll na direção do tiro (na cabeça, o tranco vai nela e joga a cabeça para trás); a poça cresce embaixo.
func die(dir := Vector3.ZERO, at: Variant = null, head := false, silent := false) -> void:
	dead = true
	state = "dead"
	_t = 0.0
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if drop_is_weapon and model:
		model.holster(true)
	drop_loot(_drop_aside(dir))
	model.start_ragdoll(dir.normalized() * (20.0 if head else 14.0) + Vector3.UP * 2.5, at)
	Blood.pool(model.ragdoll.bodies["Chest"], 1.1)
	if head:
		Blood.pool(model.ragdoll.bodies["Head"], 0.6, Blood.POOL_DELAY + 0.4)
	if not silent and is_inside_tree():
		get_tree().call_group("enemies", "hear_death", global_position, 6.0, 1.2)
	if is_inside_tree():
		get_tree().call_group("enemies", "on_nearby_kill", global_position, 8.0)
		get_tree().call_group("enemies", "witness_death", self)  # quem o viu cair entra em alerta (até no abate furtivo)
	_update_marker()
	killed.emit()


## Corpo pegando fogo (explosão dos caixotes, ExplosiveCrate): fogo no peito e no quadril do ragdoll (Fire.attach) e o
## corpo escurece até carbonizado em CHAR_TIME s.
func ignite() -> void:
	if burning or not model or not model.ragdoll:
		return
	burning = true
	for part: String in ["Chest", "Hips"]:
		if model.ragdoll.bodies.has(part):
			Fire.attach(get_parent(), model.ragdoll.bodies[part], 0.3 if part == "Chest" else 0.24)
	_char_tw = create_tween()
	_char_tw.tween_method(model.char_body, 0.0, 1.0, CHAR_TIME)


func reset() -> void:
	burning = false
	if _char_tw:
		_char_tw.kill()
		_char_tw = null
	model.char_body(0.0)
	model.stop_ragdoll()
	model.set_weapon(weapon)
	model.holster(false)
	_reset_enemy()
	health = MAX_HEALTH
	engage_dist = ENGAGE_DIST + rng.randf_range(-1.0, 1.0)
	keep_dist = KEEP_DIST + rng.randf_range(-0.4, 0.4)
	collision_layer = 2
	_shape.set_deferred("disabled", false)
	_burst = 0
	_burst_i = 0
	_lock_t = 0.0
	_react = REACT_TIME
	_blocked_t = 0.0
	_peek = null
	_peek_side = 0.0
	_lean = 0.0
	model.set_lean(0.0)
	if model and model.aim_pitch:
		model.aim_pitch.pitch = 0.0
	_enter("idle", "Idle", 0.0)

func has_head_look() -> bool:
	return true


## Busca ativa num ponto (procurando ou vasculhando em volta): fuzil no ombro apontado para onde olha, jeito tático, pronto
## para atirar (`REACT_READY`). Correndo para a área (hunt/investigate) leva a arma baixa.
func weapon_ready() -> bool:
	return not dead and active_search and state in ["search", "sweep"]


## Busca amarela: anda até o lugar suspeito. Busca ativa: corre.
func _investigate_speed() -> float:
	return hunt_speed if active_search else patrol_speed


## Busca ativa: vasculha em volta no trote, de arma pronta (amarela, no passo de ronda).
func _sweep_speed() -> float:
	return investigate_speed if active_search else patrol_speed


## Busca amarela: observa o lugar e volta à rotina, sem vasculhar em volta (isso é da busca ativa).
func _start_sweep() -> bool:
	return active_search and super._start_sweep()


## 1 = amarelo também na busca de quem só desconfiou (andou até o lugar e observa); laranja só a busca ativa.
func alert_level() -> int:
	var lv := super.alert_level()
	if lv == 2 and not active_search and state in ["investigate", "search", "sweep"]:
		return 1
	return lv


## Olhando em volta. De arma em punho (busca ativa) gira o corpo com o fuzil de um ângulo a outro em volta do lugar
## procurado, parando a mira em cada um, e às vezes confere as costas; senão, a cabeça vigia como sempre.
func _look(delta: float, anim: String) -> void:
	if not weapon_ready():
		super._look(delta, anim)
		return
	_stop(delta)
	_play(anim, 0.3)
	head_yaw = lerpf(head_yaw, 0.0, 1.0 - exp(-8.0 * delta))
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = rng.randf_range(0.8, 1.4)
		var to := _flat(_search_center - global_position)
		var base := atan2(-to.x, -to.z) if to.length() > 1.0 else rotation.y
		_look_to = base + (PI if rng.randf() < 0.2 else rng.randf_range(-1.3, 1.3))
	rotation.y = lerp_angle(rotation.y, _look_to, 1.0 - exp(-READY_TURN * delta))


func _idle_vigil(delta: float) -> void:
	if distracted and alert_t <= 0.0:
		# de volta ao posto: encosta no lugar exato da bancada e mexe no painel, sem olhar em volta
		var off := _flat(_spawn.origin - global_position)
		velocity.x = off.x * 4.0
		velocity.z = off.z * 4.0
		head_yaw = lerpf(head_yaw, 0.0, 1.0 - exp(-5.0 * delta))
		head_pitch = lerpf(head_pitch, 0.0, 1.0 - exp(-5.0 * delta))
		if model:
			model.set_head_look(head_yaw, head_pitch)
		_play("Idle", 0.3)
		return
	_stop(delta)
	_play("Idle", 0.3)
	_vigil_t -= delta
	if _vigil_t <= 0.0:
		_vigil_t = rng.randf_range(2.0, 3.8)
		var r := rng.randf()
		_vigil_target_yaw = 0.0 if r < 0.3 else (rng.randf_range(0.5, 1.05) if r < 0.65 else rng.randf_range(-1.05, -0.5))
	head_yaw = lerpf(head_yaw, _vigil_target_yaw, 1.0 - exp(-3.0 * delta))
	head_pitch = lerpf(head_pitch, 0.0, 1.0 - exp(-3.0 * delta))
	if model:
		model.set_head_look(head_yaw, head_pitch)
