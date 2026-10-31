extends Node3D
## Cena de teste: sala, heroína, guardas da porta do pátio, baús com M16 e escopeta, um velociraptor, HUD e pós-processo PS1.
## Captura para conferência:  godot --path game -- --capture=out.png [--shot=idle|aim|run|ragdoll|front|roll|crouch|face]
##   movimentos:  --shot=walk|crouch_walk|crouch_aim|jump|hang|climb|mantle|pickup|rifle|rifle_aim|dodge_l|dodge_r|dodge_back|dodge_roll  (--at=segundos)
##   golpes:  --shot=hit_crouch|stagger|getup|getup_fwd  (getup = desaba de costas e levanta girando; getup_fwd = arremessada
##     pelas costas, levanta de bruços; --at=segundos)
##   armas:  --shot=pickup_shotgun|shotgun|shotgun_aim|fire_pistol|fire_m16|fire_shotgun|pump  (tiros: --at=segundos)
##   raptor:  --shot=raptor_idle|raptor_roar|raptor_study|raptor_bite|raptor_tail|raptor_leap|raptor_charge|raptor_dead
##            (câmera de revisão em volta dele; --yaw=graus gira a câmera; --playercam usa a câmera dela)
##   sangue:  --shot=soldier_headshot|soldier_wounded|raptor_blood  (esguicho/poça: --at=segundos)
##   alossauro:  --shot=allo_idle|allo_roar|allo_roar_at|allo_stomp|allo_headbutt|allo_tail|allo_bite|allo_dead|allo_end
##               (na pedreira; --yaw, --playercam)
##   pedreira:  --shot=arena (a câmera dela olhando a sala da entrada; --pos=x,z[,graus] para outro ponto)
##   --pitch=graus inclina a câmera dela junto com --yaw (> 0 = para cima; mirando, a arma acompanha)
##   M79 e chave:  --shot=locked|unlock|corpse|key_get|m79_aim|fire_m79|pickup_m79  (locked/unlock/key_get salvam
##                 quando a tela de inspeção termina de aparecer; fire_m79: --at=segundos para pegar a explosão;
##                 corpse = o guerrilheiro morto com a chave na mão, no meio do pátio; --yaw gira em volta dele)
##   emboscada:  --shot=ambush  (a cena dos 3 raptors cercando ela no morto do pátio; --at=segundos escolhe o quadro)
## Showroom (menu de pausa):  --shot=showroom [--creature=raptor|allosaurus] [--anim=Walk] [--move=lugar|circulo|girando]
##   [--yaw=graus]  (abre o showroom e salva --at segundos depois, contados com o jogo pausado)
## Visual:  --gfx=ps1|ps2  (F2 alterna no jogo; ver Gfx)
## Perfil de jogo:  --mode=survival|arcade  (F3 alterna no jogo; ver GameMode)
## Começo da fase:  --shot=roof|hatch|ladder_mount|ladder_out|ladder_roof|sniper_ladder|maze|gate|lab|clones  (hatch/clones: --at=segundos escolhe o
##   quadro da tampa subindo / da cena do choque; sniper_ladder: o sniper a vê na escada do telhado e atira)
##   --shot=smell: na beira do telhado do lado do pátio, salva quando a mensagem do cheiro de sangue para o jogo
## Caixa de paraquedas:  --shot=drop|drop_get|drop_pick|fire_sd  (drop = de frente para a caixa no teto dos clones, --dist=m
##   do lugar de ajoelhar (padrão 2); drop_get pega e salva quando a tela do item aparece; drop_pick = câmera de lado
##   enquanto ela pega (--at escolhe o quadro, --yaw gira); fire_sd = atirando com a pistola com silenciador)
## Sala dos clones e portão da pedreira:  --shot=tank|plate|plate_allo|keypad|keypad_on|keypad_ok|gate_open
##   (tank = o tanque vazio do alossauro; plate/plate_allo salvam quando a tela aparece; keypad = sem o cartão,
##   keypad_on = com ele, digitando; keypad_ok = código certo; gate_open = depois, o portão abrindo: --at escolhe o quadro)
## Torres de guarda do portão do pátio:  --shot=towers|tower_fall|gate_card  (towers = as duas com os snipers, vistas da
##   estrada; tower_fall = o último sniper tomba da torre, câmera de lado, --at escolhe o quadro; gate_card = pega o cartão
##   que ele derrubou e salva quando a tela do item aparece)
## Menu de pausa:  --shot=pause  (ESC / START no jogo; salva quando o menu aparece)
## HUD:  --shot=danger|danger_roll  (no galpão, na mira dos guardas da porta do pátio: sensor de perigo subindo e o radar
##   com eles; danger_roll rola em 2,6 s e a barra cai — --at escolhe o quadro)

const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const MOVE_SHOTS := [
	"walk", "crouch_walk", "crouch_aim", "jump", "hang", "climb", "mantle", "pickup", "rifle", "rifle_aim",
	"pickup_shotgun", "shotgun", "shotgun_aim", "fire_pistol", "fire_m16", "fire_shotgun", "pump",
	"dodge_l", "dodge_r", "dodge_back", "dodge_roll", "sniper_aim", "sniper_zoom",
	"hit_crouch", "stagger", "getup", "getup_fwd",
]
## ela e o guerrilheiro lado a lado, parados (idle_compare = sem arma; carry_compare = com a M16) ou andando no lugar
## com a M16 (walk_compare); --yaw gira a câmera em volta (0 = de frente)
const COMPARE_SHOTS := ["idle_compare", "carry_compare", "walk_compare"]
## revisão dos golpes na heroína (câmera de revisão de lado)
const HURT_SHOTS := ["hit_crouch", "stagger", "getup", "getup_fwd"]
## revisão do container trancado da M79, da chave na mão do morto do pátio e da M79 (ver _setup_key_shot)
const KEY_SHOTS := ["locked", "unlock", "corpse", "key_get", "ambush", "m79_aim", "fire_m79", "pickup_m79"]
## revisão do começo da fase: telhado, alçapão, escada do canto, labirinto, portão e sala dos clones (ver _setup_start_shot)
const START_SHOTS := ["roof", "hatch", "ladder_mount", "ladder_out", "ladder_roof", "sniper_ladder", "maze", "gate", "lab", "clones",
	"drop", "drop_get", "drop_pick", "fire_sd", "smell", "tank", "plate", "plate_allo", "keypad", "keypad_on", "keypad_ok",
	"gate_open"]
## revisão das torres de guarda do portão do pátio e do cartão do painel (ver _setup_tower_shot)
const TOWER_SHOTS := ["towers", "tower_fall", "gate_card"]
const LOCKER_POS := Vector3(0, Catwalk.FLOOR_Y, 12.2)  # container trancado da M79 no mezanino
const HEADSHOT_TIME := 1.0  # quanto tempo o aviso de tiro na cabeça fica na tela
const END_DELAY := 3.0  # depois que o alossauro cai, a tela de fim aparece (dá tempo de ver o corpo tombar)
const GAME_OVER_DELAY := 1.5  # depois que ela morre, a tela de game over aparece (dá tempo de ver o corpo cair)
const RESTART_ACTIONS := ["reset", "interact", "roll", "jump", "shoot", "ui_accept"]
const NOTICE_TIME := 1.6  # quanto tempo um aviso (munição, vida, "pare para atirar") fica na tela
const LOW_AMMO := 3  # com tão pouca munição o número fica vermelho
const HELP := "WASD mover  SHIFT corrida forte (L3)  ALT andar devagar (arcade: SHIFT)  MOUSE-D mirar  MOUSE-E atirar (mirando)\nESPAÇO esquiva  C agachar  F pular/agarrar  SNIPER MIRA: X aumenta / O diminui zoom\nE pegar (triângulo)  Q trocar arma (select)  ESC pausa (start)\nH dano  K morrer  G guerrilheiro ragdoll  R reiniciar  F1 ajuda  F2 PS1/PS2  F3 SOBREVIVÊNCIA/ARCADE"

var player: Player
var dummies: Array[TargetDummy] = []
var chest: Chest
var chests: Array[Chest] = []
var locker: Chest  # container trancado com a M79
var key: KeyItem  # chave do container da M79 (etiqueta "0M79"), na mão do guerrilheiro morto
var corpse: Corpse  # guerrilheiro morto no meio do pátio, com a chave do container na mão
var yard_raptors: Array[Raptor] = []  # os 3 do pátio: escondidos na mata até a emboscada no morto
var keycard: KeyItem
var inspect: Inspect
var pause_menu: PauseMenu
var raptors: Array[Raptor] = []
var soldiers: Array[Soldier] = []
var allosaurus: Allosaurus
var catwalk: Catwalk
var hatch: Hatch  # alçapão do telhado, por onde ela entra na fase
var lab: CloneLab  # sala dos clones, atrás da plataforma de carga
var drop: SupplyDrop  # caixa de paraquedas com a pistola com silenciador, no teto da sala dos clones
var towers: Array[GuardTower] = []  # torres de guarda dos dois lados do portão do pátio (Yard.TOWERS)
var tower_snipers: Array[Sniper] = []  # um em cada torre, fora de cena até os raptors da emboscada morrerem
var gate_card: KeyItem  # cartão do painel do portão da pedreira: cai do último sniper das torres
var cutscene: Cutscene
var sniper: Sniper
var sniper_scope: SniperScope
var _hud_daze: Label
var _end: Control
var _end_stats: Label
var _play_t := 0.0  # tempo de jogo até o fim (tela de fim)
var _end_t := -1.0  # > 0: contando para mostrar a tela de fim
var _game_over_t := -1.0  # > 0: contando para mostrar a tela de game over
var ended := false
var game_over := false
var _hud: CanvasLayer
var _post: ColorRect
var _hud_health: HudBar
var _hud_help: Label
var _hud_weapon: Label  # munição ao lado do modelo da arma (só no perfil de sobrevivência)
var _weapon_icon: WeaponIcon
var danger: DangerMeter
var radar: Radar
var _hud_headshot: Label
var _hud_notice: Label
var _notice_t := 0.0
var smelled := false  # o aviso do cheiro de sangue na beira do telhado já apareceu (Roof.near_yard)
var _headshot_t := 0.0
var _prompt: UiStyle.Hint
var _end_hint: UiStyle.Hint
var _crosshair: Crosshair
var _capture := ""
var _shot := "idle"
var _t := 0.0
var _until := 1.5
var _saving := false
var _yaw := NAN
var _pitch := -0.15
var _dist := 2.0  # --dist: distância da revisão da caixa de paraquedas
var _show := {"creature": "raptor", "anim": "", "move": 0}  # --shot=showroom
var _review_cam: Camera3D
var _player_cam := false


