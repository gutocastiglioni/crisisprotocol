# syphoncrisis

Protótipo de jogo no visual de PS2 do começo (com modo PS1 para comparar; Syphon Filter + Dino Crisis): heroína em
3ª pessoa, animações principais e ragdoll, e um velociraptor inimigo (estilo Dino Crisis 2).

## Stack
- Arte gerada por código: Blender 4.5 LTS (`bpy`, sem interface) + Pillow (`requirements.txt`) para as texturas.
- Sons gerados por código: numpy (`requirements.txt`), WAV mono 16 bits a 22050 Hz. Falas por TTS local (Piper), sem rede no jogo.
- `art/heroine.blend` e `art/raptor.blend` são gerados pelo build e ficam fora do git (guardavam caminhos absolutos da máquina).
- Jogo: Godot 4.7 (GDScript, Forward+, física Jolt). Projeto em `game/`.
- Sem backend, sem rede, sem dados pessoais.

## Pastas
- `art/` — gerador da heroína: `heroine_spec.py` (medidas/ossos), `heroine_mesh.py` (malha por anéis + UV + pesos),
  `heroine_rig.py` (esqueleto, materiais, marcador do cano), `heroine_anims.py` (animações em keyframes),
  `heroine_head.py` (cabeça esculpida de 16 lados, nariz; cabelo por `HAIR_STYLE`: "braid" = calota puxada + franja + trança única
  nas costas (retângulo "braid" do atlas, pintado em `paint_face.paint_braid`), "loose" = calota/franja/laterais/cortina com pontas por alfa),
  `build_heroine.py` (monta tudo e exporta), `solve_run.py` (resolve pernas/quadril da corrida para o pé de apoio não
  deslizar; imprime `RUN_HALF` para `heroine_anims.py` — rodar com `art/heroine.blend` ao mudar a pose da corrida), `preview.py` (renders de conferência, serve para os dois), `atlas.py` (layout da textura).
  `heroine_ik.py` (FK pelas matrizes de repouso + IK numérica), `heroine_gait.py` (caminhada, agachada e passos
  laterais com o pé de apoio preso no chão por IK), `heroine_moves.py` (cambalhota, pendurar, subir da
  borda, escalar obstáculo baixo, sair da escada pelo topo = LadderOut (mãos na beirada viradas para a frente, joelho na beira) e entrar = LadderIn (a mesma ao contrário; versões `Low` para beirada sem rebordo): poses + apoios presos + caminho da raiz), `heroine_jump.py` (pulo parado JumpUp, pulo projetado Jump, queda Fall e pouso Land com os pés presos, `_air_pose`/`_air_arms`), `heroine_strike.py` (golpes furtivos Assassinate/CritStrike, mesmo jeito), `heroine_rifle.py` (malha do M16, poses
  com o fuzil e a animação de pegar no baú), `heroine_shotgun.py` (malha da escopeta, telha à parte e a animação de
  tiro com coice e bombeamento), `heroine_m79.py` (malha do lança-granadas M79, cano octogonal, e a animação M79Shoot), `heroine_reload.py` (ReloadPistol/ReloadRifle: só a parte de cima, a arma deitada na frente do peito e a palma esquerda por IK no caminho do pente: solta, bolsa do cinto, encaixa, bate, ferrolho; quadros dos sons em heroine_moves.json "reload"), `heroine_drop.py` (PickupPistol = ajoelhada, a direita pega a pistola com silenciador na caixa de paraquedas; posição dela na caixa = `crate_frame`, exportada em `pistol_crate.glb`), `heroine_hurt.py` (golpes: HitFront/HitBack/HitL/HitR aditivas, StaggerBack/StaggerFwd, GetUpFront/GetUpBack com mãos/joelho/pés presos por IK), `heroine_cover.py` (CoverL/CoverR/CoverCrouchL/CoverCrouchR = encostada de costas na parede olhando para a esquerda/direita, glúteo e omoplatas no plano a `WALL` m atrás da raiz por IK; medidas em heroine_moves.json "cover"), `heroine_cutscene.py` (HatchOpen = abrir o
  alçapão do telhado, Shocked = o susto na sala dos clones, Surrender/SurrenderHold = rendida de mãos ao alto, braços por IK
  `SURRENDER_*`; quadros HATCH_GRAB/HATCH_UP usados pelo `hatch.gd`).
  Guerrilheiro (inimigo humano, de balaclava e colete; medidas da referência em `guerrilla_spec.py`, imagem em `art/ref/`):
  `guerrilla_body.py` (monta a pele única: tronco de moletom `BARE`, toco do ombro, união `_self_union`, braços e cabeça
  costurados; `PARTS` = o aprovado), `guerrilla_arms.py` (braços do modelo padrão `art/base_body`, manga medida),
  `guerrilla_head.py` (cabeça do modelo padrão em escala de homem, sem orelhas, pescoço encaixado no anel do tronco, vão
  do olho aberto), `guerrilla_paint.py` (balaclava, janela dos olhos com textura própria "Body_window" e a amêndoa do olho
  pintada no globo), `guerrilla_vest.py` (colete `CARRIER_*`: placas, alças com almofada, faixa, bolsas; peças unidas na
  pele), `guerrilla_lower.py` (calça e coturnos), `guerrilla_atlas.py` (layout dela + `cargo`/`cord`/`vest`),
  `build_guerrilla.py` (mesmo esqueleto/animações; gera `guerrilla.glb`; `-- <pasta> [partes]` = prévia; `art/guerrilla.blend` fica fora do git) e
  `tools/make_guerrilla_texture.py` (atlas 512 com o layout da heroína).
  Raptor: vem do modelo "PBR Velociraptor (Animated)" de Ferocious Industries (CC BY 4.0, `possible_models/velocirraptor/`,
  fora do git; crédito na tela de fim `main.CREDIT` e em `game/CREDITOS.txt`): `build_raptor.py` (com `raptor_import.py` =
  referência, malha e esqueleto, e `raptor_motion.py` = animações e medidas) deforma a malha dele até o
  primeiro quadro do Idle_01 (= repouso), leva ao nosso espaço (quadril a 0,93 m), monta o esqueleto com os nossos nomes
  (Hips, Spine, Chest, Neck1..3, Head, Jaw, Tail1..10, Pelvis/Hip/Thigh/Shin/Meta/Toe, Shoulder/Arm/Forearm/Hand, dedos,
  língua, olhos; 81 ossos), reduz a malha (~7900 triângulos), passa as animações dele quadro a quadro para esse esqueleto
  (30 fps; Idle, Walk, Run, Jog, Roar, Bite 2x, Hit, Death, CallAlert, Sniff, LeapPrep/LeapAir do Leap_01) e monta em cima
  delas as que ele não tem (`composed`: Stalk, Study, Shake, TailWhip/TailWhipR e a pose Embryo dos tubos), com a regra dos
  braços (`hands_down`). O objeto dele é voltado à posição inicial antes de cada animação (`HOME`; o salto e a morte o movem)
  e o quadril de cada uma começa no repouso. `raptor_paint.py` repinta a pele com as cores do jogo (paleta de
  `make_raptor_texture.py`; o relevo e a oclusão vêm da textura dele); olhos, dentes e garras ficam com a textura dele
  (`raptor_parts.png`, material "RaptorParts"). Mede o que o jogo usa (velocidade dos ciclos, quadros da boca) em
  `art/raptor_build.json`. `raptor_spec.py`/`raptor_mesh.py`/`raptor_rig.py`/`raptor_anims.py`/`raptor_atlas.py` (o
  gerador do raptor antigo) seguem como base do alossauro (IK, união booleana, ciclos `gait`).
  Alossauro (chefe, 9 m, mesmos ossos do raptor): `allosaurus_spec.py` (proporções da referência medida: quadril a 1,95 m,
  dorso ~2,6 m, crista ~3,1 m; juntas das pernas e dos braços = as medidas; `HEAD_LIFT` 0 = o medido fica na altura dela), `allosaurus_mesh.py`
  (tronco/cauda pelos anéis medidos `allosaurus_rings.body_rings`; pernas, braço e palma pelos cortes medidos `REF.LIMBS`
  postos nos nossos ossos, 12 lados), `allosaurus_head.py` (pescoço medido + crânio,
  mandíbula, fileira de dentes de cima por fora da mandíbula jeito Dino Crisis com gengiva atrás, chifres em lâmina
  (peça rígida), olho com aro de pálpebra, escultura da órbita e da barra pós-orbital), `allosaurus_rings.py` (anéis
  finais da cabeça/mandíbula, Python puro: a malha e a pintura usam os mesmos), `allosaurus_ref.py` (gerado por
  `tools/measure_allosaurus.py`: medidas e retopologia da referência "Alice" de `possible_models/`; nada da malha dela
  entra no jogo; atrás da boca o casco medido com a mandíbula, `HULL`; tronco `BODY`; juntas dos membros
  `JOINTS` tiradas da borda entre os ossos da pele, porque o esqueleto do arquivo dela veio torto), `allosaurus_anims.py` (IK do raptor recarregado com as medidas dele; quadros
  STOMP_HIT/BITE_SNAP/THROW_RELEASE/ROAR_PEAK usados pelo jogo), `build_allosaurus.py` (`art/allosaurus.blend` fora do git).
  `possible_models/` (modelos extraídos de jogos comerciais) é só referência local, fora do git: nada dali entra no jogo.
- `tools/` — `make_textures.py` (atlas 512x512 da heroína: corpo pintado em 256 e ampliado) + `paint_clothes.py` (trama,
  rugas, costuras, zíper em 512) + `paint_face.py` (rosto e cabelo em 512, preenchimento das bordas),
  `make_raptor_texture.py` (ferramentas de pintura e paleta do alossauro; o atlas do raptor sai do `build_raptor.py`), `make_allosaurus_texture.py` (atlas 1024 do alossauro com as mesmas ferramentas; cabeça/mandíbula pintadas pela
  posição 3D nos anéis de `allosaurus_rings`: mancha do olho e barra pós-orbital medidas na textura da referência,
  mandíbula e bloco da bochecha claros, listras do corpo jeito Dino Crisis 2 também no pescoço), `make_level_textures.py` (texturas 256x256 do cenário e dos baús,
  buracos de bala `bullet_holes.png`, quadros do clarão/fumaça `shot_fx.png` e do sangue `blood_fx.png`),
  `make_sounds.py` (efeitos sonoros em `game/assets/sounds/`; blocos de síntese em `sound_dsp.py`, vozes do raptor/avisos/
  ambientes em `sound_creatures.py`; as vozes do raptor são trechos de gravação real CC0 de `art/ref_sounds/` (T-rex = jacaré + leão + alce, fora do
  git, fonte em `LEIAME.txt`) com o tom subido por `sound_samples.py` e volume por RMS; sem a pasta vale a voz sintética de reserva),
  `make_voices.py` (falas dos guerrilheiros em `game/assets/voices/<voz>_<fala>_<n>.wav` por TTS local Piper, `pip install
  piper-tts`; vozes pt_BR cadu/faber/jeff, dataset CC0, em `art/voice_models/` fora do git, comando de baixar no cabeçalho;
  abafa como balaclava, satura as gritadas, volume por RMS; `LINES` tem que bater com `Voice.LINES`), `contact_sheet.py` / `game_sheet.py` (folhas de prévia), `run_godot_tests.mjs` (testes).
- `game/` — `scripts/` (jogadora + `player_moves.gd` + `player_stealth.gd` + esgueirar `player_lean.gd`/`lean_tilt.gd`, encostar `player_cover.gd`, inimigos `enemy.gd` (base) / `raptor.gd` / `soldier.gd`, câmera, modelo, ragdoll, alvos, raptor + modelo do raptor, granada da M79 `grenade.gd`, caixotes de explosivos `explosive_crate.gd` + fogo `fire.gd`, pés presos dos dinossauros `foot_plant.gd` + inércia ao virar `turn_sway.gd`, chave `key_item.gd`, telas de inspeção `inspect.gd`, cenário, galpão em seções `shed.gd` (grades, computadores `terminal.gd`, guardas da sala dos clones e reforços), pátio da mata `yard.gd` + trilha em S dele `forest_trail.gd` (trechos de raptors, portões de grade por seção),
  portas `door.gd` (galpão→pátio, pátio→túnel, túnel→pedreira arrombável), túnel da mina `tunnel.gd`, pedreira `arena.gd` (última sala) + alossauro `allosaurus.gd`/`allosaurus_model.gd`, telhado `roof.gd` + alçapão `hatch.gd` + caixa de paraquedas `supply_drop.gd`, sala dos clones `clone_lab.gd` + plaquetas dos tubos `subject_plate.gd`, cenas `cutscene.gd` (choque dos clones, emboscada do pátio, rendição aos snipers das torres, conversa do túnel e chegada à pedreira), mira laser do sniper `sniper_laser.gd` (+ `shaders/sniper_laser`/`laser_dot`), checkpoints `checkpoint.gd`, guerrilheiro morto `corpse.gd`, torres de guarda do portão do pátio `guard_tower.gd`, baú `chest.gd`, `moves.gd` (lê heroine_moves.json), efeitos `fx.gd` + sangue `blood.gd`, `gfx.gd`), `shaders/` (`psx_*` = PS1, `ps2_*` = PS2 do
  começo), `game_mode.gd` (perfil de jogo), `pickup.gd` (munição e kits no chão), `pause_menu.gd` (menu de pausa) + `showroom.gd` (palco dos dinossauros), HUD `hud_bar.gd` (barra) + `danger_meter.gd` (sensor de perigo) + `radar.gd` + `weapon_icon.gd` (modelo da arma), `tests/run_tests.gd` (+ `raptor_tests.gd`, `gfx_tests.gd`, `moves_tests.gd`, `weapons_tests.gd`, `ai_tests.gd`, `soldier_tests.gd`, `blood_tests.gd`, `allosaurus_tests.gd`, `survival_tests.gd`, `key_tests.gd`, `start_tests.gd`, `hurt_tests.gd`, `ambush_tests.gd`, `trail_tests.gd`, `shed_tests.gd`, `supply_drop_tests.gd`, `lab_gate_tests.gd`, `tower_tests.gd`, `pause_tests.gd`, `hud_tests.gd`, `console_tests.gd`, `lean_tests.gd`, `cover_tests.gd`, `explosive_tests.gd`, `tunnel_tests.gd`, `checkpoint_tests.gd`, `voice_tests.gd`), `assets/` (gerados — não
  editar à mão; inclui `m16.glb`/`shotgun.glb`/`m79.glb` = armas dos baús, `pistol_sd.glb` = pistola com silenciador sozinha, `pistol_crate.glb` = a mesma deitada na caixa e `heroine_moves.json` = caminhos/medidas dos movimentos).

