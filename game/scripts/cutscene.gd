class_name Cutscene
extends Node
## Cena do choque na sala dos clones (CloneLab.entered): faixas pretas em cima e embaixo, o HUD some e ela fica sem
## controle (Player.cutscene: sem dano). Quatro planos com câmera própria:
##   1. atrás dela, baixo, enquanto ela anda devagar entre os tubos (WALK_TIME);
##   2. perto do primeiro clone, a câmera chegando no focinho parado no líquido;
##   3. o rosto dela: recua com as mãos para cima (animação Shocked) e a legenda "O QUE...?!";
##   4. por cima do ombro dela, agachando: no fundo o tanque vazio do alossauro com os guardas examinando e o do
##      computador (Shed.LAB_GUARDS, de costas, distraídos); no fim ela fica agachada atrás da caixa de equipamento.
## Cada cena só pode ser pulada depois de vista até o fim uma vez (`Settings.cutscene_seen`, guardado no arquivo de config):
## da segunda vez em diante (reinício, outra partida) aparece "<glifo> PULAR" na faixa de baixo e interagir (E/X) depois de
## SKIP_AFTER pula o resto. No fim a câmera volta para a dela, atrás dela, na inclinação inicial (`CameraRig.reset_view`).
## O jogo não para (os outros inimigos seguem); a linha do tempo anda no passo da física (testes com passo fixo).
##
## Emboscada no pátio (`play_ambush`, Corpse.noticed): mesma moldura, outros planos:
##   1. atrás dela, chegando ao guerrilheiro morto (AMB_WALK);
##   2. perto da mão dele: segura alguma coisa (a chave) e a legenda AMB_SUBTITLE; ela agachada olhando;
##   3. o rosto dela levantando (os raptors saem das moitas em AMB_EMERGE_AT, o grito em AMB_LOOK_AT);
##   4. do alto, girando devagar: ela no meio e os três saindo dos cantos e parando em volta dela (Raptor.start_ambush);
##   5. por cima do ombro dela, o da frente ruge (Raptor.ambush_roar).
## No fim (ou pulando) os raptors largam a roda já em luta (Raptor.end_ambush, um de cada vez) e ela está de arma na mão.
##
## Conversa no fundo do túnel da mina (`play_talk`, Tunnel.talk_speakers: ela chega sem ser vista):
##   1. atrás dela, agachada no corredor, a câmara dos explosivos à frente;
##   2. o primeiro larga o detonador, vira para o outro e fala TALK_LINES[0];
##   3. o outro vira e responde TALK_LINES[1];
##   4. de trás dela outra vez, eles voltando ao trabalho (Soldier: distraídos de novo, não a veem).
## Chegada à pedreira (`play_lair`, Tunnel.lair_ready: passou pelo portão arrombado):
##   1. atrás dela, entrando na pedreira;
##   2. o rosto dela, pensando (LAIR_LINES);
##   3. o alossauro a vê e ruge (Enemy.spot: chama os raptors da pedreira), por cima do ombro dela e depois perto da
##      cabeça dele. Pulando antes do rugido, ele a vê do mesmo jeito.
## Rendição no pátio (`play_standoff`, main: os 3 raptors da emboscada mortos, os snipers das torres sobem):
##   1. atrás dela, virando para o portão: os dois erguem o fuzil e os lasers acendem (STAND_LASER), "PARADA AÍ!";
##   2. de frente, perto: os dois lasers cruzando no peito dela, ela levanta as mãos (Surrender), "É O FIM DA LINHA.";
##   3. por cima do ombro de um sniper, ela lá embaixo com o laser nela, "NÃO FAÇA MOVIMENTOS BRUSCOS OU ATIRAREMOS.".
##   No fim (ou pulando) ela fica rendida (`Player.surrender`) com os dois na mira (`Sniper.hold_at_gunpoint`); o jogo
##   segue a partir daí (ver Player._hold_surrender e Sniper.release).

signal finished