func _ready() -> void:
	InputSetup.register()
	var built := Level.build(self)
	hatch = built.hatch
	lab = built.lab
	# ela começa no telhado, olhando para o alçapão (desce pela escada do canto até o labirinto de caixas)
	player = Player.new()
	player.position = Roof.START
	var to_hatch := hatch.kneel_point() - Roof.START
	player.rotation.y = atan2(-to_hatch.x, -to_hatch.z)
	add_child(player)
	# baú com o M16 no canto superior direito do galpão, guardado por sentinela à sua direita
	chest = Chest.new()
	chest.position = Vector3(10.0, 0, -11.4)
	chest.rotation.y = 0.0
	add_child(chest)
	chests.append(chest)
	# baú com a escopeta no canto esquerdo inferior do pátio dos velociraptors (mata sul, perto do fundo)
	var sg := Chest.new()
	sg.item = "shotgun"
	sg.position = Vector3(-49.5, 0, 14.0)
	sg.rotation.y = 0.0
	add_child(sg)
	chests.append(sg)
	# container trancado com a M79 no mezanino às costas da heroína; a chave está na mão do guerrilheiro morto no pátio
	locker = Chest.new()
	locker.item = "m79"
	locker.lock = "container"
	locker.position = LOCKER_POS
	locker.rotation.y = PI
	add_child(locker)
	chests.append(locker)
	# caixa de paraquedas no fundo do teto da sala dos clones, escondida na neblina do telhado
	drop = SupplyDrop.new()
	drop.position = SupplyDrop.POS
	drop.rotation.y = SupplyDrop.YAW
	add_child(drop)
	# a chave do container na mão do morto; a etiqueta "0M79" parece um código (não é o do portão)
	key = KeyItem.new()
	key.id = locker.lock
	key.tag = "0M79"
	key.description = "Chave de latão. Na etiqueta vermelha: \"0M79\".\nAbre o cadeado de algum container."
	key.shine = false  # só brilha depois que os raptors da emboscada morrem
	add_child(key)
	corpse = Corpse.new()
	corpse.position = Yard.CORPSE
	corpse.rotation.y = Yard.CORPSE_YAW
	corpse.target = player
	add_child(corpse)
	corpse.hold_key(key)
	# os velociraptors ficam no pátio da mata (segunda sala, pela porta oeste) e na pedreira (última sala, junto com o
	# alossauro); os da pedreira patrulham a sua rota, os do pátio ficam escondidos na mata até a emboscada no morto
	for post in Yard.POSTS + Arena.POSTS:
		var r := Raptor.new()
		_place(r, post)
		raptors.append(r)
	yard_raptors.assign(raptors.slice(0, Yard.POSTS.size()))
	_lurk_yard_raptors()
	for r in yard_raptors:
		r.killed.connect(_on_yard_raptor_killed)
	allosaurus = Allosaurus.new()
	_place(allosaurus, Arena.ALLO)
	allosaurus.killed.connect(func() -> void:
		if not player.dead and not game_over:
			_end_t = END_DELAY)
	player.died.connect(_on_player_died)
	# área suspensa na parede traseira às costas da heroína (com escada)
	catwalk = Catwalk.new()
	add_child(catwalk)
	
	# inimigo guerrilheiro Sniper no mezanino às costas da heroína (posto de observação elevado)
	sniper = Sniper.new()
	sniper.target = player
	sniper.position = Vector3(-2.0, Catwalk.FLOOR_Y, 11.7)
	sniper.rotation.y = 0.0  # olhando para frente do galpão (-Z)
	sniper.route = [Vector3(-3.5, Catwalk.FLOOR_Y, 11.7), Vector3(0.5, Catwalk.FLOOR_Y, 11.7)]
	add_child(sniper)
	
	# keycard no sniper que abre o portão da primeira fase
	keycard = KeyItem.new()
	keycard.id = "keycard_gate"
	keycard.kind = "keycard"
	keycard.display_name = "CARTÃO DE ACESSO"
	keycard.description = "Cartão de acesso magnético nível 1.\nAbre o portão de segurança do pátio."
	add_child(keycard)
	sniper.loot = keycard
	keycard.picked.connect(func(k: KeyItem) -> void: inspect.show_item(k))
	_build_towers()
	
	# soldados de guarda no galpão/pátio (2 patrulhando o pátio, 2 sentinelas no portão; os de "hold" guardam a porta
	# do pátio e só saem do posto depois que alguém a vê)
	for g in Soldier.GUARDS:
		var sd := Soldier.new()
		sd.target = player
		sd.hold_post = g.get("hold", false)
		if g.route.is_empty():
			sd.position = g.pos
			sd.rotation.y = g.rot_y
		else:
			sd.position = g.route[0]
			var next: Vector3 = g.route[1] - g.route[0]
			sd.rotation.y = atan2(-next.x, -next.z)
			for p in g.route:
				sd.route.append(p)
		add_child(sd)
		soldiers.append(sd)
	Yard.bake_nav(self)
	var people := Yard.bake_people_nav(self)
	for sd: Soldier in soldiers:
		sd.nav_map = people
	# itens do chão (só no perfil de sobrevivência): depois da malha de navegação, que não os conhece
	Pickup.build(self)
	var sound := Soundscape.new()
	sound.target = player
	add_child(sound)
	_build_post()
	add_child(UiStyle.Watcher.new())  # glifos dos botões pelo último aparelho usado
	_build_hud()
	inspect = Inspect.new()
	inspect.player = player
	inspect.hud = _hud
	add_child(inspect)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.restart.connect(_restart_from_overlay)
	pause_menu.quit.connect(func() -> void: get_tree().quit())
	sniper_scope = SniperScope.new()
	add_child(sniper_scope)
	cutscene = Cutscene.new()
	cutscene.hud = _hud
	add_child(cutscene)
	lab.entered.connect(func() -> void: cutscene.play_clones(player, lab))
	corpse.noticed.connect(func() -> void: cutscene.play_ambush(player, corpse, yard_raptors))
	player.locked.connect(_on_locked)
	player.keypad.connect(_on_keypad)
	player.read_plate.connect(func(pl: SubjectPlate) -> void: inspect.plate_zoom(pl))
	key.picked.connect(func(k: KeyItem) -> void: inspect.show_item(k))
	drop.picked.connect(func(d: SupplyDrop) -> void: inspect.show_drop(d))
	gate_card.picked.connect(func(k: KeyItem) -> void: inspect.show_item(k))
	player.health_changed.connect(_set_health)
	player.headshot.connect(func(_who: Node) -> void: _headshot_t = HEADSHOT_TIME)
	player.notice.connect(show_notice)
	apply_gfx(Gfx.mode)
	_parse_args()
	if _capture == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().create_timer(10.0).timeout.connect(func() -> void: _hud_help.visible = false)


## Os raptors do pátio vão para as moitas da beira da clareira do morto (Yard.LURK) e esperam a emboscada.
func _lurk_yard_raptors() -> void:
	for i in yard_raptors.size():
		yard_raptors[i].lurk(Yard.LURK[i % Yard.LURK.size()])


## Morreu um raptor do pátio: com os três mortos, a chave na mão do guerrilheiro começa a brilhar e os snipers sobem nas
## torres do portão.
func _on_yard_raptor_killed() -> void:
	if yard_raptors.all(func(r: Raptor) -> bool: return r.dead):
		key.shine = true
		for s in tower_snipers:
			s.appear()


## Torres de guarda dos dois lados do portão do pátio, com um sniper fora de cena em cada (sobem depois da emboscada), e o
## cartão do painel do portão, que fica com o último deles.
func _build_towers() -> void:
	for at: Vector3 in Yard.TOWERS:
		var tw := GuardTower.new()
		tw.position = at
		add_child(tw)
		towers.append(tw)
		var s := Sniper.new()
		s.target = player
		s.perch = tw.perch()
		s.floor_y = tw.global_position.y + GuardTower.FLOOR_Y
		s.home_yaw = tw.facing_yaw()
		s.ledge = tw.ledge()
		s.position = tw.post()
		s.rotation.y = s.home_yaw
		add_child(s)
		s.lurk()
		s.killed.connect(_on_tower_sniper_killed)
		tower_snipers.append(s)
	gate_card = KeyItem.new()
	gate_card.id = Yard.GATE_KEY
	gate_card.kind = "keycard"
	gate_card.card_color = Color(0.45, 0.2, 0.07)
	gate_card.display_name = "CARTÃO DO PAINEL"
	gate_card.description = "Cartão do painel do portão da pedreira.\nNo verso: \"CÓDIGO = SUBJECT DO PROTÓTIPO\"."
	add_child(gate_card)


## Morreu um sniper das torres: o que sobrou fica com o cartão do painel e, quando morrer, cai da torre e o derruba.
func _on_tower_sniper_killed() -> void:
	var alive := tower_snipers.filter(func(s: Sniper) -> bool: return not s.dead)
	if alive.size() == 1:
		alive[0].loot = gate_card
		alive[0].falls = true


