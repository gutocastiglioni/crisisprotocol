class_name SniperScope
extends CanvasLayer
## Overlay de mira telescópica da Sniper (Sniper Scope).
## Apresenta visor óptico circular (shader), retículo balístico com mil-dots e marcações BDC,
## indicador digital de zoom (2.0x / 4.0x / 8.0x / 16.0x), telemetria de distância em metros
## e prompt de controle conforme padrão PlayStation: X aumenta e O diminui o zoom.

const SHADER := preload("res://shaders/sniper_scope.gdshader")

var _root: Control
var _mask_rect: ColorRect
var _mask_mat: ShaderMaterial
var _reticle: Control
var _label_zoom: Label
var _label_range: Label
var _label_prompt: Label
var _active := false
var _blocked := false


func _init() -> void:
	layer = 1
	_build_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SniperScopeRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# 1. Máscara circular com lente óptica
	_mask_rect = ColorRect.new()
	_mask_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_mat = ShaderMaterial.new()
	_mask_mat.shader = SHADER
	_mask_rect.material = _mask_mat
	_root.add_child(_mask_rect)

	# 2. Retículo desenhado em canvas
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_on_reticle_draw)
	_root.add_child(_reticle)

	# 3. Informações de telemetria da mira
	_label_zoom = _create_label("ZOOM: 2.0x", Color(0.4, 1.0, 0.4))
	_label_range = _create_label("DIST: --- m", Color(1.0, 0.85, 0.3))
	_label_prompt = _create_label("[X] AUMENTA   [O] DIMINUI", Color(0.85, 0.9, 0.8))


func _create_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func update_scope(active: bool, zoom_label: String, target_dist: float, blocked := false) -> void:
	_active = active
	_blocked = blocked
	_root.visible = active
	if not active:
		return

	var vp := _root.get_viewport_rect().size
	if vp.y <= 0:
		return

	# Atualiza aspecto no shader
	var aspect := vp.x / vp.y
	_mask_mat.set_shader_parameter("aspect", aspect)

	# Atualiza telemetria
	_label_zoom.text = "ZOOM: %s" % zoom_label
	if target_dist > 0.0 and target_dist < 120.0:
		_label_range.text = "DIST: %.1f m" % target_dist
	else:
		_label_range.text = "DIST: > 120 m" if target_dist >= 120.0 else "DIST: --- m"

	# Posicionamento proporcional ao visor circular
	var center := vp * 0.5
	var r := vp.y * 0.42

	# Telemetria acima do visor
	_label_zoom.position = Vector2(roundf(center.x - r * 0.85), roundf(center.y - r * 0.88))
	_label_range.position = Vector2(roundf(center.x + r * 0.85 - _label_range.size.x), roundf(center.y - r * 0.88))

	# Prompt na base do visor
	_label_prompt.position = Vector2(roundf(center.x - _label_prompt.size.x * 0.5), roundf(center.y + r * 0.82))

	_reticle.queue_redraw()


func _on_reticle_draw() -> void:
	if not _active:
		return

	var vp := _root.get_viewport_rect().size
	var center := vp * 0.5
	var r := vp.y * 0.42
	var gap := 6.0

	var col_dark := Color(0.12, 0.12, 0.14, 0.95)
	var col_shadow := Color(0.9, 1.0, 0.9, 0.25)
	var col_red := Color(1.0, 0.2, 0.15, 0.95)

	# Eixos principais (horizontal e vertical com folga no centro)
	# Linha horizontal
	_reticle.draw_line(center - Vector2(r * 0.95, 0), center - Vector2(gap, 0), col_dark, 1.5)
	_reticle.draw_line(center + Vector2(gap, 0), center + Vector2(r * 0.95, 0), col_dark, 1.5)
	# Linha vertical
	_reticle.draw_line(center - Vector2(0, r * 0.95), center - Vector2(0, gap), col_dark, 1.5)
	_reticle.draw_line(center + Vector2(0, gap), center + Vector2(0, r * 0.95), col_dark, 1.5)

	# Mil-dots / marcações nos eixos horizontais
	for i in range(1, 5):
		var dx: float = r * 0.18 * i
		if dx < r * 0.9:
			var tick_h := 3.5 if i % 2 == 0 else 2.0
			_reticle.draw_line(center + Vector2(dx, -tick_h), center + Vector2(dx, tick_h), col_dark, 1.0)
			_reticle.draw_line(center - Vector2(dx, tick_h), center - Vector2(dx, -tick_h), col_dark, 1.0)

	# Marcações balísticas verticais (BDC para compensação de queda)
	for j in range(1, 5):
		var dy: float = r * 0.15 * j
		if dy < r * 0.9:
			var w := 3.0 + j * 1.5
			_reticle.draw_line(center + Vector2(-w, dy), center + Vector2(w, dy), col_dark, 1.0)

	# Ponto iluminado de precisão no centro exato
	var dot_col := Color(0.55, 0.55, 0.55) if _blocked else col_red
	_reticle.draw_circle(center, 2.0, dot_col)
	_reticle.draw_circle(center, 0.9, Color(0.8, 0.8, 0.8, 1.0) if _blocked else Color(1.0, 0.8, 0.7, 1.0))

	# Quadrantes de enquadramento (cantos táticos em 45 graus)
	var bdc_r := r * 0.65
	var arc_len := 0.14
	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		_reticle.draw_arc(center, bdc_r, angle - arc_len, angle + arc_len, 8, col_shadow, 1.0)