const SUBTITLE := "O QUE...?!"
const WALK_SPEED := 1.0
const WALK_TIME := 2.4
const REVEAL_AT := 2.4
const FACE_AT := 3.4
const SUB_AT := 3.6
const WIDE_AT := 6.4
const END_AT := 8.4
const SKIP_AFTER := 1.0
const SKIP := ["interact", "ui_accept"]
const SKIP_ITEMS := [{"action": "interact", "pad_action": "crouch", "text": "PULAR"}]
const BAR := 0.13  # altura de cada faixa preta (fração da tela)
const AMB_SUBTITLE := "ELE ESTÁ SEGURANDO ALGUMA COISA..."
const AMB_APPROACH := 2.2  # ela começa a cena a esta distância de onde para (o corte esconde o salto)
const AMB_WALK := 1.9
const AMB_SUB_AT := 2.5
const AMB_EMERGE_AT := 3.9
const AMB_LOOK_AT := 4.6
const AMB_WIDE_AT := 6.0
const AMB_ROAR_AT := 8.4
const AMB_END_AT := 10.4
const AMB_RING := 5.0  # raio da roda dos raptors em volta dela
const AMB_CIRCLE := 0.0  # sem roda: cada um sai do canto dele, para a AMB_RING m de frente para ela e observa
const AMB_STAGGER := 0.9  # s entre um raptor e o próximo sair da roda para atacar
const TALK_LINES := ["ISSO É MAIS QUE O SUFICIENTE PRA EXPLODIR AQUELE BICHO AGORA. EU CANSEI DESSE LUGAR.",
	"NOSSO SALÁRIO NÃO COBRE ESSA INSANIDADE."]
const TALK_A_AT := 2.2  # o primeiro vira e fala
const TALK_SUB1 := [2.7, 6.2]
const TALK_B_AT := 6.4  # o outro vira e responde
const TALK_SUB2 := [6.9, 9.6]
const TALK_WIDE_AT := 9.8  # voltam ao trabalho
const TALK_END_AT := 11.2
const TALK_TURN := 4.0  # rapidez com que eles viram um para o outro
const LAIR_LINES := ["ELES QUERIAM EXPLODIR ALGO?",
	"COM ESSE TANTO DE EXPLOSIVO, TENHO CERTEZA QUE ISSO NÃO VEM COISA BOA POR AÍ..."]
const LAIR_WALK := 1.8
const LAIR_WALK_SPEED := 1.2
const LAIR_SUB1 := [2.0, 3.8]
const LAIR_SUB2 := [3.8, 6.6]
const LAIR_ROAR_AT := 6.6
const LAIR_CLOSE_AT := 7.1  # câmera vai para perto da cabeça dele (o rugido)
const LAIR_END_AT := 9.6
const STAND_LINES := ["PARADA AÍ!", "É O FIM DA LINHA.", "NÃO FAÇA MOVIMENTOS BRUSCOS OU ATIRAREMOS."]
const STAND_SUBS := [[0.5, 2.4], [2.8, 4.8], [5.1, 7.7]]  # quando cada fala fica na tela
const STAND_LASER := [0.9, 1.4]  # quando o laser de cada sniper acende
const STAND_CLOSE_AT := 2.4  # de frente, os lasers no peito dela
const STAND_HANDS_AT := 2.8  # ela levanta as mãos
const STAND_SNIPER_AT := 4.9  # por cima do ombro de um sniper
const STAND_END_AT := 8.1
const STAND_TURN := 3.0  # rapidez com que ela vira para o portão

var player: Player
var lab: CloneLab
var hud: CanvasLayer  # HUD do jogo, escondido durante a cena
var busy := false
var scene := ""  # "clones", "ambush", "talk" (túnel) ou "lair" (pedreira)
var t := 0.0
var layer: CanvasLayer
var _cam: Camera3D
var _top: ColorRect
var _bottom: ColorRect
var _sub: Label
var _shocked := false
var _ui_scale := 1.0
var _skip := false
var skippable := false  # esta cena já foi vista até o fim uma vez
var _hint: UiStyle.Hint
var corpse: Corpse
var ambushers: Array[Raptor] = []
var _roarer: Raptor
var _from := Vector3.ZERO  # onde ela começa a andar até o morto
var _emerged := false
var _stood := false
var _roared := false
var speakers: Array[Soldier] = []  # conversa do túnel: quem fala primeiro e quem responde
var _talk_yaw := {}  # giro de cada um enquanto a cena o vira (por cima do que a IA dele faz)
var _talk_home := {}  # giro de trabalho de cada um (virado para o caixote): volta a ele no fim
var allo: Allosaurus  # chegada à pedreira
var gunmen: Array[Sniper] = []  # rendição no pátio: os snipers das torres
var _hands_up := false


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cam.near = 0.05
	_cam.far = 120.0
	add_child(_cam)
	layer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_top = _bar()
	_bottom = _bar()
	_sub = Label.new()
	_sub.text = SUBTITLE
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # fala comprida quebra em duas linhas dentro da faixa
	_sub.add_theme_color_override("font_color", UiStyle.INK)
	_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_sub)
	_hint = UiStyle.Hint.new()
	_hint.set_items(SKIP_ITEMS)
	_hint.visible = false
	layer.add_child(_hint)
	set_ui_scale(1.0)
	layer.visible = false


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


