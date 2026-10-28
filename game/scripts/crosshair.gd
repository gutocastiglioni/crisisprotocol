class_name Crosshair
extends Control
## Mira de quando ela aponta a arma (jeito Syphon Filter): uma cruz com um retângulo no meio. O retângulo é feito de dois
## colchetes "[ ]" nas laterais e um tracinho no meio da borda de cima e da de baixo; os braços da cruz saem do meio de
## cada borda para fora (os verticais atravessam um pouco o tracinho) e crescem junto com o retângulo.
## Tamanho dinâmico: meia altura = AREA_R m na distância do que está sob ela (inimigo ou cenário), pela lente da câmera
## (perto = maior, longe = menor), entre MIN_HALF e LOOSE_MAX, mais o cone em que o próximo tiro sai (`Player.aim_spread`:
## a arma, os tiros seguidos e andando). Focada num inimigo (o mesmo, com o tiro livre) ela vai fechando em FOCUS_TIME até
## FOCUS_HALF; saiu dele ou ele trocou, abre de novo. O tamanho corre para o novo valor (SMOOTH), sem pular.
## Na cabeça de quem tem headshot (`Player.body_part` = "Head", `Player._has_headshot`) sai do canto de cima uma linha
## até a palavra HEADSHOT.
## Cor: verde sem alvo, vermelha sobre um inimigo vivo, cinza se o tiro bate antes num obstáculo.
## Camada sem escala do HUD (ancorada no centro da tela); `ui_scale` = altura da resolução interna / 240.

const AREA_R := 0.3  # m: meia altura do que ela enquadra no ponto mirado
const RATIO := 1.8  # largura / altura do retângulo
const MIN_HALF := 3.5  # meia altura em unidades de 240
const LOOSE_MAX := 20.0  # sem foco, antes da dispersão
const MAX_HALF := 28.0
const FOCUS_HALF := 4.0  # fechada num inimigo
const FOCUS_TIME := 0.6  # s focada nele até fechar
const NEAR := 0.5  # m: distância mínima da conta
const SMOOTH := 14.0  # por segundo
# desenho, em frações da meia largura (w) / meia altura (h) do retângulo, medido na mira do Syphon Filter
const SERIF := 0.35  # pé dos colchetes, para dentro (× w)
const MID := 0.33  # meio tracinho de cima e de baixo (× w)
const ARM_H := 1.0  # braço horizontal da cruz para fora (× w)
const ARM_V := 1.1  # braço vertical para fora (× h)
const ARM_IN := 0.15  # o braço vertical entra no retângulo, cruzando o tracinho (× h)
# linha do HEADSHOT (unidades de 240): diagonal do canto de cima à direita, depois reta sob a palavra
const HEAD_RISE := 9.0
const HEAD_TEXT := "HEADSHOT"
const FREE := UiStyle.ACTION
const ON_TARGET := UiStyle.DANGER
const BLOCKED := UiStyle.MUTED

var player: Player
var ui_scale := 2.0
var half := 0.0  # meia altura agora (pixels da resolução interna)
var goal := 0.0  # meia altura para onde corre
var color := FREE
var head := false  # mirando a cabeça de quem tem headshot
var focus_t := 0.0  # s focada no mesmo inimigo
var _focus_on: Node = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## Distância focal da câmera em pixels da tela (a lente com KEEP_HEIGHT mede o fov na altura).
static func focal(cam: Camera3D, screen: Vector2) -> float:
	var span := screen.y if cam.keep_aspect == Camera3D.KEEP_HEIGHT else screen.x
	return span * 0.5 / tan(deg_to_rad(cam.fov * 0.5))


## Meia altura (pixels) de um alvo de `r` m a `dist` m, pela lente `f`.
static func area_size(dist: float, r: float, f: float) -> float:
	return f * r / maxf(dist, NEAR)


## Meia altura (pixels) que o cone de `spread` graus soma, pela lente `f`.
static func spread_size(spread: float, f: float) -> float:
	return f * tan(deg_to_rad(spread))


