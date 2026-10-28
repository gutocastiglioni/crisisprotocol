extends RefCounted
## Testes do design system (UiStyle): glifos dos botões pelo mapa de controles e pelo último aparelho usado, fileira de
## botões (Hint) e a caixa de texto das telas de inspeção sem nada se sobrepor.
## Chamado por run_tests.gd (usa check/_frames de lá).

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	test_glyphs()
	test_watcher()
	await test_hint()
	await test_inspect_box()
	test_no_loose_styles()
	UiStyle.pad = false


func test_glyphs() -> void:
	t.check(UiStyle.glyph("interact", false) == {"text": "E"}, "teclado: pegar = E", str(UiStyle.glyph("interact", false)))
	t.check(UiStyle.glyph("interact", true) == {"shape": "triangle"}, "controle: pegar = triângulo", str(UiStyle.glyph("interact", true)))
	t.check(UiStyle.glyph("shoot", false) == {"text": "MOUSE E"} and UiStyle.glyph("shoot", true) == {"text": "R1"},
		"atirar = MOUSE E / R1", "%s %s" % [UiStyle.glyph("shoot", false), UiStyle.glyph("shoot", true)])
	t.check(UiStyle.glyph("pause", false) == {"text": "ESC"} and UiStyle.glyph("pause", true) == {"text": "START"}, "pausa = ESC / START")
	t.check(UiStyle.glyph("crouch", true) == {"shape": "circle"} and UiStyle.glyph("zoom_in", true) == {"shape": "cross"},
		"agachar = bola, aumentar zoom = X do controle")
	t.check(UiStyle.glyph("reset", true) == {"text": "R"}, "sem botão no controle: mostra a tecla (R)", str(UiStyle.glyph("reset", true)))


func test_watcher() -> void:
	var w := UiStyle.Watcher.new()
	UiStyle.pad = false
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_Y
	b.pressed = true
	w._input(b)
	t.check(UiStyle.pad, "apertou botão do controle: glifos do controle")
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 0.1
	UiStyle.pad = false
	w._input(m)
	t.check(not UiStyle.pad, "analógico parado (zona morta) não troca o aparelho")
	UiStyle.pad = true
	var k := InputEventKey.new()
	k.physical_keycode = KEY_E
	k.pressed = true
	w._input(k)
	t.check(not UiStyle.pad, "apertou tecla: volta para os glifos do teclado")
	w.free()


func test_hint() -> void:
	UiStyle.pad = false
	var h := UiStyle.Hint.new()
	t.get_root().add_child(h)
	h.set_items([{"action": "interact", "text": "ABRIR PORTA"}, {"action": "shoot", "text": "ABATE FURTIVO"}])
	var kb := h.size
	t.check(h.text() == "ABRIR PORTA  ABATE FURTIVO" and kb.x > 60.0 and kb.y == UiStyle.KEY_H + 2.0, "fileira com dois botões", "%s %s" % [h.text(), kb])
	UiStyle.pad = true
	await t._frames(1)
	t.check(h.size.x != kb.x, "trocou para o controle: os glifos mudam sozinhos", "%s -> %s" % [kb, h.size])
	UiStyle.pad = false
	h.queue_free()
	await t.process_frame


## Caixa de baixo: título longe do topo, botões no pé, texto no meio; com texto comprido a caixa cresce sem sobrepor.
func test_inspect_box() -> void:
	var ins := Inspect.new()
	t.get_root().add_child(ins)
	var area := Vector2(320, 240)
	for body in ["Curto.", "Linha um.\n\nLinha três.\nLinha quatro.", "Um texto comprido que precisa quebrar em várias linhas porque passa da largura da caixa de texto e não pode passar por cima de nada."]:
		ins._text("PEGOU: TESTE", body)
		var top := ins._layout_box(area)
		var title_bottom := ins._title.position.y + ins._title.get_combined_minimum_size().y
		var body_top := ins._body.position.y
		var body_bottom := body_top + ins._body.size.y
		var text_h := ins._body.get_combined_minimum_size().y
		t.check(ins._title.position.y - top >= Inspect.BOX_PAD and title_bottom <= body_top and body_bottom <= ins._ok.position.y
			and text_h <= ins._body.size.y + 0.5 and ins._band.position.y + ins._band.size.y <= area.y,
			"caixa sem sobreposição (%d linhas)" % ins._body.get_line_count(),
			"top %d título %d..%d texto %d..%d (%d) botões %d" % [top, ins._title.position.y, title_bottom, body_top, body_bottom, text_h, ins._ok.position.y])
		var mid := (ins._ok.position.x + ins._ok.size.x * 0.5)
		t.check(absf(mid - area.x * 0.5) <= 1.0, "botões centralizados", str(mid))
	ins._keypad_text("DIGITE O CÓDIGO")
	ins._layout_box(area)
	t.check(ins._ok.visible and ins._ok.text() == "ESCOLHER  CONFIRMAR  SAIR" and ins._body.text == "", "teclado: botões no pé da caixa", ins._ok.text())
	t.check(ins._title.get_theme_font_size("font_size") == UiStyle.M, "título da caixa no tamanho M")
	ins.queue_free()
	await t.process_frame


## Nenhuma tela monta rótulo com tamanho/cor soltos: tudo sai do UiStyle.
func test_no_loose_styles() -> void:
	var loose: Array[String] = []
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd") or f == "ui_style.gd":
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		for bad in ['"font_size", 8)', '"font_size", 24)', "Color(0.85, 0.9, 0.8)", "Color(0.4, 1.0, 0.5)", "Color(1.0, 0.85, 0.3)"]:
			if bad in src:
				loose.append("%s: %s" % [f, bad])
	t.check(loose.is_empty(), "textos usam os tokens do UiStyle", str(loose))
