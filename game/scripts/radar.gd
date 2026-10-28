class_name Radar
extends Control
## Radar do HUD (canto de cima à direita, unidades de 320x240 ampliadas com ele): quadrado centrado nela e girado com
## a câmera (para cima = para onde a câmera olha), com o contorno das salas (galpão, sala dos clones, pátio, pedreira)
## e as portas (verde aberta, amarela fechada, vermelha trancada). Inimigo só aparece depois que ela o avista uma vez
## (`spot`: na tela, a até SPOT_RANGE m, com nada do cenário no meio); daí em diante o radar o rastreia onde estiver,
## com a cor do alerta dele (Enemy.alert_level). Fora do alcance fica preso na borda, apagado. Morto some; R esquece todos.
## Furtividade junto: o fundo e a moldura pulsam na cor do maior alerta dos inimigos (verde calmo, amarelo desconfiados,
## laranja busca ativa, vermelho alerta; mais rápido quanto pior) e embaixo vem um olho + VISIVEL/INVISIVEL e o estado.
## INVISIVEL = `Player.visibility()` até INVISIBLE_AT (agachada, capim alto) ou num lugar onde não a percebem (telhado,
## alto da escada), desde que nenhum inimigo esteja com ela à vista agora (`Enemy.has_eyes_on`). O olho fecha quando ela
## some, abre mais quanto mais ela aparece, olha para os lados na busca e fica vermelho e arregalado no alerta.

const SIZE := 50.0
const STATUS_H := 20.0  # faixa do olho e do estado embaixo do radar
const INVISIBLE_AT := 0.5
const STATES := ["", "DESCONFIADOS", "BUSCA ATIVA", "ALERTA!"]
const PULSE_HZ := [0.4, 0.9, 1.5, 2.6]  # pulsação da cor do alerta por nível
const HIDDEN_COLOR := Color(0.45, 0.95, 0.8)
const FONT_SIZE := UiStyle.S
const RANGE := 22.0  # m do centro até a borda
const SPOT_RANGE := 32.0
const RESET_HOLD := 0.3  # s depois do R sem avistar: a câmera ainda está voltando de onde estava
const BG := Color(0.0, 0.07, 0.03, 0.62)
const FRAME := Color(0.35, 0.85, 0.45, 0.9)
const WALL := Color(0.35, 0.8, 0.45, 0.55)
const ALERT_COLORS := [UiStyle.ACTION, UiStyle.ACCENT, UiStyle.WARN, UiStyle.DANGER]
const BLIP_CALM := Color(0.92, 0.95, 0.9)  # inimigo calmo: branco (o verde do alerta calmo some nas paredes)
## contorno das salas no chão (x, z, largura em x, comprimento em z)
const ROOMS := [
	Rect2(-Level.SIZE * 0.5, -Level.SIZE * 0.5, Level.SIZE, Level.SIZE),
	Rect2(-CloneLab.HALF_W, CloneLab.Z_FAR, CloneLab.HALF_W * 2.0, CloneLab.Z_NEAR - CloneLab.Z_FAR),
	Rect2(Yard.GATE_X, -Yard.Z_HALF, Yard.X_NEAR - Yard.GATE_X, Yard.Z_HALF * 2.0),
	Rect2(Arena.X_FAR, -Arena.Z_HALF, Arena.X_NEAR - Arena.X_FAR, Arena.Z_HALF * 2.0),
]

var player: Player
var seen := {}  # instance_id -> Enemy já avistado
var level := 0  # maior Enemy.alert_level dos inimigos
var unseen := false  # INVISIVEL
var _t := 0.0
var _hold := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(SIZE, SIZE + STATUS_H)


func update(delta: float) -> void:
	_t += delta
	_hold = maxf(_hold - delta, 0.0)
	if _hold <= 0.0:
		_spot_new()
	_update_stealth()
	queue_redraw()


## Alerta dos inimigos e se ela está escondida (ver o cabeçalho).
func _update_stealth() -> void:
	level = 0
	var watched := false
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		level = maxi(level, e.alert_level())
		watched = watched or e.has_eyes_on()
	unseen = false
	if player and not watched:
		unseen = player.visibility() <= INVISIBLE_AT or Roof.has(player.global_position) or player.moves.hidden_on_ladder()


func status_text() -> String:
	return "INVISÍVEL" if unseen else "VISÍVEL"


## 0..1 pulsando no ritmo do alerta.
func _pulse() -> float:
	return 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ[clampi(level, 0, 3)])


