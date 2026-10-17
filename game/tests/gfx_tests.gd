extends RefCounted
## Testes do modo de visual (Gfx) e do atlas da heroína, chamados por run_tests.gd.

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_atlas()
	test_other_textures()
	await test_toggle()


func check(cond: bool, name: String, detail := "") -> void:
	t.check(cond, name, detail)


func test_atlas() -> void:
	var img: Image = (load("res://assets/characters/heroine_atlas.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	check(img.get_width() == 512 and img.get_height() == 512, "atlas da heroína 512x512", str(img.get_size()))
	# retângulos em unidades de layout (art/atlas.py) x 2
	var hair := Rect2i(0, 192, 256, 128)
	var face := Rect2i(256, 0, 256, 128)
	var cut := 0
	for y in range(hair.position.y, hair.end.y, 4):
		for x in range(hair.position.x, hair.end.x, 4):
			if img.get_pixel(x, y).a < 0.5:
				cut += 1
	check(cut > 50, "pontas do cabelo recortadas por alfa", str(cut))
	var holes := 0
	for y in range(face.position.y, face.end.y, 4):
		for x in range(face.position.x, face.end.x, 4):
			if img.get_pixel(x, y).a < 0.5:
				holes += 1
	check(holes == 0, "rosto sem buracos de alfa", str(holes))
	var magenta := 0
	for y in range(0, 512, 8):
		for x in range(0, 512, 8):
			var c := img.get_pixel(x, y)
			if c.r > 0.95 and c.g < 0.05 and c.b > 0.95:
				magenta += 1
	check(magenta == 0, "sem fundo magenta (não vaza com filtro linear)", str(magenta))


func _image(path: String) -> Image:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _has_magenta(img: Image, step := 8) -> bool:
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.r > 0.95 and c.g < 0.05 and c.b > 0.95:
				return true
	return false


func test_other_textures() -> void:
	var raptor := _image("res://assets/characters/raptor_atlas.png")
	check(raptor.get_size() == Vector2i(512, 512), "atlas do raptor 512x512", str(raptor.get_size()))
	check(not _has_magenta(raptor), "atlas do raptor sem fundo magenta")
	for n in ["concrete", "wall", "crate", "hazard"]:
		var tex := load("res://assets/textures/%s.png" % n) as Texture2D
		check(tex.get_width() == 256 and tex.get_height() == 256, "textura do cenário %s 256x256" % n, str(tex.get_size()))
		check(tex.get_image().has_mipmaps(), "textura do cenário %s com mipmaps (filtro do PS2)" % n)


func _shaders(root: Node) -> Array:
	var out := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var mats := [mi.material_override]
		for i in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(i))
		for m in mats:
			if m is ShaderMaterial:
				out.append(m)
	return out


func test_toggle() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(2, 1, 2), Vector3(0, -0.5, 0), "concrete")
	var lamp := OmniLight3D.new()
	lamp.add_to_group("lamps")
	w.add_child(lamp)
	var m := HeroineModel.new()
	w.add_child(m)
	var r := RaptorModel.new()
	w.add_child(r)
	await t._frames(3)
	var ps2: Array = Gfx.SHADERS["ps2"]
	var ps1: Array = Gfx.SHADERS["ps1"]
	Gfx.set_mode("ps2", w)
	var mats := _shaders(w)
	check(mats.size() > 3, "materiais encontrados", str(mats.size()))
	check(mats.all(func(x: ShaderMaterial) -> bool: return x.shader in ps2), "PS2: todos os materiais trocam de shader")
	check(mats.all(func(x: ShaderMaterial) -> bool: return x.get_shader_parameter("albedo_tex") != null), "PS2: textura mantida na troca")
	check(lamp.shadow_enabled, "PS2: lâmpadas fazem sombra")
	var hero := _shaders(m)
	check(hero.size() > 0 and is_equal_approx(float(hero[0].get_shader_parameter("rim")), 0.35), "PS2: contorno de luz nos personagens")
	Gfx.set_mode("ps1", w)
	mats = _shaders(w)
	check(mats.all(func(x: ShaderMaterial) -> bool: return x.shader in ps1), "PS1: volta aos shaders de PS1")
	check(not lamp.shadow_enabled, "PS1: sem sombras")
	await test_toggle_twice_keeps_params()
	await test_toggle_during_raptor_attack()
	await test_fx_after_toggle()
	await test_bite_ragdoll_finite()