## Comandos
- Regerar arte: `python tools/make_textures.py && python tools/make_sounds.py && python tools/make_voices.py && python tools/make_level_textures.py && python tools/make_allosaurus_texture.py && python tools/make_guerrilla_texture.py && blender --background --factory-startup --python art/build_heroine.py && blender --background --factory-startup --python art/build_raptor.py && blender --background --factory-startup --python art/build_allosaurus.py && blender --background --factory-startup --python art/build_guerrilla.py`
  (Blender em `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe`)
- Prévia no Blender: `blender --background art/heroine.blend --python art/preview.py -- <pasta> turntable|anims|Acao:f1,f2` (ou `art/raptor.blend`)
- Testes: `node tools/run_godot_tests.mjs` (passo fixo `--fixed-fps 60`: segundos em vez de minutos; o hook corta em 420 s).
  Só algumas partes: `node tools/run_godot_tests.mjs raptor ai` (nome = arquivo `*_tests.gd` sem o sufixo; `core` = os
  testes de dentro do `run_tests.gd`; tabela `SUITES` no `run_tests.gd`).
  Uma execução por vez na máquina: o runner faz fila (trava no temp do SO) e reaproveita o resultado de quem testou o mesmo
  `game/` (a suíte inteira que passou vale para qualquer parte); não esperar outra execução à mão. Saída 75 = a fila não andou
  em 180 s (o hook avisa "NÃO VERIFICADO" em vez de bloquear).
- CI (`.github/workflows/ci.yml`, a cada push na main e PR): só segredos no histórico (gitleaks) e esta suíte no Godot 4.7.2
  do Linux. Nada de etapa de web/backend (RLS, DAST, responsividade, semgrep/osv): não se aplicam ao jogo.
- Rodar o jogo: `godot --path game` (F2 alterna o visual PS1/PS2; `-- --gfx=ps2` já começa no PS2; F3 alterna o perfil SOBREVIVENCIA/ARCADE e reinicia; `-- --mode=arcade` já começa no arcade)
- Captura do jogo: `godot --path game -- --capture=out.png --shot=idle|aim|run|crouch|roll|ragdoll|dummy [--yaw=graus] [--at=segundos]`
  Rosto: `--shot=face [--yaw=graus]`. Visual: `--gfx=ps1|ps2`.
  Encostada na caixa: `--shot=cover|cover_crouch|cover_edge|cover_peek|cover_over` (atrás da fileira de caixas do T, V/L3 em 0,6 s; cover_edge anda de lado até a beirada; cover_peek anda até ela e mira em 2,8 s = esgueira; cover_over agacha, encosta e mira em 1,6 s = por cima se a caixa for baixa, com `--pos`).
  Mirando e andando de lado (câmera de 3/4 pela frente): `--shot=aim_strafe`.
  Movimentos: `--shot=walk|crouch_walk|crouch_aim|jump|hang|climb|mantle|pickup|rifle|rifle_aim|roll_side|jump_side` (roll_side/jump_side = cambalhota/pulos de lado, câmera parada, `--at` escolhe o quadro; jump_side: pulo parado em 0,4 s e projetado em 1,8 s).
  Armas: `--shot=pickup_shotgun|shotgun|shotgun_aim|fire_pistol|fire_m16|fire_shotgun|pump` (tiros na pilha de caixas;
  a captura imprime `buracos=`).
  Ela e o guerrilheiro lado a lado: `--shot=idle_compare|carry_compare|walk_compare [--yaw=graus]` (sem arma / M16 parados / M16 andando).
  Caixotes de explosivos (fundo do túnel): `--shot=crates|crates_fire|crates_ping|crates_close|crates_boom` (crates/crates_fire/crates_ping
  = da entrada da câmara do fundo mirando a primeira pilha do lado norte com a M79 / atirando nela, `--at` pega a cadeia / pistola no caixote =
  HARDENED; crates_close = câmera perto do guarda do detonador, `--yaw` gira, `--dist=m` afasta e mostra a câmara; crates_boom = a
  mesma com a granada estourando em 1 s e o fogo).
  Raptor: `--shot=raptor_roar|raptor_study|raptor_bite|raptor_tail|raptor_leap|raptor_charge|raptor_dead|raptor_idle [--playercam]`
  Sangue: `--shot=soldier_headshot|soldier_wounded|raptor_blood [--playercam]`.
  Container/chave/M79: `--shot=locked|unlock|corpse|key_get|m79_aim|fire_m79|pickup_m79` (locked/unlock/key_get salvam quando a
  tela de inspeção termina de aparecer; fire_m79 com `--at=0.9` pega a explosão; corpse = o morto com a chave, `--yaw` gira em volta).
  Emboscada: `--shot=ambush` (ela anda até o morto e a cena toca; `--at` escolhe o quadro: ~3 a mão, ~7 do alto, ~9,6 o rugido).
  Galpão de cima: `--shot=shed_map` (ortográfica abaixo do telhado, com a sala dos clones; as grades finas quase não aparecem
  de cima: conferir na altura dela com `--shot=yard --pos=x,z[,graus[,altura]]`).
  Trilha do pátio: `--shot=trail_map` (planta de cima, ortográfica, sul em cima e galpão à direita) e `--shot=yard --pos=x,z[,graus[,altura]]`
  (na altura dela; passar das linhas dos trechos solta os raptors; `--pos=-25,-4,180,3.5` = em cima do planalto); trecho saindo da mata:
  `--shot=walk --pos=-31.5,-38.2,180 --playercam --at=4.5`.
  Começo da fase: `--shot=roof|hatch|ladder_mount|ladder_out|ladder_roof|sniper_ladder|maze|mezz_climb|ladder_locked|gate|lab|clones` (hatch/ladder_mount/ladder_out/clones/sniper_ladder/mezz_climb: `--at` escolhe o quadro; mezz_climb = sobe pela caixa do nicho até o mezanino, câmera atrás, `--yaw` gira; ladder_locked salva no aviso da escada trancada).
  Sala dos clones e portão da pedreira: `--shot=tank|plate|plate_allo|keypad|keypad_on|keypad_ok|gate_open` (plate/plate_allo/
  keypad/keypad_on/keypad_ok salvam quando a tela aparece; keypad = sem o cartão; gate_open: `--at` escolhe o quadro).
  De perto, câmera parada: `--shot=clone` (o clone do primeiro tubo, `--yaw` gira, `--dist` afasta) e `--shot=chest_open --part=0|1|2|3`
  (baú da M16 / escopeta / container da M79 / caixa de paraquedas aberto visto de cima, a espuma com o vão da arma; `--empty` tira a
  arma e mostra só o vão; `--yaw`, `--dist`).
  `--pos=x,z[,graus[,altura]]` também vale nas capturas de movimento (`climb`, `mantle`...: sobe onde for posta).
  Torres do portão do pátio: `--shot=towers|tower_fall|gate_card` (towers = vistas da estrada com os snipers; tower_fall = o último
  cambaleia, debruça na cerca e cai, câmera de lado, `--at` escolhe o quadro, `--yaw` gira; gate_card = pega o cartão que ele derrubou).
  Rendição: `--shot=standoff|surrender_roll|surrender_aim|surrender_walk|surrender_run` (standoff = a cena, `--at`; as outras = cena
  pulada, rendida, em 3 s rola (tiros erram, mira de 5 s), mira (acertam), anda devagar de lado (lasers seguem) ou corre (acertam));
  `--shot=standoff_live` = a rendição sem cena da segunda vez (falas no HUD, `--at`). Game Over com checkpoint: `--shot=game_over_cp`. Laser do sniper do mezanino: `--shot=sniper_laser`
  (ela no chão do galpão, câmera de lado, `--yaw`, ou `--playercam`; `--at` escolhe o quadro da mira).
  Caixa de paraquedas: `--shot=drop [--dist=m]|drop_get|drop_pick|fire_sd` (drop_get salva quando a tela do item aparece; drop_pick = câmera de lado
  enquanto ela pega, `--at` escolhe o quadro, `--yaw` gira; fire_sd = tiro com silenciador).
  Golpes: `--shot=hit_crouch|stagger|getup|getup_fwd` (câmera de revisão de lado; getup = desaba de costas e levanta girando,
  getup_fwd = arremessada pelas costas, levanta de bruços; `--at` escolhe o quadro).
  Guarda do painel: `--shot=console` (atrás dele, só ele anda; `--pos` muda o lugar dela).
  HUD: `--shot=danger|danger_roll` (no galpão na mira dos guardas da porta do pátio; danger_roll rola em 2,6 s; `--at` escolhe o quadro).
  Túnel da mina: `--shot=tunnel|tunnel_mid|tunnel_far|tunnel_talk|tunnel_boom|lair` (tunnel = da boca; tunnel_mid = os 2 sentinelas do
  meio; tunnel_far = os 4 do fundo nos explosivos; tunnel_talk = cena da conversa, `--at`; tunnel_boom = arma o detonador e corre,
  explosão e portão arrombado em ~10,3 s, `--at`; lair = passa pelo portão arrombado e a cena do alossauro toca, `--at`).
  Alossauro: `--shot=allo_idle|allo_roar|allo_roar_at|allo_stomp|allo_headbutt|allo_tail|allo_bite|allo_dead|allo_end|allo_hop [--playercam]`; pedreira: `--shot=arena`.
  Mira nas proteções: `--shot=allo_aim --part=Head|Chest|Tail2|...` (de lado para ele) e `--shot=flak --part=Chest|Head` (sentinela da
  porta da sala dos clones); ela atira em 2 s e a proteção aparece na mira por 1 s: `--at=2.3`.
  Depois de regerar um .glb/.png, `godot --headless --path game --import` (rodar o jogo não reimporta sozinho).
  (a primeira execução depois de editar scripts reimporta o projeto e pode sair com a cena errada: rode de novo).

## Verificação e revisão (vale por cima da regra global e da skill `fullstack-feature`)
- A suíte inteira roda sozinha no hook (`.claude/hooks/stop-check.mjs`) no fim de todo turno que mudou código, `.gd`,
  `.gdshader` ou `.tscn` incluídos. Não rodar a suíte inteira na mão antes de encerrar (o hook repete); enquanto
  desenvolve, rodar só as partes mexidas (ver Comandos).
- Neste projeto NÃO chamar os agentes `e2e-qa`, `security-reviewer` nem `ui-verifier`: não há backend, rede, contas nem
  dados pessoais, e a suíte do Godot já prova o comportamento. "Pronto" = suíte do hook passando + capturas `--shot` da
  mudança olhadas por mim. O `security-reviewer` volta a valer se o jogo ganhar rede, salvamento online, contas ou loja.
- Capturas: só as `--shot` que mostram a mudança, na janela padrão 1280x720. A matriz de telas abaixo só para mudança de
  HUD, telas de inspeção ou pausa.

## Verificação visual
- Neste projeto NÃO testar nem capturar tela de celular em pé (retrato: 360/375/430 x ~800): gasta token e tempo à toa.
  Isso vale por cima da matriz de tamanhos da regra global e do agente `ui-verifier`. Conferir só nas telas deitadas
  (celular deitado ~1000x500, 720p, 1366x768, 1080p, 2K) e nas capturas `--shot` do jogo.

## Modelos de personagem (regras)
- **A referência é o contrato.** Quando o usuário manda uma imagem (num painel com vários bonecos, a referência é o
  primeiro, "REFERÊNCIA"), o modelo tem que ficar igual a ela, não "inspirado" nela. Antes de modelar, levantar da imagem
  a lista de parâmetros e escrever no código como constantes: proporções em fração da altura (largura de ombro, tronco,
  cintura, quadril, grossura de braço/coxa, comprimento de braço, abertura das pernas, tamanho da cabeça/capuz) e cada
  peça de roupa com forma, volume e cor (ex.: colete com espessura, borda e bolsas; moletom; capuz; calça; coturno).
  Cada item da lista tem que existir no modelo.
- **Comparar antes de entregar.** Renderizar o modelo na mesma pose, câmera e escala da referência (frente, lado e
  sobreposição do contorno) e comparar item por item, com números (silhueta faixa por faixa) e no olho (forma de cada peça,
  cor, contraste). Diferença visível = não está pronto; se não der para resolver, dizer qual é e por quê. Não basta bater o
  contorno: peça que na referência tem volume próprio (colete por cima do moletom, capuz) tem que ter volume no modelo, não
  só uma cor pintada.
- **Pele única.** Corpo e roupa são uma malha contínua e soldada (como o raptor: anel de emenda soldado + `_self_union`).
  Nada de boneco montado com pedaços encaixados: tronco de um modelo com calça de outro, capuz/colete como objeto solto
  encostado, bolsas de caixinhas. Só o que é rígido e preso a um osso só (arma, carregador) pode ser objeto à parte.
- **Nada de `possible_models/` no jogo**: dali só se mede e se olha; geometria e textura do jogo saem do nosso gerador.
  Exceção decidida pelo usuário: a calça, o cinto e os coturnos do guerrilheiro vêm de `possible_models/tr_guerilla.glb`
  (`art/guerrilla_lower.py`, alinhados aos ossos dele); o que importa ali é modelo e proporção, não o desenho dessas peças.
  Outra exceção decidida pelo usuário: o velociraptor é o modelo "PBR Velociraptor (Animated)" (CC BY 4.0, crédito
  obrigatório no jogo), com malha, UV, pesos, animações e a textura dos olhos/dentes/garras dele; a pele é repintada com
  as cores do jogo (`art/build_raptor.py`). As animações que ele não tem são as nossas, refeitas em cima do corpo dele.