## Escala do HUD (main.apply_gfx): a legenda acompanha o tamanho do resto do texto.
func set_ui_scale(k: float) -> void:
	_ui_scale = k
	_sub.add_theme_font_size_override("font_size", int(UiStyle.M * k))
	_sub.add_theme_constant_override("outline_size", int(UiStyle.OUTLINE * k))
	_hint.scale = Vector2.ONE * k


func play_clones(p: Player, room: CloneLab) -> void:
	if busy:
		return
	lab = room
	_begin(p, "clones", SUBTITLE)
	_place_camera()


## Emboscada no pátio: ela chega ao morto `body`, vê a mão dele e `raptors` saem da mata e a cercam.
func play_ambush(p: Player, body: Corpse, raptors: Array[Raptor]) -> void:
	if busy:
		return
	corpse = body
	ambushers = raptors.filter(func(r: Raptor) -> bool: return not r.dead)
	_begin(p, "ambush", AMB_SUBTITLE)
	_emerged = false
	_stood = false
	_roared = false
	_roarer = null
	# começa a AMB_APPROACH de onde para, no caminho de onde ela vinha
	var stand := corpse.stand_point()
	var back := Vector3(p.global_position.x - stand.x, 0.0, p.global_position.z - stand.z)
	if back.length() > AMB_APPROACH:
		p.global_position = Vector3(stand.x, p.global_position.y, stand.z) + back.normalized() * AMB_APPROACH
		p.reset_physics_interpolation()
	_from = p.global_position
	_place_camera()


## Conversa dos guardas do fundo do túnel: `who` = [quem fala primeiro, quem responde].
func play_talk(p: Player, who: Array[Soldier]) -> void:
	if busy or who.size() < 2:
		return
	speakers = who
	_talk_yaw.clear()
	_talk_home.clear()
	for sd in speakers:
		_talk_yaw[sd] = sd.rotation.y
		_talk_home[sd] = sd.rotation.y
	_begin(p, "talk", TALK_LINES[0])
	_place_camera()


## Chegada à pedreira pelo portão arrombado: ela pensa e o alossauro `a` ruge.
func play_lair(p: Player, a: Allosaurus) -> void:
	if busy or a == null:
		return
	allo = a
	_roared = false
	_begin(p, "lair", LAIR_LINES[0])
	_place_camera()


## Rendição no pátio: os snipers `who` (das torres) a pegam na mira; no fim ela fica rendida.
func play_standoff(p: Player, who: Array[Sniper]) -> void:
	if busy or who.is_empty():
		return
	gunmen = who
	_hands_up = false
	_begin(p, "standoff", STAND_LINES[0])
	for i in gunmen.size():
		gunmen[i].hold_at_gunpoint(STAND_LASER[mini(i, STAND_LASER.size() - 1)])
	_place_camera()


func _begin(p: Player, which: String, subtitle: String) -> void:
	player = p
	scene = which
	busy = true
	t = 0.0
	_skip = false
	skippable = Settings.cutscene_seen(which)
	_hint.visible = false
	_shocked = false
	p.moves.cancel()
	p.cutscene = true
	p.cutscene_walk = Vector3.ZERO
	p.model.holster(true)
	if hud:
		hud.visible = false
	layer.visible = true
	_sub.text = subtitle
	_sub.visible = false
	_cam.current = true


func _physics_process(delta: float) -> void:
	if not busy:
		return
	# o pulo fica para o passo de física seguinte ao aperto: a jogadora (que roda antes) já ignorou aquele E
	if _skip:
		if scene == "lair" and not _roared:
			_lair_roar()  # pulou antes do rugido: ele a vê do mesmo jeito
		stop()
		return
	t += delta
	if scene == "ambush":
		_ambush_step(delta)
		return
	if scene == "talk":
		_talk_step(delta)
		return
	if scene == "lair":
		_lair_step(delta)
		return
	if scene == "standoff":
		_standoff_step(delta)
		return
	if t < WALK_TIME:
		player.cutscene_walk = Vector3(0, 0, -WALK_SPEED)
		player.model.set_state("walk", WALK_SPEED / Moves.speed("walk"))
	else:
		player.cutscene_walk = Vector3.ZERO
		if t < FACE_AT:
			player.model.set_state("idle")
	if t >= FACE_AT and not _shocked:
		_shocked = true
		player.model.play("shocked")
	if t >= WIDE_AT and t - get_physics_process_delta_time() < WIDE_AT:
		player.model.set_state("crouch")  # vê os guardas no fundo e se abaixa atrás da caixa
	_sub.visible = t >= SUB_AT and t < WIDE_AT + 0.6
	if t >= END_AT:
		_finish()


