class_name Settings
## Preferências do jogador guardadas na máquina (`user://settings.cfg`, fora do projeto): por enquanto só a tela cheia,
## trocada no menu de pausa e usada ao abrir o jogo (`main._ready`; capturas `--capture` ficam sempre na janela).

const SECTION := "video"

static var path := "user://settings.cfg"  # os testes trocam para não mexer na config de verdade
static var fullscreen := false


## Lê o arquivo (sem arquivo ou com erro = padrão: janela).
static func load_file() -> void:
	var cfg := ConfigFile.new()
	fullscreen = cfg.load(path) == OK and bool(cfg.get_value(SECTION, "fullscreen", false))


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # mantém o que já existir no arquivo
	cfg.set_value(SECTION, "fullscreen", fullscreen)
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