- **Não polir por cima de modelo errado.** Se o personagem existente quebra estas regras, dizer isso primeiro e propor
  refazer, em vez de ajustar proporção/cor por cima.
- **Prévia antes de gravar.** Mudança estrutural no modelo: mostrar a prévia lado a lado com a referência e só gravar os
  .glb/.png do jogo depois do "ok" do usuário. Depois, conferir também no jogo (`--shot`), com a luz do jogo.

## Convenções
- Perfil de jogo (`GameMode`, padrão `survival`; F3 ou `--mode=arcade|survival`): **os dois perfis ficam vivos e testados**, nada do
  jogo de ação de antes foi apagado, para servir de base a outro jogo. `arcade` = o jogo de antes (câmera livre que volta atrás dela,
  munição infinita, tiro do quadril liga a mira temporária, inimigos com o dano base, sem itens). `survival` (RE4 Remake + Dino
  Crisis 2): câmera por cima do ombro direito (`CameraRig.SHOULDER`; não volta sozinha para trás dela; direcional para trás = anda de costas sem virar, `GameMode.back_walk`/`Player._backing`, a `BACK_WALK_SCALE` do andar, nunca corre: 1,35 m atrás, pivô na altura da cabeça, ela no terço esquerdo da coxa para cima; andando não troca de ombro; sem mirar o ombro vai para o lado aberto quando um lado da frente DELA fica fechado (`CameraRig.side`/`SIDE_*`, por `SIDE_HOLD`: leque de raios `SIDE_FAN` do peito pelo giro do corpo dela, `SIDE_WALL` m, `SIDE_BLOCKED`/`SIDE_OPEN`; o lado aberto dela vira ombro pela câmera, `SIDE_ALIGN`; a caixa na frente dela para um lado conta, parede reta na frente ou corredor não) e volta ao direito depois de `SIDE_RELAX`; girando a câmera para o lado dela na tela, uma mola puxa quase para o centro, afasta e abre o campo de visão (`SWING_*`), sem trocar de ombro, e volta ao parar; mirando sempre o direito; mirando 1,1 m; coice `kick`; nas ações (`Player.camera_action` = modo do `PlayerMoves` em `CameraRig.ACTIONS`: alçapão, porta abrindo; pegar item em pé/detonador = `focus_pulse`; pegar arma no baú não) gira em volta dela até o ângulo da ação, perto e de cima, pelo lado mais livre de parede (`_pick_side`), e volta devagar (`ACTION_IN`/`ACTION_OUT`); sobe até `CameraRig.PITCH_UP`: de dentro do labirinto mira o mezanino), anda/corre a 80%
  (`move_scale`; SHIFT/L3 = corrida forte `Player.SPRINT_SPEED` 4,2 m/s, andar devagar passa para ALT; no arcade SHIFT segue sendo andar), sem esquiva (o pulinho DodgeL/R/Back foi tirado): o botão de rolar é a mesma cambalhota do arcade, com intervalo de 1,4 s (`roll_cooldown`), a retícula só existe com o botão de mirar apertado e só atira mirando (sem
  mira apertada não há tiro), inimigos machucam ×2 (`GameMode.enemy_damage`, usado em todo `take_hit` de inimigo na jogadora),
  munição limitada (`Player.ammo` = total; `START_AMMO`/`WEAPON_AMMO` do baú/`AMMO_CAP`, escopeta até 25; clique `dry_fire` e aviso quando
  acaba). Pistola e M16 têm pente (`GameMode.MAGAZINE` 10 / 30; `Player.mag`, `mag_of`/`reserve_of`; reserva até 50 / 150, `AMMO_CAP` = pente
  + reserva; HUD "pente/reserva", cinza recarregando): o tiro gasta o pente; vazio com reserva recarrega sozinha, G / R1 recarrega antes
  (`Player.reload`: ReloadPistol/ReloadRifle por cima, nó OneShot "reload" do `HeroineModel`, sons mag_out/mag_in/slide_rack nos quadros do
  heroine_moves.json "reload"; o pente só enche no fim; trocar de arma, rolar, ser agarrada etc. cortam). Baú = pente cheio; no chão
  pistola 1 pente (10) e M16 meio pente (15), também o M16 que o guarda larga (`give_weapon(w, grant)`); pentes extras no galpão em
  `Pickup.LAYOUT`. Checkpoint grava o pente. Captura: `--shot=reload_pistol|reload_m16` (`--at`, `--yaw`). E itens no chão (`Pickup.LAYOUT`: caixas de munição pela cor da arma e kits de vida, pegos ao passar por cima;
  o teste confere que estão em chão livre). Cada arma manda no movimento enquanto o botão de mirar está apertado, sem a jogadora
  precisar parar (`aim_speed`/`lock`/`lock_slow` em `GameMode.SURVIVAL_WEAPONS`, `Player._armed_locomotion`): pistola corre e atira
  (coice mínimo; de lado, acima de `Player.FAST_STRAFE_AT` x o passo lateral curto, toca o passo largo StrafeFastL/R, ciclo "strafe_fast" de 1,35 m/s em `heroine_moves.gaits`, em vez do curto acelerado), M16 vira andar devagar e atira (coice médio, o tiro a desacelera mais), escopeta trava o movimento sozinha (só gira
  a mira; também agachada). Soltou a mira, volta a andar/correr normal.
  Os números das armas lidos pelo jogo vêm de `Player.weapon_stats(kind)` (o `WEAPON_STATS` é o do arcade). Teste novo nos dois
  perfis: `run_tests.gd` roda tudo no `arcade` (comportamento antigo intacto) e `survival_tests.gd` cobre o novo.
- Blender: Z para cima, personagem olha para -Y, lado esquerdo dela em +X. No Godot o modelo é girado 180° (frente = -Z).
- Ossos sem ponto no nome (`UpperArm_L`), para virarem nomes válidos no Godot.
- Ângulos das animações: ver cabeçalho de `art/heroine_anims.py` (X>0 dobra para a frente, joelho dobra com X<0).
- Orçamento (PS2 do começo): 800–5000 triângulos por personagem (o teste confere). Atlas 512x512 (heroína com alfa nas
  pontas do cabelo). Exceção decidida pelo usuário: o raptor tem teto de 8000 triângulos (atlas 512 da pele + 512 das peças); o chefe (alossauro) tem teto de 12000 triângulos e atlas 1024; o Godot usa os PNGs direto, não a cópia do .glb. Fundo dos atlas preenchido (sem magenta) para o filtro.
  Cenário: ladrilhos de 256 (~2 m cada), com mipmaps.
- Tronco da heroína: elipse por anel + `torso_volume` (busto, glúteos, escápulas); laterais na altura do ombro com peso
  parcial no braço (`_shoulder_share`) para não abrir vão ao erguer o braço. `loft` aceita `wfn` (pesos por vértice).
- Visual (`Gfx`, padrão "ps2"): materiais dos dois modos têm os mesmos parâmetros; trocar de modo só troca o shader. Material novo: `Gfx.shader()`.
  Luzes do cenário no grupo "lamps" (sombra no PS2).
  Ar pesado do galpão (`Haze`, grupo "haze"): debaixo de cada luminária de `Level.LAMPS` um feixe de luz falso (cone aberto somado à
  cena, `shaders/light_shaft.gdshader`, da cor da lâmpada) e um halo no painel, e névoa rala no galpão inteiro (`Haze.air`, FogVolume `AIR_DENSITY`, acesa só pelas lâmpadas); sem corpo, luz, sombra nem partículas (a poeira em
  partículas foi tentada e recusada: virava quadradinhos de luz). Igual no PS1 e no PS2 (fora da troca do `Gfx`).
- Camadas de física: 1 cenário, 2 personagens (cápsulas; o raptor também, com caixa no tronco para os tiros), 4 ragdoll (só colide com o cenário),
  5 barra da frente das torres (`GuardTower.RAIL_LAYER`), 6 grade (`Yard.GRATE_LAYER`: portões de grade e bordas do planalto da trilha,
  alambrado do galpão; seguram ela, os raptors e os guardas, que têm a camada na máscara, e deixam passar tiro, vista, câmera e a malha de navegação).
- IA e furtividade (`enemy.gd` = base de `Raptor` e `Soldier`; `Player.visibility()/make_noise()`): o inimigo patrulha `route` e percebe pela visão (cone de 150°, alcance
  `SIGHT_RANGE * Player.visibility()`; raptor 20 m, guerrilheiro `sight_range` 23 m, alertado `ALERT_SIGHT` 32 m: parada 0,7, andando 0,75, correndo/rolando/atirando 1, agachada 0,3 / andando 0,39 (guerrilheiro: 7 m / 9 m) só com algo baixo entre o olho dele e o quadril dela, `PlayerStealth.exposed_to`; agachada no aberto `OPEN_CROUCH` 0,65 / andando 0,7, capim alto ×0,5 agachada)
  e pelo barulho (`hear_noise`: passos de corrida 10 m, andando 4 m, agachada 2 m, tiro 26 m). A atenção (`aware`) sobe → `suspicious`
  (para e olha, "?") → `investigate` (vai ao ponto do barulho) ou, se a vê, `spot()` = grito + `on_alarm` nos outros do grupo "raptors"
  (`hunt` até o último ponto, "!"; o grupo "enemies" mistura raptors e soldados). Alertado (`alert_t`, `ALERT_TIME` 15 s) vê com cone
  mais aberto (`ALERT_FOV_BONUS`, nunca nas costas) e alcance `ALERT_SIGHT * visibility()` (agachada/capim ainda esconde). Em combate só
  sabe onde ela está com linha livre (`_combat_sees`, `COMBAT_SENSE`): parede/caixa corta o rastro; sem vê-la por `LOSE_TIME` (3 s) →
  `hunt` → `search` → esquece (`alert_t`/`aware` = 0) e volta à rota.
  Soldado = guerrilheiro encapuzado (`soldier.gd`, `HeroineModel` com `guerrilla.glb`/`guerrilla_atlas.png` e M16): guardas do galpão em `Soldier.GUARDS` (índice = número no comentário dele): porta do pátio 2 sentinelas (3, 4), 2 de posto (`"hold"`, 5, 7) e a ronda em T 0 (tronco pelo vão da parede de caixas do sul, barra na frente dela); baú da M16 o sentinela 2 e a ronda 1 (frente do canto da M16, desce pela parede leste); porta norte (portão da sala dos clones) 2 sentinelas de Flak Jacket (9, 10) e a ronda em T 11 (até a fileira de caixas do meio); no meio a ronda 6 (do vão leste das caixas, desce por um corredor entre duas paredes de caixas e sai bem na frente da rota do 8: tem que ser eliminada no corredor) e a ronda 8 (da quina perto da coluna, atravessa na frente do labirinto até o canto da M16). No canto da saída do labirinto o 12, de pistola (`Soldier.weapon`/`PISTOL`), mexe no painel da parede (`Level.CONSOLE`: bancada com o teclado na altura dos punhos da animação Console, `heroine_anims.console_keys`; tela verde e luz própria): `Enemy.distracted`, e `is_distracted()` (de volta ao lugar exato, virado para o painel, sem alerta) = não vê nada (nem ela, nem corpo) e a pistola fica guardada; o barulho o tira de lá como qualquer guarda e, quando desiste, volta ao painel. Caixas baixas em `Level.DIVIDERS` na frente do labirinto (z = 4,1), descendo da caixa do canto da M16 e fechando o canto do painel. Testes: `console_tests.gd`. Cada ronda tem um ponto cego (`Soldier.BLIND_SPOTS`, atrás das paredes de caixas de `Level.DIVIDERS`): morta ali em silêncio, ninguém nota, nem as outras rondas passando; `Soldier.RISK_SPOTS` são pontas que só a ronda 8 vê de passagem; os verticais 6 e 11 se veem na descida. Morte só é notada com linha livre: o barulho do corpo caindo (`Enemy.hear_death`, 6 m) e `on_nearby_kill` não atravessam caixa/parede, e corpo caído só é visto até `Enemy.CORPSE_SIGHT` (7 m); o tiro segue sendo ouvido como sempre (`Player.make_noise`). Gente (`Enemy.shouts`: soldado e sniper) avisa gritando (`_alarm_from`): ferido sem tê-la notado grita `SHOUT_DELAY` (1 s) depois (morto antes disso = só o `hear_death`) e quem acha um corpo a 2,2 m grita com o lugar do corpo (não o dela); o grito só chega a `SHOUT_RANGE` (12 m) com linha livre ou `SHOUT_MUFFLED` (4 m) atrás de caixa/parede (`broadcast_alarm(at, true)`). Raptor/alossauro seguem chamando a sala toda; vê-la (`spot`) também segue avisando a sala toda. Teste: `ai_tests.test_shout_earshot`. Caixas baixas (`Level.LOW_CRATE_H` 1,5 m) escondem ela agachada inteira (cabeça a ~1,3 m) e ainda dão para escalar. Testes: `ai_tests.test_blind_spot_kills` (uma ronda morta por vez, as outras andando). Os de posto ficam dentro do canto cercado pelas paredes de caixas `Level.DIVIDERS` (o galpão não tem mais bonecos de treino, `TargetDummy` só nos testes e no `--shot=dummy|ragdoll`) os de posto têm `Enemy.hold_post`: barulho/vulto/grito de corpo achado só os faz parar e olhar ("?"), sem sair do lugar, até alguém vê-la (`Enemy.identified`: ela vista de verdade, ele ou o alarme de quem a viu; acaba com o `alert_t`); corpo à vista os tira do lugar para ver; depois da busca voltam ao posto. Fixos de um portão dividem o posto (`"post"` em `GUARDS` = `Enemy.post`: "patio" 3, 4, 5, 7; "norte" 9, 10): sem `identified`, no máximo metade dos vivos do posto sai (`_post_full`, ao menos 1); quem não pode ir olha para lá e fica (`_stay_on_post`). Corpo visto: cada um vai até ele uma vez (`_known_dead`; quem ficou no posto também o dá por visto), ao chegar a 2,2 m (ou o mais perto que der) grita se ninguém o anunciou ou se ele não sabia; R esquece. Teste: `ai_tests.test_post_keeps_half`; `alert` (reage 0,45 s) → `engage` (mira, rajadas de 4–7
  tiros instantâneos com descanso de 0,3–0,7 s, chance de acerto cai com distância/agachada/correndo e a cada tiro da rajada (`BURST_DECAY`),
  rolar esquiva; ela some de vista = `SUPPRESS_TIME` de fogo de supressão onde ela estava, que não acerta, só com linha livre do cano até lá (`Soldier._clear_shot`: nunca atira na caixa/parede em que ela se esconde); avança, recua ou anda de lado); morre em ragdoll. Revisão: `--shot=soldier|soldier_dead`.
  Guerrilheiro, ritmo do alerta: busca ativa e vermelho 15% mais curtos que os dos bichos (`alert_time`/`lose_time`/`search_time` = ×`Soldier.TIME_SCALE`).
  Busca amarela (`Enemy.active_search` falso: só barulho/vulto/corpo visto, nível 1 "?"): anda até o lugar, para a `OBSERVE_DIST` com vista dele
  e observa de arma baixa, sem vasculhar; volta à rotina. Busca ativa (começou alertado: alarme, corpo achado, ela sumiu da luta; nível 2):
  corre para a área e nos pontos (`search`/`sweep`) procura de fuzil no ombro girando o corpo (`Soldier.weapon_ready`); vista ali = tiro em
  `REACT_READY` (0,1 s); pego de surpresa (rotina, amarela, correndo) = `REACT_TIME` (0,6 s). O `LOCK_TIME` do primeiro acerto segue igual.
  Corpo à vista em luta fica conhecido (`Enemy._note_corpses`): depois de perdê-la ele não se surpreende com ele; os outros podem; o grito de quem
  acha um corpo leva o corpo (`_alarm_from(at, about)`): não chega a quem já o conhece e quem ouve passa a conhecê-lo.
  Ronda que foi alertada (`_was_alerted`), quando a busca acaba, guarda o corpo conhecido mais perto (estado "guard": a ~1,8 m, de costas
  para ele, do lado de vista mais aberta; um por corpo); fixo de portão (sem rota/`post`/`hold_post`/painel) nunca (`guards_bodies`).
  Linha de tiro: o cano colado na caixa não atira através dela (`Soldier._body_block`, do corpo até o cano). Sem linha por `PEEK_AFTER`
  s (caixa, quina ou parede entre o cano e ela, ou ela sumiu atrás dela): passo de lado até a beirada de onde o cano a vê (`_find_peek`,
  `PEEK_STEPS`) inclinado para fora (`PEEK_LEAN`); sem beirada, vai para cima dela. Revisão: `--shot=soldier_search|soldier_guard|soldier_peek`
  (`--at`, `--yaw`; soldier_peek de lado com `--yaw=90`). Testes: `soldier_tests.gd`.
  Corpo do guerrilheiro = mesmas animações e mecânica de passo da heroína: `adapt_anims` não mexe em pose nenhuma (a corrida
  dela é resolvida para o pé não escorregar), e soldado/sniper andam por `HeroineModel.set_gait(v)` (critério do Player: andar até
  `Moves.speed("walk")`, acima disso corrida no ritmo da velocidade; nunca o andar acelerado). Malha: tronco de moletom
  (`guerrilla_spec.BARE`, junta do ombro `SHOULDER` em 1,47 para o ombro bater com a referência), braços e cabeça do modelo
  padrão, pernas da calça levadas à linha dos ossos (`_align_legs`), colete preto (`CARRIER_*`) bem mais escuro que o moletom.
  Os materiais `Body_*` do .glb (manga, rosto, olhos, janela dos olhos, calça) usam a textura própria; o resto usa o atlas.
  Caminhos: `NavigationServer3D` com a malha de `Yard.bake_nav` (sem malha, anda reto desviando com raios); soldados com `nav_map` = a malha
  de gente. Destino fora da malha (alto, atrás de porta): chega ao ponto alcançável mais perto; sem encurtar o caminho por
  `NO_PROGRESS_TIME`, desiste. Busca (`_search_goal`/`_sweep_goal`): cada um a um lugar diferente (`CLAIM_DIST`; o primeiro ao ponto
  mais perto, os outros a pontos do chão com vista do lugar), olha `SEARCH_TIME`, vasculha `SEARCH_SWEEPS` pontos em volta (prefere os
  que não vê de onde está), desiste e volta à rotina; sentinela sem rota anda de volta ao posto. Alarme (`broadcast_alarm`, do mais perto ao mais longe): de cada tipo só
  os `alarm_responders` mais perto saem (soldado: 2, andando = `alarm_walks`, `search_sweeps` 3; raptors: a matilha toda, correndo); os
  outros param, olham para o lugar (`_heed`) e seguem alertados. Sniper: mira e atira só com ela à vista (`SEES_GRACE`); sem vê-la por
  `LOSE_TIME`, procura na passarela e esquece (`_lose_target`). Testes: `ai_tests.gd`.