func reset() -> void:
	seen.clear()
	_hold = RESET_HOLD
	queue_redraw()


func is_tracked(e: Enemy) -> bool:
	return seen.has(e.get_instance_id()) and is_instance_valid(e) and not e.dead


## Avista os inimigos que ainda não conhece: na câmera de agora (a dela ou a de uma cena), perto e sem parede no meio.
func _spot_new() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or player == null:
		return
	var space := player.get_world_3d().direct_space_state
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.lurking or seen.has(e.get_instance_id()):
			continue
		var body := e.global_position + Vector3.UP * e.eye_height * 0.75
		if cam.global_position.distance_to(body) > SPOT_RANGE or not cam.is_position_in_frustum(body):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, body, 1)).is_empty():
			seen[e.get_instance_id()] = e


## Eixos do radar no chão: direita e frente da câmera (sem inclinação).
func _axes() -> Array[Vector3]:
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector3.FORWARD
	if cam:
		fwd = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	return [fwd.cross(Vector3.UP).normalized(), fwd]


func _to_radar(p: Vector3, axes: Array[Vector3]) -> Vector2:
	var rel := p - player.global_position
	return Vector2(rel.dot(axes[0]), -rel.dot(axes[1])) * (SIZE * 0.5 / RANGE) + Vector2(SIZE, SIZE) * 0.5


func _draw() -> void:
	var box := Rect2(0, 0, SIZE, SIZE)
	var tint: Color = ALERT_COLORS[clampi(level, 0, 3)]
	var k := _pulse()
	# fundo tingido pela cor do alerta, pulsando (calmo, quase parado)
	draw_rect(box, BG.lerp(Color(tint, BG.a), (0.08 if level == 0 else 0.22) * k + (0.0 if level == 0 else 0.08)))
	if player == null:
		return
	var axes := _axes()
	var c := Vector2(SIZE, SIZE) * 0.5
	# anéis de distância (a cada metade do alcance) e cruz fraca
	draw_arc(c, SIZE * 0.25, 0.0, TAU, 20, Color(WALL, 0.25), 1.0)
	draw_line(Vector2(c.x, 0), Vector2(c.x, SIZE), Color(WALL, 0.15))
	draw_line(Vector2(0, c.y), Vector2(SIZE, c.y), Color(WALL, 0.15))
	for r: Rect2 in ROOMS:
		var pts := [Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y),
			Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]
		for i in 4:
			_clipped_line(_to_radar(pts[i], axes), _to_radar(pts[(i + 1) % 4], axes), WALL)
	for d: Door in get_tree().get_nodes_in_group("doors"):
		var shape := d._col.shape as BoxShape3D if d._col else null
		if shape == null:
			continue
		var along := d.global_basis.x * shape.size.x if shape.size.x >= shape.size.z else d.global_basis.z * shape.size.z
		var col := UiStyle.ACTION if d.opened else (UiStyle.DANGER if d.is_locked() else UiStyle.ACCENT)
		_clipped_line(_to_radar(d.global_position - along * 0.5, axes), _to_radar(d.global_position + along * 0.5, axes), col, 2.0)
	# inimigos já avistados (a cor diz o alerta); fora do alcance, presos na borda e apagados
	for id in seen.keys():
		if not is_instance_valid(seen[id]):
			seen.erase(id)
			continue
		var e: Enemy = seen[id]
		if e.dead:
			continue
		var p := _to_radar(e.global_position, axes)
		var inside := box.grow(-2.0).has_point(p)
		var lv := clampi(e.alert_level(), 0, 3)
		var col: Color = BLIP_CALM if lv == 0 else ALERT_COLORS[lv]
		var half := 2.0 if e is Allosaurus else 1.5
		if not inside:
			p = p.clamp(Vector2(2, 2), box.size - Vector2(2, 2))
			col = Color(col, 0.55)
			half = 1.0
		draw_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), Color.BLACK)
		draw_rect(Rect2(p - Vector2(half - 0.5, half - 0.5), Vector2(half - 0.5, half - 0.5) * 2.0), col)
		if inside:
			var look := _to_radar(e.global_position - e.global_basis.z * 2.0, axes) - p
			draw_line(p, p + look.normalized() * (half + 2.5), col)
	# ela no meio: triângulo para onde está virada
	var f := _to_radar(player.global_position - player.global_basis.z, axes) - c
	f = f.normalized() if f.length() > 0.01 else Vector2.UP
	var s := Vector2(-f.y, f.x)
	# sem contorno: no PS1 (escala 1) o contorno de 1 px comia o triângulo
	var tri := PackedVector2Array([c + f * 5.0, c - f * 3.0 + s * 3.0, c - f * 3.0 - s * 3.0])
	draw_colored_polygon(tri, UiStyle.ACTION)
	# moldura na cor do alerta, pulsando
	draw_rect(box, Color(tint.lerp(Color.WHITE, 0.25 * k), 0.55 + 0.45 * k), false, 1.0)
	_draw_status(tint, k)