## Põe o inimigo no começo da rota, olhando para o próximo ponto, com a rota dele.
func _place(e: Enemy, post: Dictionary) -> void:
	e.target = player
	e.position = post.pos
	var first: Vector3 = post.route[1] - post.pos
	e.rotation.y = atan2(-first.x, -first.z)
	for p in post.route:
		e.route.append(p)
	add_child(e)


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	_post = rect
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	layer.add_child(rect)
	add_child(layer)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	_hud = layer
	# vida em barra no alto à esquerda e o sensor de perigo logo abaixo; radar no alto à direita (com a furtividade
	# embaixo dele: olho + VISIVEL/INVISIVEL e o estado dos inimigos); arma embaixo à direita
	_hud_health = HudBar.new("VIDA", 60.0)
	_hud_health.position = Vector2(6, 5)
	_hud_health.colors = [[0.25, UiStyle.DANGER], [0.5, UiStyle.ACCENT], [1.0, UiStyle.ACTION]]
	layer.add_child(_hud_health)
	_set_health(player.health)
	danger = DangerMeter.new()
	danger.player = player
	danger.position = Vector2(6, 15)
	layer.add_child(danger)
	radar = Radar.new()
	radar.player = player
	layer.add_child(radar)
	_weapon_icon = WeaponIcon.new()
	layer.add_child(_weapon_icon)
	_hud_weapon = _label(layer, "", Vector2.ZERO)
	_hud_weapon.add_theme_font_size_override("font_size", UiStyle.M)
	_hud_weapon.size.x = 40
	_hud_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# aviso de tiro na cabeça, logo abaixo da mira
	_hud_headshot = _label(layer, "HEADSHOT", Vector2.ZERO)
	_hud_headshot.add_theme_color_override("font_color", UiStyle.DANGER)
	_hud_headshot.visible = false
	# botões das ações possíveis embaixo, no centro: "<glifo> ABRIR PORTA", "<glifo> ABATE FURTIVO"
	_prompt = UiStyle.Hint.new()
	_prompt.visible = false
	layer.add_child(_prompt)
	_hud_notice = _label(layer, "", Vector2.ZERO)
	_hud_notice.add_theme_color_override("font_color", UiStyle.ACCENT)
	_hud_notice.visible = false
	# mira numa camada sem escala: ancorada no centro, a escala do HUD (apply_gfx) a jogaria para o canto
	var cross_layer := CanvasLayer.new()
	cross_layer.layer = 1
	add_child(cross_layer)
	_crosshair = Crosshair.new()
	_crosshair.player = player
	cross_layer.add_child(_crosshair)
	# no topo, logo abaixo da vida e do perigo: embaixo ficava por cima das pernas dela em telas 4:3
	_hud_help = _label(layer, HELP, Vector2(6, 26))
	_hud_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # quebra antes do radar (largura em _process)
	_hud_help.add_theme_constant_override("line_spacing", -4)  # linhas juntas: quebrada, não desce até o rosto dela
	# atordoada pelo rugido do alossauro: aviso piscando acima do centro
	_hud_daze = _label(layer, "ATORDOADA", Vector2.ZERO)
	_hud_daze.add_theme_color_override("font_color", UiStyle.ACCENT)
	_hud_daze.visible = false
	_end = _build_end(layer)
	add_child(layer)


## Tela de fim (o alossauro caiu) e de morte (game over): escurecimento avermelhado na morte, faixa escura no meio com o título, o tempo e os tiros, e como jogar de novo.
func _build_end(layer: CanvasLayer) -> Control:
	var box := Control.new()
	box.visible = false
	var shade := UiStyle.rect(box, UiStyle.DEATH_SHADE)
	shade.name = "Shade"
	shade.visible = false
	var band := UiStyle.rect(box, UiStyle.BAND)
	band.name = "Band"
	var title := UiStyle.label(box, "FIM", UiStyle.ACCENT, UiStyle.L, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	_end_stats = UiStyle.label(box, "", UiStyle.INK, UiStyle.S, HORIZONTAL_ALIGNMENT_CENTER)
	_end_hint = UiStyle.Hint.new()
	box.add_child(_end_hint)
	layer.add_child(box)
	return box


func _on_player_died() -> void:
	if ended or (_capture != "" and _shot != "game_over"):
		return
	_end_t = -1.0
	_game_over_t = GAME_OVER_DELAY


func show_end() -> void:
	if game_over or player.dead:
		return
	ended = true
	_end_t = -1.0
	var t := int(_play_t)
	(_end.get_node("Shade") as ColorRect).visible = false
	var title: Label = _end.get_node("Title")
	title.text = "FIM"
	title.add_theme_color_override("font_color", UiStyle.ACCENT)
	title.reset_size()
	_end_stats.text = "O ALOSSAURO CAIU\nTEMPO %02d:%02d   TIROS %d   VIDA %d" % [t / 60, t % 60, player.shots_fired, player.health]
	_end_hint.set_items([{"action": "reset", "text": "JOGAR DE NOVO"}])
	_end_stats.reset_size()
	_layout_overlays(get_viewport().get_visible_rect().size / _hud.scale)
	_end.visible = true


func show_game_over() -> void:
	if ended:
		return
	game_over = true
	_game_over_t = -1.0
	var t := int(_play_t)
	(_end.get_node("Shade") as ColorRect).visible = true
	var title: Label = _end.get_node("Title")
	title.text = "GAME OVER"
	title.add_theme_color_override("font_color", UiStyle.DANGER)
	title.reset_size()
	_end_stats.text = ("VOCÊ MORREU NA QUEDA" if player.death_cause == "fall" else "VOCÊ MORREU") + "\nTEMPO %02d:%02d   TIROS %d" % [t / 60, t % 60, player.shots_fired]
	# R no teclado; no controle o triângulo (RESTART_ACTIONS também aceita E, espaço, pular e atirar)
	_end_hint.set_items([{"action": "reset", "pad_action": "interact", "text": "RECOMEÇAR"}])
	_end_stats.reset_size()
	_layout_overlays(get_viewport().get_visible_rect().size / _hud.scale)
	_end.visible = true


## Centraliza a tela de fim/game over e o aviso de atordoada na área do HUD (320x240 ampliado, qualquer proporção).
func _layout_overlays(area: Vector2) -> void:
	_hud_daze.position = Vector2(roundf((area.x - _hud_daze.size.x) * 0.5), roundf(area.y * 0.32))
	var shade: ColorRect = _end.get_node("Shade")
	shade.size = area
	var band: ColorRect = _end.get_node("Band")
	band.position = Vector2(0, area.y * 0.5 - 46)
	band.size = Vector2(area.x, 104)
	var title: Label = _end.get_node("Title")
	title.position = Vector2(roundf((area.x - title.size.x) * 0.5), area.y * 0.5 - 42)
	_end_stats.position = Vector2(roundf((area.x - _end_stats.size.x) * 0.5), area.y * 0.5 - 8)
	_end_hint.position = Vector2(roundf((area.x - _end_hint.size.x) * 0.5), area.y * 0.5 + 32)


func _label(parent: Node, text: String, pos: Vector2) -> Label:
	var l := UiStyle.label(parent, text)
	l.position = pos
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo() and can_pause():
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if game_over:
			_restart_from_overlay()
	elif event.is_action_pressed("reset"):
		reset_all()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_G or event.physical_keycode == KEY_G):
		var sd: Soldier = soldiers[0] if not soldiers.is_empty() else null
		if sd:
			if sd.dead:
				sd.reset()
			sd.global_position = player.global_position - player.global_basis.z * 2.8
			sd.rotation.y = player.rotation.y + PI
			sd.reset_physics_interpolation()
			sd.die(-player.global_basis.z, sd.global_position + Vector3.UP * 1.2)
			show_notice("GUERRILHEIRO RAGDOLL (G para repetir)")
	elif game_over and _is_restart_event(event):
		_restart_from_overlay()
	elif event.is_action_pressed("toggle_help"):
		_hud_help.visible = not _hud_help.visible
	elif event.is_action_pressed("toggle_gfx"):
		apply_gfx("ps2" if Gfx.mode == "ps1" else "ps1")
	elif event.is_action_pressed("toggle_mode"):
		apply_mode(GameMode.ARCADE if GameMode.is_survival() else GameMode.SURVIVAL)


## Menu de pausa (ESC / START): não abre por cima de uma tela que já parou o jogo (inspeção) nem no game over,
## que tem o seu próprio recomeçar.
func can_pause() -> bool:
	return not get_tree().paused and not game_over and not inspect.busy


func _is_restart_event(event: InputEvent) -> bool:
	for a in RESTART_ACTIONS:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func _poll_restart() -> bool:
	for a in RESTART_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _restart_from_overlay() -> void:
	for a in RESTART_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)
	reset_all()
	player._roll_cd = 0.1
	player._shot_cd = 0.1


## Troca o perfil de jogo (ver GameMode) e reinicia: a jogadora volta ao começo com a munição do perfil novo.
func apply_mode(m: String) -> void:
	GameMode.set_mode(m)
	reset_all()
	show_notice("MODO " + ("SOBREVIVÊNCIA" if GameMode.is_survival() else "ARCADE"))


## Aviso rápido no centro, embaixo (munição pega, arma vazia, mudança de modo).
func show_notice(text: String) -> void:
	_hud_notice.text = text
	_notice_t = NOTICE_TIME


