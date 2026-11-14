class_name OptionsScreen
extends Node
## Tela OPÇÕES: TELA CHEIA (SIM/NÃO), VOLUME (volume geral do jogo, 0 a 100% de 10 em 10) e VIBRAÇÃO (SIM/NÃO) + VOLTAR.
## Abre pelo menu inicial (`TitleScreen`) e pelo menu de pausa (`PauseMenu`), uma só para os dois (criada pelo menu de
## pausa, `pause_menu.options`); quem abriu reaparece no sinal `closed`. Cada troca vale na hora e é salva em `Settings`
## (`user://settings.cfg`) para o jogo já abrir assim. Cima/baixo escolhe; esquerda/direita troca o valor (volume: -/+);
## E / X / ENTER troca também (volume sobe e, no 100%, volta ao 0) e em VOLTAR fecha; ESC / START / bola voltam. O mouse
## escolhe e clica (botão direito baixa o volume). Pausa a árvore enquanto aberta (como a `ControlsScreen`).

signal closed

const ITEMS := ["TELA CHEIA", "VOLUME", "VIBRAÇÃO", "VOLTAR"]
const UP := ["move_forward", "ui_up"]
const DOWN := ["move_back", "ui_down"]
const LEFT := ["move_left", "ui_left"]
const RIGHT := ["move_right", "ui_right"]
const CONFIRM := ["interact", "crouch", "ui_accept"]
const BACK := ["crouch"]  # bola; ESC / START chegam como "pause" (_unhandled_input)
const HINT_ITEMS := [{"keys": ["SETAS"], "pad": "dpad", "text": "ESCOLHER / AJUSTAR"},
	{"action": "interact", "pad_action": "crouch", "text": "CONFIRMAR"}, {"action": "pause", "text": "VOLTAR"}]
const ROW := 14.0  # altura de cada opção (unidades do HUD de 240 de altura), igual ao menu de pausa

var is_open := false
var selected := 0
var on_shown := Callable()
var layer: CanvasLayer
var _shade: ColorRect
var _band: ColorRect
var _title: Label
var _hint: UiStyle.Hint
var _rows: Array[Label] = []
var _opened_frame := -1
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_shade = UiStyle.rect(layer, UiStyle.SHADE)
	_band = UiStyle.rect(layer, UiStyle.BAND)
	_title = UiStyle.label(layer, "OPÇÕES", UiStyle.ACCENT, UiStyle.L, HORIZONTAL_ALIGNMENT_CENTER)
	_hint = UiStyle.Hint.new()
	layer.add_child(_hint)
	_hint.set_items(HINT_ITEMS)
	for i in ITEMS.size():
		var l := UiStyle.label(layer, "", UiStyle.INK, UiStyle.S, HORIZONTAL_ALIGNMENT_CENTER)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_row_input.bind(i))
		_rows.append(l)
	_set_visible(false)


func set_ui_scale(k: float) -> void:
	layer.scale = Vector2(k, k)


func _set_visible(v: bool) -> void:
	for c: CanvasItem in [_shade, _band, _title, _hint]:
		c.visible = v
	for l in _rows:
		l.visible = v


func open() -> void:
	if is_open:
		return
	is_open = true
	_opened_frame = Engine.get_process_frames()
	_was_paused = get_tree().paused
	get_tree().paused = true
	Rumble.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_select(0, false)
	_layout()
	_set_visible(true)
	Sfx.ui(self, "keypad_beep")
	if on_shown.is_valid():
		on_shown.call()


## Fecha; quem abriu (título ou pausa) reaparece pelo sinal. O botão que fechou não chega no menu de baixo.
func close() -> void:
	if not is_open:
		return
	is_open = false
	_set_visible(false)
	for a in CONFIRM + BACK + LEFT + RIGHT + ["roll", "pause"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	closed.emit()
	if _was_paused:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 2:
		await get_tree().physics_frame
	if not is_open:
		get_tree().paused = false


func _select(i: int, beep := true) -> void:
	if beep and i != selected:
		Sfx.ui(self, "keypad_beep")
	selected = i
	_refresh()


func _refresh() -> void:
	for k in _rows.size():
		_rows[k].text = ("> %s <" if k == selected else "%s") % item_text(k)
		_rows[k].add_theme_color_override("font_color", UiStyle.ACCENT if k == selected else UiStyle.INK)


## Texto da opção com o valor atual.
func item_text(i: int) -> String:
	match ITEMS[i]:
		"TELA CHEIA":
			return "TELA CHEIA: %s" % ("SIM" if Settings.fullscreen else "NÃO")
		"VOLUME":
			return "VOLUME: %d%%" % Settings.volume_percent()
		"VIBRAÇÃO":
			return "VIBRAÇÃO: %s" % ("SIM" if Settings.vibration else "NÃO")
	return ITEMS[i]


## Muda o valor da opção escolhida: `dir` -1/+1 = esquerda/direita, 0 = confirmar (liga/desliga; volume sobe e dá a volta).
func adjust(dir: int) -> void:
	match ITEMS[selected]:
		"TELA CHEIA":
			Settings.set_fullscreen(not Settings.fullscreen)
		"VIBRAÇÃO":
			Settings.set_vibration(not Settings.vibration)
		"VOLUME":
			var steps := Settings.VOLUME_STEPS
			var now := roundi(Settings.volume * steps)
			var next := posmod(now + 1, steps + 1) if dir == 0 else clampi(now + dir, 0, steps)
			if next == now:
				return
			Settings.set_volume(float(next) / steps)
		_:
			return
	Sfx.ui(self, "keypad_ok")  # já no volume novo: dá para ouvir como ficou
	_refresh()


func _choose() -> void:
	if not is_open:
		return
	if ITEMS[selected] == "VOLTAR":
		Sfx.ui(self, "keypad_ok")
		close()
	else:
		adjust(0)


func _on_row_input(e: InputEvent, i: int) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	_select(i)
	if e.button_index == MOUSE_BUTTON_LEFT:
		_choose()
	elif e.button_index == MOUSE_BUTTON_RIGHT and ITEMS[i] == "VOLUME":
		adjust(-1)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if not is_open:
		return
	_layout()
	if Engine.get_process_frames() == _opened_frame:
		return  # o botão que abriu não conta
	var step := int(_just(DOWN)) - int(_just(UP))
	var side := int(_just(RIGHT)) - int(_just(LEFT))
	if step != 0:
		_select(posmod(selected + step, ITEMS.size()))
		return
	if side != 0:
		adjust(side)
		return
	var pad_x := _just(["crouch"]) and Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var pad_o := _just(["roll"]) and Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	var pad_y := _just(["interact"]) and Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	if pad_x or (_just(CONFIRM) and not pad_o and not pad_y):
		_choose()
	elif pad_o or (_just(BACK) and not pad_x):
		Sfx.ui(self, "keypad_ok")
		close()


func _just(actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _layout() -> void:
	var area := get_viewport().get_visible_rect().size / layer.scale
	var h := 40.0 + ROW * ITEMS.size() + 18.0
	var top := roundf(area.y * 0.5 - h * 0.5)
	_shade.size = area
	_band.position = Vector2(0, top)
	_band.size = Vector2(area.x, h)
	for l: Label in [_title] + _rows:
		l.position.x = 0
		l.size.x = area.x
	_title.position.y = top + 4
	for i in _rows.size():
		_rows[i].position.y = top + 40 + ROW * i
	_hint.position = Vector2(roundf((area.x - _hint.size.x) * 0.5), top + h - 14)
