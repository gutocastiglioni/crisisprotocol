class_name Tutorial
extends Node3D
## Pista de treino (TUTORIAL da tela de título): corredor fechado em `ORIGIN`, longe a leste do galpão (nenhum inimigo vê
## nem ouve), montado só quando o treino começa (`main.start_tutorial`) e apagado ao sair. Ela segue os passos `STEPS`, um
## de cada vez, com o aviso e os botões do aparelho usado no alto da tela (`UiStyle.Hint`):
##   corredor (mover e câmera) → vão baixo (`LOW_X`, só agachada passa: cápsula `Player.CROUCH_H`) → caixa A (escalar) →
##   pulo para a caixa B por cima do fosso (caiu: degrau no fundo e as beiradas para se pendurar) → baú da M16 → botão
##   na parede (`Terminal`, "APERTAR BOTÃO") que abre o portão de grade → sala de tiro: encostar na caixa alta
##   (`COVER_AT`; arcade: esgueirar), mirar na beirada e acertar o alvo escondido atrás dela → trocar de arma → alvo do fim.
## Acabou: "TUTORIAL COMPLETO" e o sinal `finished` (o main volta à tela de título). R recomeça do primeiro passo.
## Coordenadas locais: o corredor corre para +X, meia largura `HALF`, paredes de `WALL_H` que não se escalam ("no_climb").

signal finished

const ORIGIN := Vector3(70, 0, 0)
const HALF := 1.8  # meia largura do corredor
const WALL_H := 3.6  # = Shed.FENCE_H: a grade em cima do portão fecha até o alto das paredes
const START := Vector3(0, 0, 0)
const MOVE_X := 4.0
const LOW_X := 7.0  # vão baixo
const LOW_GAP := 1.25  # altura do vão (agachada passa, em pé não)
const CRATE_A := Vector2(11.0, 12.5)  # x de começo e fim
const CRATE_B := Vector2(14.1, 15.6)
const CRATE_H := 1.2
const PIT_Y := -1.2
const CHEST_AT := Vector3(18.6, 0, -HALF + 0.5)
const BUTTON_AT := Vector3(20.6, 0, -HALF + 0.8)  # onde ela fica para apertar (olhando para a parede, -Z)
const GATE_X := 22.0
const ROOM := Vector2(42.0, 4.5)  # fim e meia largura da sala de tiro
const COVER_AT := Vector3(27.0, 0, 0)
const COVER_SIZE := Vector3(1.2, 2.0, 2.4)
const TARGET_HIDDEN := Vector3(33.0, 0, 0)  # atrás da caixa: só esgueirando ela o vê
const TARGET_END := Vector3(40.8, 0, 3.0)
const DONE_FLASH := 0.7  # s do aviso verde antes do próximo passo
const END_TIME := 3.0
const STEPS := ["move", "crouch", "climb", "leap", "chest", "button", "cover", "peek", "switch", "final"]

var player: Player
var step := 0
var finished_t := -1.0
var chest: Chest
var gate: Door
var button: Terminal
var targets: Array[TargetDummy] = []
var layer: CanvasLayer
var _band: ColorRect
var _count: Label
var _text: Label
var _hint: UiStyle.Hint
var _flash := 0.0
var _weapon_at_step := ""


## Monta a pista e o aviso (o main põe no mundo e chama `begin`).
func _ready() -> void:
	position = ORIGIN
	_build()
	layer = Overlay.new()
	layer.tutorial = self
	layer.layer = 1
	add_child(layer)
	_band = UiStyle.rect(layer, UiStyle.BAND)
	_count = UiStyle.label(layer, "", UiStyle.MUTED, UiStyle.XS, HORIZONTAL_ALIGNMENT_CENTER)
	_text = UiStyle.label(layer, "", UiStyle.INK, UiStyle.S, HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = UiStyle.Hint.new()
	layer.add_child(_hint)


func set_ui_scale(k: float) -> void:
	if layer:
		layer.scale = Vector2(k, k)


## Lugar e direção em que ela começa (olhando para +X, o corredor).
static func spawn() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), ORIGIN + START)