## Aplica o modo de visual (ver Gfx): materiais e luzes, resolução interna, pós-processo de PS1 e HUD.
func apply_gfx(m: String) -> void:
	Gfx.set_mode(m, self)
	get_window().content_scale_size = Gfx.RES[m]
	_post.visible = m == "ps1"
	# o HUD foi feito para 320x240: na resolução maior é ampliado para manter o tamanho na tela
	var k := float(Gfx.RES[m].y) / 240.0
	_hud.scale = Vector2(k, k)
	_crosshair.ui_scale = k
	if inspect:
		inspect.set_ui_scale(k)
	if pause_menu:
		pause_menu.set_ui_scale(k)
	if cutscene:
		cutscene.set_ui_scale(k)
	if sniper_scope:
		sniper_scope.set_ui_scale(k)


## Ela tentou abrir um baú trancado: o cadeado de perto; com a chave ele abre e a chave é gasta.
## Ela usou o teclado de uma porta trancada por código: o painel de perto; com a chave e o código certo, destranca
## (a chave é gasta) e o portão abre.
func _on_keypad(d: Door) -> void:
	if inspect.busy:
		return
	var ok := await inspect.keypad(d, player.has_key(d.lock))
	if ok:
		player.use_key(d.lock)
		d.unlock(player)


func _on_locked(c: Chest) -> void:
	if inspect.busy:
		return
	var has := player.has_key(c.lock)
	var id := c.lock
	await inspect.lock_zoom(c, has)
	if has:
		player.use_key(id)


func _set_health(v: int) -> void:
	_hud_health.value = float(v) / Player.MAX_HEALTH
	_hud_health.tail = str(maxi(v, 0))


## Arma na mão no canto de baixo à direita: o modelo dela (WeaponIcon; a pistola com silenciador tem o seu) e, no perfil
## de sobrevivência, a munição ao lado (vermelha quando está acabando).
func _update_weapon_hud(area: Vector2) -> void:
	var kind := player.weapon()
	_weapon_icon.show_weapon("pistol_sd" if kind == "pistol" and player.silencer else kind, player.model)
	_weapon_icon.position = Vector2(area.x - WeaponIcon.VIEW.x - 4, area.y - WeaponIcon.VIEW.y - 4)
	var text := ""
	var color := UiStyle.INK
	if GameMode.limited_ammo():
		var n := player.ammo_of(kind)
		text = str(n)
		if n <= LOW_AMMO:
			color = UiStyle.DANGER
	_hud_weapon.text = text
	_hud_weapon.add_theme_color_override("font_color", color)
	_hud_weapon.position = Vector2(_weapon_icon.position.x - _hud_weapon.size.x - 2, area.y - 4 - roundf((WeaponIcon.VIEW.y + _hud_weapon.size.y) * 0.5))


func reset_all() -> void:
	for g in get_tree().get_nodes_in_group("grenades"):
		g.queue_free()
	cutscene.stop()
	player.respawn()
	hatch.reset()
	lab.reset()
	for c in chests:
		c.reset()
	drop.reset()
	for d: Door in get_tree().get_nodes_in_group("doors"):
		d.reset()
	Fx.clear_decals()
	Blood.clear()
	for d in dummies:
		d.reset()
	key.reset()
	gate_card.reset()
	for i in tower_snipers.size():
		var s := tower_snipers[i]
		s.reset()
		s.global_position = towers[i].post()
		s.rotation.y = s.home_yaw
		s.reset_physics_interpolation()
		s.loot = null
		s.falls = false
		s.lurk()
	if is_instance_valid(keycard):
		keycard.reset()
	for r in raptors:
		r.reset()
	_lurk_yard_raptors()
	key.shine = false
	corpse.reset()
	for sd in soldiers:
		sd.reset()
	if is_instance_valid(sniper):
		sniper.reset()
		sniper.position = Vector3(-2.0, Catwalk.FLOOR_Y, 11.7)
		sniper.rotation.y = 0.0
	for pk: Pickup in get_tree().get_nodes_in_group("pickups"):
		pk.reset()
	allosaurus.reset()
	ended = false
	game_over = false
	_end_t = -1.0
	_game_over_t = -1.0
	_end.visible = false
	danger.reset()
	radar.reset()
	_notice_t = 0.0
	smelled = false
	_headshot_t = 0.0
	_t = 0.0
	_play_t = 0.0
	player.shots_fired = 0


# ------------------------------------------------------------------ captura de tela para revisão
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			# ferramenta de desenvolvimento: só em build de debug, só .png, sem caminho de rede
			var path := a.trim_prefix("--capture=")
			if OS.is_debug_build() and path.get_extension().to_lower() == "png" and not path.replace("\\", "/").begins_with("//"):
				_capture = path
			else:
				push_warning("--capture ignorado (só .png local em build de debug): " + path)
		elif a.begins_with("--shot="):
			_shot = a.get_slice("=", 1)
		elif a.begins_with("--at="):
			_until = float(a.get_slice("=", 1))
		elif a.begins_with("--mode="):
			var gm := a.get_slice("=", 1)
			if gm in GameMode.MODES:
				GameMode.set_mode(gm)
				player.reset_loadout()
		elif a.begins_with("--gfx="):
			var g := a.get_slice("=", 1)
			if g in Gfx.MODES:
				apply_gfx(g)
		elif a == "--playercam":
			_player_cam = true
		elif a == "--pad":
			UiStyle.pad = true  # captura com os glifos do controle
		elif a.begins_with("--yaw="):
			_yaw = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--pitch="):
			_pitch = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--dist="):
			_dist = float(a.get_slice("=", 1))
		elif a.begins_with("--creature="):
			_show.creature = a.get_slice("=", 1)
		elif a.begins_with("--anim="):
			_show.anim = a.get_slice("=", 1)
		elif a.begins_with("--move="):
			_show.move = maxi(["lugar", "circulo", "girando"].find(a.get_slice("=", 1)), 0)
		elif a.begins_with("--pos=") and OS.is_debug_build():
			# ferramenta de revisão: começa em x,z (e olhando para `graus`, 0 = para -Z; o 4º número = altura dos pés)
			var v := a.get_slice("=", 1).split(",")
			player.global_position = Vector3(float(v[0]), float(v[3]) if v.size() > 3 else 0.0, float(v[1]))
			player.rotation.y = deg_to_rad(float(v[2])) if v.size() > 2 else 0.0
			player.camera_rig.yaw = player.rotation.y
			player.reset_physics_interpolation()
	if _capture == "" and _shot == "idle":
		return
	_hud_help.visible = _shot == "idle"
	if _shot in COMPARE_SHOTS:
		_setup_idle_compare()
	elif _shot in ["danger", "danger_roll"]:
		# no meio do galpão, de frente para os guardas da porta do pátio (eles a veem e atiram): sensor de perigo e radar
		player.global_position = Vector3(1.0, 0, -6.0)
		player.rotation.y = PI * 0.5
		player.camera_rig.yaw = player.rotation.y
		player.reset_physics_interpolation()
		sniper.process_mode = Node.PROCESS_MODE_DISABLED
	elif _shot.begins_with("soldier") or _shot == "assassinate_soldier":
		_setup_soldier_shot()
	else:
		# nas outras capturas os guardas do galpão ficam parados (senão atiram na jogadora)
		for sd in soldiers:
			sd.process_mode = Node.PROCESS_MODE_DISABLED
	if _shot in ["ragdoll", "dummy"]:
		# o alvo de treino só existe nesta revisão (o galpão não tem mais bonecos)
		var t := TargetDummy.new()
		t.pose = "aim"
		t.position = Vector3(0, 0, -3)
		t.rotation.y = PI
		add_child(t)
		dummies.append(t)
	if _shot.begins_with("raptor_") or _shot in ["assassinate_raptor", "crit_raptor"]:
		_setup_raptor_shot()
	elif _shot.begins_with("allo_"):
		_setup_allo_shot()
	elif _shot == "arena":
		# da entrada da pedreira (logo depois do portão), olhando para dentro
		if not "--pos=" in " ".join(OS.get_cmdline_user_args()):
			player.global_position = Vector3(-60, 0, -3)
			player.rotation.y = PI * 0.5
			player.reset_physics_interpolation()
		player.camera_rig.yaw = player.rotation.y
		allosaurus.process_mode = Node.PROCESS_MODE_DISABLED
		for r in raptors:
			r.process_mode = Node.PROCESS_MODE_DISABLED
	elif _shot == "face":
		# close do rosto (--yaw gira em volta dela: 0 = de frente)
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 30.0
		add_child(_review_cam)
		_review_cam.current = true
	match _shot:
		"aim":
			Input.action_press("aim")
		"run":
			Input.action_press("move_forward")
		"crouch":
			Input.action_press("crouch")
	if _shot in MOVE_SHOTS:
		_setup_move_shot()
	if _shot in KEY_SHOTS:
		_setup_key_shot()
	if _shot in START_SHOTS:
		_setup_start_shot()
	if _shot in TOWER_SHOTS:
		_setup_tower_shot()


