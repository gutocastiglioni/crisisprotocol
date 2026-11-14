class_name ControlsScreen
extends Node
## Tela CONTROLES: o desenho do controle (jeito PlayStation, com uma linha de cada botão até o que ele faz) ou do teclado
## e do mouse (teclas usadas acesas, legenda embaixo). Os botões saem do mapa do `InputSetup` (`UiStyle.glyphs`) e os
## textos do perfil de jogo (`GameMode`: sobrevivência encosta/corre no L3, arcade esgueira). Abre pela tela de título,
## pelo menu de pausa (CONTROLES) e pelo F1 no jogo; começa no aparelho usado por último (ou no controle, se tem um ligado).
## Q / TAB / SELECT ou esquerda/direita trocam o desenho; E / X / ENTER / ESC / START / bola voltam. Pausa a árvore enquanto
## aberta (aberta por cima de um menu, o menu segue pausado e reaparece no sinal `closed`).

signal closed

const CLOSE := ["interact", "crouch", "ui_accept", "roll", "ui_cancel"]
const SWAP := ["switch_weapon", "move_left", "move_right", "ui_left", "ui_right"]

var is_open := false
var view_pad := false
var on_shown := Callable()
var layer: CanvasLayer
var board: Board
var _shade: ColorRect
var _dim: ColorRect
var _title: Label
var _sub: Label
var _hint: UiStyle.Hint
var _opened_frame := -1
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_shade = UiStyle.rect(layer, UiStyle.SHADE)
	_dim = UiStyle.rect(layer, UiStyle.BAND)  # por cima da sombra: o HUD do jogo quase some atrás do desenho
	_title = UiStyle.label(layer, "CONTROLES", UiStyle.ACCENT, UiStyle.M, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = UiStyle.label(layer, "", UiStyle.MUTED, UiStyle.S, HORIZONTAL_ALIGNMENT_CENTER)
	board = Board.new()
	layer.add_child(board)
	_hint = UiStyle.Hint.new()
	layer.add_child(_hint)
	_set_visible(false)


func set_ui_scale(k: float) -> void:
	layer.scale = Vector2(k, k)


func _set_visible(v: bool) -> void:
	for c: CanvasItem in [_shade, _dim, _title, _sub, board, _hint]:
		c.visible = v


func open() -> void:
	if is_open:
		return
	is_open = true
	_opened_frame = Engine.get_process_frames()
	_was_paused = get_tree().paused
	get_tree().paused = true
	Rumble.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view_pad = UiStyle.pad or not Input.get_connected_joypads().is_empty()
	_rebuild()
	_set_visible(true)
	Sfx.ui(self, "keypad_beep")
	if on_shown.is_valid():
		on_shown.call()


## Fecha; aberta de dentro do jogo, o jogo volta dois passos de física depois (o botão que fechou não chega nela).
func close() -> void:
	if not is_open:
		return
	is_open = false
	_set_visible(false)
	for a in CLOSE + SWAP + ["pause", "jump"]:
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


func set_view(on_pad: bool) -> void:
	view_pad = on_pad
	_rebuild()


func _rebuild() -> void:
	var survival := GameMode.is_survival()
	_sub.text = ("CONTROLE" if view_pad else "TECLADO E MOUSE") + "  ·  " + ("SOBREVIVÊNCIA" if survival else "ARCADE")
	_hint.set_items([{"action": "switch_weapon", "text": "VER TECLADO" if view_pad else "VER CONTROLE"},
		{"action": "interact", "pad_action": "crouch", "text": "VOLTAR"}])
	board.build(view_pad, survival)
	_layout()


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
	if _just(SWAP):
		Sfx.ui(self, "keypad_beep")
		set_view(not view_pad)
	elif _just(CLOSE):
		Sfx.ui(self, "keypad_ok")
		close()


func _just(actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _layout() -> void:
	var area := get_viewport().get_visible_rect().size / layer.scale
	_shade.size = area
	_dim.size = area
	for l: Label in [_title, _sub]:
		l.position.x = 0
		l.size.x = area.x
	_title.position.y = 6
	_sub.position.y = 21
	board.place(area)
	_hint.position = Vector2(roundf((area.x - _hint.size.x) * 0.5), area.y - 17)


## O desenho e as legendas. Coordenadas nas unidades do HUD (240 de altura); `place` centraliza na área visível.
class Board extends Control:
	const PAD := Vector2(150, 92)  # tamanho do controle desenhado
	const PITCH := 15.0  # entre uma legenda e a próxima
	const KEY := 13.0  # tecla de 1 unidade
	const KEY_STEP := 15.0
	const MOUSE := Vector2(26, 40)
	## pontos do controle (em relação ao canto de cima do desenho)
	const P := {
		"l2": Vector2(29, 3.5), "l1": Vector2(29, 11), "r2": Vector2(121, 3.5), "r1": Vector2(121, 11),
		"select": Vector2(60, 26), "start": Vector2(90, 26), "dpad": Vector2(30, 34),
		"triangle": Vector2(120, 24), "circle": Vector2(130, 34), "cross": Vector2(120, 44), "square": Vector2(110, 34),
		"stick_l": Vector2(52, 54), "stick_r": Vector2(98, 54),
	}
	## teclado desenhado: [linha, coluna (em teclas), largura (em teclas), texto]
	const KEYS := [
		[0, 0.0, 1.0, "ESC"], [0, 2.0, 1.0, "F1"], [0, 3.0, 1.0, "F2"], [0, 4.0, 1.0, "F3"],
		[1, 0.0, 1.5, "TAB"], [1, 1.5, 1.0, "Q"], [1, 2.5, 1.0, "W"], [1, 3.5, 1.0, "E"], [1, 4.5, 1.0, "R"], [1, 5.5, 1.0, "T"],
		[2, 0.0, 1.75, "CAPS"], [2, 1.75, 1.0, "A"], [2, 2.75, 1.0, "S"], [2, 3.75, 1.0, "D"], [2, 4.75, 1.0, "F"], [2, 5.75, 1.0, "G"],
		[3, 0.0, 2.25, "SHIFT"], [3, 2.25, 1.0, "Z"], [3, 3.25, 1.0, "X"], [3, 4.25, 1.0, "C"], [3, 5.25, 1.0, "V"], [3, 6.25, 1.0, "B"],
		[4, 0.0, 1.5, "CTRL"], [4, 1.5, 1.25, ""], [4, 2.75, 1.25, "ALT"], [4, 4.0, 3.25, "ESPAÇO"],
	]

	var on_pad := true
	var survival := true
	## legendas com linha: [{"hint": Hint, "to": [pontos locais do desenho], "side": "left"|"right"|"top", "under": bool}]
	## ("top" = em cima do controle, linha reta para baixo; "under" = a linha vai por baixo do botão e sobe até ele, sem
	## cruzar os vizinhos)
	var calls: Array = []
	var legend: Array[UiStyle.Hint] = []
	var lit: Array[String] = []  # teclas acesas no desenho do teclado
	var device_rect := Rect2()  # onde ficou o controle (ou o teclado)
	var mouse_rect := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Monta as legendas do aparelho (`pad` = controle) para o perfil de jogo.
	func build(pad: bool, surv: bool) -> void:
		on_pad = pad
		survival = surv
		for c in get_children():
			c.queue_free()
		calls.clear()
		legend.clear()
		lit.clear()
		if on_pad:
			_build_pad()
		else:
			_build_keys()
		queue_redraw()

	func _hint(items: Array, dev: int) -> UiStyle.Hint:
		var h := UiStyle.Hint.new()
		h.device = dev
		add_child(h)
		h.set_items(items)
		return h

	func _call(item: Dictionary, to: Array, side: String, under := false) -> void:
		calls.append({"hint": _hint([item], 1 if on_pad else 0), "to": to, "side": side, "under": under})

	func _a(action: String, text: String) -> Dictionary:
		return {"glyphs": UiStyle.glyphs(action, on_pad), "text": text}

	func _build_pad() -> void:
		_call(_a("aim", "MIRAR (SEGURAR)"), [P.l2, P.l1], "left")
		_call(_a("switch_weapon", "TROCAR ARMA"), [P.select], "top")
		_call({"glyphs": [{"shape": "dpad"}], "text": "ESCOLHER (MENUS)"}, [P.dpad], "left")
		_call({"glyphs": [{"shape": "stick_l"}], "text": "MOVER"}, [P.stick_l], "left")
		if survival:
			_call(_a("sprint", "SEGURAR: CORRER"), [P.stick_l], "left")
			_call(_a("lean", "TOQUE: ENCOSTAR"), [P.stick_l], "left")
		else:
			_call(_a("lean", "TOQUE: ESGUEIRAR"), [P.stick_l], "left")
		_call(_a("shoot", "ATIRAR (MIRANDO)" if survival else "ATIRAR"), [P.r2], "right")
		if survival:
			_call(_a("reload", "RECARREGAR"), [P.r1], "right")
		_call(_a("interact", "PEGAR / USAR"), [P.triangle], "right")
		_call(_a("pause", "PAUSA"), [P.start], "top")
		_call(_a("roll", "ROLAR"), [P.circle], "right")
		_call(_a("jump", "PULAR / AGARRAR"), [P.cross], "right")
		_call(_a("crouch_pad", "AGACHAR"), [P.square], "right", true)
		_call({"glyphs": [{"shape": "stick_r"}], "text": "CÂMERA"}, [P.stick_r], "right", true)
		_call(_a("crouch_stick", "AGACHAR"), [P.stick_r], "right", true)

	func _build_keys() -> void:
		var move := []
		for a in ["move_forward", "move_left", "move_back", "move_right"]:
			move.append(UiStyle.glyphs(a, false)[0])
		var items: Array = [{"glyphs": move, "text": "MOVER"}]
		if survival:
			items += [_a("sprint", "CORRER"), _a("walk_slow", "ANDAR DEVAGAR")]
		else:
			items.append(_a("walk", "ANDAR DEVAGAR"))
		items += [_a("crouch", "AGACHAR"), _a("roll", "ROLAR"), _a("jump", "PULAR / AGARRAR"), _a("interact", "PEGAR / USAR")]
		if survival:
			items.append(_a("reload", "RECARREGAR"))
		items += [_a("switch_weapon", "TROCAR ARMA"), _a("lean", "ENCOSTAR" if survival else "ESGUEIRAR"),
			_a("pause", "PAUSA"), _a("reset", "REINICIAR"), _a("toggle_help", "CONTROLES"), _a("toggle_gfx", "VISUAL PS1/PS2"),
			_a("toggle_mode", "MODO DE JOGO")]
		for it: Dictionary in items:
			legend.append(_hint([it], 0))
			for g: Dictionary in it.glyphs:
				lit.append(g.get("text", ""))
		# mouse: linhas até os botões e a roda
		_call({"text": "BOTÃO ESQ.: ATIRAR" + (" (MIRANDO)" if survival else "")}, ["mouse_l"], "right")
		_call({"text": "BOTÃO DIR.: MIRAR (SEGURAR)"}, ["mouse_r"], "right")
		_call({"text": "RODA: ZOOM DA LUNETA"}, ["mouse_wheel"], "right")
		_call({"text": "MOVER O MOUSE: CÂMERA"}, ["mouse_body"], "right")

	## Posiciona tudo na área visível (unidades do HUD).
	func place(area: Vector2) -> void:
		size = area
		if on_pad:
			_place_pad(area)
		else:
			_place_keys(area)
		queue_redraw()

	func _column(list: Array, x: float, top: float, right_align: bool) -> void:
		for i in list.size():
			var h: UiStyle.Hint = list[i].hint
			h.position = Vector2(roundf(x - h.size.x) if right_align else roundf(x), roundf(top + PITCH * i))

	func _place_pad(area: Vector2) -> void:
		var left := calls.filter(func(c: Dictionary) -> bool: return c.side == "left")
		var right := calls.filter(func(c: Dictionary) -> bool: return c.side == "right")
		var top := calls.filter(func(c: Dictionary) -> bool: return c.side == "top")
		var mid := 36.0 + (area.y - 36.0 - 22.0) * 0.5
		device_rect = Rect2(Vector2(roundf((area.x - PAD.x) * 0.5), roundf(mid - PAD.y * 0.5)), PAD)
		_column(left, device_rect.position.x - 14.0, mid - PITCH * left.size() * 0.5, true)
		_column(right, device_rect.end.x + 14.0, mid - PITCH * right.size() * 0.5, false)
		# em cima do controle, entre os gatilhos: o primeiro termina sobre o botão dele, o segundo começa sobre o seu
		for i in top.size():
			var h: UiStyle.Hint = top[i].hint
			var ax: float = point(top[i].to[0]).x
			h.position = Vector2(roundf(ax + 4.0 - h.size.x) if i == 0 else roundf(ax - 4.0), device_rect.position.y - 18.0)

	func _place_keys(area: Vector2) -> void:
		var kb := Vector2(7.25 * KEY_STEP, 4.0 * KEY_STEP + 4.0 + KEY)
		var callouts := 0.0
		for c: Dictionary in calls:
			callouts = maxf(callouts, (c.hint as UiStyle.Hint).size.x)
		var total := kb.x + 22.0 + MOUSE.x + 16.0 + callouts
		var x0 := roundf((area.x - total) * 0.5)
		device_rect = Rect2(Vector2(x0, 38), kb)
		mouse_rect = Rect2(Vector2(x0 + kb.x + 22.0, 38 + (kb.y - MOUSE.y) * 0.5), MOUSE)
		_column(calls, mouse_rect.end.x + 16.0, device_rect.position.y + (kb.y - PITCH * calls.size()) * 0.5 + 1.0, false)
		var cols := 3
		var col_w := minf(floorf((area.x - 24.0) / cols), 150.0)
		var rows := ceili(legend.size() / float(cols))
		var lx := roundf((area.x - col_w * cols) * 0.5)
		for i in legend.size():
			legend[i].position = Vector2(lx + col_w * (i / rows), device_rect.end.y + 10.0 + 13.0 * (i % rows))

	## Ponto de um nome do desenho (botão do controle ou do mouse) no espaço deste Control.
	func point(name: Variant) -> Vector2:
		if name is Vector2:
			return device_rect.position + name
		match name:
			"mouse_l":
				return mouse_rect.position + Vector2(MOUSE.x * 0.22, MOUSE.y * 0.3)
			"mouse_r":
				return mouse_rect.position + Vector2(MOUSE.x * 0.8, MOUSE.y * 0.24)
			"mouse_wheel":
				return mouse_rect.position + Vector2(MOUSE.x * 0.5, MOUSE.y * 0.12)
		return mouse_rect.position + Vector2(MOUSE.x * 0.5, MOUSE.y * 0.7)

	func _draw() -> void:
		if on_pad:
			_draw_pad(device_rect.position)
		else:
			_draw_keyboard(device_rect.position)
			_draw_mouse(mouse_rect)
		# linhas das legendas até o botão: contorno preto por baixo, ponto no botão
		for c: Dictionary in calls:
			var h: UiStyle.Hint = c.hint
			var y := h.position.y + h.size.y * 0.5
			var left: bool = c.side == "left"
			var from := Vector2(h.position.x + h.size.x + 3.0, y) if left else Vector2(h.position.x - 3.0, y)
			var elbow_x := (device_rect.position.x - 5.0) if left else ((device_rect.end.x + 5.0) if on_pad else (mouse_rect.end.x + 5.0))
			for to in c.to:
				var at := point(to)
				var pts := PackedVector2Array([from, Vector2(elbow_x, y), at])
				if c.side == "top":
					pts = PackedVector2Array([Vector2(at.x, h.position.y + h.size.y + 1.0), at])
				elif c.under:
					pts = PackedVector2Array([from, Vector2(at.x, y), at])
				draw_polyline(pts, Color.BLACK, 3.0)
				draw_polyline(pts, UiStyle.MUTED, 1.0)
				draw_circle(at, 2.2, Color.BLACK)
				draw_circle(at, 1.4, UiStyle.ACCENT)

	func _round_rect(r: Rect2, radius: float, color: Color) -> void:
		var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
		draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2.0, 0)), color)
		draw_rect(Rect2(r.position + Vector2(0, rad), r.size - Vector2(0, rad * 2.0)), color)
		for c in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad),
				Vector2(r.position.x + rad, r.end.y - rad)]:
			draw_circle(c, rad, color)

	func _ellipse(c: Vector2, rad: Vector2, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
		draw_colored_polygon(pts, color)

	## Controle jeito PlayStation: gatilhos, corpo com as duas pegadas, direcional, botões de forma, SELECT/START e os analógicos.
	func _draw_pad(o: Vector2) -> void:
		var line := UiStyle.DEVICE_LINE
		# gatilhos L2/R2 atrás e L1/R1 na frente
		for x in [14.0, 106.0]:
			_round_rect(Rect2(o + Vector2(x, 0), Vector2(30, 8)), 3.0, line)
			_round_rect(Rect2(o + Vector2(x + 1, 1), Vector2(28, 6)), 2.5, UiStyle.DEVICE)
			_round_rect(Rect2(o + Vector2(x, 8), Vector2(30, 7)), 2.0, line)
			_round_rect(Rect2(o + Vector2(x + 1, 9), Vector2(28, 5)), 1.5, UiStyle.DEVICE)
		# corpo e pegadas: tudo crescido de 1 em cinza por baixo vira o contorno da união
		for pass_i in 2:
			var grow := 1.2 if pass_i == 0 else 0.0
			var col := line if pass_i == 0 else UiStyle.DEVICE
			_round_rect(Rect2(o + Vector2(0, 13) - Vector2(grow, grow), Vector2(150, 48) + Vector2(grow, grow) * 2.0), 14.0 + grow, col)
			for gx in [26.0, 124.0]:
				_ellipse(o + Vector2(gx, 66), Vector2(22, 25) + Vector2(grow, grow), col)
		# direcional
		var d := o + P.dpad
		for r in [Rect2(d + Vector2(-3, -10), Vector2(6, 20)), Rect2(d + Vector2(-10, -3), Vector2(20, 6))]:
			draw_rect(r.grow(0.8), Color.BLACK)
		for r in [Rect2(d + Vector2(-3, -10), Vector2(6, 20)), Rect2(d + Vector2(-10, -3), Vector2(20, 6))]:
			draw_rect(r, line)
		# botões de forma: círculo escuro com o desenho
		for k in ["triangle", "circle", "cross", "square"]:
			var c: Vector2 = o + P[k]
			draw_circle(c, 5.4, Color.BLACK)
			draw_circle(c, 4.6, line)
			draw_circle(c, 3.8, UiStyle.DEVICE)
			_face(k, c, 2.4)
		# SELECT e START
		for k in ["select", "start"]:
			_round_rect(Rect2(o + P[k] - Vector2(5, 2), Vector2(10, 4)), 2.0, line)
		# analógicos
		for k in ["stick_l", "stick_r"]:
			var c: Vector2 = o + P[k]
			draw_circle(c, 9.5, Color.BLACK)
			draw_circle(c, 8.5, line)
			draw_circle(c, 6.0, UiStyle.DEVICE)
			draw_arc(c, 6.0, 0.0, TAU, 20, line, 1.0)

	func _face(shape: String, c: Vector2, k: float) -> void:
		var col := UiStyle.ACTION
		match shape:
			"triangle":
				draw_polyline(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, k * 0.8), c + Vector2(-k, k * 0.8), c + Vector2(0, -k)]), col, 1.0)
			"circle":
				draw_arc(c, k, 0.0, TAU, 12, col, 1.0)
			"cross":
				draw_line(c + Vector2(-k, -k), c + Vector2(k, k), col, 1.0)
				draw_line(c + Vector2(-k, k), c + Vector2(k, -k), col, 1.0)
			"square":
				draw_rect(Rect2(c - Vector2(k, k) * 0.85, Vector2(k, k) * 1.7), col, false, 1.0)

	## Metade esquerda do teclado: as teclas do jogo acesas.
	func _draw_keyboard(o: Vector2) -> void:
		var font := get_theme_default_font()
		for k: Array in KEYS:
			var y: float = k[0] * KEY_STEP + (0.0 if k[0] == 0 else 4.0)
			var r := Rect2(o + Vector2(k[1] * KEY_STEP, y), Vector2(k[2] * KEY_STEP - (KEY_STEP - KEY), KEY))
			var on: bool = k[3] != "" and k[3] in lit
			draw_rect(r, UiStyle.KEY_FILL if on else UiStyle.DEVICE)
			draw_rect(r.grow(0.5), Color.BLACK, false, 2.0)
			draw_rect(r, UiStyle.ACTION if on else UiStyle.DEVICE_LINE, false, 1.0)
			var t: String = k[3]
			var fs := UiStyle.XS if t.length() > 2 else UiStyle.S
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(r.position.x + roundf((r.size.x - tw) * 0.5), r.position.y + (r.size.y + fs * 0.7) * 0.5), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.ACTION if on else UiStyle.MUTED)

	func _draw_mouse(r: Rect2) -> void:
		var line := UiStyle.DEVICE_LINE
		_round_rect(r.grow(1.2), 13.2, line)
		_round_rect(r, 12.0, UiStyle.DEVICE)
		var split := r.position.y + r.size.y * 0.42
		draw_line(Vector2(r.position.x + 1, split), Vector2(r.end.x - 1, split), line, 1.0)
		draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 1), Vector2(r.position.x + r.size.x * 0.5, split), line, 1.0)
		draw_rect(Rect2(Vector2(r.position.x + r.size.x * 0.5 - 2, r.position.y + r.size.y * 0.12), Vector2(4, 8)), line)
