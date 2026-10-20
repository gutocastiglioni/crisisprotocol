class_name PlayerStealth
extends RefCounted
## Furtividade da jogadora: o quanto ela aparece para os inimigos (`visibility`, 0..1: multiplica o alcance da visão
## deles; agachada, devagar, parada ou no capim alto = menos) e o barulho dos passos (raptors e soldados ouvem pelo
## grupo "enemies"). Tiros e cambalhota fazem barulho pela própria Player (make_noise) e a deixam visível (`shot`).

const RUN_NOISE_SPEED := 2.5  # acima disto os passos são de corrida
const LOUD_TIME := 1.5  # depois de atirar, o clarão e o estampido a deixam bem visível por este tempo
const STEP_TIME := 0.3
const COVER_GROUP := "cover"  # capim alto (Yard): nó com meta "radius"; dentro dele ela é vista de menos longe
const ASSASSINATE_PROMPT := "ABATE FURTIVO DISPONIVEL (ATIRAR)"
const CRIT_PROMPT := "GOLPE CRITICO DISPONIVEL (ATIRAR)"

var visibility := 0.7
var loud_t := 0.0
var step_t := 0.0
var p: Player
var _last_prompt := ""


func _init(player: Player) -> void:
	p = player


## Atirou: o clarão a deixa bem visível por LOUD_TIME.
func shot() -> void:
	loud_t = LOUD_TIME


func update(delta: float) -> void:
	loud_t = maxf(loud_t - delta, 0.0)
	step_t -= delta
	var silent_move := p.moves.mode in ["assassinate", "crit_strike"]
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	var moving := speed > 0.3 and p.is_on_floor() and not p.grabbed and not p.dead
	if moving and step_t <= 0.0 and not p.rolling and p.moves.mode != "dodge" and not silent_move:
		step_t = STEP_TIME
		if p.crouching:
			p.make_noise(2.0, 0.25)
		elif speed < RUN_NOISE_SPEED:
			p.make_noise(4.0, 0.3)
		else:
			p.make_noise(10.0, 0.5)
	var v := 0.7  # parada em pé
	if p.crouching:
		v = 0.45 if moving else 0.3
	elif speed >= RUN_NOISE_SPEED:
		v = 1.0
	elif moving:
		v = 0.75
	if p.rolling or loud_t > 0.0 or (p.moves.busy() and not silent_move):
		v = 1.0
	# capim alto cobre mais quem está agachada
	if in_cover():
		v *= 0.5 if p.crouching else 0.8
	visibility = maxf(v, 0.1)
	var cur := prompt()
	if cur != "" and cur != _last_prompt:
		p.notice.emit(cur)
	_last_prompt = cur


## Inimigo (soldado ou velociraptor; nunca o alossauro) ao alcance para abate furtivo ou golpe crítico sem mirar, ou null.
func target() -> Node3D:
	if p == null or not p.is_inside_tree() or p.dead or p.grabbed or p._down_t > 0.0 or p.is_dazed() or p._stun > 0.0 or p.moves.busy():
		return null
	if p.aiming or Input.is_action_pressed("aim"):
		return null
	var best: Node3D = null
	var best_d := INF
	for node in p.get_tree().get_nodes_in_group("enemies") + p.get_tree().get_nodes_in_group("dummies"):
		var e := node as Node3D
		if e == null or bool(e.get("dead")) or not (e is Soldier or e is Raptor or e is TargetDummy):
			continue
		if e.can_crit_strike(p) or e.can_assassinate(p):
			var d := p.global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


## Instrução para o HUD quando o abate furtivo ou o golpe crítico está disponível ("" = nenhum).
func prompt() -> String:
	var e := target()
	if e == null:
		return ""
	return CRIT_PROMPT if e.can_crit_strike(p) else ASSASSINATE_PROMPT


## Tenta executar o abate furtivo ou golpe crítico no inimigo ao alcance; devolve true se iniciou o golpe.
func try_strike() -> bool:
	var e := target()
	if e == null:
		return false
	if e.can_crit_strike(p):
		p.moves.start_crit_strike(e)
	else:
		p.moves.start_assassinate(e)
	return true


func in_cover() -> bool:
	for c: Node3D in p.get_tree().get_nodes_in_group(COVER_GROUP):
		var flat := c.global_position - p.global_position
		flat.y = 0.0
		if flat.length() < float(c.get_meta("radius", 0.0)):
			return true
	return false