- Galpão em seções furtivas (`Shed`, `shed.gd`; `Shed.build` chamado pelo `Level`, o nó criado pelo main): grade de alambrado do
  chão até `FENCE_H` (3,6 m: acima do pulo de qualquer pilha escalável perto; nada até o teto) (`Shed.fence`, na `Yard.GRATE_LAYER`: segura ela e os guardas, deixa passar tiro, vista e som; as grades
  fixas entram na malha de navegação como parede, os portões não) divide o galpão: 1 labirinto → 2 faixa do painel (z > `FENCE_A_Z`)
  → 3 meio + ala da M16 → 4 sala dos clones → 5 canto da porta do pátio. Cada passagem abre por um objetivo (`Terminal`, `terminal.gd`:
  E na frente, "USAR COMPUTADOR"; com o guarda dele distraído no posto não serve): o computador do painel (`PANEL_USE`, guarda 12)
  destrava a grade do meio (`MID_GATE`); o computador do laboratório (`LAB_USE`, guarda 0 de `LAB_GUARDS`) destrava o portão de grade
  do canto (`CORNER_GATE`, no vão leste das caixas do canto). Os outros vãos do canto ficam fechados por grade (`CORNER_FENCES`: o vão
  do sul, que dava direto nos guardas da porta do pátio, e a quina perto da coluna (-5; -4), por fora da rota da ronda 8); as
  caixas das paredes do canto (e a pilha encostada nela por fora) não se escalam (`Shed.sealed_crate` → meta "no_climb"; a grade por
  cima delas saiu: visualmente demais). Portões (`Shed.grate_gate`): grade pintada de amarelo (`GATE_PAINT`) com batentes, travessa e
  chapa embaixo com faixa de perigo e o lampião em cima: se destacam do alambrado cinza. Travado = `Door.held` (`Door.add_status_lamp`).
  Guardas abrem portões (`Shed._guards_at_gates`): o caminho da malha dele passando pelo vão (`_path_through`) a até `GUARD_OPEN` = abre,
  travado ou não; o que um guarda abriu fecha sozinho (`Door.close`) `AUTO_CLOSE` s depois do vão (`DOORWAY`) ficar livre e segue
  travado; destravado pelo computador segue destravado. Ela pode passar enquanto está aberto.
  Canto à parte (`Shed.apart`/`in_corner`, contorno `CORNER_AREA`): com o portão do canto fechado, de dentro dele não se vê quem está
  fora (fora de luta) e som, grito e alarme não passam (`Enemy._reaches`/`_sees_target`): o tiroteio na ala da M16 não chama o canto da
  porta do pátio (nem a sala dos clones, que já é à parte com o portão de enrolar fechado). Duas pilhas altas (`CORNER_SCREEN`) dentro do
  canto, na frente do portão, e a caixa do meio da parede leste (agora pilha de 2) tapam a vista do canto até a ala da M16. A ronda 0 ficou só com a barra
  do T na faixa entre o canto e a grade do painel; a ronda 6 começa fora do canto.
  Sala dos clones: `LAB_GUARDS` = 2 examinando o tanque vazio e 1 no computador (distraídos, jeito do guarda do painel) e 1 de ronda
  no corredor; caixas de equipamento baixas `CloneLab.COVER`. Com o portão de enrolar fechado, som e grito não passam entre a sala e
  o galpão (`Enemy._reaches`). A cena do susto mostra os guardas no fundo e termina com ela agachada atrás da primeira caixa.
  Reforços (seções 4 e 5): alarme vermelho na seção (`Shed.red_alert`: ela dentro, alguém dela em luta) → `WAVE_DELAY` s depois a
  porta de serviço (`SERVICE`, selada para ela, com uma saleta fechada atrás) abre e entram `WAVE` guardas alertados correndo para
  onde ela foi vista; seguindo o vermelho `SECOND_AFTER` s depois, a segunda leva (`WAVES` = 2). Escondidos na saleta =
  `lurking` + `PROCESS_MODE_DISABLED`. Ficam no fim de `main.all_enemies()` (`main.shed_soldiers()`). R (`Shed.reset`): grades
  travadas, computadores sem uso, reforços na saleta; checkpoint (`save_state`/`load_state`): uso dos computadores; reforço vivo
  volta à saleta e a leva dele conta como não mandada. Testes: `shed_tests.gd`.