## Linha do tempo da emboscada (ver o cabeçalho).
func _ambush_step(delta: float) -> void:
	var stand := corpse.stand_point()
	var to_stand := Vector3(stand.x - player.global_position.x, 0.0, stand.z - player.global_position.z)
	var hand := corpse.bone_point("Hand_R")
	if t < AMB_WALK and to_stand.length() > 0.12:
		var speed := minf(Moves.speed("walk"), to_stand.length() / maxf(AMB_WALK - t, 0.05))
		player.cutscene_walk = to_stand.normalized() * speed
		player.model.set_state("walk", speed / Moves.speed("walk"))
	else:
		player.cutscene_walk = Vector3.ZERO
		if t < AMB_LOOK_AT:
			# agachada, olhando a mão dele
			_turn_to(hand, delta, 6.0)
			player.model.set_state("crouch")
	if t >= AMB_EMERGE_AT and not _emerged:
		_emerged = true
		for i in ambushers.size():
			ambushers[i].start_ambush(AMB_RING, AMB_CIRCLE)
	if t >= AMB_LOOK_AT:
		if not _stood:
			_stood = true
			player.model.holster(false)
			player.model.set_state("idle")
			if not ambushers.is_empty():
				Sfx.play(ambushers[0].model, "raptor_screech", ambushers[0].model.mouth_position())
		# vira para o que vai rugir (o mais perto da frente dela quando a roda fecha)
		if _roarer == null and t >= AMB_WIDE_AT and not ambushers.is_empty():
			_roarer = _pick_roarer()
		var look_at: Vector3 = _roarer.global_position if _roarer else (ambushers[0].global_position if not ambushers.is_empty() else hand)
		_turn_to(look_at, delta, 2.5)
	if t >= AMB_ROAR_AT and not _roared and _roarer:
		_roared = true
		_roarer.ambush_roar()
	_sub.visible = t >= AMB_SUB_AT and t < AMB_LOOK_AT
	if t >= AMB_END_AT:
		_finish()


## Linha do tempo da conversa no túnel (ver o cabeçalho).
func _talk_step(delta: float) -> void:
	player.cutscene_walk = Vector3.ZERO
	player.model.set_state("crouch")
	if t >= TALK_A_AT and t < TALK_WIDE_AT:
		_turn_speaker(speakers[0], speakers[1], delta)
	if t >= TALK_B_AT and t < TALK_WIDE_AT:
		_turn_speaker(speakers[1], speakers[0], delta)
	if t >= TALK_WIDE_AT:
		for sd in speakers:
			_turn_home(sd, delta)
	if t >= TALK_SUB1[0] and t < TALK_SUB1[1]:
		_sub.text = TALK_LINES[0]
		_sub.visible = true
	elif t >= TALK_SUB2[0] and t < TALK_SUB2[1]:
		_sub.text = TALK_LINES[1]
		_sub.visible = true
	else:
		_sub.visible = false
	if t >= TALK_END_AT:
		_finish()


## `who` vira para `other` (a cena manda no giro dele por cima da IA, que o puxaria de volta ao caixote).
func _turn_speaker(who: Soldier, other: Soldier, delta: float) -> void:
	if not is_instance_valid(who) or who.dead or not is_instance_valid(other):
		return
	var to := other.global_position - who.global_position
	var yaw: float = _talk_yaw.get(who, who.rotation.y)
	yaw = lerp_angle(yaw, atan2(-to.x, -to.z), 1.0 - exp(-TALK_TURN * delta))
	_talk_yaw[who] = yaw
	who.rotation.y = yaw


## `who` volta a ficar virado para o caixote dele (o guarda distraído só trabalha virado para lá: `Enemy.is_distracted`).
func _turn_home(who: Soldier, delta: float) -> void:
	if not is_instance_valid(who) or who.dead:
		return
	var yaw: float = _talk_yaw.get(who, who.rotation.y)
	yaw = lerp_angle(yaw, _talk_home.get(who, yaw), 1.0 - exp(-TALK_TURN * 1.5 * delta))
	_talk_yaw[who] = yaw
	who.rotation.y = yaw