## Começa (ou recomeça) do primeiro passo: ela no começo do corredor, só com a pistola e munição cheia; pista como nova.
func begin(p: Player) -> void:
	player = p
	step = 0
	finished_t = -1.0
	_flash = 0.0
	chest.reset()
	button.load_done(false)
	gate.reset()
	gate.set_held(true, true)
	for t in targets:
		t.reset()
	p.global_transform = spawn()
	p.reset_physics_interpolation()
	p.camera_rig.reset_view(p.rotation.y)
	_fill_ammo()
	_show_step()


func _fill_ammo() -> void:
	for w in player.weapons:
		if GameMode.AMMO_CAP.has(w):
			player.ammo[w] = int(GameMode.AMMO_CAP[w])
	player._fill_mags()


func local_pos() -> Vector3:
	return player.global_position - ORIGIN


func current() -> String:
	return STEPS[step] if step < STEPS.size() else ""


## O passo de agora já foi feito?
func step_done(id: String) -> bool:
	var lp := local_pos()
	var on_floor := player.is_on_floor()
	match id:
		"move":
			return lp.x > MOVE_X
		"crouch":
			return lp.x > LOW_X + 0.6
		"climb":
			return on_floor and lp.y > CRATE_H - 0.2 and lp.x > CRATE_A.x - 0.1 and lp.x < CRATE_A.y + 0.1
		"leap":
			return on_floor and lp.y > CRATE_H - 0.2 and lp.x > CRATE_B.x - 0.1
		"chest":
			return "m16" in player.weapons
		"button":
			return button.done
		"cover":
			return player.cover.active if GameMode.is_survival() else player.lean.side != 0
		"peek":
			return targets[0].dead
		"switch":
			return player.weapon() != _weapon_at_step
		"final":
			return targets[1].dead
	return false


## Texto e botões de um passo (no perfil de jogo atual).
func step_info(id: String) -> Dictionary:
	var survival := GameMode.is_survival()
	var move := {"keys": _keys(["move_forward", "move_left", "move_back", "move_right"]), "pad": "stick_l", "text": "MOVER"}
	match id:
		"move":
			return {"text": "ANDE PELO CORREDOR E GIRE A CÂMERA",
				"items": [move, {"keys": ["MOUSE"], "pad": "stick_r", "text": "CÂMERA"}]}
		"crouch":
			return {"text": "AGACHE PARA PASSAR POR BAIXO", "items": [{"action": "crouch", "pad_action": "crouch_pad", "text": "AGACHAR"}, move]}
		"climb":
			return {"text": "SUBA NA CAIXA", "items": [{"action": "jump", "text": "ESCALAR"}]}
		"leap":
			if local_pos().y < -0.5:
				return {"text": "CAIU? PULE NA BEIRADA DA CAIXA PARA SE PENDURAR E SUBIR", "items": [{"action": "jump", "text": "AGARRAR"}]}
			return {"text": "ANDE ATÉ A BEIRADA E PULE PARA A OUTRA CAIXA", "items": [move, {"action": "jump", "text": "PULAR"}]}
		"chest":
			return {"text": "PEGUE A ARMA NO BAÚ", "items": [{"action": "interact", "text": "PEGAR"}]}
		"button":
			return {"text": "APERTE O BOTÃO DA PAREDE PARA ABRIR O PORTÃO", "items": [{"action": "interact", "text": "APERTAR"}]}
		"cover":
			if survival:
				return {"text": "PERTO DA CAIXA ALTA, ENCOSTE NELA", "items": [{"action": "lean", "text": "ENCOSTAR"}, move]}
			return {"text": "DE FRENTE PARA A CAIXA ALTA, ESGUEIRE PELA QUINA", "items": [{"action": "lean", "text": "ESGUEIRAR"}]}
		"peek":
			if survival:
				return {"text": "ANDE ATÉ A BEIRADA, MIRE PARA ESGUEIRAR E ATIRE NO ALVO",
					"items": [move, {"action": "aim", "text": "MIRAR"}, {"action": "shoot", "text": "ATIRAR"}]}
			return {"text": "MIRE E ATIRE NO ALVO ATRÁS DA CAIXA", "items": [{"action": "aim", "text": "MIRAR"}, {"action": "shoot", "text": "ATIRAR"}]}
		"switch":
			return {"text": "TROQUE DE ARMA (PISTOLA / M16)", "items": [{"action": "switch_weapon", "text": "TROCAR ARMA"}]}
		"final":
			return {"text": "ACERTE O ALVO NO FIM DA SALA", "items": [{"action": "aim", "text": "MIRAR"}, {"action": "shoot", "text": "ATIRAR"}]}
	return {"text": "", "items": []}