func _process(delta: float) -> void:
	if _crosshair == null:
		return
	var in_sniper := player.is_sniper_zoomed()
	_crosshair.update(delta, player.aiming and player.model.is_aimed() and not in_sniper)
	if sniper_scope:
		var aim_pt := player.camera_rig.aim_point([player.get_rid()])
		var dist := player.camera_rig.camera.global_position.distance_to(aim_pt)
		var aim_info: Dictionary = player.aim_target_info() if in_sniper else {}
		sniper_scope.update_scope(in_sniper, player.sniper_zoom_label(), dist, aim_info.get("blocked", false))
	if corpse.armed and not inspect.busy:
		corpse.check_notice()
	var target := player.pick_target()
	var key_node := player.pick_key() if target == null else null
	var drop_node := player.pick_drop() if target == null and key_node == null else null
	var plate := player.pick_plate() if target == null and key_node == null and drop_node == null else null
	var door := player.pick_door() if target == null and key_node == null and drop_node == null and plate == null else null
	var hatch_node := player.pick_hatch() if target == null and key_node == null and drop_node == null and plate == null and door == null else null
	var ladder := player.pick_ladder() if target == null and key_node == null and drop_node == null and plate == null and door == null and hatch_node == null else null
	var verb := ""
	if target and target.is_locked():
		# trancado: não diz o que tem dentro
		verb = "USAR CHAVE" if player.has_key(target.lock) else "ABRIR"
	elif target:
		verb = "PEGAR %s" % Player.WEAPON_STATS[target.item].name
	elif key_node:
		verb = "PEGAR %s" % key_node.display_name
	elif drop_node:
		verb = "ABRIR CAIXA"  # o que tem dentro é surpresa
	elif plate:
		verb = "VER PLACA"
	elif door:
		if door.is_locked() and door.code != "":
			verb = "USAR CHAVE NO PAINEL" if player.has_key(door.lock) else "PAINEL DO PORTÃO"
		elif door.is_locked():
			verb = "USAR CARTÃO DE ACESSO" if player.has_key(door.lock) else "LEITOR DE CARTÃO"
		else:
			verb = door.verb
	elif hatch_node:
		verb = "ABRIR ALÇAPÃO"
	elif ladder:
		var info: Dictionary = ladder.can_mount(player.global_position)
		verb = "DESCER ESCADA" if info.get("at_top", false) else "SUBIR ESCADA"
	# os botões possíveis lado a lado: pegar/abrir (E) e o abate furtivo / golpe crítico (atirar sem mirar)
	var actions := []
	if verb != "":
		actions.append({"action": "interact", "text": verb})
	var sp := player.stealth_prompt()
	if sp != "":
		actions.append({"action": "shoot", "text": sp})
	_prompt.set_items(actions)
	_prompt.visible = not actions.is_empty()
	# HUD ampliado (apply_gfx): arma embaixo à direita, radar em cima à direita e aviso embaixo no centro, em qualquer proporção
	var area := get_viewport().get_visible_rect().size / _hud.scale
	_update_weapon_hud(area)
	radar.position = Vector2(area.x - Radar.SIZE - 6, 6)
	_hud_help.size = Vector2(radar.position.x - 12, 0)
	radar.update(delta)
	danger.update(delta)
	_headshot_t = maxf(_headshot_t - delta, 0.0)
	_hud_headshot.visible = _headshot_t > 0.0
	_hud_headshot.position = Vector2(roundf((area.x - _hud_headshot.size.x) * 0.5), roundf(area.y * 0.5) + 10)
	_prompt.position = Vector2(roundf((area.x - _prompt.size.x) * 0.5), area.y - 34)
	if not smelled and not player.cutscene and not inspect.busy and Roof.near_yard(player.global_position):
		smelled = true
		inspect.show_message(Roof.SMELL_TEXT)
	_notice_t = maxf(_notice_t - delta, 0.0)
	_hud_notice.visible = _notice_t > 0.0
	_hud_notice.position = Vector2(roundf((area.x - _hud_notice.size.x) * 0.5), area.y - 50)
	# atordoada: o aviso pisca enquanto dura
	_hud_daze.visible = player.is_dazed() and fmod(_play_t, 0.5) < 0.32
	_layout_overlays(area)
	if not ended and not game_over and not player.dead:
		_play_t += delta
	if _end_t > 0.0:
		_end_t -= delta
		if _end_t <= 0.0:
			show_end()
	if _game_over_t > 0.0 and not player.grabbed:
		_game_over_t -= delta
		if _game_over_t <= 0.0:
			show_game_over()
	elif game_over and _poll_restart():
		_restart_from_overlay()
	elif ended and InputMap.has_action("reset") and Input.is_action_just_pressed("reset"):
		_restart_from_overlay()
	if _capture == "" and _shot == "idle":
		return
	var prev := _t
	_t += delta
	var at := func(sec: float) -> bool: return prev < sec and _t >= sec
	if not is_nan(_yaw) and (_shot != "ragdoll" or _t > 2.3):
		# ângulo fixo de câmera relativo à frente dela (0 = atrás, 180 = de frente)
		player.camera_rig.yaw = player.rotation.y + _yaw
		player.camera_rig.pitch = _pitch
	if _review_cam and _shot == "face":
		var a := player.rotation.y + PI + (0.0 if is_nan(_yaw) else _yaw)
		var head := player.global_position + Vector3.UP * 1.6
		_review_cam.global_position = head + Vector3(sin(a), 0.03, cos(a)) * 0.75
		_review_cam.look_at(head)
	elif _review_cam and (_shot.begins_with("raptor_") or _shot in ["assassinate_raptor", "crit_raptor"]):
		_raptor_shot(at)
	elif _shot.begins_with("allo_"):
		_allo_shot(at)
	if _shot.begins_with("soldier") or _shot == "assassinate_soldier":
		_soldier_shot(at)
	if _review_cam and _shot in COMPARE_SHOTS:
		var yaw := (0.0 if is_nan(_yaw) else _yaw)
		var c := (player.global_position + soldiers[0].global_position) * 0.5
		_review_cam.global_position = c + Vector3(sin(yaw), 0.0, cos(yaw)) * 3.2 + Vector3.UP * 1.3
		_review_cam.look_at(c + Vector3.UP * 1.0)
	if _shot in MOVE_SHOTS:
		_move_shot(at)
	match _shot:
		"aim":
			# reaplica: o Godot solta ações pressionadas se a janela perde o foco
			Input.action_press("aim")
		"run":
			Input.action_press("move_forward")
		"crouch":
			if at.call(0.05):
				Input.action_release("crouch")
		"danger_roll":
			# a barra no alto (os guardas já atirando): rola (cai depressa) e volta a subir no fim da esquiva
			if at.call(2.6):
				Input.action_press("roll")
			if at.call(2.65):
				Input.action_release("roll")
		"roll":
			if at.call(0.4):
				Input.action_press("roll")
			if at.call(0.45):
				Input.action_release("roll")
		"pause":
			if at.call(0.5):
				pause_menu.on_shown = _save_and_quit
				pause_menu.open()
		"showroom":
			if at.call(0.3):
				pause_menu.open()
				pause_menu._set_visible(false)
				var room := pause_menu.showroom
				room.open(_show.creature if _show.creature in Showroom.CREATURES else "raptor", _show.anim, _show.move)
				if not is_nan(_yaw):
					room.yaw = _yaw
				# o jogo fica pausado (o _t daqui para): espera o --at no relógio que roda na pausa
				await get_tree().create_timer(maxf(_until - 0.3, 0.2), true).timeout
				_save_and_quit()
		"game_over":
			if at.call(0.1):
				player.take_hit(999, player.global_basis.z, player.global_position + Vector3.UP * 1.2)
				player.camera_rig.yaw = PI * 0.75
				player.camera_rig.pitch = -0.6
				_game_over_t = 0.4
			if _t > 0.1:
				player.camera_rig.camera.fov = 34.0
		"ragdoll", "dummy":
			if at.call(0.3):
				Input.action_press("aim")
			if _t > 0.5 and _t < 2.0:
				player.camera_rig.look_at_point(dummies[0].global_position + Vector3.UP * 1.2)
			for k in 3:
				if at.call(0.9 + k * 0.35):
					player.fire()
			if at.call(2.1):
				Input.action_release("aim")
				if _shot == "ragdoll":
					player.take_hit(999, player.global_basis.z, player.global_position + Vector3.UP * 1.2)
					player.camera_rig.yaw = PI * 0.75
					player.camera_rig.pitch = -0.6
			if _t > 2.1:
				player.camera_rig.camera.fov = 34.0
				if _shot == "dummy" and at.call(2.4):
					# chega perto para ver o alvo caído
					player.global_position = Vector3(2.0, 0, -1.0)
					player.reset_physics_interpolation()
					player.model.visible = false
				if _shot == "dummy" and _t > 2.5:
					player.camera_rig.look_at_point(dummies[0].model.ragdoll.bodies["Hips"].global_position)
	if _shot in KEY_SHOTS:
		_key_shot(at)
	if _shot in START_SHOTS:
		_start_shot(at)
	if _shot in TOWER_SHOTS:
		_tower_shot(at)
	if _capture != "" and _t >= _until:
		_save_and_quit()