## Trocar de modo duas vezes mantém os parâmetros dos materiais (texturas).
func test_toggle_twice_keeps_params() -> void:
	var w: Node3D = await t._fresh_world()
	var m := HeroineModel.new()
	w.add_child(m)
	var r := RaptorModel.new()
	w.add_child(r)
	await t._frames(3)
	var initial_mode := Gfx.mode
	# captura as texturas antes
	var mats := _shaders(w)
	var tex_before := []
	for mat in mats:
		tex_before.append(mat.get_shader_parameter("albedo_tex"))
	# primeiro toggle
	Gfx.set_mode("ps1" if initial_mode == "ps2" else "ps2", w)
	await t._frames(2)
	# segundo toggle: volta
	Gfx.set_mode(initial_mode, w)
	await t._frames(2)
	# texturas devem ser preservadas
	var mats_after := _shaders(w)
	check(mats_after.size() == mats.size(), "mesmo número de materiais após toggle duplo")
	for i in mini(mats_after.size(), tex_before.size()):
		var tex_after = mats_after[i].get_shader_parameter("albedo_tex")
		check(tex_after == tex_before[i], "textura preservada no material %d após toggle duplo" % i)


## Trocar de modo enquanto o raptor está atacando não trava o jogo.
func test_toggle_during_raptor_attack() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = Vector3(0, 0, 4)
	w.add_child(p)
	var r := Raptor.new()
	r.target = p
	r.position = Vector3(0, 0, 0)
	r.rotation.y = PI
	w.add_child(r)
	await t._frames(10)
	# ataque: salto
	r.start_leap()
	await t._frames(5)
	var mode_before := Gfx.mode
	Gfx.set_mode("ps1" if mode_before == "ps2" else "ps2", w)
	check(r.state == "leap_prep", "toggle durante prep do salto não muda o estado do raptor")
	await t._frames(20)
	# verifica que o ataque continua (pode ter acertado ou errado, mas não travou)
	check(r.state == "leap" or r.state == "recover", "salto prossegue após toggle", r.state)
	Gfx.set_mode(mode_before, w)
	# raptor morto vira ragdoll
	r.take_hit(999, Vector3.FORWARD, r.global_position + Vector3.UP)
	await t._frames(5)
	check(r.dead and r.model.is_ragdoll(), "raptor morto vira ragdoll")
	Gfx.set_mode("ps1" if mode_before == "ps2" else "ps2", w)
	await t._frames(30)
	var hips: PhysicalBone3D = r.model.ragdoll.bodies["Hips"]
	var pos := hips.global_position
	check(is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z), "toggle durante ragdoll do raptor: sem NaN", str(pos))


## Fx (efeitos de tiro) criados após toggle de visual funcionam.
func test_fx_after_toggle() -> void:
	var w: Node3D = await t._fresh_world()
	var initial := Gfx.mode
	Gfx.set_mode("ps1" if initial == "ps2" else "ps2", w)
	await t._frames(2)
	# cria os efeitos (muzzle flash, tracer, impact)
	Fx.muzzle_flash(w, Vector3(0, 1.5, 0))
	Fx.tracer(w, Vector3(0, 1.5, 0), Vector3(0, 1.5, -5))
	Fx.impact(w, Vector3(0, 1, -5), false)
	await t._frames(2)
	# os efeitos são StandardMaterial3D unshaded (não ShaderMaterial), então não são afetados pelo modo
	var fx_count := 0
	for ch in w.get_children():
		if ch is MeshInstance3D or (ch is Node3D and ch.get_child_count() > 0):
			fx_count += 1
	check(fx_count >= 2, "efeitos criados após toggle", str(fx_count))
	Gfx.set_mode(initial, w)


## Ragdoll da heroína após mordida e após reshape do corpo continua finito.
func test_bite_ragdoll_finite() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = Vector3(0, 0, 4)
	w.add_child(p)
	var r := Raptor.new()
	r.target = p
	r.position = Vector3(0, 0, 2.2)
	r.rotation.y = PI
	w.add_child(r)
	await t._frames(10)
	r.start_bite()
	await t._frames(int(Raptor.BITE_SNAP * 60) + 5)
	check(p.grabbed, "mordida agarra")
	check(p.model.is_ragdoll(), "mordida vira ragdoll")
	await t._frames(40)
	var bodies := p.model.ragdoll.bodies
	var finite := true
	for b: PhysicalBone3D in bodies.values():
		var pos := b.global_position
		if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)):
			finite = false
			break
	check(finite, "ragdoll da heroína durante mordida sem NaN (após reshape do corpo)")
	# verifica o braço preso
	var arm: PhysicalBone3D = bodies[Player.BITTEN_BONE]
	var mouth: Node3D = r.model.skeleton.find_child("Mouth", true, false)
	if mouth:
		var dist := arm.global_position.distance_to(mouth.global_position)
		check(dist < 0.5, "braço preso perto da boca", "%.2f" % dist)
	# força soltar para não travar
	p.struggle = 999
	await t._frames(20)
	check(not p.grabbed, "solta com struggle alto")