## Linha do tempo da chegada à pedreira (ver o cabeçalho).
func _lair_step(delta: float) -> void:
	if t < LAIR_WALK:
		player.cutscene_walk = Vector3(-LAIR_WALK_SPEED, 0, 0)
		player.model.set_state("walk", LAIR_WALK_SPEED / Moves.speed("walk"))
	else:
		player.cutscene_walk = Vector3.ZERO
		player.model.set_state("idle")
		if t >= LAIR_ROAR_AT and is_instance_valid(allo) and not allo.dead:
			_turn_to(allo.global_position, delta, 2.0)
	if t >= LAIR_ROAR_AT and not _roared:
		_lair_roar()
	if t >= LAIR_SUB1[0] and t < LAIR_SUB1[1]:
		_sub.text = LAIR_LINES[0]
		_sub.visible = true
	elif t >= LAIR_SUB2[0] and t < LAIR_SUB2[1]:
		_sub.text = LAIR_LINES[1]
		_sub.visible = true
	else:
		_sub.visible = false
	if t >= LAIR_END_AT:
		_finish()


## Linha do tempo da rendição (ver o cabeçalho).
func _standoff_step(delta: float) -> void:
	player.cutscene_walk = Vector3.ZERO
	if t < STAND_HANDS_AT:
		_turn_to(_gate_mid(), delta, STAND_TURN)
		player.model.set_state("idle")
	elif not _hands_up:
		_hands_up = true
		player.model.play("surrender")
	elif t > STAND_HANDS_AT + Player.SURRENDER_RAISE:
		player.model.set_state("surrender_hold")
	# o clique do fuzil de cada um quando o laser acende
	for i in gunmen.size():
		var at: float = STAND_LASER[mini(i, STAND_LASER.size() - 1)]
		if t >= at and t - delta < at and is_instance_valid(gunmen[i]) and not gunmen[i].dead:
			Sfx.play(gunmen[i].model, "weapon_switch", gunmen[i].model.muzzle_position())
	_sub.visible = false
	for i in STAND_SUBS.size():
		if t >= STAND_SUBS[i][0] and t < STAND_SUBS[i][1]:
			_sub.text = STAND_LINES[i]
			_sub.visible = true
	if t >= STAND_END_AT:
		_finish()


## Meio dos snipers (entre as torres, no portão): para onde ela vira.
func _gate_mid() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for g in gunmen:
		if is_instance_valid(g):
			c += g.global_position
			n += 1
	return c / float(n) if n > 0 else player.global_position - player.global_basis.z


## O alossauro a vê: ruge virado para ela e chama os raptors da pedreira.
func _lair_roar() -> void:
	_roared = true
	if is_instance_valid(allo) and not allo.dead and not allo.in_combat():
		allo.spot()


## Chegou ao fim sem pular: a cena fica vista (da próxima vez dá para pular).
func _finish() -> void:
	Settings.mark_cutscene_seen(scene)
	stop()


func _turn_to(p: Vector3, delta: float, rate: float) -> void:
	var d := Vector3(p.x - player.global_position.x, 0.0, p.z - player.global_position.z)
	if d.length() > 0.05:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-rate * delta))


## O raptor da roda mais à frente dela (o close final é por cima do ombro, nele).
func _pick_roarer() -> Raptor:
	var best: Raptor = ambushers[0]
	var fwd := -player.global_basis.z
	var score := -INF
	for r in ambushers:
		var d := (r.global_position - player.global_position).normalized()
		if d.dot(fwd) > score:
			score = d.dot(fwd)
			best = r
	return best


## Pular: só um aperto de verdade (evento de tecla/botão), não um estado de ação que sobrou de outro lugar.
func _unhandled_input(event: InputEvent) -> void:
	if not busy or not skippable or t <= SKIP_AFTER or event.is_echo():
		return
	for a in SKIP:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			get_viewport().set_input_as_handled()
			_skip = true
			return


func _process(_delta: float) -> void:
	if not busy:
		return
	_place_camera()
	var vp := get_viewport().get_visible_rect().size
	var h := roundf(vp.y * BAR)
	_top.position = Vector2.ZERO
	_top.size = Vector2(vp.x, h)
	# a legenda fica longe das bordas e do "PULAR" (que vai no canto direito da faixa); fala de duas linhas sobe a faixa
	var pad := h * 0.5 + (_hint.size.x * _hint.scale.x if skippable else 0.0)
	_sub.size = Vector2(vp.x - pad * 2.0, h)
	var hb := h
	if _sub.visible:
		hb = maxf(h, roundf(_sub.get_line_count() * _sub.get_line_height() + h * 0.3))
	_sub.position = Vector2(pad, vp.y - hb)
	_sub.size = Vector2(vp.x - pad * 2.0, hb)
	_bottom.position = Vector2(0, vp.y - hb)
	_bottom.size = Vector2(vp.x, hb)
	# "PULAR" no canto direito da faixa de baixo, só quando já dá para pular
	_hint.visible = skippable and t > SKIP_AFTER
	var hs := _hint.size * _hint.scale
	_hint.position = Vector2(roundf(vp.x - hs.x - h * 0.5), roundf(vp.y - (h + hs.y) * 0.5))