## Revisão do começo da fase: põe a jogadora no lugar de cada parte (o telhado já é o começo).
func _setup_start_shot() -> void:
	if _shot != "sniper_ladder":
		sniper.process_mode = Node.PROCESS_MODE_DISABLED
	var spot := func(at: Vector3, yaw: float) -> void:
		player.global_position = at
		player.rotation.y = yaw
		player.reset_physics_interpolation()
		player.camera_rig.yaw = yaw
	match _shot:
		"hatch", "ladder_mount", "ladder_out":
			if _shot != "hatch":
				hatch.open(0.01)
			spot.call(hatch.kneel_point(), atan2(-hatch.facing().x, -hatch.facing().z))
			if _shot == "ladder_out":
				# no alto da escada: subindo, sai pela beirada do alçapão (LadderOut)
				player.moves.start_ladder(hatch.ladder, true)
			_review_cam = Camera3D.new()
			_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			_review_cam.fov = 50.0
			add_child(_review_cam)
			_review_cam.current = not _player_cam
		"ladder_roof", "sniper_ladder":
			hatch.open(0.01)
			player.moves.start_ladder(hatch.ladder, true)
			if _shot == "sniper_ladder":
				# passou dos degraus escondidos do alto: à vista do mezanino
				player.moves._ladder_y = player.moves._ladder_top_y() - hatch.ladder.hidden_top - 0.1
				player.moves._update_ladder_pos()
				# o sniper no fim do mezanino, virado para o canto da escada
				sniper.global_position = Vector3(1.0, Catwalk.FLOOR_Y, 11.7)
				sniper.rotation.y = -PI * 0.5
				sniper.route.clear()
				sniper.reset_physics_interpolation()
				_review_cam = Camera3D.new()
				_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
				_review_cam.fov = 60.0
				add_child(_review_cam)
				_review_cam.current = not _player_cam
		"maze":
			# no pé da escada do telhado, olhando para o labirinto (oeste)
			spot.call(hatch.ladder.bottom_pos + hatch.ladder.ladder_out * 0.45, PI * 0.5)
		"gate":
			spot.call(Vector3(0, CloneLab.FLOOR_Y, -11.4), 0.0)
		"smell":
			# andando até a beira do telhado do lado do pátio (a câmera já atrás dela): salva quando a mensagem aparece
			spot.call(Vector3(-Roof.EDGE + Roof.SMELL_DIST + 1.5, Roof.Y, Yard.DOOR_Z + 1.5), PI * 0.5)
			Input.action_press("move_forward")
			if _capture != "":
				inspect.on_shown = _save_and_quit
		"lab", "clones":
			lab.gate.open()
			lab.played = _shot == "lab"
			spot.call(Vector3(0, CloneLab.FLOOR_Y, CloneLab.ENTER_Z - (0.4 if _shot == "lab" else 0.2)), 0.0)
		"drop", "drop_get", "drop_pick":
			# na frente da caixa, olhando para ela (drop_get/drop_pick: no lugar de ajoelhar)
			var fwd := drop.global_basis.z
			spot.call(drop.front_point() + fwd * (_dist if _shot == "drop" else 0.0), drop.rotation.y)
			if _shot == "drop_get" and _capture != "":
				inspect.on_shown = _save_and_quit
			if _shot == "drop_pick":
				_review_cam = Camera3D.new()
				_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
				_review_cam.fov = 45.0
				add_child(_review_cam)
				_review_cam.current = not _player_cam
		"fire_sd":
			# no teto dos clones, de frente para a mureta do fundo, com a pistola com silenciador
			player.silencer = true
			spot.call(Vector3(2.0, Roof.LAB_Y, -22.0), 0.3)
		"tank", "plate", "plate_allo":
			# dentro da sala dos clones (cena do choque já vista): o tanque vazio, uma plaqueta
			lab.gate.open()
			lab.played = true
			if _shot == "tank":
				var at := Vector3(-0.3, CloneLab.FLOOR_Y, -25.0)
				var to := CloneLab.TANK - at
				spot.call(at, atan2(-to.x, -to.z))
			else:
				var pl: SubjectPlate = lab.plates[-1 if _shot == "plate_allo" else 0]
				spot.call(pl.global_transform * Vector3(0, 0, 0.8), pl.global_rotation.y)
			if _shot != "tank" and _capture != "":
				inspect.on_shown = _save_and_quit
		"keypad", "keypad_on", "keypad_ok", "gate_open":
			# na frente do teclado do portão da pedreira (keypad: sem a chave; keypad_on: com ela, digitando; keypad_ok: o
			# código certo; gate_open: depois de aceito, o portão abrindo — --at escolhe o quadro)
			var gate := _code_door()
			spot.call(gate.global_position + Vector3(1.2, 0, Yard.GATE_GAP * 0.5 - 0.2), PI * 0.5)
			if _shot != "keypad":
				player.add_key(Yard.GATE_KEY)
			if _shot in ["keypad_ok", "gate_open"]:
				inspect.auto_code = CloneLab.ALLO_SUBJECT
			if _shot == "gate_open":
				inspect.auto_close = 0.0
			elif _capture != "":
				inspect.on_shown = _save_and_quit


## A porta trancada por código (o portão da pedreira).
func _code_door() -> Door:
	for d: Door in get_tree().get_nodes_in_group("doors"):
		if d.code != "":
			return d
	return null


func _start_shot(at: Callable) -> void:
	match _shot:
		"hatch", "ladder_mount", "ladder_out":
			var key := "move_forward" if _shot == "ladder_out" else "interact"
			if at.call(0.2):
				Input.action_press(key)
			if at.call(0.25):
				Input.action_release(key)
			if _review_cam:
				# de lado e um pouco na frente dela (--yaw gira em volta do alçapão)
				var a := deg_to_rad(-70.0) if is_nan(_yaw) else _yaw
				var mid := hatch.kneel_point().lerp(hatch.ladder.top_pos, 0.5) + Vector3.UP * 0.6
				_review_cam.global_position = mid + Vector3(sin(a), 0.0, -cos(a)) * 2.6 + Vector3.UP * 0.5
				_review_cam.look_at(mid)
		"ladder_roof":
			# só na captura (que fecha o jogo no fim); jogando com --shot o direcional fica com quem joga
			if _t > 0.3 and _capture != "":
				Input.action_press("move_back")
		"drop_get", "drop_pick":
			if at.call(0.3):
				Input.action_press("interact")
			if at.call(0.35):
				Input.action_release("interact")
			if _review_cam:
				# de lado, entre ela e a caixa (--yaw gira em volta)
				var a := drop.rotation.y + (deg_to_rad(80.0) if is_nan(_yaw) else _yaw)
				var mid := drop.front_point().lerp(drop.global_position, 0.5) + Vector3.UP * 0.55
				_review_cam.global_position = mid + Vector3(sin(a), 0.0, cos(a)) * 2.2 + Vector3.UP * 0.4
				_review_cam.look_at(mid)
		"plate", "plate_allo", "keypad", "keypad_on", "keypad_ok", "gate_open":
			if at.call(0.3):
				Input.action_press("interact")
			if at.call(0.35):
				Input.action_release("interact")
		"fire_sd":
			Input.action_press("aim")
			if at.call(0.8):
				player.fire()
		"sniper_ladder":
			if at.call(0.2):
				sniper.spot()
			if _review_cam:
				# no corredor do labirinto ao lado do pé da escada, olhando para cima
				_review_cam.fov = 78.0
				_review_cam.global_position = Vector3(8.4, 1.2, 12.2)
				_review_cam.look_at(Vector3(11.6, 1.9, 12.4))


## Revisão das torres de guarda: os raptors do pátio já mortos (os snipers sobem), ela na estrada olhando para o portão.
## tower_fall/gate_card: um sniper já morto e o último cai da torre em 0,5 s; gate_card ainda vai até o cartão e o pega.
func _setup_tower_shot() -> void:
	corpse.armed = false
	for r in yard_raptors:
		r.lurking = false
		r.take_hit(999, Vector3.FORWARD, r.global_position)
	player.global_position = Vector3(-43.0, 0, -4.0)
	player.rotation.y = PI * 0.5
	player.reset_physics_interpolation()
	player.camera_rig.yaw = player.rotation.y
	player.camera_rig.pitch = 0.12
	for s in tower_snipers:
		s.sight_range = 0.0  # calmos na revisão (senão atiram nela)
	if _shot != "towers":
		tower_snipers[1].take_hit(999, Vector3.RIGHT, tower_snipers[1].global_position + Vector3.UP * 1.3)
	if _shot == "tower_fall":
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 55.0
		add_child(_review_cam)
		_review_cam.current = not _player_cam
	if _shot == "gate_card" and _capture != "":
		inspect.on_shown = _save_and_quit


func _tower_shot(at: Callable) -> void:
	var last := tower_snipers[0]
	if _shot != "towers" and at.call(0.5):
		# tiro de frente (empurra para trás, para dentro da torre): mesmo assim ele tomba para o pátio
		last.take_hit(999, Vector3.LEFT, last.global_position + Vector3.UP * 1.3)
	if _review_cam:
		# de lado, olhando a frente da torre (--yaw gira em volta dela)
		var tw := towers[0]
		var a := deg_to_rad(80.0) if is_nan(_yaw) else _yaw
		var mid := tw.ledge() + Vector3(1.3, -2.6, 0)
		_review_cam.global_position = mid + Vector3(cos(a), 0.0, sin(a)) * 7.5 + Vector3.UP * 0.6
		_review_cam.fov = 70.0
		_review_cam.look_at(mid)
	if _shot == "gate_card" and gate_card.state == "dropped" and not inspect.busy and not player.has_key(Yard.GATE_KEY):
		if player.global_position.distance_to(gate_card.global_position) > 0.6:
			player.global_position = gate_card.global_position + Vector3(0.4, 0, 0)
			player.reset_physics_interpolation()
			Input.action_press("interact")
		else:
			Input.action_release("interact")


## Revisão do container trancado, da chave e da M79: põe a jogadora no lugar e aperta os botões na hora certa. As telas
## de inspeção pausam o jogo (e o relógio da captura): a captura é salva quando a tela termina de aparecer.
func _setup_key_shot() -> void:
	var front := locker.kneel_transform().origin + locker.global_basis.z * 0.5
	var spots := {
		"locked": [front, locker.rotation.y], "unlock": [front, locker.rotation.y], "pickup_m79": [front, locker.rotation.y],
		# do lado da mão da chave, olhando para o morto (key_get: os raptors do pátio já mortos, a chave brilhando)
		"corpse": [corpse.global_position + Vector3(8.0, 0, -6.0), PI * 0.5],
		"key_get": [corpse.stand_point() + Vector3(1.8, 0, 0), PI * 0.5],
		# vindo pela estrada, a uns 6 m do morto: entra na cena da emboscada
		"ambush": [corpse.stand_point() + Vector3(5.8, 0, -2.0), PI * 0.4],
		# de frente para o fundo do galpão: a granada cai no chão a ~7 m
		"fire_m79": [Vector3(-1.0, 0, 5.0), 0.0], "m79_aim": [Vector3(-2.4, 0, 1.6), 0.0],
	}
	player.global_position = spots[_shot][0]
	player.rotation.y = spots[_shot][1]
	if _shot == "ambush":
		var to := corpse.global_position - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
	player.reset_physics_interpolation()
	player.camera_rig.yaw = player.rotation.y
	if _shot in ["locked", "unlock", "key_get"] and _capture != "":
		inspect.on_shown = _save_and_quit
	if _shot in ["corpse", "key_get"]:
		corpse.armed = false
		player.model.visible = _shot == "key_get"
		if _shot == "key_get":
			for r in yard_raptors:
				r.lurking = false
				r.take_hit(999, Vector3.FORWARD, r.global_position)
		# câmera de revisão em volta do morto (--yaw gira; --playercam usa a dela)
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 45.0
		add_child(_review_cam)
		_review_cam.current = not _player_cam
	if _shot == "unlock":
		player.add_key(locker.lock)
	if _shot == "pickup_m79":
		locker.unlock()
	if _shot in ["m79_aim", "fire_m79"]:
		for d in dummies:
			d.visible = false
		player.give_weapon("m79")