## Embaixo do radar: olho + VISIVEL/INVISIVEL e, abaixo, o estado dos inimigos (alinhados à direita do radar).
func _draw_status(tint: Color, k: float) -> void:
	var font := get_theme_default_font()
	var text := status_text()
	var col := HIDDEN_COLOR if unseen else (UiStyle.INK if level == 0 else tint)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var y := SIZE + 9.0
	_text(font, Vector2(SIZE - w, y), text, col)
	_draw_eye(Vector2(SIZE - w - 8.0, y - 3.0), tint, k)
	if level > 0:
		var st: String = STATES[level]
		var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		_text(font, Vector2(SIZE - sw, y + 9.0), st, Color(tint, 0.6 + 0.4 * k))


func _text(font: Font, at: Vector2, text: String, col: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)


## Olho de 11x7: fechado (cílios para baixo) escondida; aberto quanto mais ela aparece; na busca a íris vai de um
## lado ao outro; no alerta arregala e fica vermelha.
func _draw_eye(c: Vector2, tint: Color, k: float) -> void:
	var w := 5.5
	if unseen:
		var lid := PackedVector2Array()
		for i in 9:
			var x := -w + w * 2.0 * i / 8.0
			lid.append(c + Vector2(x, 1.5 * (1.0 - pow(x / w, 2.0))))
		draw_polyline(lid, Color.BLACK, 3.0)
		draw_polyline(lid, HIDDEN_COLOR, 1.0)
		for x: float in [-3.0, 0.0, 3.0]:
			var a := c + Vector2(x, 1.5 * (1.0 - pow(x / w, 2.0)))
			draw_line(a, a + Vector2(x * 0.25, 1.8), HIDDEN_COLOR, 1.0)
		return
	var vis := clampf(player.visibility() if player else 1.0, INVISIBLE_AT, 1.0)
	var open := remap(vis, INVISIBLE_AT, 1.0, 0.65, 1.0)
	if level == 3:
		open = 1.25
	var h := 3.0 * open
	var shape := PackedVector2Array()
	for i in 9:
		var x := -w + w * 2.0 * i / 8.0
		shape.append(c + Vector2(x, -h * (1.0 - pow(x / w, 2.0))))
	for i in range(7, 0, -1):
		var x := -w + w * 2.0 * i / 8.0
		shape.append(c + Vector2(x, h * 0.8 * (1.0 - pow(x / w, 2.0))))
	var lid_col := UiStyle.INK if level == 0 else tint
	draw_colored_polygon(shape, Color(0.05, 0.06, 0.05, 0.9))
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color.BLACK, 3.0)
	draw_polyline(outline, lid_col, 1.0)
	var look := 0.0
	if level == 2:
		look = sin(_t * 3.0) * w * 0.45  # procurando: olha de um lado ao outro
	elif level == 1:
		look = sin(_t * 1.2) * w * 0.2
	var iris := c + Vector2(look, 0.0)
	var r := clampf(h * 0.75, 1.2, 2.2)
	draw_circle(iris, r, UiStyle.DANGER.lerp(Color.WHITE, 0.3 * k) if level == 3 else lid_col)
	draw_circle(iris, r * (0.35 if level == 3 else 0.5), Color.BLACK)


## Linha recortada pelo quadrado do radar (Liang-Barsky): o desenho do Control não se recorta sozinho.
func _clipped_line(a: Vector2, b: Vector2, col: Color, width := 1.0) -> void:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for k in 4:
		var p: float = [-d.x, d.x, -d.y, d.y][k]
		var q: float = [a.x, SIZE - a.x, a.y, SIZE - a.y][k]
		if absf(p) < 1e-6:
			if q < 0.0:
				return
			continue
		var r := q / p
		if p < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)
		if t0 > t1:
			return
	draw_line(a + d * t0, a + d * t1, col, width)
