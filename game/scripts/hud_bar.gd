class_name HudBar
extends Control
## Barra do HUD (unidades de 320x240, ampliada com ele): título à esquerda, barra com moldura preta e `tail` (o valor
## em número, um aviso) à direita. `segments` > 0 = blocos separados (sensor de perigo); 0 = barra cheia (vida).
## A cor de cada pedaço vem de `colors` (limites crescentes: [até, cor], ...). `blink` pisca a barra e o título.

const FONT_SIZE := 8
const TITLE_W := 34.0
const BAR_H := 5.0
const DIM := Color(0.08, 0.1, 0.08, 0.85)
const TEXT := Color(0.85, 0.9, 0.8)

var title := ""
var value := 1.0  # 0..1
var tail := ""  # escrito depois da barra, na cor dela
var bar_w := 60.0
var segments := 0
var colors: Array = [[1.0, Color(0.4, 0.95, 0.45)]]
var title_color := TEXT
var blink := false
var _t := 0.0


func _init(text := "", width := 60.0, blocks := 0) -> void:
	title = text
	bar_w = width
	segments = blocks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(TITLE_W + bar_w + 22.0, 10.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Cor do pedaço da barra na altura `at` (0..1).
func color_at(at: float) -> Color:
	for c: Array in colors:
		if at <= c[0]:
			return c[1]
	return colors[-1][1]


func _draw() -> void:
	var font := get_theme_default_font()
	var off := blink and fmod(_t, 0.3) < 0.15  # piscando: metade do tempo apagada
	var y := FONT_SIZE - 1.0
	draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color.BLACK)
	draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, title_color if not off else title_color.darkened(0.6))
	var box := Rect2(TITLE_W, 1.0, bar_w, BAR_H)
	draw_rect(box.grow(1.0), Color.BLACK)
	draw_rect(box, DIM)
	var v := clampf(value, 0.0, 1.0)
	if segments > 0:
		var w := (bar_w - (segments - 1)) / segments
		for i in segments:
			var at := float(i + 1) / segments
			if at - 0.5 / segments > v:
				break
			var c := color_at(at)
			draw_rect(Rect2(box.position.x + i * (w + 1.0), box.position.y, w, BAR_H), c.darkened(0.55) if off else c)
	elif v > 0.0:
		var c := color_at(v)
		draw_rect(Rect2(box.position, Vector2(maxf(roundf(bar_w * v), 1.0), BAR_H)), c.darkened(0.55) if off else c)
		# brilho de cima: cara de barra de jogo antigo, não de retângulo chapado
		draw_rect(Rect2(box.position, Vector2(maxf(roundf(bar_w * v), 1.0), 1.0)), c.lightened(0.35))
	if tail != "" and not off:
		var p := Vector2(TITLE_W + bar_w + 4.0, y)
		draw_string_outline(font, p, tail, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color.BLACK)
		draw_string(font, p, tail, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color_at(v))