func _key_shot(at: Callable) -> void:
	match _shot:
		"locked", "unlock", "pickup_m79":
			if at.call(0.3):
				Input.action_press("interact")
			if at.call(0.35):
				Input.action_release("interact")
		"corpse", "key_get":
			if _review_cam:
				var a := corpse.rotation.y + (deg_to_rad(60.0) if is_nan(_yaw) else _yaw)
				var mid := corpse.bone_point("Spine")
				_review_cam.global_position = mid + Vector3(sin(a), 0.0, cos(a)) * 2.6 + Vector3.UP * 1.7
				_review_cam.look_at(mid)
			if _shot == "key_get" and at.call(1.2):
				player.global_position = key.global_position + Vector3(0.3, 0, 0.3)
				player.reset_physics_interpolation()
			if _shot == "key_get" and at.call(1.3):
				Input.action_press("interact")
			if _shot == "key_get" and at.call(1.35):
				Input.action_release("interact")
		"ambush":
			# anda até o morto; a cena começa sozinha ao chegar perto
			if not cutscene.busy and not corpse.armed:
				Input.action_release("move_forward")
			elif corpse.armed:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
		"m79_aim":
			Input.action_press("aim")
		"fire_m79":
			Input.action_press("aim")
			if _t < 0.6:
				player.camera_rig.look_at_point(Vector3(-1.0, 0.0, -2.0))
			if at.call(0.6):
				player.fire()


## Revisão dos movimentos novos: põe a jogadora na frente do obstáculo/baú e aperta os botões na hora certa.
func _setup_move_shot() -> void:
	for d in dummies:
		d.visible = false
	var spots := {
		"hang": [Vector3(-2.5, 0, -0.35), 0.0], "climb": [Vector3(-2.5, 0, -0.35), 0.0],
		"mantle": [Vector3(0, 0, -9.95), 0.0], "pickup": [chest.kneel_transform().origin + chest.global_basis.z * 0.5, chest.rotation.y],
		"pickup_shotgun": [chests[1].kneel_transform().origin + chests[1].global_basis.z * 0.5, chests[1].rotation.y],
		# de frente para a pilha de caixas de madeira, com a coluna de metal à esquerda
		"fire_pistol": [Vector3(-2.4, 0, 1.6), 0.0], "fire_m16": [Vector3(-2.4, 0, 1.6), 0.0],
		"fire_shotgun": [Vector3(-2.4, 0, 1.6), 0.0], "pump": [Vector3(-2.4, 0, 1.6), 0.0],
		# golpes, no meio do telhado (aberto), empurrada para +Z
		"hit_crouch": [Vector3(0, Roof.Y, 0), 0.0], "stagger": [Vector3(0, Roof.Y, 0), 0.0],
		"getup": [Vector3(0, Roof.Y, -2.0), 0.0], "getup_fwd": [Vector3(0, Roof.Y, -2.0), PI],
	}
	if _shot in spots:
		player.global_position = spots[_shot][0]
		player.rotation.y = spots[_shot][1]
		player.reset_physics_interpolation()
		player.camera_rig.yaw = player.rotation.y
	if _shot.begins_with("rifle") or _shot == "fire_m16":
		player.give_weapon("m16")
	if _shot.begins_with("shotgun") or _shot in ["fire_shotgun", "pump"]:
		player.give_weapon("shotgun")
	if _shot.begins_with("sniper"):
		player.give_weapon("sniper")
	if _shot == "pump" or _shot in HURT_SHOTS:
		# pump: de lado, perto das mãos, para ver a telha indo e voltando; golpes: de lado, seguindo o corpo
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 40.0
		add_child(_review_cam)
		_review_cam.current = true


func _move_shot(at: Callable) -> void:
	var tap := func(action: String, sec: float) -> void:
		if at.call(sec):
			Input.action_press(action)
		if at.call(sec + 0.05):
			Input.action_release(action)
	match _shot:
		"walk":
			Input.action_press("walk")
			Input.action_press("walk_slow")
			Input.action_press("move_forward")
		"crouch_walk", "crouch_aim":
			tap.call("crouch", 0.05)
			if _t > 0.3:
				Input.action_press("move_forward" if _shot == "crouch_walk" else "move_left")
			if _shot == "crouch_aim":
				Input.action_press("aim")
		"jump", "hang", "mantle":
			tap.call("jump", 0.4)
		"climb":
			tap.call("jump", 0.4)
			tap.call("jump", 1.2)
		"pickup", "pickup_shotgun":
			tap.call("interact", 0.3)
		"dodge_l", "dodge_r", "dodge_back":
			# pulinho do survival (com --mode=arcade vira cambalhota); --at escolhe o quadro
			var side: String = {"dodge_l": "move_left", "dodge_r": "move_right"}.get(_shot, "")
			if side and at.call(0.35):
				Input.action_press(side)
			tap.call("roll", 0.4)
			if side and at.call(0.5):
				Input.action_release(side)
		"dodge_roll":
			# clique duplo no X: cambalhota
			tap.call("roll", 0.4)
			tap.call("roll", 0.5)
		"hit_crouch":
			# agachada leva tiro pela frente e depois pela direita (a reação soma por cima, sem ficar em pé)
			tap.call("crouch", 0.05)
			if at.call(0.6):
				player.take_hit(10, Vector3.BACK, player.global_position + Vector3.UP)
			if at.call(1.2):
				player.take_hit(10, Vector3.LEFT, player.global_position + Vector3.UP)
		"stagger":
			if at.call(0.4):
				player.knockback(Vector3(0, 0, 4))
		"getup":
			# desaba para trás (cai de costas: GetUpBack)
			if at.call(0.3):
				player.knock_down(Vector3(0, 0, 1))
		"getup_fwd":
			# arremessada pelas costas (cai de bruços: GetUpFront)
			if at.call(0.3):
				player.launch(Vector3(0, 3, 4.5), player.global_position + Vector3.UP)
		"rifle_aim", "shotgun_aim", "sniper_aim":
			Input.action_press("aim")
		"sniper_zoom":
			Input.action_press("aim")
			if at.call(0.1):
				player.zoom_in()
			if at.call(0.2):
				player.zoom_in()
		"fire_pistol", "fire_m16", "fire_shotgun", "pump":
			Input.action_press("aim")
			var gap: float = {"fire_pistol": 0.3, "fire_m16": 0.12, "fire_shotgun": 0.85, "pump": 9.0}[_shot]
			var n: int = {"fire_pistol": 6, "fire_m16": 12, "fire_shotgun": 3, "pump": 1}[_shot]
			if _t < 0.6 + gap * n:
				# pistola: tiros espalhados pela caixa (a mira anda antes do próximo); os outros, no mesmo ponto
				# (a dispersão é da arma)
				var spread := (player.shots_fired - 2.5) * 0.05 if _shot == "fire_pistol" else 0.0
				# mira na face da caixa de baixo da pilha
				player.camera_rig.look_at_point(Vector3(-2.5, 0.7, -0.9))
				player.camera_rig.yaw += spread + (0.0 if is_nan(_yaw) else _yaw)
			for k in n:
				if at.call(0.6 + k * gap):
					player.fire()
			if _shot == "pump":
				var right := player.global_basis.x
				var hands := player.global_position + Vector3.UP * 1.35 - player.global_basis.z * 0.35
				_review_cam.global_position = hands + right * 1.1 + Vector3.UP * 0.1 - player.global_basis.z * 0.2
				_review_cam.look_at(hands)
	if _shot in HURT_SHOTS:
		# câmera fixa no mundo, de lado (+X; --yaw gira em volta), olhando o quadril (do ragdoll, se caída)
		var hips := player.camera_focus() + Vector3.UP * 0.75
		var a := PI * 0.5 + (0.0 if is_nan(_yaw) else _yaw - PI * 0.5)
		_review_cam.global_position = hips + Vector3(sin(a), 0.0, cos(a)) * 3.4 + Vector3.UP * 0.6
		_review_cam.look_at(hips)


## Revisão do soldado: de frente para ela, a 4 m (soldier = ele a vê e atira; soldier_dead = leva um tiro e cai;
## soldier_headshot = ela acerta a cabeça dele; soldier_wounded = ferido, luta e deixa rastro de sangue).
func _setup_soldier_shot() -> void:
	for d in dummies:
		d.visible = false
	var sd := soldiers[0]
	sd.route.clear()
	for other in soldiers.slice(1):
		other.process_mode = Node.PROCESS_MODE_DISABLED
	if _shot == "soldier_idle":
		sd.sight_range = 0.0
		sd.target = null
		sd.model.holstered = true
	sd.global_position = player.global_position + Vector3(0, 0, -1.6 if _shot == "assassinate_soldier" else -4.0)
	sd.rotation.y = 0.0 if _shot == "assassinate_soldier" else PI
	sd.reset_physics_interpolation()
	# câmera de revisão perto dele (--yaw gira em volta: 0 = de frente); --playercam usa a dela
	if not _player_cam:
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 45.0
		add_child(_review_cam)
		_review_cam.current = true