func _keys(actions: Array) -> Array:
	var out := []
	for a in actions:
		out.append(UiStyle.glyph(a, false).text)
	return out


func _show_step() -> void:
	_weapon_at_step = player.weapon()
	_refresh_text()


func _refresh_text() -> void:
	if finished_t >= 0.0:
		_count.text = ""
		_text.text = "TUTORIAL COMPLETO!"
		_text.add_theme_color_override("font_color", UiStyle.ACTION)
		_hint.set_items([])
		return
	var info := step_info(current())
	_count.text = "TUTORIAL %d/%d" % [step + 1, STEPS.size()]
	_text.text = info.text
	_text.add_theme_color_override("font_color", UiStyle.ACTION if _flash > 0.0 else UiStyle.INK)
	_hint.verb_color = UiStyle.ACTION if _flash > 0.0 else UiStyle.INK
	_hint.set_items(info.items)
	_hint.queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if finished_t >= 0.0:
		finished_t += delta
		if finished_t >= END_TIME:
			player = null
			finished.emit()
		return
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			step += 1
			if step >= STEPS.size():
				finished_t = 0.0
				Sfx.ui(self, "keypad_ok")
			else:
				_show_step()
			_refresh_text()
		return
	if step_done(current()):
		_flash = DONE_FLASH
		Sfx.ui(self, "keypad_beep")
		if current() == "chest":
			_fill_ammo()
		_refresh_text()
	elif current() == "leap":
		_refresh_text()  # o texto muda se ela cair no fosso


## O aviso roda com o jogo pausado (`Overlay`): some na pausa e nas telas por cima.
func _ui() -> void:
	var on := is_inside_tree() and player != null and not get_tree().paused and not player.cutscene
	for c: CanvasItem in [_band, _count, _text, _hint]:
		c.visible = on
	if not on:
		return
	var area := get_viewport().get_visible_rect().size / layer.scale
	var max_w := area.x - 2.0 * (Radar.SIZE + 20.0)
	_text.size = Vector2(max_w, 0)
	_text.reset_size()
	_text.size.x = max_w
	var tw := _text.get_theme_default_font().get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S).x
	var w := minf(maxf(_hint.size.x, tw) + 16.0, max_w + 16.0)
	var x := roundf((area.x - w) * 0.5)
	var y := 28.0
	_count.position = Vector2(0, y + 2)
	_count.size.x = area.x
	_text.position = Vector2(roundf((area.x - max_w) * 0.5), y + 9)
	_hint.position = Vector2(roundf((area.x - _hint.size.x) * 0.5), _text.position.y + _text.size.y + 2)
	_band.position = Vector2(x, y)
	_band.size = Vector2(w, _hint.position.y + _hint.size.y + 4 - y)


class Overlay extends CanvasLayer:
	var tutorial: Tutorial

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		tutorial._ui()


# ------------------------------------------------------------------ pista
func _wall(size: Vector3, pos: Vector3, tex := "wall") -> StaticBody3D:
	var b := Level.block(self, size, pos, tex, 0.5)
	b.set_meta("no_climb", true)
	return b


