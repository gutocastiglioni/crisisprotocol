class_name Crosshair
extends Control
## Mira de quando ela aponta a arma (jeito Syphon Filter): uma cruz com um retângulo no meio. O retângulo é feito de dois
## colchetes "[ ]" nas laterais e um tracinho no meio da borda de cima e da de baixo; os braços da cruz saem do meio de
## cada borda para fora (os verticais atravessam um pouco o tracinho) e crescem junto com o retângulo.
## O tamanho é o que o tiro pode acertar visto da câmera: um alvo de TARGET_R m de raio na distância do ponto mirado
## (perto = maior, longe = menor) mais o cone em que o próximo tiro sai (`Player.aim_spread`: a arma, os tiros seguidos
## e andando), os dois projetados pela lente da câmera. O tamanho corre para o novo valor (SMOOTH), sem pular.
## Cor: verde sem alvo, vermelha sobre um inimigo vivo, cinza se o tiro bate antes num obstáculo.
## Camada sem escala do HUD (ancorada no centro da tela); `ui_scale` = altura da resolução interna / 240.

const TARGET_R := 0.4  # m: meia altura do que o retângulo enquadra no ponto mirado (cabeça e tronco)
const RATIO := 1.8  # largura / altura do retângulo
const MIN_HALF := 5.0  # meia altura em unidades de 240
const MAX_HALF := 28.0
const NEAR := 0.5  # m: distância mínima da conta (o raio da câmera ignora o que está a menos de 2 m)
const SMOOTH := 14.0  # por segundo
# desenho, em frações da meia largura (w) / meia altura (h) do retângulo, medido na mira do Syphon Filter
const SERIF := 0.35  # pé dos colchetes, para dentro (× w)
const MID := 0.33  # meio tracinho de cima e de baixo (× w)
const ARM_H := 1.0  # braço horizontal da cruz para fora (× w)
const ARM_V := 1.1  # braço vertical para fora (× h)
const ARM_IN := 0.15  # o braço vertical entra no retângulo, cruzando o tracinho (× h)
const FREE := Color(0.4, 1.0, 0.4)
const ON_TARGET := Color(1.0, 0.25, 0.2)
const BLOCKED := Color(0.55, 0.55, 0.55)

var player: Player
var ui_scale := 2.0
var half := 0.0  # meia altura agora (pixels da resolução interna)
var goal := 0.0  # meia altura para onde corre
var color := FREE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## Distância focal da câmera em pixels da tela (a lente com KEEP_HEIGHT mede o fov na altura).
static func focal(cam: Camera3D, screen: Vector2) -> float:
	var span := screen.y if cam.keep_aspect == Camera3D.KEEP_HEIGHT else screen.x
	return span * 0.5 / tan(deg_to_rad(cam.fov * 0.5))


## Meia altura (pixels) do alvo de TARGET_R a `dist` m somado ao cone de `spread` graus, pela lente `f`.
static func half_size(dist: float, spread: float, f: float) -> float:
	return f * (TARGET_R / maxf(dist, NEAR) + tan(deg_to_rad(spread)))


func update(delta: float, on: bool) -> void:
	var was := visible
	visible = on and player != null
	if not visible:
		return
	var info: Dictionary = player.aim_target_info()
	color = (BLOCKED if info.blocked else ON_TARGET) if info.has_target else FREE
	var cam := player.camera_rig.camera
	var at: Vector3
	if info.has_target:
		at = info.target_pos
	else:
		var skip: Array[RID] = [player.get_rid()]
		skip.append_array(player.model.ragdoll.body_rids())
		at = player.camera_rig.aim_point(skip)
	var dist := cam.global_position.distance_to(at)
	var f := focal(cam, get_viewport_rect().size)
	goal = clampf(half_size(dist, player.aim_spread(), f), MIN_HALF * ui_scale, MAX_HALF * ui_scale)
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
	# sombra um pixel abaixo/à direita: a mira não some no chão claro nem no céu
	for pass_i in 2:
		var o := c + (Vector2(line, line) if pass_i == 0 else Vector2.ZERO)
		var col := Color(0, 0, 0, 0.45) if pass_i == 0 else color
		for sg: Array in segs:
			draw_line(o + sg[0], o + sg[1], col, line)
