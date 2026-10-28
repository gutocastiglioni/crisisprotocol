class_name UiStyle
## Design system dos textos e telas do jogo (unidades do HUD de 320x240, ampliado por `main.apply_gfx`).
## Toda tela usa estes tokens em vez de cor/tamanho próprio:
##   - cores: INK (texto), ACCENT (título, item escolhido, "?"), ACTION (botão, confirmar, tudo bem), WARN (busca),
##     DANGER (alerta, erro, morte), MUTED (desligado, bloqueado); contorno preto de OUTLINE;
##   - tamanhos: S (HUD, texto, dicas), M (título de caixa, legenda de cena), L (título de tela cheia);
##   - fundos: SHADE (tela escurecida), DEATH_SHADE (game over), BAND (faixa/caixa de texto);
##   - botões: `Hint` mostra "<glifo> VERBO" (vários lado a lado). O glifo vem do mapa de controles (InputSetup) e do
##     último aparelho usado (`pad`, atualizado pelo `Watcher` que o main cria): tecla numa moldura no teclado,
##     triângulo/bola/X/quadrado (ou L1, R1, START...) no controle.
## Textos em português com acento; títulos, botões e avisos em MAIÚSCULAS, descrições com só a primeira maiúscula.

const INK := Color(0.9, 0.92, 0.85)
const ACCENT := Color(1.0, 0.85, 0.3)
const ACTION := Color(0.4, 1.0, 0.5)
const WARN := Color(1.0, 0.55, 0.15)
const DANGER := Color(1.0, 0.3, 0.25)
const MUTED := Color(0.55, 0.55, 0.55)
const OUTLINE := 2
const S := 8
const M := 12
const L := 24
const SHADE := Color(0, 0, 0, 0.7)
const DEATH_SHADE := Color(0.22, 0.0, 0.0, 0.45)
const BAND := Color(0, 0, 0, 0.72)
const KEY_FILL := Color(0, 0, 0, 0.55)
const KEY_H := 11.0  # altura do glifo (a linha do texto S)
const HINT_GAP := 4.0  # entre o glifo e o verbo
const HINT_SPACE := 12.0  # entre um botão e o próximo

## nome curto das teclas no glifo do teclado (o resto usa o nome do Godot em maiúsculas)
const KEY_NAMES := {KEY_ESCAPE: "ESC", KEY_SPACE: "ESPAÇO", KEY_CTRL: "CTRL", KEY_SHIFT: "SHIFT", KEY_TAB: "TAB",
	KEY_UP: "CIMA", KEY_DOWN: "BAIXO", KEY_LEFT: "ESQ.", KEY_RIGHT: "DIR."}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "MOUSE E", MOUSE_BUTTON_RIGHT: "MOUSE D"}
## controle de PlayStation (InputSetup: A = X, B = bola, X = quadrado, Y = triângulo)
const PAD_SHAPES := {JOY_BUTTON_A: "cross", JOY_BUTTON_B: "circle", JOY_BUTTON_X: "square", JOY_BUTTON_Y: "triangle"}
const PAD_NAMES := {JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "START",
	JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}