## Câmera do plano de agora (ver o cabeçalho), em movimento lento dentro de cada plano.
func _place_camera() -> void:
	if scene == "ambush":
		_ambush_camera()
		return
	if scene == "talk":
		_talk_camera()
		return
	if scene == "lair":
		_lair_camera()
		return
	if scene == "standoff":
		_standoff_camera()
		return
	var her := player.get_global_transform_interpolated().origin
	var head := her + Vector3.UP * 1.55
	if t < REVEAL_AT:
		var k := t / REVEAL_AT
		_cam.fov = 58.0
		_cam.global_position = her + Vector3(0.75, 1.0 + 0.2 * k, 2.4 - 0.4 * k)
		_cam.look_at(her + Vector3(0, 1.6, -7.0))
	elif t < FACE_AT:
		var k := (t - REVEAL_AT) / (FACE_AT - REVEAL_AT)
		var clone: RaptorModel = lab.clones[0]
		var sk := clone.skeleton
		var face := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
		var side := Vector3(1, 0, 0) if clone.global_position.x < 0.0 else Vector3(-1, 0, 0)
		_cam.fov = 42.0
		_cam.global_position = face + side * (2.4 - 0.5 * k) + Vector3(0, -0.35, 0.8)
		_cam.look_at(face)
	elif t < WIDE_AT:
		var k := (t - FACE_AT) / (WIDE_AT - FACE_AT)
		var front := -player.global_basis.z
		var right := player.global_basis.x
		_cam.fov = 38.0
		# na pose do susto a cabeça vai para trás e para baixo: mira um pouco abaixo, o rosto fica no meio do quadro
		_cam.global_position = head + front * (1.7 - 0.25 * k) + right * 0.25 + Vector3.UP * (-0.3)
		_cam.look_at(head + Vector3.UP * (-0.2))
	else:
		var k := (t - WIDE_AT) / (END_AT - WIDE_AT)
		var tank := CloneLab.TANK + Vector3(1.2, 1.2, 1.5)
		_cam.fov = 48.0
		_cam.global_position = her + Vector3(0.9 + 0.3 * k, 1.75 - 0.35 * k, 1.5 - 0.3 * k)
		_cam.look_at(tank.lerp(her + Vector3.UP * 0.9, 0.18))


func _ambush_camera() -> void:
	var her := player.get_global_transform_interpolated().origin
	var body := corpse.bone_point("Chest")
	if t < AMB_WALK:
		# atrás dela, baixo, o morto à frente
		var k := t / AMB_WALK
		var ahead := Vector3(body.x - _from.x, 0.0, body.z - _from.z).normalized()
		var side := ahead.cross(Vector3.UP)
		_cam.fov = 55.0
		_cam.global_position = her - ahead * (2.4 - 0.3 * k) - side * 0.7 + Vector3.UP * (1.25 - 0.15 * k)
		_cam.look_at(body + Vector3.UP * 0.2)
	elif t < AMB_LOOK_AT:
		# a mão dele, de perto e baixo: o punho fechado com a chave
		var k := (t - AMB_WALK) / (AMB_LOOK_AT - AMB_WALK)
		var key := corpse.key_transform().origin
		var out := Vector3(key.x - body.x, 0.0, key.z - body.z).normalized()
		var feet := -corpse.global_basis.z
		_cam.fov = 40.0
		_cam.global_position = key + feet * (0.8 - 0.2 * k) + out * 0.25 + Vector3.UP * 0.3
		_cam.look_at(key + Vector3.UP * 0.05)
	elif t < AMB_WIDE_AT:
		# o rosto dela, levantando e olhando em volta
		var k := (t - AMB_LOOK_AT) / (AMB_WIDE_AT - AMB_LOOK_AT)
		var head := her + Vector3.UP * 1.5
		var front := -player.global_basis.z
		_cam.fov = 42.0
		_cam.global_position = head + front * (1.8 + 0.3 * k) + player.global_basis.x * 0.4 + Vector3.UP * -0.15
		_cam.look_at(head)
	elif t < AMB_ROAR_AT:
		# do alto, do lado de onde ela veio (a trilha: aberta, sem copa no caminho), girando devagar: os três em volta
		var k := (t - AMB_WIDE_AT) / (AMB_ROAR_AT - AMB_WIDE_AT)
		var back := Vector3(_from.x - her.x, 0.0, _from.z - her.z)
		var ang := atan2(back.x, back.z) - 0.25 + 0.5 * k
		_cam.fov = 60.0
		_cam.global_position = her + Vector3(sin(ang), 0.0, cos(ang)) * 8.0 + Vector3.UP * 8.5
		_cam.look_at(her)
	else:
		# por cima do ombro dela, no que ruge
		var k := (t - AMB_ROAR_AT) / (AMB_END_AT - AMB_ROAR_AT)
		var r: Raptor = _roarer if _roarer else (ambushers[0] if not ambushers.is_empty() else null)
		var aim := r.model.mouth_position() if r else her - player.global_basis.z * 5.0 + Vector3.UP
		var dir := Vector3(aim.x - her.x, 0.0, aim.z - her.z).normalized()
		var right := dir.cross(Vector3.UP)
		_cam.fov = 45.0 - 6.0 * k
		_cam.global_position = her - dir * 1.5 + right * 0.55 + Vector3.UP * 1.65
		_cam.look_at(aim.lerp(her + Vector3.UP * 1.2, 0.3))


