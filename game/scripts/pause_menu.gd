class_name PauseMenu
extends Node
## Menu de pausa (ESC / START): árvore pausada (este nó roda mesmo assim), fundo escurecido e a lista
## CONTINUAR / REINICIAR / SAIR DO JOGO. Cima/baixo (W/S, setas, analógico, direcional) escolhe, E / X / ENTER confirma,
## ESC / START / bola volta ao jogo; o mouse também escolhe e clica. Quem abre é o `main` (não abre com o jogo já pausado
## por uma tela de inspeção nem no game over). Captura e testes: `on_shown` é chamado quando o menu aparece.

signal restart
signal quit

const ITEMS := ["CONTINUAR", "REINICIAR", "SAIR DO JOGO"]
const UP := ["move_forward", "ui_up"]
const DOWN := ["move_back", "ui_down"]
const CONFIRM := ["interact", "roll", "ui_accept"]
const BACK := ["crouch"]  # bola; ESC / START chegam como "pause" (_unhandled_input)
const TEXT := UiStyle.INK
const PICK := UiStyle.ACCENT
const HINT_ITEMS := [{"keys": ["SETAS"], "pad": "dpad", "text": "ESCOLHER"}, {"action": "interact", "text": "CONFIRMAR"},
	{"action": "pause", "text": "VOLTAR"}]
const ROW := 14.0  # altura de cada opção (unidades do HUD de 320x240)

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_shade = UiStyle.rect(layer, UiStyle.SHADE)
	_band = UiStyle.rect(layer, UiStyle.BAND)
	_title = _label("PAUSA", PICK)
	_title.add_theme_font_size_override("font_size", UiStyle.L)
	_hint = UiStyle.Hint.new()
	layer.add_child(_hint)
	_hint.set_items(HINT_ITEMS)
	for i in ITEMS.size():
		var l := _label(ITEMS[i], TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_row_input.bind(i))
		_rows.append(l)
	_set_visible(false)


func _label(text: String, color: Color) -> Label:
	return UiStyle.label(layer, text, color, UiStyle.S, HORIZONTAL_ALIGNMENT_CENTER)


func _set_visible(v: bool) -> void:
	for c in [_shade, _band, _title, _hint]:
		c.visible = v
	for l in _rows:
		l.visible = v


## Escala do HUD (main.apply_gfx): o menu foi feito para 320x240 como ele.
func set_ui_scale(k: float) -> void:
	layer.scale = Vector2(k, k)


func open() -> void:
	if is_open:
		return
	is_open = true
	_opened_frame = Engine.get_process_frames()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_select(0, false)
	_layout()
	_set_visible(true)
	Sfx.ui(self, "keypad_beep")
	if on_shown.is_valid():
		on_shown.call()


## Volta ao jogo. O botão que fechou não chega nela (rolar, pegar, agachar): as ações são soltas e o jogo só volta
## dois passos de física depois (o "acabou de apertar" de um botão que chegou entre passos vale para o passo seguinte).
func close() -> void:
	if not is_open:
		return
	is_open = false
	_set_visible(false)
	for a in CONFIRM + BACK + ["pause"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 2:
		await get_tree().physics_frame
	if not is_open:
		get_tree().paused = false


func _select(i: int, beep := true) -> void:
	if beep and i != selected:
		Sfx.ui(self, "keypad_beep")
	selected = i
	for k in _rows.size():
		_rows[k].text = ("> %s <" if k == selected else "%s") % ITEMS[k]
		_rows[k].add_theme_color_override("font_color", PICK if k == selected else TEXT)


func _on_row_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_select(i)
		_choose()


func _choose() -> void:
	if not is_open:
		return
	Sfx.ui(self, "keypad_ok")
	match ITEMS[selected]:
		"CONTINUAR":
			close()
		"REINICIAR":
			close()
			restart.emit()
		"SAIR DO JOGO":
			quit.emit()


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
	if step != 0:
		_select(posmod(selected + step, ITEMS.size()))
	if _just(CONFIRM):
		_choose()
	elif _just(BACK):
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
	_hint.position.x = roundf((area.x - _hint.size.x) * 0.5)
	_title.position.y = top + 4
	for i in _rows.size():
		_rows[i].position.y = top + 40 + ROW * i
	_hint.position.y = top + h - 14
