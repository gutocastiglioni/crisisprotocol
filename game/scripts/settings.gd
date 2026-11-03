class_name Settings
## Preferências do jogador guardadas na máquina (`user://settings.cfg`, fora do projeto): a tela cheia e a vibração do
## controle, trocadas no menu de pausa e usadas ao abrir o jogo (`main._ready`; capturas `--capture` ficam sempre na janela).

const SECTION := "video"
const INPUT_SECTION := "input"

static var path := "user://settings.cfg"  # os testes trocam para não mexer na config de verdade
static var fullscreen := false
static var vibration := true  # `Rumble`


## Lê o arquivo (sem arquivo ou com erro = padrão: janela, com vibração).
static func load_file() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(path) == OK
	fullscreen = ok and bool(cfg.get_value(SECTION, "fullscreen", false))
	vibration = not ok or bool(cfg.get_value(INPUT_SECTION, "vibration", true))


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # mantém o que já existir no arquivo
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(INPUT_SECTION, "vibration", vibration)
	var err := cfg.save(path)
	if err != OK:
		push_warning("não deu para salvar %s (erro %d)" % [path, err])


## Põe a janela no modo guardado (janela maximizada continua maximizada).
static func apply() -> void:
	var now := DisplayServer.window_get_mode()
	var is_full := now in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Troca a tela cheia, aplica na hora e salva.
static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_file()


## Liga/desliga a vibração e salva; ligar dá um toque para mostrar, desligar para o que estiver vibrando.
static func set_vibration(on: bool) -> void:
	vibration = on
	if on:
		Rumble.pulse(0.5, 0.5, 0.25)
	else:
		Rumble.stop()
	save_file()