func _soldier_shot(at: Callable) -> void:
	var sd := soldiers[0]
	if _shot == "assassinate_soldier":
		if at.call(0.3):
			player.fire()
	elif _shot == "soldier_headshot":
		if at.call(0.1):
			Input.action_press("aim")
		if _t < 0.6 and not sd.dead:
			player.camera_rig.look_at_point(sd.model.ragdoll.bodies["Head"].global_position)
		if at.call(0.6):
			player.fire()
	elif at.call(0.1):
		if _shot == "soldier_dead":
			sd.take_hit(999, Vector3.BACK, sd.global_position + Vector3.UP)
		elif _shot == "soldier_wounded":
			player.health = 1000  # só para a revisão: ela aguenta os tiros dele enquanto ele anda sangrando
			sd.take_hit(45, Vector3.BACK, sd.global_position + Vector3.UP * 1.2)
		elif _shot == "soldier_idle":
			pass
		else:
			sd.spot()
	if _review_cam:
		var body: Vector3 = sd.model.ragdoll.bodies["Hips"].global_position * Vector3(1, 0, 1) if sd.dead else sd.global_position
		var a := sd.rotation.y + PI + (0.0 if is_nan(_yaw) else _yaw)
		var is_idle := _shot == "soldier_idle"
		_review_cam.fov = 30.0 if is_idle else 45.0
		var dist := 2.2 if is_idle else (2.6 if not sd.dead else 2.2)
		var cam_y := 1.38 if is_idle else (1.45 if not sd.dead else 1.45)
		var target_y := 1.28 if is_idle else (1.05 if not sd.dead else 0.2)
		_review_cam.global_position = body + Vector3(sin(a), 0.0, cos(a)) * dist + Vector3.UP * cam_y
		_review_cam.look_at(body + Vector3.UP * target_y)


## Revisão do raptor: posiciona os dois, liga uma câmera própria e força o estado pedido.

func _setup_idle_compare() -> void:
	for d in dummies:
		d.visible = false
	var sd := soldiers[0]
	sd.route.clear()
	sd.sight_range = 0.0
	sd.target = null
	for other in soldiers.slice(1):
		other.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(-0.65, 0.0, 0.0)
	player.rotation.y = PI
	player.reset_physics_interpolation()
	sd.global_position = Vector3(0.65, 0.0, 0.0)
	sd.rotation.y = PI
	sd.reset_physics_interpolation()
	var armed := _shot != "idle_compare"
	for m: HeroineModel in [player.model, sd.model]:
		m.holster(not armed)
		if armed:
			m.set_weapon("m16")
	if armed:
		# os dois parados ou andando no lugar: sem física, controle nem IA, só o corpo tocando a pose
		for body: Node in [player, sd]:
			body.process_mode = Node.PROCESS_MODE_DISABLED
			body.model.process_mode = Node.PROCESS_MODE_ALWAYS
			body.model.set_state("walk" if _shot == "walk_compare" else "idle")
	_review_cam = Camera3D.new()
	_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_review_cam.fov = 34.0
	add_child(_review_cam)
	_review_cam.current = true


func _setup_raptor_shot() -> void:
	var r := raptors[0]
	for d in dummies:
		d.visible = false
	# só este raptor entra na cena de revisão, parado no lugar (sem patrulha)
	r.route.clear()
	for other in raptors.slice(1):
		other.process_mode = Node.PROCESS_MODE_DISABLED
	# corredor livre no fundo do galpão (z = 9), ele olhando para +X, ela à frente/atrás dele
	r.global_position = Vector3(-4, 0, 9)
	r.rotation.y = -PI * 0.5
	var fwd := Vector3.RIGHT
	var her := {
		"bite": fwd * 1.7, "tail": -fwd * 1.6 - Vector3.BACK * 1.0, "leap": fwd * 7.0,
		"charge": fwd * 8.0, "idle": fwd * 15.0, "assassinate_raptor": -fwd * 1.6, "crit_raptor": -fwd * 1.6,
	}
	player.global_position = r.global_position + her.get(_shot.trim_prefix("raptor_"), fwd * 4.0)
	player.rotation.y = -PI * 0.5 if _shot in ["assassinate_raptor", "crit_raptor"] else PI * 0.5
	player.reset_physics_interpolation()
	r.reset_physics_interpolation()
	player.camera_rig.yaw = 0.0
	_review_cam = Camera3D.new()
	_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_review_cam.fov = 55.0
	add_child(_review_cam)
	_review_cam.current = not _player_cam


func _raptor_shot(at: Callable) -> void:
	var r := raptors[0]
	if _shot == "assassinate_raptor" and at.call(0.3):
		player.fire()
	elif _shot == "crit_raptor":
		if at.call(0.2) or at.call(1.0):
			player.fire()
	elif at.call(0.15):
		match _shot:
			"raptor_roar": r.start_roar()
			"raptor_study": r.start_study()
			"raptor_bite": r.start_bite()
			"raptor_tail": r.start_tail()
			"raptor_leap": r.start_leap()
			"raptor_charge": r.start_charge()
			"raptor_dead": r.take_hit(999, Vector3.FORWARD, r.global_position)
			"raptor_blood": Input.action_press("aim")
	if _shot == "raptor_blood":
		# tiros de pistola no tronco até cair (esguicho, respingos, poça)
		if not r.dead and _t < 3.5:
			player.camera_rig.look_at_point(r.model.ragdoll.bodies["Chest"].global_position)
		for k in 5:
			if at.call(0.7 + k * 0.35) and not r.dead:
				player.fire()
	if _player_cam:
		# um pouco de lado: atrás dela, em linha reta, o corpo dela tapa o raptor
		player.camera_rig.yaw = player.rotation.y + (0.6 if is_nan(_yaw) else _yaw)
		return
	var vp := get_viewport().get_visible_rect().size
	_review_cam.keep_aspect = Camera3D.KEEP_WIDTH if vp.y > vp.x else Camera3D.KEEP_HEIGHT
	# segue os corpos de verdade (ragdoll dela arremessada, ragdoll dele morto), não as cápsulas
	var her := player.camera_focus()
	var him: Vector3 = r.model.ragdoll.bodies["Hips"].global_position * Vector3(1, 0, 1) if r.dead else r.global_position
	var mid := him.lerp(her, 0.5)
	var dist := 3.0 + 0.45 * him.distance_to(her)
	var yaw := deg_to_rad(160.0) if is_nan(_yaw) else _yaw
	_review_cam.global_position = mid + Vector3(sin(yaw), 0.0, cos(yaw)) * dist + Vector3.UP * 1.3
	_review_cam.look_at(mid + Vector3.UP * 0.8)


## Revisão do alossauro: no meio da pedreira, ele olhando para +X, ela à frente na distância de cada golpe.
func _setup_allo_shot() -> void:
	var a := allosaurus
	a.route.clear()
	for r in raptors:
		r.process_mode = Node.PROCESS_MODE_DISABLED
	a.global_position = Vector3(-80, 0, -3)
	a.rotation.y = -PI * 0.5
	var fwd := Vector3.RIGHT
	var left := Vector3.FORWARD  # olhando para +X, a esquerda dele é -Z
	var her := {
		"stomp": fwd * 2.6, "bite": fwd * 4.2, "roar": fwd * 9.0, "roar_at": fwd * 7.0, "idle": fwd * 14.0,
		"headbutt": fwd * 2.2 + left * 2.2, "tail": -fwd * 4.5 + left * 1.5, "dead": fwd * 8.0, "end": fwd * 8.0,
	}
	player.global_position = a.global_position + her.get(_shot.trim_prefix("allo_"), fwd * 8.0)
	player.rotation.y = PI * 0.5
	player.reset_physics_interpolation()
	a.reset_physics_interpolation()
	player.camera_rig.yaw = 0.0
	_review_cam = Camera3D.new()
	_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_review_cam.fov = 55.0
	add_child(_review_cam)
	_review_cam.current = not _player_cam


func _allo_shot(at: Callable) -> void:
	var a := allosaurus
	if at.call(0.15):
		match _shot:
			"allo_roar": a.start_roar()
			"allo_roar_at": a.start_roar_at()
			"allo_headbutt": a.start_headbutt()
			"allo_tail": a.start_tail()
			"allo_stomp": a.start_stomp()
			"allo_bite": a.start_bite()
			"allo_dead", "allo_end": a.take_hit(9999, Vector3.FORWARD, a.global_position + Vector3.UP * 2.5)
	if _shot == "allo_end" and at.call(0.2):
		_end_t = 0.3  # na revisão a tela de fim não espera o corpo cair
	if _player_cam:
		player.camera_rig.yaw = player.rotation.y + (0.6 if is_nan(_yaw) else _yaw)
		return
	var vp := get_viewport().get_visible_rect().size
	_review_cam.keep_aspect = Camera3D.KEEP_WIDTH if vp.y > vp.x else Camera3D.KEEP_HEIGHT
	var her := player.camera_focus()
	var him: Vector3 = a.model.ragdoll.bodies["Hips"].global_position * Vector3(1, 0, 1) if a.dead else a.global_position - a.global_basis.z * 1.2
	var mid := him.lerp(her, 0.4)
	var dist := 8.0 + 0.4 * him.distance_to(her)
	var yaw := deg_to_rad(155.0) if is_nan(_yaw) else _yaw
	_review_cam.global_position = mid + Vector3(sin(yaw), 0.0, cos(yaw)) * dist + Vector3.UP * 2.6
	_review_cam.look_at(mid + Vector3.UP * 1.6)


func _save_and_quit() -> void:
	if _saving:
		return
	_saving = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture)
	print("captura salva: ", _capture, " ", img.get_size(), " yaw_cam=", player.camera_rig.yaw, " yaw_player=", player.rotation.y, " estado=", player.model.state, " raptor=", raptors[0].state if raptors else "-", " buracos=", Fx.decal_count())
	get_tree().quit()