func _talk_camera() -> void:
	var her := player.get_global_transform_interpolated().origin
	var chamber := Vector3((Tunnel.SECTIONS[3][0] + Tunnel.SECTIONS[3][1]) * 0.5, 1.1, Tunnel.Z)
	if t < TALK_A_AT or t >= TALK_WIDE_AT:
		# atrás dela, baixo, a câmara dos explosivos à frente
		var k := t / TALK_A_AT if t < TALK_A_AT else (t - TALK_WIDE_AT) / (TALK_END_AT - TALK_WIDE_AT)
		var ahead := Vector3(chamber.x - her.x, 0.0, chamber.z - her.z).normalized()
		var side := ahead.cross(Vector3.UP)
		_cam.fov = 50.0
		_cam.global_position = her - ahead * (2.2 - 0.3 * k) + side * 0.6 + Vector3.UP * (1.25 + 0.1 * k)
		_cam.look_at(chamber)
		return
	# o rosto de quem fala, do lado para onde ele vira (o outro, no meio da câmara)
	var who: Soldier = speakers[0] if t < TALK_B_AT else speakers[1]
	var other: Soldier = speakers[1] if t < TALK_B_AT else speakers[0]
	var k := (t - TALK_A_AT) / (TALK_B_AT - TALK_A_AT) if t < TALK_B_AT else (t - TALK_B_AT) / (TALK_WIDE_AT - TALK_B_AT)
	var head := who.global_position + Vector3.UP * 1.6
	var f := Vector3(other.global_position.x - who.global_position.x, 0.0, other.global_position.z - who.global_position.z).normalized()
	var side := f.cross(Vector3.UP)
	_cam.fov = 40.0
	_cam.global_position = head + f * (2.0 - 0.3 * k) + side * 0.7 + Vector3.UP * -0.1
	_cam.look_at(head + Vector3.UP * -0.05)


func _lair_camera() -> void:
	var her := player.get_global_transform_interpolated().origin
	var head := her + Vector3.UP * 1.55
	var front := -player.global_basis.z
	var right := player.global_basis.x
	if t < LAIR_WALK:
		# atrás dela, baixo, entrando na pedreira
		var k := t / LAIR_WALK
		_cam.fov = 55.0
		_cam.global_position = her - front * (2.4 - 0.4 * k) + right * 0.6 + Vector3.UP * 1.2
		_cam.look_at(her + front * 10.0 + Vector3.UP * 1.6)
	elif t < LAIR_ROAR_AT:
		# o rosto dela, pensando
		var k := (t - LAIR_WALK) / (LAIR_ROAR_AT - LAIR_WALK)
		_cam.fov = 38.0
		_cam.global_position = head + front * (1.7 - 0.2 * k) + right * 0.3 + Vector3.UP * -0.1
		_cam.look_at(head)
	elif not is_instance_valid(allo):
		return
	elif t < LAIR_CLOSE_AT:
		# por cima do ombro dela, ele lá na frente
		var aim := allo.model.mouth_position()
		var dir := Vector3(aim.x - her.x, 0.0, aim.z - her.z).normalized()
		var side := dir.cross(Vector3.UP)
		_cam.fov = 45.0
		_cam.global_position = her - dir * 1.6 + side * 0.6 + Vector3.UP * 1.7
		_cam.look_at(aim.lerp(her + Vector3.UP * 1.4, 0.15))
	else:
		# perto da cabeça dele, rugindo
		var k := (t - LAIR_CLOSE_AT) / (LAIR_END_AT - LAIR_CLOSE_AT)
		var m := allo.model.mouth_position()
		var to_her := Vector3(her.x - m.x, 0.0, her.z - m.z).normalized()
		var side := to_her.cross(Vector3.UP)
		_cam.fov = 50.0
		_cam.global_position = m + to_her * (7.0 - 1.0 * k) + side * 2.5 + Vector3.UP * 0.4
		_cam.look_at(m + Vector3.DOWN * 0.6)


