class_name Soundscape
extends Node
## Som de fundo e avisos de furtividade: ambiente em loop de cada sala (galpão: zumbido e ar parado; pátio da mata:
## vento, grilos e pássaro), misturando os dois perto da porta conforme o lado em que ela está, e os avisos quando
## um inimigo muda de atenção (Enemy.alert_level): "?" quando um desconfia (e o raptor pia perguntando) e o acorde de
## "visto!" quando o primeiro entra em caça/combate.

const FADE := 3.0  # metros, em volta da porta, em que um ambiente vira o outro
const ALERT_GAP := 3.0  # segundos mínimos entre dois acordes de "visto!"
const SUSPICIOUS_GAP := 1.5

@export var target: Player

var yard: AudioStreamPlayer
var warehouse: AudioStreamPlayer
var _levels := {}  # inimigo -> último alert_level
var _alert_t := 0.0
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


## Quanto do pátio da mata se ouve (0 = dentro do galpão, 1 = lá fora): a parede da porta fica em Yard.X_NEAR.
func yard_mix() -> float:
	if target == null:
		return 0.0
	return clampf((Yard.X_NEAR + FADE * 0.5 - target.global_position.x) / FADE, 0.0, 1.0)


func _mix() -> void:
	var k := yard_mix()
	yard.volume_db = float(Sfx.SOUNDS.amb_yard.db) + linear_to_db(maxf(k, 0.001))
	warehouse.volume_db = float(Sfx.SOUNDS.amb_warehouse.db) + linear_to_db(maxf(1.0 - k, 0.001))


func _physics_process(delta: float) -> void:
	_mix()
	_alert_t -= delta
	_suspicious_t -= delta
	var was_hunted := false
	for lv: int in _levels.values():
		was_hunted = was_hunted or lv >= 2
	var now := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("alert_level"):
			continue
		var lv: int = e.alert_level()
		var before: int = _levels.get(e, 0)
		now[e] = lv
		if lv >= 2 and not was_hunted and _alert_t <= 0.0:
			_alert_t = ALERT_GAP
			was_hunted = true
			Sfx.ui(self, "alert")
		elif lv == 1 and before == 0:
			if e is Raptor:
				Sfx.play(e, "raptor_suspicious", e.model.mouth_position())
			if _suspicious_t <= 0.0:
				_suspicious_t = SUSPICIOUS_GAP
				Sfx.ui(self, "suspicious")
	_levels = now