- Pátio da mata (`Yard`): segunda sala a oeste do galpão (porta na parede oeste, z = `Yard.DOOR_Z`), uma trilha de terra em S por mata
  fechada (jeito Dino Crisis 2 / RE4: ela segue um caminho e a luta vem da frente, não de todos os lados): três faixas norte-sul separadas
  por paredes de mata (`WALL_A`/`WALL_B`, `_bands`: parede invisível de `WALL_H` 10 m, alta para ninguém escalar nem do planalto, com
  árvores/moitas de enfeite por cima), `Z_HALF` 45 m. S1 = faixa leste, da porta para o sul até a clareira do morto (emboscada); S2 = faixa do
  meio para o norte (7 raptors); S3 = a mesma faixa depois da parede que a cruza em z = 0 (9 raptors); L3 = faixa oeste para o sul, só capim
  (nada sólido: a rendição é de longe), até a praça das torres (`PLAZA_Z`; ao sul dela mata fechada) e o portão de ferro do fundo (boca do túnel
  = último ponto de `ROAD`, que túnel e pedreira usam). Portões de grade (`Yard.GRATES`, `_grate`: `Door` de barras com `solid_layer` = a
  camada da grade, room -1, lampião de trava em cima = `Door.add_status_lamp`) entre as seções: travados (`Door.held`, sem E) até a seção de
  antes acabar; aí destravam (`set_held(false)`: estalo, lampião verde) e ela abre com E. O de trás fica aberto (dá para voltar; eles vão atrás).
  Trilha (`ForestTrail`, `forest_trail.gd`, criado pelo main; seções 0/1/2 = S1/S2/S3): os 3 da emboscada são a seção 0; os de S2/S3 ficam
  escondidos em moitas sem colisão (`Yard.WAVES`: cada trecho tem uma linha `z` e as moitas `entries`, sempre 6 m ou mais à frente dela) e,
  quando ela passa da linha na faixa do meio no chão (`Yard.in_mid`), saem um `ForestTrail.STAGGER` depois do outro (`Raptor.emerge`: agacha,
  pula na direção dela e cai a `EMERGE_GAP` m, já em luta, e entra na vez da matilha). S2 = trechos de 2, 2, 2, 1; S3 = 3, 3, 3. Passou
  correndo: os trechos seguintes soltam os seus e todos a perseguem (vão se juntando). Escondido, o raptor nem anima (`lurk` desliga o
  modelo; são 21 na mata). Seção limpa → `cleared` → `main._on_trail_cleared`: S1 = a chave brilha + checkpoint "trail"; S2 = "trail2"; S3 =
  "standoff" e as torres ficam prontas (`towers_armed`). R (`reset`): todos às moitas, trechos armados, portões travados; checkpoint
  (`restore`): vivo volta à moita e o trecho arma de novo, seção sem vivo = portão destravado.
  Barranco e planalto da escopeta: no fim de S2, meio escondido atrás de samambaias, o degrau `ROCK1` (`ROCK1_H` 1,2 m, raso: de cima dele a
  beira fica ao alcance) e a beira `SHELF` do planalto (`PLATEAU`, `PLATEAU_Y` 3,5 m, faixa leste ao norte de S1, por cima da `WALL_A`): escala,
  pula, fica pendurada e sobe. O fim de S1 (face sul do planalto e da beira, da parede do galpão até a `WALL_A`) tem alambrado do chão até
  `WALL_H` (`S1_END_FENCE`) e a borda colada no galpão também (`ROOF_FENCE_X`): do telhado ela não pula para o planalto nem agarra a beira;
  `PlayerMoves.find_ledge` recusa beira com grade entre a face e o lugar de ficar de pé. Lá em cima o baú da escopeta (`SHOTGUN_CHEST`, boca para o norte, tronco `CHEST_LOG` no fundo), munição e kit,
  e os 2 raptors de `CLIFF_RAPTORS` (fora das seções) que saem das moitas quando ela chega (`Yard.on_plateau`). As bordas do planalto (menos a
  do barranco) têm grade invisível (camada da grade): da beira sobre S3 a vista e o tiro descem, ninguém pula.
  Lâmpadas `LAMPS` (só as `SHADOW_LAMPS` primeiras fazem sombra), touceiras de capim alto (grupo "cover", meta "radius"); a faixa do meio é
  mais rala de coisa sólida (espaço para a luta). Os 3 raptors da emboscada em `Yard.POSTS` (rotas usadas só depois dela).
  Mata das faixas numa grade (`Yard.COVER_CELL`, um item mexido por célula: sem vazios grandes); perto da trilha só capim, que
  acompanha a beira sem entrar na terra; a `CLEARING + TREE_GAP` do morto só moita (copa de árvore entraria no plano do alto da emboscada).
  O portão do fundo (`Yard._gate`) é de chapa cheia (`GATE_H`) com viga de concreto até `Arena.CLIFF_H`: nem pela frente nem do
  telhado se vê a pedreira. Neblina rasteira sobre o pátio (`Yard._mist`, FogVolume; `Level` liga `volumetric_fog` com densidade 0 fora dele).
  Testes: `trail_tests.gd`.
  Guerrilheiro morto (`Corpse` em `Yard.CORPSE`, clareira de `Yard.CLEARING` m sem nada sólido): `HeroineModel` do guerrilheiro com a
  árvore de animação desligada e `Corpse.POSE` posta no esqueleto (convenção do heroine_anims; deitado, X>0 = para o céu, Z<0 abre
  braço/perna), sangue por `Blood.splat` (refeito no R), chave do container presa na mão direita (`KeyItem.hold`, estado "held").
  Emboscada: os 3 raptors da emboscada (S1) começam escondidos nas moitas sem colisão dos cantos da clareira, `Yard.LURK` (`Raptor.lurk`:
  `Enemy.lurking` = sem corpo, sem IA, não ouvem nem recebem alarme). Ela a `Corpse.NOTICE_RANGE` do morto, com linha livre →
  `Cutscene.play_ambush` (só com `trail.sections[0]`; anda até a mão, close do punho com a chave + "ELE ESTÁ SEGURANDO ALGUMA COISA...",
  eles saem dos cantos e param a `AMB_RING` m de frente para ela sem rodear (`start_ambush` com `AMB_CIRCLE` 0, estado "ambush"; o plano do alto
  vem do lado da trilha por onde ela chegou), o da frente ruge; E pula, ver Cenas). No fim `end_ambush` = em luta, um de cada vez (`AMB_STAGGER`).
  A chave fica sem brilho (`KeyItem.shine` falso) até os 3 morrerem; dá para pegá-la antes. R: moitas, chave e cena de volta.
  A etiqueta vermelha da chave tem "0M79" escrito (`KeyItem.tag`, Label3D na etiqueta, também na tela do item): parece um código e
  engana (não é o do portão).
  Torres de guarda (`GuardTower`, `Yard.TOWERS`; madeira = textura `planks` de tábuas de obra, nunca a `crate` das caixas): uma de cada lado do portão do fundo, encostadas na parede, frente (+X local) para o
  pátio; plataforma em `FLOOR_Y` 4,2, parapeito de tábuas atrás/dos lados, guarda-corpo vazado na frente cuja barra de cima
  (`RAIL_H` 1,1 = abdome) só segura o corpo mole (`RAIL_LAYER`, a cápsula viva não encosta), telhado e lâmpada; sem escada
  (ninguém sobe). Em volta delas `Yard._off_towers` tira árvore (`TOWER_TREES`) e o resto sólido (`TOWER_CLEAR`) depois de montar a
  mata (o sorteio do resto fica igual). Um sniper em cada (`main._build_towers`: `Sniper.perch` = retângulo da plataforma,
  `floor_y`, `home_yaw` = vigia o pátio, `ledge` = alto da barra), fora de cena (`Sniper.lurk`) até a mata limpa (S3 da trilha) e ela descer a trilha da faixa oeste até `Yard.STANDOFF_Z`
  (`main.wake_towers` → `appear`). Morreu um: o outro fica com o cartão do painel (`main.gate_card`, `loot`) e `falls`. O que cai: morto ainda
  em pé toca StaggerFwd e cambaleia até a barriga bater na barra (`_stagger_to_rail`), amolece com o embalo num corpo firme
  (`_firm`: juntas a `FIRM_JOINTS` do normal e giro amortecido em `FIRM_DAMP`, sem chacoalho de boneco mole; só a coluna vai a
  `SLUMP_WAIST`), o quadril fica na altura da barra, atrás dela, enquanto o tronco pende para fora (`_tip_over`: dobra no
  abdome, pernas esticadas), depois passa por cima e a gravidade leva; o fuzil fica na mão até o corpo parar no chão e só então
  o fuzil (pickup) e o cartão aparecem um de cada lado do corpo (`_drop_when_landed`, `DROP_SIDE`). O que morre lá em cima (não cai) fica com o fuzil na mão e não larga nada. R: snipers fora de
  cena de novo, cartão escondido. Testes: `tower_tests.gd`.
  Rendição (`main._update_standoff`): `main.STANDOFF_DELAY` s depois das torres acordarem (`wake_towers`), com ela na faixa oeste
  (`Yard.in_west`), de pé e com controle, e os dois snipers vivos, `Cutscene.play_standoff` (uma vez: `main.standoff_armed`, o R arma de novo): eles erguem o
  fuzil, os lasers acendem (`Sniper.hold_at_gunpoint`, estado "standoff": laser firme nela, sem tiro, ameaça 0) e cruzam no peito
  dela, ela levanta as mãos (Surrender) e as falas `STAND_LINES` ("PARADA AÍ!" / "É O FIM DA LINHA." / "NÃO SE MOVA OU
  ATIRAREMOS.", a última "NÃO FAÇA MOVIMENTOS BRUSCOS OU ATIRAREMOS."). No fim (ou pulando) `Player.surrender`: mãos ao alto
  (SurrenderHold), sem arma na mão; o direcional anda (nunca corre; agachada também) com as mãos ao alto por cima do andar
  (`HeroineModel.hands_up`/`HANDS_UP_UNDER`) e os lasers a seguem; sem dica na tela. O sensor de perigo enche em
  `Sniper.STANDOFF_TIMEOUT` (15 s, fora da cena, dividido entre os dois) e aí eles atiram (`standoff_timeout` → "timeout", acerta).
  Movimento brusco = `Player.surrender_broken(how)` → `Sniper.release`: mirar/atirar ("aim") ou correr (botão de corrida; no
  arcade o direcional inteiro sem o andar devagar)/pular ("rush") = os dois atiram na hora e acertam; rolar ("roll") = atiram e erram; saiu andando da vista de um deles
  (`Sniper.standoff_lost`, `STANDOFF_BLIND`) = "move", sem tiro. Em todo caso a próxima mira leva `Sniper.STANDOFF_LOCK` (5 s, um
  `main.STANDOFF_STAGGER` depois do outro) e o sensor de perigo sai do zero e enche nesse tempo (a ameaça é dividida entre os
  snipers na mira lenta); depois, o ritmo de sempre. Matou um sniper antes da cena: sem rendição.
  Os snipers das torres vestem Flak Jacket (`Sniper.flak`, `Soldier.FLAK_MULT`, a mira escreve FLAK JACKET). As torres não tapam a
  vista, o tiro nem o laser deles (`Sniper.see_through`; sem ponto cego embaixo da plataforma) e, com ela perto demais do portão do
  fundo ou das torres (`main.in_tower_zone`: `TOWER_ZONE` m da parede do fundo, entre as torres + `TOWER_ZONE_SIDE`), os vivos a
  veem e atiram (rendida = "rush").
  Mira laser do sniper (`SniperLaser`, os dois tipos de sniper): fita virada para a câmera com espessura mínima na tela
  (`min_px`; a caixa de 1,5 cm de antes sumia na resolução interna), núcleo claro e halo, ponto brilhante onde bate
  (`BODY_DEPTH` antes do meio do peito dela, com uma luzinha vermelha curta) e brilho no cano. Ao travar, o ponto começa de um
  lado dela (`_sweep`) e vem tremendo até o peito (`SWEEP_SETTLE`), firma e de `BLINK_AT` até o tiro pisca cada vez mais rápido.
  Texturas `grass/dirt/bark/leaves/rock/grass_card/fern_card` vêm de `tools/make_level_textures.py`. Revisão: `--shot=yard --pos=x,z[,graus]`.
- Golpes na heroína (`art/heroine_hurt.py`): a reação ao tiro/dano é **aditiva** (`HeroineModel.hit(dir, força)` → nó Add2 por
  cima de tudo; HitFront/HitBack/HitL/HitR pelo lado atingido, `hit_side`; duas entradas por direção que se alternam): agachada
  continua agachada, mirando continua mirando (nada de pose inteira em pé). `knockback` toca StaggerBack/StaggerFwd conforme o
  empurrão. Caída em ragdoll (arremesso, mordida, `knock_down` = queda que machuca ou derrubada da escada), `Player._get_up` vira a
  cápsula para o lado da cabeça do corpo, encaixa o quadril do quadro 0 no do ragdoll e toca GetUpFront (de bruços) ou GetUpBack
  (de costas: gira de lado até ficar de bruços) a `GETUP_SPEED`: flexão, quatro apoios, um pé à frente, depois o outro, sem pulo;
  `PoseFade` (modificador depois do Ragdoll) parte da pose em que o corpo ficou. Levantando (`is_getting_up`) = sem controle,
  sem arma na mão e sem levar golpe.
- Raptor: tiro = tranco no tronco/pescoço/cabeça (`HitFlinch`, modificador do `RaptorModel`, por cima de tudo) e, fora de um
  golpe (`Raptor.HIT_KEEPS`), o estado "hit" (`HIT_TIME`, animação Hit) e volta a estudá-la. Ataques resolvidos em `raptor.gd` (`_strike` = dano + `knockback`); a mordida chama `Player.grab()`, que liga o ragdoll dela
  com o antebraço esquerdo puxado para a boca (`Ragdoll.drag`) e a luta dela por cima; rolar (`is_dodging`) esquiva de tudo.
  Salto (golpe sai das garras dos pés) e investida chamam `Player.launch()`: ragdoll arremessado em C em volta do golpe
  (`Ragdoll.fling` + `_hold_c`), depois ela levanta. A morte do raptor é ragdoll (`RaptorModel.RAGDOLL`), não animação.
  Matilha (survival, `GameMode` "pack_turns"; arcade como antes): um raptor ataca por vez (`Raptor._may_attack`: ninguém em
  `ATTACKS`, `PACK_GAP` s desde o fim do último ataque de qualquer um, e ele é o mais bem colocado por `_turn_score`: de lado/atrás
  dela, perto da distância de estudo, quem espera há mais tempo); no survival ninguém rodeia (jeito Dino Crisis: o raptor do DC1
  só tem Walk/Idle_Aggressive, sem andar em volta): cada um tem um lugar em volta dela (`_slot`, a `PACK_SPREAD` dos lugares dos
  outros, faixa `SLOT_BAND` m), vai andando até lá e para no Study de frente para ela, como o alossauro (`_hold_slot`; só anda de
  novo se o lugar ficar a mais de `SLOT_LEAVE`, p.ex. ela arremessada ou fugindo); a rabada de reflexo também espera a vez. Dano no survival pela
  tabela `Raptor.SURVIVAL_DAMAGE` (agarrão inteiro 24, golpes 14–20), não pelo dobro. Teste: `survival_tests.test_pack_turns`.
  Andando, o raptor só se move para a frente do corpo e a velocidade da animação acompanha (`WALK_ANIM_SPEED`/`RUN_ANIM_SPEED`).
  Pés presos (`FootPlant`, SkeletonModifier3D do `RaptorModel`, vale para o alossauro; medidas pela perna do esqueleto): o pé
  que a animação põe no chão fica onde tocou no mundo (IK de coxa/canela, metatarso e dedos como na animação) até a animação
  levantá-lo; girando no lugar ou andando mais devagar que a animação, o corpo se afasta do pé preso e ele dá um passo (um pé
  de cada vez, som de passo pelo sinal `stepped`). No ar e no ragdoll segue a animação; clone do tubo (dono não é
  CharacterBody3D) não usa. Inércia (`TurnSway`, modificador antes do `FootPlant`): virando, pescoço/cabeça entram na curva antes
  (`LEAD`), a cauda fica para trás no mundo e volta com mola (base e ponta com molas próprias, a ponta chicoteia), o quadril
  inclina para dentro da curva pela velocidade (`BANK`; `HEAD_SHARE` inclui Neck3, que só o raptor tem). O raptor usa as
  animações do modelo dele (ver `build_raptor.py`); passo pela velocidade em `Raptor._gait`: Walk até `JOG_FROM`, Jog até
  `JOG_TOP`, Run acima, cada um no ritmo medido (`*_ANIM_SPEED`, sem patinar; a corrida dele é curta e a 8,4 m/s toca ~4x,
  decisão do usuário); a IA comum segue com o limiar de corrida antigo (`RUN_GATE`). Ciclos do alossauro (`raptor_anims.gait`, os
  dele em `allosaurus_anims`) com gingado: quadril desce depois de cada toque, leva o peso para cima da perna de apoio (`shift` de lado + `roll`) e gira
  com a passada (`yaw`), a onda sobe pelo tronco/pescoço atrasada (`wave`) e desce pela cauda larga (`sway`), a cabeça desfaz o
  giro e dá o bote de ave a cada passo (`thrust`), braços atrasados, calcanhar sobe no fim do apoio; o IK abre a coxa pelo rolar
  e pelo quadril de lado; uma chave por quadro (chave a cada 2 quadros fazia o pé andar aos trancos). Espreita (`Stalk`,
  `Raptor.STALK_SPEED`/`STALK_ANIM_SPEED`, só raptor): o andar dele 1,6x mais lento, peito e pescoço baixos, cabeça nivelada
  varrendo os lados; usada ao rodear a presa (`_study`). FootPlant: a coxa do raptor sai de Pelvis/Hip (o IK usa o pai de verdade).
  Testes que leem a pose final usam `Skeleton3D.skeleton_updated`; estado mudado dentro da lambda vai num dicionário (a lambda
  copia variável local). `possible_models/dino-crisis-*` só como referência de
  ritmo, nada de keyframe deles no jogo.
- Começo da fase: ela nasce no telhado do galpão (`Roof.START`; laje sem sombra, parapeito de 1 m que dá para
  escalar e se jogar: a queda mata, ver Queda). Em cima da laje (`Roof.has`) os inimigos não a percebem: passos/tiro não chegam (`Enemy._reaches`) e
  ela não é vista, nem por quem está alertado. Na beira do lado do pátio (`Roof.near_yard`, a `SMELL_DIST` da mureta oeste), uma vez
  só (`main.smelled`, o R zera): o jogo para com `Roof.SMELL_TEXT` na faixa de baixo até confirmar (`Inspect.show_message`, jeito
  RE/Dino Crisis). Captura `--shot=smell`. Interagir no alçapão (`Hatch`, canto do fundo à direita) = ajoelha e abre (`PlayerMoves.start_hatch`, animação
  HatchOpen; a tampa sobe entre HATCH_GRAB e HATCH_UP, as palmas presas por IK na alça girando com ela (`heroine_cutscene.handle_at`, = `Hatch.HANDLE`) até HATCH_LET_GO, depois empurra); fechado, a escada dele (`Ladder.top_open`) não monta. A escada fica na beira
  do furo do lado de quem chega, presa à parede do fundo por suportes, e desce até o labirinto de caixas (`Level.MAZE`: grade de
  células de 1,6 m, pilhas de 2,7 m = acima do alcance de pendurar; frente fechada; saída única à esquerda por baixo do mezanino; a
  escada do mezanino num beco que só abre para o corredor de cima; vigas do mezanino com colisão). Na fase a escada do mezanino
  fica recolhida e trancada (`Catwalk.suspended` → `Ladder.locked`/`lift`: degraus só de `LADDER_LIFT` para cima, o lance de baixo
  encaixado atrás, corrente e cadeado; não monta de baixo nem de cima; E embaixo dela = `Player.ladder_locked` → `Catwalk.LOCKED_TEXT`
  na faixa de baixo) e a subida é escalando: vão do guarda-corpo até a parede do nicho (`CLIMB_GAP_R`) e a caixa `CLIMB_CRATE`
  de `CLIMB_CRATE_H` embaixo dela (escala a caixa, pula, fica pendurada na beira e sobe). `Catwalk.new()` sozinho (testes da escada) segue com a escada de subir. Raptors não navegam no labirinto
  (raio da malha 0,75 m); soldados usam a malha de gente (`Yard.bake_people_nav`: raio 0,25 m, célula de 5 cm, só no galpão) e entram
  em todo corredor do labirinto e no nicho da escada do mezanino (passam debaixo das mãos-francesas do mezanino, `Catwalk.BRACE_Y` acima da cabeça); o sniper anda reto no mezanino (`Sniper._steer`: a malha mais perto é a do topo das caixas/telhado).
  Na escada, entrando/saindo pelo topo e nos `Hatch.HIDDEN_RUNGS` degraus abaixo do alto do ciclo (`Ladder.hidden_top`, `PlayerMoves.hidden_on_ladder`) fica escondida de todos, mesmo alertados; abaixo, o sniper a vê se estiver olhando para o canto: o tiro
  derruba da escada (`PlayerMoves.knock_off_ladder`) e a queda sem controle mata (`Player.KNOCKED_*`).
  Na ronda o sniper do mezanino alterna entre o galpão e as caixas lá embaixo (`Sniper.LOOK_DOWN`; desconfiado de algo no
  labirinto segue de cabeça baixa): de cabeça baixa o ponto cego não vale no labirinto (`Level.in_maze`) e ele vê quem está
  em pé num corredor à vista; agachada entre as pilhas, não.
- Teto da sala dos clones (`Roof.LAB_Y`, 1,5 m acima da laje: sobe escalando a parede do fundo do galpão; mureta nos três lados
  de fora; `Roof.has` conta ele como telhado) com a caixa de paraquedas (`SupplyDrop`, no fundo, em `SupplyDrop.POS`): caixa
  oliva torta, lona murcha e cordas; E na frente = o mesmo `PlayerMoves.start_pickup` do baú (ajoelha em `kneel_transform`,
  tampa abre, animação PickupPistol, a mão pega no quadro `pistol_pickup.grab_frame` do heroine_moves.json, `finish` no fim
  mostra o item) e a pistola com silenciador entra no lugar da pistola
  (`Player.silencer`: mesma arma "pistol", mesma munição e dano; `Player.SILENCER` troca o nome no HUD "PISTOLA SIL.", o barulho
  do tiro de 26 m para 3,5 m e tira o clarão que a mostra; `HeroineModel.silenced`/`gun()` = malha PistolSD, cano SDMuzzle, som
  `pistol_sd_shot`, clarão `Fx.FLASH.pistol_sd`; a malha PistolSD é só o silenciador, 12 triângulos: o teste do orçamento soma
  todas as armas do heroine.glb e está em 4996 de 5000). Tela do item `Inspect.show_drop`. R fecha a caixa e tira o silenciador.
  Neblina do telhado (`Roof._fog`, FogVolume como a do pátio): `FOG_DENSITY` sobre o galpão (o alçapão aparece do começo) e
  `LAB_FOG_DENSITY` a mais sobre o anexo (a caixa só aparece a poucos metros).
- Checkpoints (`Checkpoint`, `checkpoint.gd`; `main.reach_checkpoint`, só andam para a frente, aviso "CHECKPOINT"): "lab" = entrou na
  sala dos clones, "corner" = usou o computador do laboratório (o canto da porta do pátio destravou), "yard" = abriu o
  portão do galpão para o pátio (`main.yard_door`), "trail" = os 3 raptors da emboscada mortos (S1), "trail2" = S2 limpa, "standoff" = S3
  limpa (as torres esperam ela descer de novo: `towers_armed`/`towers_up` também vão no checkpoint), "tunnel" = abriu o portão do teclado
  (`main.mine_door`), "allosaurus" = passou pelo portão arrombado para a pedreira. Grava a jogadora (vida, armas, munição, silenciador,
  chaves, tiros, tempo) e o mundo (mortos por índice de `main.all_enemies()`, portas/baús/caixa de paraquedas/alçapão/chave e cartões
  pelo `save_state`/`load_state` de cada um, itens pegos e os largados no chão, caixotes estourados, cenas já tocadas). Game Over:
  E/X = CONTINUAR (`main.continue_from_checkpoint` = `_reset_world` + `Checkpoint.restore`, ela em `Checkpoint.SPAWNS`), R = do zero;
  sem checkpoint, os dois recomeçam. R / REINICIAR / F3 = `reset_all` (apaga o checkpoint). Morto antes do checkpoint volta fora do
  jogo (`Enemy.clear_out`: sumido em `CLEARED_AT`, `PROCESS_MODE_DISABLED`, `cleared`; o `reset` traz de volta). Fogo, sangue e
  buracos não voltam. Só na partida aberta (sem arquivo). A emboscada e a chegada à pedreira tocam de novo (dá para pular); a
  rendição, depois de vista (`main.standoff_seen`, o R zera), vem sem cena (`main._standoff_live`): lasers, mãos ao alto onde ela
  está (`Player.surrender(false, grace)`: mexer-se só conta depois de `SURRENDER_RAISE + LIVE_GRACE`) e as falas `STAND_LINES` no
  HUD (`_hud_line`) no tempo da cena, jogo andando. Testes: `checkpoint_tests.gd`.
- Queda (`Player.fall_damage`): sem dano até `FALL_SAFE` (3,6 m: pular do mezanino não machuca), morte a partir de `FALL_LETHAL`
  (5 m); derrubada da escada usa `KNOCKED_SAFE/KNOCKED_LETHAL`. `death_cause` "fall" → Game Over "VOCÊ MORREU NA QUEDA".
  Fora do galpão/pátio/pedreira não há chão: caindo abaixo de `Player.VOID_Y` (-10 m) ela morre na queda (não cai para sempre).
- Sala dos clones (`CloneLab`): anexo atrás da plataforma de carga (piso na altura da doca, `FLOOR_Y` 1,3), portão de enrolar (`Door`
  com `room` -1, fora da corrente de salas) aberto com E. Seis tubos com raptors (`RaptorModel` parado na animação `Embryo`, encolhidos e centrados no tubo; osso nenhum a menos de
  `GLASS_GAP` do vidro: se a cauda passa, o clone encolhe até caber,
  azulados, sem piar). Ao entrar pela primeira vez: `Cutscene.play_clones` (faixas pretas, sem HUD; `Player.cutscene` = sem controle nem dano;
  anda, close no clone, rosto dela com Shocked e "O QUE...?!", plano geral; E pula, ver Cenas; R reinicia e a cena volta a valer).
  Cenas (`Cutscene`): só dá para pular depois de vista até o fim uma vez (`Settings.cutscenes_seen`, no `user://settings.cfg`;
  os testes usam `user://test_settings.cfg`, capturas não leem nem gravam); aí aparece "<glifo> PULAR" na faixa de baixo e E/X
  pula. Na cena mouse/analógico não giram a câmera dela; no fim `CameraRig.reset_view` a põe atrás dela, reta, olhando para onde ela olha.
  Cada tubo tem uma plaqueta num pedestal (`SubjectPlate`, "SUBJECT XXXX" de `CloneLab.SUBJECTS`, grupo "plates"): E na frente dela
  (`Player.pick_plate` → sinal `read_plate`) = `Inspect.plate_zoom` (pausa, câmera até a plaqueta, ficha embaixo). No canto do fundo à
  esquerda (`CloneLab.TANK`; a sala foi até `Z_FAR` -32 para caber) o tanque do alossauro: vidro de `TANK_SIDES` lados inteiro,
  drenado, porta de vidro aberta, mangueiras soltas, luz vermelha; a plaqueta dele (`ALLO_SUBJECT`, "VAZIO / TRANSFERIDO") é o
  código do portão da pedreira. O console não tem mais a chave do painel: o cartão (`main.gate_card`, keycard cor de ferrugem, id
  `Yard.GATE_KEY`, sem dica do código: a ligação com a plaqueta do tanque vazio fica para a jogadora) cai do último sniper das torres do pátio.
- Salas e portas (`Door`, `Level.room_of/connected`): 0 galpão, 1 pátio, 2 túnel da mina, 3 pedreira. As duas portas (de correr no galpão, portão de ferro no fundo do pátio) começam fechadas: bloqueiam corpo, tiro e visão e abrem com E perto delas (`Player.pick_door`; reiniciar fecha). `Enemy.hear_noise`/`on_alarm` só valem na mesma sala ou com todas as portas entre elas abertas: tiro e grito de uma sala não chamam os inimigos das outras. `Yard.bake_nav` desliga as portas na hora de assar a malha.
  Porta trancada: `Door.lock` = id da chave/cartão. Com leitor (`add_card_reader`, porta do galpão) abre com o cartão no bolso. Com
  teclado (`add_keypad` + `Door.code`, portão da pedreira: cartão `Yard.GATE_KEY` na fenda do lado do teclado + código
  `CloneLab.ALLO_SUBJECT`): E emite
  `Player.keypad` → `main._on_keypad` → `Inspect.keypad` (pausa, câmera no painel; sem o cartão "PAINEL DESLIGADO"; com ele o visor
  acende e ela digita 4 algarismos: 0-9 ou setas/direcional, E confirma, C sai; errado = `keypad_error` e zera; certo = `keypad_ok`,
  o cartão é gasto e a porta abre). `Inspect.auto_code` digita sozinho (testes/capturas). R tranca de novo e apaga o visor.
- Túnel da mina (`Tunnel`, sala 2): do portão do teclado do pátio até a pedreira, `LENGTH` m de galeria na rocha (escoras,
  trilho, lâmpadas penduradas) em trechos `SECTIONS`: boca, câmara do meio (caixas de cobertura, itens em `Pickup.LAYOUT`, 2
  sentinelas `GUARDS` 0 e 1 olhando para a boca: abrir o portão longe deles não alerta ninguém), corredor e câmara do fundo (pilhas
  `Tunnel.STACKS` de `ExplosiveCrate` até o portão da pedreira e 4 guardas `GUARDS` 2..5 nos caixotes de trabalho, distraídos com
  Console). A galeria abafa: com ponta na sala 2, `Enemy._reaches` só passa até `Tunnel.SOUND_REACH` (a briga do meio não chega ao
  fundo; levada até eles, chega). Chegando ao fundo (`TALK_X`) com os dois `TALKERS` no trabalho: `Cutscene.play_talk` (viram um
  para o outro e falam `TALK_LINES`; voltam ao trabalho). Detonador no caixote do `DETONATOR` (E na frente, `Player.pick_detonator`,
  "ARMAR DETONADOR"): `FUSE` s de contagem (sinal `tick` → aviso "DETONAÇÃO EM n", bipe e luz piscando) e todas as pilhas
  explodem; granada da M79 também detona. Caixote a `BREACH_RADIUS` do portão explodindo arromba o portão (`Door.blow`: as folhas
  voam e caem; `Door.sealed` = sem E), um passo de física depois do estouro (o barulho não chega à pedreira). Passando pelo portão
  arrombado (`LAIR_X`) com o alossauro calmo: `Cutscene.play_lair` (ela pensa `LAIR_LINES`, ele ruge = `Enemy.spot`; pulando, ele a vê
  igual). Numa cena (`Player.cutscene`) ninguém a vê (`Enemy._target_hidden`). R: caixotes, portão e as duas cenas de volta.
  Ambiente de lugar fechado dentro dele (`Soundscape.yard_mix`). Testes: `tunnel_tests.gd`.
- Pedreira (`Arena`): última sala, no fim do túnel da mina (posições de antes + `Arena.DX`); entra pelo portão arrombado; paredões de pedra, ruínas e pedras grandes
  (cobertura que o alossauro não atravessa), capim alto, postes (`Yard.lamp`). Alossauro em `Arena.ALLO` e 2 raptors em `Arena.POSTS`.
- Alossauro (`allosaurus.gd`, herda `Enemy`; modelo `AllosaurusModel` = `RaptorModel` com outro arquivo/atlas/ragdoll/sons graves):
  vê → ruge (`ROAR_RANGE`: `Player.daze(3 s)`, não fere; volta a rugir com `ROAR_COOLDOWN`) → persegue andando (`stalk`) e escolhe:
  pisada (perto: o pé que desce fere e arremessa, o tremor só empurra), mordida (à frente: `Player.grab`, sacode e arremessa para a
  esquerda dele com `release`) ou investida (longe). Rolar esquiva de pisada e mordida. O tiro não interrompe a ação dele (só rosna a cada `GROWL_DAMAGE`).
  Não se deixa rodear: com ela fora da frente (`HOP_ANGLE`, até `HOP_RANGE`, sem ser a rabada) dá um pulinho esgueirado de lado
  (`start_hop`, animações HopL/HopR; no ar entre `HOP_AIR` é levado `HOP_DIST` de lado e gira até ficar de frente para ela; perto
  dela, `HOP_NEAR`, pula para o lado contrário) e com ela mirando nele de frente às vezes pula como esquiva (`DODGE_CHANCE`);
  intervalo `HOP_COOLDOWN`. No ar `airborne` = `FootPlant.grounded` falso (pés seguem a animação).
  Casco (HARDENED): só as costelas (`RIBS` = partes Spine/Chest do ragdoll) levam o dano cheio; cabeça, pescoço, quadril, pernas e
  cauda levam `HARDENED_MULT` (sem headshot, `head_mult` 1); a granada não passa pelo casco.
  Morte em ragdoll → sinal `killed` → tela de fim do `main` (FIM, tempo, tiros; R reinicia). Atordoada: estado "dazed" da
  heroína (animação Dazed), aviso "ATORDOADA" no HUD; golpe, mordida ou reinício acabam com ela.
- Tela 16:9: resolução interna `Gfx.RES` 854x480 (PS2) / 427x240 (PS1), janela padrão 1280x720 (as capturas saem em 16:9);
  `stretch/aspect="expand"` e câmeras com `KEEP_HEIGHT`: outra proporção só muda a largura vista, a altura fica igual.
  HUD/telas de inspeção/pausa usam a área visível em unidades de 240 de altura (cantos e centro acompanham a largura).
- HUD (unidades de 240 de altura ampliadas, `main._build_hud`): no alto à esquerda a vida em barra (`HudBar`, número ao lado) e logo abaixo o sensor
  de perigo (`DangerMeter`, jeito Syphon Filter); no alto à direita o radar (`Radar`); embaixo à direita o modelo da arma na mão
  (`WeaponIcon`: SubViewport ortográfica, .glb soltos (as armas longas são os do baú, deitados: `LYING` os põe de perfil de novo), pistola comum = malha "Pistol" do corpo dela, `pistol_sd` com o
  silenciador; giro em `WeaponIcon.TURN`) com a munição ao lado só no survival; a ajuda (F1) quebra antes do radar.
  Mira (`Crosshair`, jeito Syphon Filter, camada sem escala no centro): cruz com um retângulo no meio, colchetes "[ ]" dos lados, tracinho no meio de cima/baixo e um pontinho fixo no centro (`DOT`). Tamanho
  dinâmico: `AREA_R` m na distância do que está sob ela pela lente da câmera (perto = maior, até `LOOSE_MAX`) + cone do
  próximo tiro (`Player.aim_spread`: arma, tiros seguidos, andando); focada no mesmo inimigo com tiro livre fecha em
  `FOCUS_TIME` até `FOCUS_HALF` (`focus_t`), saiu dele abre; na cabeça de quem tem headshot (`Player.body_part`) uma linha
  sai do canto de cima até "HEADSHOT"; tiro que bateu numa proteção com nome (`Player.armor_hit`) põe esse nome na mesma linha
  por `ARMOR_TIME` (FLAK JACKET, HARDENED; só depois do disparo, mirar não entrega). Corre para o tamanho (`SMOOTH`); verde, vermelha no alvo, cinza bloqueada.
  Furtividade no radar: fundo e moldura pulsam na cor do maior `alert_level` (mais rápido quanto pior) e embaixo dele um olho +
  VISÍVEL/INVISÍVEL (`Radar.INVISIBLE_AT` da `Radar._exposure`: agachada no aberto ao alcance de alguém não distraído = VISÍVEL, telhado ou alto da escada; nunca com alguém a vendo, `Enemy.has_eyes_on`)
  e o estado (DESCONFIADOS / BUSCA ATIVA / ALERTA!); o olho fecha escondida, olha para os lados na busca e fica vermelho no alerta.
  Perigo: cada inimigo diz `Enemy.threat()` (0..1, só em combate; esquivando = 0): soldado = chance de pelo menos um tiro da rajada
  acertar (`Soldier._hit_chance`, a mesma do `_fire`); o primeiro acerto só vem depois de `Soldier.LOCK_TIME` (0,6 s) mirando nela à vista (antes os tiros passam raspando), então o sensor avisa antes do dano; travou, vale até ele esquecê-la (`alert_t` = 0 fora de combate): sumir de vista ou esquivar não traz o aviso de volta (teste `soldier_tests.test_danger_before_hit`), sniper = sobe com a mira do laser, raptor/alossauro = golpe ao alcance
  (`_melee_threat`). O sensor junta tudo (1 - produto(1 - chance)), sobe rápido e desce devagar, rolando desce depressa e volta a subir
  se ela segue na mira; de `WARN` para cima pisca com "!!". Radar: centrado nela, girado com a câmera, contorno das salas
  (`Radar.ROOMS`) e portas (verde aberta/amarela fechada/vermelha trancada); inimigo só aparece depois de avistado uma vez (na tela, a
  `SPOT_RANGE` m, sem cenário no meio) e daí é rastreado (cor = `alert_level`; fora do alcance, preso na borda); morto some; R esquece.
  Barulho no radar: cada `Player.make_noise` (passo, cambalhota, tiro) emite `noise_made(raio, quem_ouviu)` (`Enemy.can_hear`) e o
  radar solta um anel que abre até o alcance real do som (`Radar.RING_TIME`): claro (`QUIET`) se ninguém ouviu, laranja (`HEARD`)
  se alguém ouviu, e o ponto de quem ouviu pisca com um anelzinho (`pings`). Parada/silenciosa = sem anel.
- Controles novos: F / X (cruz) = pular (com borda à frente: escala até MANTLE_MAX ou pula e fica pendurada; pendurada,
  frente/pular sobe e trás/agachar solta; sem borda, `Player._jump`: parada e sem direcional = pulo parado no lugar
  (`JUMP_UP_SPEED`, animação JumpUp; chegando parada no chão vindo do ar, `HeroineModel` toca Land = amortece com os pés presos e levanta, `heroine_jump.land_keys`; andar/correr cortam); andando (`JUMP_MOVING`) ou com direcional = pulo projetado para onde ele aponta, embalo
  mínimo `JUMP_FWD`, animação Jump = passada aberta; JumpUp/Jump/Fall com os mesmos braços abertos (`heroine_jump._air_arms`:
  a troca no meio do pulo não sacode o braço); no ar, de frente para uma borda com o alto
  entre `PlayerMoves.AIR_GRAB_LOW`/`AIR_GRAB_HIGH` acima dos pés, agarra e fica pendurada, `try_air_grab`; depois de soltar,
  `AIR_REGRAB` sem agarrar; derrubada da escada não agarra), E / triângulo = pegar (baú), Q/Tab / Select = trocar arma, G / R1 = recarregar (survival). Espaço / O (bola) = cambalhota, C / quadrado ou R3 = agachar (quadrado = `crouch_pad`, R3 = `crouch_stick`, só no jogo: nos menus o "crouch" é o X de confirmar, e no jogo o X que pula não agacha; `InputSetup.crouch_tapped`).
  Atirar = botão esquerdo do mouse / R2 (o R1 deixou de atirar). V / L3 (um toque liga, outro desliga; L3 segurado segue sendo a corrida forte, o toque só esgueira com quina à frente) = esgueirar pela quina no arcade (no survival o V/L3 encosta e o esgueirar vem da mira encostada na beirada, `PlayerLean.peek`/`unpeek`) (`PlayerLean`, `player_lean.gd`; em pé ou
  agachada, com e sem mira): com cobertura a até `REACH` à frente da câmera, acha a beirada mais perto dos dois lados (`SCAN`, caminho do
  corpo livre), vira para a frente da câmera, inclina o tronco (`LeanTilt`, modificador depois da AimPitch, até `ANGLE`) e, se precisa,
  dá um passo de lado até a cabeça passar da beirada (`CLEAR`); a câmera vai para o lado da quina (`CAM_SIDE`, ombro esquerdo na quina
  da esquerda). Outro toque, volta ao lugar; empurrar o direcional (`WALK_OUT`) sai da quina e ela anda dali; rolar/pular/golpe saem na hora. Os inimigos olham e miram em
  `Player.sight_point()` (o peito; esgueirada, a cabeça de fora). Captura: `--shot=lean|lean_aim`. Testes: `lean_tests.gd`.
  Encostar (`PlayerCover`, `player_cover.gd`, só no survival: `GameMode` "cover"), por comando (nunca sozinha: embolava subir/escalar):
  um toque no V / L3 (ação "lean"; o G e os dois empurrões do analógico saíram); com caixa/parede a até `REACH` (qualquer lado,
  a mais perto) vai até ela, vira de costas e escora (`Moves.cover().wall` do plano; a parede tem que
  existir atrás do glúteo e das omoplatas, `back_stand`/`back_crouch`: a caixa de 1,5 m serve em pé, a de 1 m só agachada);
  olha para a beirada mais perto; direcional para os lados anda colada (passos laterais na velocidade do andar agachada com teto de `STEP_RATE` do ritmo do StrafeL/R ou CrouchStrafeL/R, sem trotinho, `PlayerCover.slide_speed`, cabeça para onde vai, `HeadLook`) e
  para na beirada (`EDGE_MARGIN`, `at_edge`; empurrando mais `EDGE_HOLD`, contorna); o mesmo comando solta; para longe da parede sai;
  rolar/pular/golpe saem. Mirar encostada (`PlayerCover.aim_from_cover`, `aim_mode`), com a câmera para o lado da parede (`TOWARD`):
  na beirada (`PEEK_EDGE`) esgueira por ela; senão, bloco com o alto até `OVER_MAX` (1,2 m; o cano mirando em pé fica a ~1,37 m) =
  levanta e mira por cima (`OVER_MAX` = `Level.LOW_CRATE_H` + 0,1: as caixas baixas do galpão contam; o tiro sai pela linha da câmera,
  por cima da caixa, e os inimigos miram na cabeça dela, `Player.sight_point`); senão (ou câmera para o lado aberto) mira normal. O giro de ~180° até a parede passa pelo lado da
  beirada (`Player._aim_turn`) e, de volta à encostada, desfaz o giro pelo mesmo caminho (`_turned`/`_unwind`, nunca volta inteira). Mirar e levantar atrás de caixa baixa só pausam (`PlayerCover.hold`): soltou a mira, volta da quina / agacha de novo e,
  sem ter saído dali (`RESUME_DIST`), fica encostada. Andando de lado sem mirar (colada ou no passo da quina) a
  parte de cima vem da pose parada (`HeroineModel.cover_upper`/`HOLD_UPPER`): a arma fica junto ao corpo, não esticada como no StrafeL/R. A depuração do guerrilheiro em ragdoll passou do G para o J. Com arma longa só
  os braços vêm do RifleHold (`HeroineModel.COVER`, nó `carry_arms`). Ocultação: `Player.visibility_from(olho)` = ×`HIDE_MULT`
  para quem está do outro lado do plano da parede (`Enemy._sight_range`); do lado aberto, normal. Testes: `cover_tests.gd`.
  ESC / START = menu de pausa (`PauseMenu`, ação "pause": CONTINUAR / REINICIAR / SHOWROOM / TELA CHEIA / VIBRAÇÃO / SAIR DO JOGO; árvore pausada, não abre por
  cima de tela de inspeção nem no game over; volta ao jogo dois passos de física depois para o botão não chegar nela).
  TELA CHEIA: SIM/NÃO troca na hora e salva em `Settings` (`settings.gd`, `user://settings.cfg`); o `main` aplica ao abrir
  (capturas `--capture` ficam sempre na janela; os testes usam outro arquivo).
  VIBRAÇÃO (`Settings.vibration`, padrão SIM, mesmo arquivo): vibração do controle (`Rumble`, `rumble.gd`, todos os controles
  conectados, nos dois perfis). Vem do tremor da câmera (`CameraRig.shake` → `Rumble.shake`: tiro de cada arma, rugido, empurrão,
  arremesso, presa na boca, explosão, queda, abate furtivo; tremor pequeno = só o motor fraco) e de `Rumble.pulse` direto no
  `Player.take_hit`/`die`; pedido mais fraco não corta um mais forte; abrir a pausa para tudo; ligar dá um toque.
  START não reinicia mais; R no teclado segue reiniciando. Captura: `--shot=pause`. Testes: `pause_tests.gd`.
  SHOWROOM (item do menu, `Showroom`, `showroom.gd`): palco 3D próprio (SubViewport com mundo à parte numa camada sem escala,
  chão quadriculado, luz com sombra) com o raptor ou o alossauro (`RaptorModel.showroom` = pés presos e inércia sem corpo de
  física) e a lista das animações dele (ciclos primeiro, nome em português de `Showroom.NAMES` + o do arquivo; as que não são
  ciclo repetem). Cima/baixo ou clique escolhe, A/D/analógico direito/arrastar gira a câmera, roda/Z/X/L1/R1 zoom, Q/TAB/SELECT
  troca o bicho, F/quadrado o modo (NO LUGAR = animação pura sem FootPlant/TurnSway; EM CÍRCULO = os ciclos de `GAITS` andam
  numa roda na velocidade do jogo; GIRANDO = vira no lugar a `TURN_RATE`), ESPAÇO/X a velocidade (1x, 1/2, 1/4, parado),
  ESC/START/C/bola volta ao menu. Captura: `--shot=showroom [--creature=raptor|allosaurus] [--anim=Walk]
  [--move=lugar|circulo|girando] [--yaw=graus] [--at=s]` (o `--at` conta num relógio que roda com o jogo pausado).
- Cambalhota de mergulho (`heroine_moves.roll_keys`): ~2,6 m em 1 s. Passada de impulso (a esquerda vai à frente, braços para trás,
  `ROLL_STEP`), empurra com ela e mergulha num arco (o corpo sobe e desce girando de inclinado até de cabeça para baixo,
  braços esticados, sem a cápsula sair do chão), as mãos tocam bem à frente (`ROLL_HANDS`), o embalo leva o corpo por cima
  delas até os ombros e ela segue rolando sem frear; levanta agachada. O centro do novelo (`ROLL_C`) fica na altura em que as costas encostam no chão e o caminho anda giro x raio.
- Movimentos com deslocamento (cambalhota, subir, escalar, pegar): o caminho da raiz sai do Blender (`*_PATH` em
  `heroine_moves.py`, gravado em heroine_moves.json) e o Godot segue o mesmo caminho (`Moves.hermite`, igual ao Python).
  Mudou pose/caminho: regerar a arte e rodar os testes (conferem mãos na borda e pé sem deslizar).
  Andar/agachar/mirar andando usam `Moves.speed(...)` = a velocidade em que o ciclo foi resolvido.
- Armas: pistola, M16 e escopeta são malhas à parte presas a Hand_R; `HeroineModel.set_weapon`/`holster` mostram uma só.
  Com arma longa (`LONG_GUNS`), a parte de cima usa RifleHold/RifleAim e o tiro RifleShoot ou ShotgunShoot.
  RifleHold (carregando, parada/andando, igual nos dois corpos): braços primeiro, fuzil depois (`heroine_rifle.hold_pose`):
  `HOLD_ARMS` somado ao IDLE (direito junto ao corpo, antebraço cruzando a barriga; esquerdo solto), o pulso direito aponta o
  fuzil para a palma esquerda (diagonal na frente do peito, coronha no alto à direita) e o braço esquerdo só ajusta a palma na telha.
  Agachada com a pistola: guarda baixa com as duas mãos (`pistol_guard` em `heroine_anims.py`, IK sobre a pegada da mira).
  Mirando, ela vira para o ponto sob a retícula (`CameraRig.aim_point`, `Player._face_aim`: giro acima de `AIM_BIG_TURN` mantém o lado em que começou) e `AimPitch` (SkeletonModifier3D) inclina coluna
  e peito até a altura dele: o cano aponta para onde o tiro vai. A pose modificada só aparece no desenho e nos
  BoneAttachment3D (cano); `get_bone_global_pose` lido de fora devolve a da animação. Captura: `--pitch=graus` com `--yaw`. A escopeta
  tem o cabo, a soleira e a telha nos mesmos pontos do M16 (mesmas poses, mesmo Pickup, mesmo RIFLE_CHEST). A arma do
  baú (`m16.glb`/`shotgun.glb`, `Chest.item` antes de entrar na árvore) já vem do build na posição em que as mãos a
  pegam (RIFLE_CHEST, em relação à raiz dela ajoelhada a `kneel_dist` da frente do baú): deitada de lado como num estojo
  (perfil para cima, cano para a esquerda dela, cabo/carregador virados para ela, `heroine_rifle.CHEST_IN/CHEST_Z/CHEST_UP`;
  a pose `reach` do Pickup resolve o tronco por IK para as mãos chegarem e a esquerda vai por cima da telha, `CHEST_GRIP`). No
  fundo do baú um colchãozinho de espuma cinza com o vão na forma da arma (`Chest.foam`, usado também pela caixa de
  paraquedas: a malha da arma projetada de cima numa grade de `FOAM_CELL`, vão em degraus de `FOAM_STEP` com `FOAM_GAP`
  células de folga, topo da espuma no meio da espessura da arma, `FOAM_MAX`; na caixa de paraquedas como nos baús: paredes por
  dentro `SupplyDrop.RIM`, espuma `FOAM_IN` abaixo da boca e a pistola atravessada no meio, cano para a esquerda dela,
  `heroine_drop.CRATE_*`; o topo é arredondado para float32 como as alturas, senão a espuma inteira vira vão). Estêncil do baú sem "U.S." (só calibre e nome).
  A telha da escopeta (`ShotgunPump`, BoneAttachment3D) é movida pelo Godot seguindo `PUMP_KEYS` (heroine_moves.json
  "shotgun"), o mesmo caminho da mão esquerda na animação; no fundo do curso sai o cartucho (`shell_ejected`).
- M79 (lança-granadas, `heroine_m79.py`; mesmas poses/Pickup/RIFLE_CHEST das armas longas, tiro `M79Shoot`): `WEAPON_STATS.m79.grenade`
  troca o raio por `Grenade.launch` (arco baixo que cai no ponto da retícula, `aim_velocity`). Antes de `ARM_DIST` só dá a pancada;
  armada explode (`Grenade.explode`: dano em área até `RADIUS`, só em quem está à vista — parede/porta protegem —, empurra corpos,
  arremessa a jogadora perto e ela leva `PLAYER_SHARE` do dano; barulho `NOISE`; `Fx.explosion` + mancha `Fx.scorch`, que conta em
  `MAX_DECALS` e some com o R). Survival: 4 granadas no baú, caixa verde em `Pickup.LAYOUT`.
- Caixotes de explosivos (`ExplosiveCrate`, jeito Syphon Filter; textura `explosive.png` de `make_level_textures.py`, UV 0..1 por
  face): só no fundo do túnel da mina (`Tunnel.STACKS`; o posto da porta do pátio do galpão voltou a ser o de antes, sem
  eles). Os 4 guardas do fundo mexem nos caixotes de trabalho (`Tunnel.GUARDS` "work"; distraídos como o do painel, animação
  Console, detonador virado para eles por `ExplosiveCrate.work_dir`, fuzil encostado `Soldier._stowed`). Bala comum
  (`Player._pellet_hit`) só bate no metal: mossa, a mira escreve HARDENED (`armor_hit`) e `ping` = `on_alarm` em quem está a
  `PING_RANGE` na mesma sala (quem está no caixote larga o trabalho). Explosão perto (`Grenade.explode` → `shockwave`, ou outro caixote a
  `CHAIN_RADIUS`) detona com atraso pela distância: cada um é um `Grenade.blast` (`RADIUS`/`DAMAGE`, os outros caixotes não protegem,
  empurrão `BODY_PUSH` pequeno: são muitos), some e deixa o chão pegando fogo (`Fire.burn`: chamas, luz, fumaça, machuca quem fica
  dentro); guarda morto perto pega fogo (`Soldier.ignite`: `Fire.attach` no peito/quadril do ragdoll, `HeroineModel.char_body`
  carboniza). As pilhas de cada lado encadeiam até as do portão: a granada num lado pega os dois daquele lado e arromba o
  portão da pedreira; o detonador (`Tunnel`) estoura todas. R: caixotes de volta, fogo apagado (`Fire.clear`).
  Testes: `explosive_tests.gd`.
- Container trancado e chave (jeito RE/Dino Crisis): `Chest.lock` = id da chave (ferrolho + cadeado na frente). A M79 fica no
  container sem estêncil (surpresa) atrás de onde ela começa (`main.LOCKER_POS`); a chave (`KeyItem`) está na mão do guerrilheiro
  morto no meio do pátio (`Corpse`, ver Pátio da mata); `TargetDummy.loot` (cai do alvo morto, brilhando) segue valendo para
  outros itens e testes. Item largado no chão (`KeyItem` "dropped": cartão do sniper, loot) brilha igual à arma largada
  (`Pickup.glow_set`: halo no chão e feixes em cruz) em azul claro (`KeyItem.DROP_GLOW`); o escondido na mão do morto ("held")
  não tem halo, só a estrela que pisca depois da emboscada. Pega com E ao chegar perto (`Player.keys`); o item no chão tem
  prioridade sobre o baú/container (`pick_key` antes de `pick_target`: o cartão do sniper do mezanino pode cair junto ao container da M79). Interagir no
  trancado emite `Player.locked` → `Inspect.lock_zoom` (jogo pausado, câmera vai até o cadeado; sem chave chacoalha e avisa, com
  chave ele cai e a chave é gasta). Pegar a chave → `Inspect.show_item` (item girando numa SubViewport). As telas de inspeção
  pausam a árvore (ao fechar, `Inspect._close` solta os botões e só volta o jogo dois passos de física depois: o X/E que fechou não vira esquiva nem ação) e rodam com `PROCESS_MODE_ALWAYS` (sons delas por `Sfx.ui`); `auto_close`/`on_shown` para testes e capturas.
  Reiniciar tranca de novo e devolve a chave ao morto. Testes: `key_tests.gd`, `ambush_tests.gd`.
  Caixa de texto das telas (`Inspect._layout_box`): título amarelo no alto com respiro (`BOX_PAD`), botões no pé (`UiStyle.Hint`: `OK_ITEMS` ou
  os do teclado, `KEYPAD_ITEMS`) e o texto centralizado no meio; a caixa cresce com o texto e o item fica acima dela, nada se sobrepõe.
- Textos do jogo em português com acento (a fonte padrão do Godot tem os glifos).
- Design system dos textos (`UiStyle`, `ui_style.gd`): cores INK/ACCENT/ACTION/WARN/DANGER/MUTED, tamanhos S 8 / M 12 / L 24 (unidades
  do HUD de 240 de altura; a munição ao lado da arma é M), fundos SHADE/DEATH_SHADE/BAND, `UiStyle.label`/`rect`. Botão nunca vai escrito no texto ("(E)", "E:"): usa
  `UiStyle.Hint` (fileira "<glifo> VERBO"; glifo do mapa do `InputSetup` pelo último aparelho, `UiStyle.pad` via `UiStyle.Watcher`:
  tecla numa moldura ou triângulo/bola/X/quadrado/direcional desenhados). Prompt de ação (`main._prompt`) junta pegar/abrir e o
  abate furtivo (atirar). Captura com os glifos do controle: `--pad`. O teste `ui_style_tests.gd` barra cor/tamanho solto nos scripts.
- Tiro pela linha da câmera: o raio sai de `Player.shot_origin` (o ponto da linha da retícula mais perto do cano; cano encostado
  em cenário = do cano) na direção da retícula, então acerta o que ela mostra (antes, olhando por cima de uma pilha, o raio do
  cano batia na quina); `aim_target_info` (mira cinza = bloqueada) usa a mesma origem. Teste: `sniper_ladder_tests.test_shot_hits_what_camera_sees`.
- Tiros: `Player.WEAPON_STATS` (cadência, dano por projétil, chumbos, dispersão/abertura em rajada, alcance com queda
  de dano, tremida, cápsula); chumbos no mesmo alvo somam num `take_hit` só. Efeitos em `Fx` por arma e por superfície
  (meta "surface" do corpo = textura do `Level.block`); buraco de bala (`Fx.decal`) só em cenário, preso ao corpo,
  sem pendurar em quina, no máximo `MAX_DECALS`; "no_decals" no corpo desliga (baú). R apaga os buracos.
- Sons (`Sfx`, tabela `SOUNDS` em `sfx.gd` = nomes/variações de `make_sounds.py`; o teste confere que batem): o corpo toca os seus
  (`HeroineModel`: tiro da arma da mão, telha, troca, pancada, queda, cambalhota/pulo/aterrissagem/borda e passos quando o osso
  Foot_* desce até o chão; `RaptorModel`: voz/golpe de cada animação em `ANIM_SOUNDS`, passos pelos Toe_*, piados), `Fx` toca
  impacto por superfície e cápsula no chão, `Chest` a tampa. Chão com meta "step" = "grass" = passos na grama. `Soundscape`
  (criado no main): ambiente do galpão/pátio misturado pela posição dela e o toque "?" dos bichos que desconfiam (caça/combate
  sem som de aviso; quem fala diz o seu "Ahn?"). O "?"/"!" sobre a cabeça (`Enemy._update_marker`) só pisca quando o nível
  sobe: cresce, fica `MARKER_HOLD` e some (`MARKER_*`), nunca fica preso.
- Falas dos guerrilheiros (`Voice`, `voice.gd`; soldado e sniper têm `Enemy.voice` de `Voice.assign()`, as 3 vozes em rodízio;
  bicho = ""): `Enemy._voice_on` na troca de estado = "spot" (viu ela), "lost" (sumiu na luta), "huh" (desconfiou), "check"
  (foi ver sozinho) / "ack" (saiu pelo alarme de outro), "search" (chegou ao lugar da busca ativa); fim da busca no estado
  "search" = "giveup" (ativa) / "nothing" (amarela); grito do `SHOUT_DELAY` = "corpse" / "hit". Uma fala por vez no jogo
  todo (`PRIORITY`: a mais alta corta a que toca; igual ou mais baixa se perde), intervalo por tipo (`GAP`), sem repetir a
  frase seguida, só se ela ouviria (`_reaches`, até `MAX_DIST`), nada na cena nem na rendição. Relógio = passos de física.
  `Voice.reset()` no `_reset_world`. Testes: `voice_tests.gd`.
- Depois de mudar arte/animação: renderizar prévia e olhar; depois de mudar o jogo: capturar e olhar.
- Sangue (`Blood`, jeito Dino Crisis): esguicho vermelho sem luz no golpe + gotas que viram respingo onde caem, respingo
  na parede/chão atrás (`SPATTER_RANGE`), rastro de gotas de quem está ferido (`Blood.Trail`, pelo `wound()` 0..1; a jogadora só pinga com vida até
  `Player.BLEED_AT` (30), `Player.bleed`) e poça
  crescendo embaixo do corpo morto (`Blood.pool`). Respingos/poças são decalques presos ao cenário (sem personagem, ragdoll
  nem "no_decals"), no máximo `MAX_SPLATS`; `Blood.clear()` no reinício. Quem leva tiro de carne: o esguicho sai no tiro
  (`Player._pellet_hit`); dano na jogadora sai no `Player.take_hit`.
- Headshot: tiro que passa pela parte "Head" do ragdoll (as partes acompanham a animação; a cápsula é atravessada por
  `Player.body_part`) multiplica o dano por `head_mult` do alvo e chama `take_headshot` (HUD "HEADSHOT"). Soldado ×10 e `Soldier.take_headshot` mata sempre (qualquer arma/distância); a cabeça conta também por proximidade do raio (`HEAD_HIT_RADIUS`),
  alvo ×4; raptor `head_mult = 1` = sem headshot (cabeçudo).
- Proteção por parte (`Enemy.armor_parts/armor/armor_name`, `armor_mult(part)`/`armor_tag(part)`): o tiro (`Player._pellet_hit`, parte
  do ragdoll achada por `body_part`, até `part_probe` m dentro da cápsula) fora da cabeça multiplica o dano pela proteção. Guerrilheiro e
  sniper de colete (`Soldier.VEST_PARTS` = tronco, `VEST_MULT` 0,5); os 2 sentinelas da porta da sala dos clones (`"flak"` em
  `Soldier.GUARDS`) de Flak Jacket (`FLAK_MULT`, a mira escreve FLAK JACKET); alossauro, ver Alossauro. `take_hit` direto (granada,
  testes) não passa pela proteção.