func _build() -> void:
	var low := PIT_Y - 0.2
	var h := WALL_H - low
	# chão do corredor (com o fosso entre as caixas) e da sala de tiro
	Level.block(self, Vector3(CRATE_A.y + 2.0, 0.4, HALF * 2.0), Vector3((CRATE_A.y - 2.0) * 0.5, -0.2, 0), "concrete", 0.35)
	Level.block(self, Vector3(CRATE_B.x - CRATE_A.y, 0.4, HALF * 2.0), Vector3((CRATE_A.y + CRATE_B.x) * 0.5, PIT_Y - 0.2, 0), "concrete", 0.35)
	Level.block(self, Vector3(GATE_X - CRATE_B.x, 0.4, HALF * 2.0), Vector3((GATE_X + CRATE_B.x) * 0.5, -0.2, 0), "concrete", 0.35)
	Level.block(self, Vector3(ROOM.x - GATE_X, 0.4, ROOM.y * 2.0), Vector3((ROOM.x + GATE_X) * 0.5, -0.2, 0), "concrete", 0.35)
	# paredes do corredor (descem até o fundo do fosso), do começo e da sala
	for s in [-1, 1]:
		_wall(Vector3(GATE_X + 2.0, h, 0.4), Vector3(GATE_X * 0.5 - 1.0, low + h * 0.5, s * (HALF + 0.2)))
		_wall(Vector3(ROOM.x - GATE_X, WALL_H, 0.4), Vector3((ROOM.x + GATE_X) * 0.5, WALL_H * 0.5, s * (ROOM.y + 0.2)))
		var side := ROOM.y - HALF
		_wall(Vector3(0.4, WALL_H, side + 0.4), Vector3(GATE_X, WALL_H * 0.5, s * (HALF + side * 0.5)))
	_wall(Vector3(0.4, h, HALF * 2.0 + 0.8), Vector3(-2.2, low + h * 0.5, 0))
	_wall(Vector3(0.4, WALL_H, ROOM.y * 2.0 + 0.8), Vector3(ROOM.x + 0.2, WALL_H * 0.5, 0))
	# vão baixo: parede com a passagem embaixo e a faixa de perigo na borda dela
	var top := WALL_H - LOW_GAP
	_wall(Vector3(0.6, top, HALF * 2.0), Vector3(LOW_X, LOW_GAP + top * 0.5, 0))
	Level.block(self, Vector3(0.64, 0.14, HALF * 2.0), Vector3(LOW_X, LOW_GAP + 0.07, 0), "hazard", 1.0)
	# as duas caixas com o fosso no meio e o degrau no fundo dele (caiu: sobe por ele)
	for c: Vector2 in [CRATE_A, CRATE_B]:
		var hh := CRATE_H - PIT_Y
		Level.block(self, Vector3(c.y - c.x, hh, HALF * 2.0), Vector3((c.x + c.y) * 0.5, PIT_Y + hh * 0.5, 0), "crate", 0.6)
	Level.block(self, Vector3(0.7, 0.8, 0.9), Vector3((CRATE_A.y + CRATE_B.x) * 0.5, PIT_Y + 0.4, -HALF + 0.45), "concrete", 0.35)
	# baú da M16 encostado na parede (boca para o meio do corredor)
	chest = Chest.new()
	chest.item = "m16"
	add_child(chest)
	chest.position = CHEST_AT
	# botão na parede e o portão de grade que ele abre
	Level.block(self, Vector3(0.5, 0.7, 0.12), Vector3(BUTTON_AT.x, 1.2, -HALF + 0.06), "wall", 2.0)
	var red := Level.material("wall", 4.0)
	red.set_shader_parameter("tint", UiStyle.DANGER)
	var cap := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.09
	cyl.height = 0.08
	cap.mesh = cyl
	cap.material_override = red
	cap.rotation_degrees.x = 90.0
	cap.position = Vector3(BUTTON_AT.x, 1.2, -HALF + 0.16)
	add_child(cap)
	button = Terminal.new()
	button.verb = "APERTAR BOTÃO"
	add_child(button)
	button.position = BUTTON_AT
	gate = Shed.grate_gate(self, Vector3(GATE_X, 0, 0), HALF * 2.0, 0.0)
	button.used.connect(func() -> void:
		gate.set_held(false)
		gate.open())
	# sala de tiro: caixa alta para encostar/esgueirar, o alvo escondido atrás dela e o do fim
	Level.block(self, COVER_SIZE, COVER_AT + Vector3.UP * COVER_SIZE.y * 0.5, "crate", 1.0 / COVER_SIZE.y)
	for at in [TARGET_HIDDEN, TARGET_END]:
		var t := TargetDummy.new()
		t.position = at
		t.rotation.y = PI * 0.5  # de frente para a entrada (-X)
		add_child(t)
		targets.append(t)
	# luz
	for at in [Vector3(1.5, 0, -HALF + 0.3), Vector3(9.5, 0, HALF - 0.3), Vector3(17.0, 0, HALF - 0.3), Vector3(25.0, 0, -ROOM.y + 0.3),
			Vector3(36.0, 0, ROOM.y - 0.3), Vector3(40.0, 0, -ROOM.y + 0.3)]:
		Yard.lamp(self, at, at.x < 20.0)
