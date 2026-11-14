class_name Settings
## Preferências do jogador guardadas na máquina (`user://settings.cfg`, fora do projeto): a tela cheia, o volume geral e a
## vibração do controle, trocados na tela OPÇÕES (`OptionsScreen`, do menu inicial e da pausa) e usados ao abrir o jogo
## (`main._ready`; capturas `--capture` ficam sempre na janela e no volume cheio).
## Também as cenas (`Cutscene`) já vistas até o fim uma vez: dali em diante dá para pular.

const SECTION := "video"
const INPUT_SECTION := "input"
const PROGRESS_SECTION := "progress"
const AUDIO_SECTION := "audio"
const VOLUME_STEPS := 10  # o volume anda de 10 em 10%

static var path := "user://settings.cfg"  # os testes trocam para não mexer na config de verdade
static var fullscreen := false
static var vibration := true  # `Rumble`
static var volume := 1.0  # volume geral (barramento Master), 0..1
static var cutscenes_seen: Array = []  # nomes das cenas (Cutscene.scene) vistas até o fim
static var loaded := false  # só grava depois de ler (capturas não leem: não sobrescrevem a config de verdade)


## Lê o arquivo (sem arquivo ou com erro = padrão: janela, volume cheio, com vibração).
static func load_file() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(path) == OK
	fullscreen = ok and bool(cfg.get_value(SECTION, "fullscreen", false))
	vibration = not ok or bool(cfg.get_value(INPUT_SECTION, "vibration", true))
	volume = clampf(float(cfg.get_value(AUDIO_SECTION, "volume", 1.0)), 0.0, 1.0) if ok else 1.0
	cutscenes_seen = Array(cfg.get_value(PROGRESS_SECTION, "cutscenes_seen", [])) if ok else []
	loaded = true


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # mantém o que já existir no arquivo
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(INPUT_SECTION, "vibration", vibration)
	cfg.set_value(AUDIO_SECTION, "volume", volume)
	cfg.set_value(PROGRESS_SECTION, "cutscenes_seen", cutscenes_seen)
	var err := cfg.save(path)
	if err != OK:
		push_warning("não deu para salvar %s (erro %d)" % [path, err])


## Põe a janela no modo guardado (janela maximizada continua maximizada) e o volume guardado.
static func apply() -> void:
	apply_volume()
	var now := DisplayServer.window_get_mode()
	var is_full := now in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Troca a tela cheia, aplica na hora e salva.
static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_file()


## Volume geral no barramento Master (todo som do jogo passa por ele); 0 = mudo.
static func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


static func volume_percent() -> int:
	return roundi(volume * 100.0)


## Troca o volume geral (0..1), aplica na hora e salva.
static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply_volume()
	save_file()


## Liga/desliga a vibração e salva; ligar dá um toque para mostrar, desligar para o que estiver vibrando.
static func set_vibration(on: bool) -> void:
	vibration = on
	if on:
		Rumble.pulse(0.5, 0.5, 0.25)
	else:
		Rumble.stop()
	save_file()


static func cutscene_seen(name: String) -> bool:
	return name in cutscenes_seen


## A cena `name` foi vista até o fim: guarda (no arquivo, se ele foi lido) para as próximas vezes poderem ser puladas.
static func mark_cutscene_seen(name: String) -> void:
	if name in cutscenes_seen:
		return
	cutscenes_seen.append(name)
	if loaded:
		save_file()