func update(delta: float, on: bool) -> void:
	var was := visible
	visible = on and player != null
	if not visible:
		_focus_on = null
		focus_t = 0.0
		return
	var info: Dictionary = player.aim_target_info()
	var target: Node = info.target if info.has_target and not info.blocked else null
	head = target != null and Player._has_headshot(target) \
		and player.body_part(target, info.target_pos, player.camera_rig.aim_ray()[1]) == "Head"
	color = (BLOCKED if info.blocked else ON_TARGET) if info.has_target else FREE
	if target != null and target == _focus_on:
		focus_t += delta
	else:
		_focus_on = target
		focus_t = 0.0
	var cam := player.camera_rig.camera
	var at: Vector3
	if info.has_target:
		at = info.target_pos
	else:
		var skip: Array[RID] = [player.get_rid()]
		skip.append_array(player.model.ragdoll.body_rids())
		at = player.camera_rig.aim_point(skip)
	var f := focal(cam, get_viewport_rect().size)
	var base := clampf(area_size(cam.global_position.distance_to(at), AREA_R, f), MIN_HALF * ui_scale, LOOSE_MAX * ui_scale)
	if target != null:
		base = lerpf(base, minf(base, FOCUS_HALF * ui_scale), smoothstep(0.0, FOCUS_TIME, focus_t))
	goal = minf(base + spread_size(player.aim_spread(), f), MAX_HALF * ui_scale)
	half = goal if not was else lerpf(half, goal, 1.0 - exp(-SMOOTH * delta))
	queue_redraw()


func _draw() -> void:
	var c := (size * 0.5).round()
	var h := roundf(half)
	var w := roundf(half * RATIO)
	var line := maxf(1.0, roundf(ui_scale * 0.75))
	var serif := roundf(w * SERIF)
	var mid := roundf(w * MID)
	var arm_h := roundf(w * ARM_H)
	var arm_v := roundf(h * ARM_V)
	var arm_in := maxf(line, roundf(h * ARM_IN))
	var segs := [
		# colchetes [ ]
		[Vector2(-w, -h), Vector2(-w, h)], [Vector2(-w, -h), Vector2(-w + serif, -h)], [Vector2(-w, h), Vector2(-w + serif, h)],
		[Vector2(w, -h), Vector2(w, h)], [Vector2(w, -h), Vector2(w - serif, -h)], [Vector2(w, h), Vector2(w - serif, h)],
		# tracinhos no meio de cima e de baixo
		[Vector2(-mid, -h), Vector2(mid, -h)], [Vector2(-mid, h), Vector2(mid, h)],
		# braços da cruz
		[Vector2(0, -h - arm_v), Vector2(0, -h + arm_in)], [Vector2(0, h - arm_in), Vector2(0, h + arm_v)],
		[Vector2(-w - arm_h, 0), Vector2(-w, 0)], [Vector2(w, 0), Vector2(w + arm_h, 0)],
	]
	var font := get_theme_default_font()
	var fs := int(UiStyle.S * ui_scale)
	var text_at := Vector2.ZERO
	if head:
		# do canto de cima à direita sobe uma diagonal e corre uma reta sob a palavra
		var rise := roundf(HEAD_RISE * ui_scale)
		var tw := font.get_string_size(HEAD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var knee := Vector2(w + rise, -h - rise)
		segs.append([Vector2(w, -h), knee])
		segs.append([knee, knee + Vector2(tw + 2.0 * line, 0)])
		text_at = c + knee + Vector2(line, -2.0 * line)
	# sombra um pixel abaixo/à direita: a mira não some no chão claro nem no céu
	for pass_i in 2:
		var o := c + (Vector2(line, line) if pass_i == 0 else Vector2.ZERO)
		var col := Color(0, 0, 0, 0.45) if pass_i == 0 else color
		for sg: Array in segs:
			draw_line(o + sg[0], o + sg[1], col, line)
	if head:
		draw_string_outline(font, text_at, HEAD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.OUTLINE * int(ui_scale), Color.BLACK)
		draw_string(font, text_at, HEAD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