const PAD_AXES := {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"}

## último aparelho usado: true = controle (os glifos mostram os botões dele)
static var pad := false


## Rótulo com o estilo do jogo (contorno preto).
static func label(parent: Node, text := "", color := INK, font_size := S, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", OUTLINE)
	if parent:
		parent.add_child(l)
	return l


## Retângulo de fundo (SHADE, DEATH_SHADE, BAND) que não pega o mouse.
static func rect(parent: Node, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(r)
	return r


## Glifo de uma ação no aparelho atual: {"text": "E"} (tecla/nome numa moldura) ou {"shape": "triangle"} (desenho).
## Sem botão no aparelho atual, usa o do outro (R no controle, por exemplo).
static func glyph(action: String, on_pad := pad) -> Dictionary:
	var g := _pad_glyph(action) if on_pad else _key_glyph(action)
	if g.is_empty():
		g = _key_glyph(action) if on_pad else _pad_glyph(action)
	return g if not g.is_empty() else {"text": action.to_upper()}


static func _key_glyph(action: String) -> Dictionary:
	if not InputMap.has_action(action):
		return {}
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			return {"text": KEY_NAMES.get(k, OS.get_keycode_string(k).to_upper())}
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and MOUSE_NAMES.has(e.button_index):
			return {"text": MOUSE_NAMES[e.button_index]}
	return {}


static func _pad_glyph(action: String) -> Dictionary:
	if not InputMap.has_action(action):
		return {}
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			if PAD_SHAPES.has(e.button_index):
				return {"shape": PAD_SHAPES[e.button_index]}
			if PAD_NAMES.has(e.button_index):
				return {"text": PAD_NAMES[e.button_index]}
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and PAD_AXES.has(e.axis):
			return {"text": PAD_AXES[e.axis]}
	return {}


## Nó que acompanha o último aparelho usado (roda com o jogo pausado: menus e telas de inspeção também trocam).
class Watcher extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if event is InputEventJoypadButton and event.pressed:
			UiStyle.pad = true
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
			UiStyle.pad = true
		elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			UiStyle.pad = false
		elif event is InputEventMouseMotion and event.relative.length() > 4.0:
			UiStyle.pad = false


## Fileira de botões "<glifo> VERBO   <glifo> VERBO". `set_items` recebe [{"action": "interact", "text": "ABRIR"}, ...];
## "pad_action" troca a ação no controle (o R do teclado vira o triângulo); em vez de "action" um item pode trazer
## "keys" (molduras fixas do teclado, ex. ["0-9"]) e "pad" (desenho no controle, ex. "dpad"). O tamanho (`size`) acompanha o conteúdo; quem usa só posiciona (centralizar = (largura
## - size.x) / 2). Troca os glifos sozinha quando muda o aparelho.
class Hint extends Control:
	var items: Array = []
	var verb_color := UiStyle.INK
	var _pad := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func set_items(list: Array) -> void:
		if list == items and _pad == UiStyle.pad:
			return
		items = list.duplicate(true)
		_refresh()

	## Os verbos juntos (testes e capturas).
	func text() -> String:
		var parts: Array[String] = []
		for it: Dictionary in items:
			parts.append(it.get("text", ""))
		return "  ".join(parts)

	func _process(_delta: float) -> void:
		if _pad != UiStyle.pad:
			_refresh()

	func _refresh() -> void:
		_pad = UiStyle.pad
		size = Vector2(_layout(false), UiStyle.KEY_H + 2.0)
		queue_redraw()

	func _glyphs(it: Dictionary) -> Array:
		if _pad and it.has("pad_action"):
			return [UiStyle.glyph(it.pad_action, true)]
		if it.has("action"):
			return [UiStyle.glyph(it.action, _pad)]
		if _pad and it.has("pad"):
			return [{"shape": it.pad}]
		var out := []
		for k in it.get("keys", []):
			out.append({"text": k})
		return out

	func _draw() -> void:
		_layout(true)

	## Mede (e desenha, com `paint`) a fileira; devolve a largura.
	func _layout(paint: bool) -> float:
		var font := get_theme_default_font()
		var x := 1.0
		for i in items.size():
			var it: Dictionary = items[i]
			if i > 0:
				x += UiStyle.HINT_SPACE
			for g: Dictionary in _glyphs(it):
				x += _glyph(font, g, x, paint) + 2.0
			x += UiStyle.HINT_GAP - 2.0
			var verb: String = it.get("text", "")
			if paint:
				var at := Vector2(x, UiStyle.KEY_H - 2.0)
				draw_string_outline(font, at, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S, UiStyle.OUTLINE, Color.BLACK)
				draw_string(font, at, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S, verb_color)
			x += font.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S).x
		return ceilf(x + 1.0)

	## Um glifo em `x` (moldura com a tecla ou o desenho do botão); devolve a largura.
	func _glyph(font: Font, g: Dictionary, x: float, paint: bool) -> float:
		var h := UiStyle.KEY_H
		var col := UiStyle.ACTION
		if g.has("shape"):
			if paint:
				_shape(g.shape, Rect2(x, 0.0, h, h), col)
			return h
		var s: String = g.text
		var w := maxf(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S).x + 5.0, h)
		if paint:
			var box := Rect2(x, 0.0, w, h)
			draw_rect(box, UiStyle.KEY_FILL)
			draw_rect(box.grow(0.5), Color.BLACK, false, 2.0)
			draw_rect(box, col, false, 1.0)
			var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S).x
			draw_string(font, Vector2(x + roundf((w - tw) * 0.5), h - 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.S, col)
		return w

	## Botões do controle desenhados (a fonte não tem os símbolos): contorno preto por baixo, cor por cima.
	func _shape(shape: String, r: Rect2, col: Color) -> void:
		var c := r.get_center()
		var k := r.size.x * 0.5 - 1.0
		for pass_i in 2:
			var color := Color.BLACK if pass_i == 0 else col
			var width := 3.0 if pass_i == 0 else 1.2
			match shape:
				"triangle":
					var pts := PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, k * 0.8), c + Vector2(-k, k * 0.8), c + Vector2(0, -k)])
					draw_polyline(pts, color, width)
				"circle":
					draw_arc(c, k, 0.0, TAU, 16, color, width)
				"cross":
					draw_line(c + Vector2(-k, -k), c + Vector2(k, k), color, width)
					draw_line(c + Vector2(-k, k), c + Vector2(k, -k), color, width)
				"square":
					draw_rect(Rect2(c - Vector2(k, k) * 0.85, Vector2(k, k) * 1.7), color, false, width)
				"dpad":
					var a := k * 0.38
					var pts := PackedVector2Array([c + Vector2(-a, -k), c + Vector2(a, -k), c + Vector2(a, -a), c + Vector2(k, -a),
						c + Vector2(k, a), c + Vector2(a, a), c + Vector2(a, k), c + Vector2(-a, k), c + Vector2(-a, a),
						c + Vector2(-k, a), c + Vector2(-k, -a), c + Vector2(-a, -a), c + Vector2(-a, -k)])
					draw_polyline(pts, color, width)