func _standoff_camera() -> void:
	var her := player.get_global_transform_interpolated().origin
	var chest := her + Vector3.UP * 1.3
	var mid := _gate_mid()
	var ahead := Vector3(mid.x - her.x, 0.0, mid.z - her.z).normalized()
	var side := ahead.cross(Vector3.UP)
	if t < STAND_CLOSE_AT:
		# atrás dela, baixo, as duas torres à frente
		var k := t / STAND_CLOSE_AT
		_cam.fov = 52.0
		_cam.global_position = her - ahead * (2.6 - 0.4 * k) + side * 0.7 + Vector3.UP * (1.1 + 0.1 * k)
		_cam.look_at(Vector3(mid.x, mid.y + GuardTower.FLOOR_Y * 0.5, mid.z))
	elif t < STAND_SNIPER_AT:
		# de frente, perto e um pouco de baixo: os dois lasers chegando de cima e cruzando no peito dela
		var k := (t - STAND_CLOSE_AT) / (STAND_SNIPER_AT - STAND_CLOSE_AT)
		_cam.fov = 44.0
		_cam.global_position = chest + ahead * (2.1 - 0.3 * k) + side * 0.35 + Vector3.UP * (-0.15 + 0.1 * k)
		_cam.look_at(chest + Vector3.UP * 0.25)
	else:
		# por cima do ombro do sniper mais perto dela: ela lá embaixo, o laser descendo até ela
		var k := (t - STAND_SNIPER_AT) / (STAND_END_AT - STAND_SNIPER_AT)
		var g: Sniper = _nearest_gunman(her)
		if g == null:
			return
		var head := g.global_position + Vector3.UP * 1.6
		var to_her := Vector3(her.x - head.x, 0.0, her.z - head.z).normalized()
		var right := to_her.cross(Vector3.UP)
		_cam.fov = 40.0 - 4.0 * k
		# do lado de dentro da torre (para trás do sniper fica o parapeito e nos cantos os postes)
		_cam.global_position = head - to_her * 0.45 - right * 0.5 + Vector3.UP * 0.35
		_cam.look_at(chest.lerp(head, 0.12))


func _nearest_gunman(at: Vector3) -> Sniper:
	var best: Sniper = null
	for g in gunmen:
		if is_instance_valid(g) and not g.dead and (best == null or g.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = g
	return best


## Acaba a cena (ou pula, ou reinício): controle e câmera de volta para ela, atrás dela e olhando para onde ela olha
## (dentro da sala dos clones; na emboscada, o raptor que rugiu), nunca na inclinação que o mouse deixou.
func stop() -> void:
	if not busy:
		return
	busy = false
	_skip = false
	layer.visible = false
	_hint.visible = false
	if scene == "ambush":
		# a roda se desfaz um de cada vez, já em luta (pulou antes de saírem: saem agora)
		for i in ambushers.size():
			if is_instance_valid(ambushers[i]) and not ambushers[i].dead:
				ambushers[i].end_ambush(AMB_STAGGER * i)
	if scene == "talk":
		# no fim (ou pulando) eles ficam de novo virados para os caixotes, no trabalho
		for sd in speakers:
			if is_instance_valid(sd) and not sd.dead and _talk_home.has(sd):
				sd.rotation.y = _talk_home[sd]
	if hud:
		hud.visible = true
	if is_instance_valid(player):
		player.cutscene = false
		player.cutscene_walk = Vector3.ZERO
		if scene == "clones":
			player.crouching = true  # termina escondida atrás da caixa de equipamento (CloneLab.COVER)
		player.model.holster(false)
		player.model.set_state("idle")
		player.camera_rig.reset_view(player.rotation.y)
		player.camera_rig.camera.current = true
		if scene == "standoff" and not player.dead:
			# fica rendida, de mãos ao alto, com os dois na mira (pulou antes: os lasers acendem já)
			for g in gunmen:
				if is_instance_valid(g):
					g.light_laser()
			if gunmen.any(func(g: Sniper) -> bool: return is_instance_valid(g) and g.in_standoff()):
				var to := _gate_mid() - player.global_position
				player.rotation.y = atan2(-to.x, -to.z)
				player.camera_rig.reset_view(player.rotation.y)
				player.surrender(true)
	finished.emit()
