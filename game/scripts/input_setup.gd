class_name InputSetup
## Registra os controles em código (teclado/mouse + controle). Pode ser chamado mais de uma vez.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"walk": [KEY_SHIFT],
	"sprint": [KEY_SHIFT],
	"walk_slow": [KEY_ALT],
	"roll": [KEY_SPACE],
	"jump": [KEY_F],
	"interact": [KEY_E],
	"switch_weapon": [KEY_Q, KEY_TAB],
	"crouch": [KEY_C, KEY_CTRL],
	"reset": [KEY_R],
	"pause": [KEY_ESCAPE],
	"zoom_in": [KEY_X, KEY_SPACE],
	"zoom_out": [KEY_O, KEY_C],
	"debug_hit": [KEY_H],
	"debug_kill": [KEY_K],
	"toggle_help": [KEY_F1],
	"toggle_gfx": [KEY_F2],
	"toggle_mode": [KEY_F3],
}
const MOUSE := {
	"aim": MOUSE_BUTTON_RIGHT,
	"shoot": MOUSE_BUTTON_LEFT,
	"zoom_in": MOUSE_BUTTON_WHEEL_UP,
	"zoom_out": MOUSE_BUTTON_WHEEL_DOWN,
}
# posições do controle de PlayStation: A = X, B = bola, X = quadrado, Y = triângulo, BACK = Select
const JOY_BUTTONS := {
	"roll": JOY_BUTTON_A,
	"zoom_in": JOY_BUTTON_A,
	"zoom_out": JOY_BUTTON_B,
	"crouch": JOY_BUTTON_B,
	"jump": JOY_BUTTON_X,
	"interact": JOY_BUTTON_Y,
	"switch_weapon": JOY_BUTTON_BACK,
	"aim": JOY_BUTTON_LEFT_SHOULDER,
	"shoot": JOY_BUTTON_RIGHT_SHOULDER,
	"pause": JOY_BUTTON_START,  # menu de pausa (reiniciar fica lá dentro; no teclado R segue reiniciando)
	"sprint": JOY_BUTTON_LEFT_STICK,
}
# ação: [eixo, sentido]
const JOY_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"shoot": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


static func register() -> void:
	var actions := {}
	for d in [KEYS, MOUSE, JOY_BUTTONS, JOY_AXES]:
		for a in d:
			actions[a] = true
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
	for a in KEYS:
		for k in KEYS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			_add(a, e)
	for a in MOUSE:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE[a]
		_add(a, m)
	for a in JOY_BUTTONS:
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTONS[a]
		_add(a, b)
	for a in JOY_AXES:
		var j := InputEventJoypadMotion.new()
		j.axis = JOY_AXES[a][0]
		j.axis_value = JOY_AXES[a][1]
		_add(a, j)


static func _add(action: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)
