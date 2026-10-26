class_name DangerMeter
extends HudBar
## Sensor de perigo (jeito Syphon Filter): o quanto é provável ela levar tiro ou golpe agora. Cada inimigo diz a sua
## chance (`Enemy.threat`: soldado pela chance da rajada acertar, sniper pela mira com laser, bichos pelo golpe ao
## alcance) e o sensor junta tudo como "pelo menos um acerta" = 1 - produto(1 - chance). A barra sobe rápido (RISE)
## e desce devagar (FALL), mas esquivando/rolando cai depressa (DODGE_FALL): nada a acerta enquanto isso. Continua
## avaliando o tempo todo: terminou a esquiva ainda na mira, volta a subir. De WARN para cima pisca, vermelho, com "!!".

const SEGMENTS := 10
const WARN := 0.7
const RISE := 3.0  # por segundo
const FALL := 0.8
const DODGE_FALL := 5.0
const TITLE := "PERIGO"

var player: Player
var raw := 0.0  # chance de agora, sem suavizar


func _init() -> void:
	super(TITLE, 60.0, SEGMENTS)
	colors = [[0.4, Color(0.45, 0.9, 0.4)], [0.7, Color(1.0, 0.82, 0.25)], [1.0, Color(1.0, 0.25, 0.2)]]
	value = 0.0


## Chance de pelo menos um inimigo acertá-la agora (0..1).
static func sample(tree: SceneTree) -> float:
	var safe := 1.0
	for e: Enemy in tree.get_nodes_in_group("enemies"):
		safe *= 1.0 - e.threat()
	return 1.0 - safe


func update(delta: float) -> void:
	raw = sample(get_tree())
	var rate := RISE if raw > value else (DODGE_FALL if player and player.is_dodging() else FALL)
	value = move_toward(value, raw, rate * delta)
	blink = value >= WARN
	tail = "!!" if blink else ""
	title_color = Color(1.0, 0.3, 0.25) if blink else TEXT


func reset() -> void:
	raw = 0.0
	value = 0.0
	blink = false
	tail = ""
	title_color = TEXT
