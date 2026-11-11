class_name Soundscape
extends Node
## Som de fundo e avisos de furtividade: ambiente em loop de cada sala (galpão: zumbido e ar parado; pátio da mata:
## vento, grilos e pássaro), misturando os dois perto da porta conforme o lado em que ela está, e os avisos quando
## um inimigo muda de atenção (Enemy.alert_level): "?" quando um desconfia (e o raptor pia perguntando). Entrar em
## caça/combate não toca aviso nenhum (o acorde "alert" foi tirado: com muitos inimigos virava barulho); só o "!" curto
## sobre a cabeça (`Enemy._update_marker`).

const FADE := 3.0  # metros, em volta da porta, em que um ambiente vira o outro
const SUSPICIOUS_GAP := 1.5

@export var target: Player

var yard: AudioStreamPlayer
var warehouse: AudioStreamPlayer
var _levels := {}  # inimigo -> último alert_level
var _suspicious_t := 0.0


func _ready() -> void:
	yard = _loop("amb_yard")
	warehouse = _loop("amb_warehouse")
	_mix()


func _loop(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = name
	p.stream = Sfx.stream(name)
	add_child(p)
	p.play()
	return p


## Quanto do pátio da mata se ouve (0 = dentro do galpão, 1 = lá fora): a parede da porta fica em Yard.X_NEAR. Dentro do
## túnel da mina volta o abafado de lugar fechado (o mesmo do galpão), com a mesma passagem nas duas bocas.
func yard_mix() -> float:
	if target == null:
		return 0.0
	var x := target.global_position.x
	var k := clampf((Yard.X_NEAR + FADE * 0.5 - x) / FADE, 0.0, 1.0)
	var inside := clampf(minf(Tunnel.X_NEAR + FADE * 0.5 - x, x - Tunnel.X_FAR + FADE * 0.5) / FADE, 0.0, 1.0)
	return k * (1.0 - inside)


func _mix() -> void:
	var k := yard_mix()
	yard.volume_db = float(Sfx.SOUNDS.amb_yard.db) + linear_to_db(maxf(k, 0.001))
	warehouse.volume_db = float(Sfx.SOUNDS.amb_warehouse.db) + linear_to_db(maxf(1.0 - k, 0.001))


func _physics_process(delta: float) -> void:
	_mix()
	_suspicious_t -= delta
	var now := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("alert_level"):
			continue
		var lv: int = e.alert_level()
		var before: int = _levels.get(e, 0)
		now[e] = lv
		if lv == 1 and before == 0:
			if e is Raptor:
				Sfx.play(e, "raptor_suspicious", e.model.mouth_position())
			if _suspicious_t <= 0.0 and not e.get("voice"):  # quem fala diz o "Ahn?" (Voice); o toque é só dos bichos
				_suspicious_t = SUSPICIOUS_GAP
				Sfx.ui(self, "suspicious")
	_levels = now
