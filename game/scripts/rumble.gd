class_name Rumble
## Vibração do controle (todos os conectados), nos dois perfis. Quase tudo vem do tremor da câmera (`CameraRig.shake` chama
## `shake`: tiro de cada arma, rugido, empurrão, arremesso, presa na boca, explosão, queda, abate furtivo); o dano e a morte
## pedem `pulse` direto (`Player.take_hit`/`die`). Desligada em `Settings.vibration` (menu de pausa), nada vibra.
## Motor fraco = zumbido rápido; forte = pancada: tremor pequeno (pistola) só usa o fraco.

const MIN_TIME := 0.08  # mais curto que isso o motor nem chega a girar
const SHAKE_WEAK := 4.0  # fraco = WEAK_BASE + tremor × isto
const WEAK_BASE := 0.25
const STRONG_FROM := 0.05  # forte só acima deste tremor
const SHAKE_STRONG := 5.0

static var last := {}  # último pedido que chegou aos motores (testes): weak, strong, time
static var _weak := 0.0
static var _strong := 0.0
static var _until := 0  # ms


## Tremor da câmera de `strength` por `time` s convertido em vibração.
static func shake(strength: float, time: float) -> void:
	pulse(clampf(WEAK_BASE + strength * SHAKE_WEAK, 0.0, 1.0), clampf((strength - STRONG_FROM) * SHAKE_STRONG, 0.0, 1.0), time)


## Vibra `weak`/`strong` (0..1) por `time` s. Um pedido mais fraco não corta um mais forte que ainda está vibrando.
static func pulse(weak: float, strong: float, time: float) -> void:
	if not Settings.vibration or time <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var busy := now < _until
	_weak = maxf(weak, _weak) if busy else weak
	_strong = maxf(strong, _strong) if busy else strong
	_until = maxi(_until if busy else 0, now + int(maxf(time, MIN_TIME) * 1000.0))
	var left := (_until - now) / 1000.0
	last = {"weak": _weak, "strong": _strong, "time": left}
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, _weak, _strong, left)


## Para tudo (pausa, opção desligada).
static func stop() -> void:
	_until = 0
	_weak = 0.0
	_strong = 0.0
	for d in Input.get_connected_joypads():
		Input.stop_joy_vibration(d)
