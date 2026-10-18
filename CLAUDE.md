# syphoncrisis

Protótipo de jogo no visual de PS2 do começo (com modo PS1 para comparar; Syphon Filter + Dino Crisis): heroína em
3ª pessoa, animações principais e ragdoll, e um velociraptor inimigo (estilo Dino Crisis 2).

## Stack
- Arte gerada por código: Blender 4.5 LTS (`bpy`, sem interface) + Pillow (`requirements.txt`) para as texturas.
- Sons gerados por código: numpy (`requirements.txt`), WAV mono 16 bits a 22050 Hz.
- `art/heroine.blend` e `art/raptor.blend` são gerados pelo build e ficam fora do git (guardavam caminhos absolutos da máquina).
- Jogo: Godot 4.7 (GDScript, Forward+, física Jolt). Projeto em `game/`.
- Sem backend, sem rede, sem dados pessoais.

## Pastas
- `art/` — gerador da heroína: `heroine_spec.py` (medidas/ossos), `heroine_mesh.py` (malha por anéis + UV + pesos),
  `heroine_rig.py` (esqueleto, materiais, marcador do cano), `heroine_anims.py` (animações em keyframes),
  `heroine_head.py` (cabeça esculpida de 16 lados, nariz, cabelo em calota/franja/laterais/cortina com pontas por alfa),
  `build_heroine.py` (monta tudo e exporta), `solve_run.py` (resolve pernas/quadril da corrida para o pé de apoio não
  deslizar; imprime `RUN_HALF` para `heroine_anims.py` — rodar com `art/heroine.blend` ao mudar a pose da corrida), `preview.py` (renders de conferência, serve para os dois), `atlas.py` (layout da textura).
  `heroine_ik.py` (FK pelas matrizes de repouso + IK numérica), `heroine_gait.py` (caminhada, agachada e passos
  laterais com o pé de apoio preso no chão por IK), `heroine_moves.py` (cambalhota, pulo/queda, pendurar, subir da
  borda, escalar obstáculo baixo: poses + apoios presos + caminho da raiz), `heroine_rifle.py` (malha do M16, poses
  com o fuzil e a animação de pegar no baú), `heroine_shotgun.py` (malha da escopeta, telha à parte e a animação de
  tiro com coice e bombeamento).
  Guerrilheiro encapuzado (inimigo humano): `guerrilla_mesh.py` (malha própria de homem no esqueleto dela: moletom com capuz levantado de dois lados, balaclava, colete,
  calça cargo, coturno), `guerrilla_atlas.py` (layout dela + `cargo`/`cord`),
  `build_guerrilla.py` (mesmo esqueleto/animações; gera `guerrilla.glb`; `art/guerrilla.blend` fica fora do git) e `tools/make_guerrilla_texture.py` (atlas 512 com o layout da heroína).
  Raptor: `raptor_spec.py`, `raptor_mesh.py` (usa o MeshBuilder da heroína; pele única: cadeias com anel de emenda
  soldado + união booleana `_self_union` das peças que se cruzam), `raptor_rig.py` (aceita `spec`/`mesh`/`name`),
  `raptor_anims.py` (IK nas pernas; convenção de ângulos no cabeçalho), `raptor_atlas.py`, `build_raptor.py`.
  Alossauro (chefe, 9 m, mesmos ossos do raptor): `allosaurus_spec.py`, `allosaurus_mesh.py` (ferramentas do raptor; cabeça
  com quinas vivas e cristas em quilha), `allosaurus_anims.py` (IK do raptor recarregado com as medidas dele; quadros
  STOMP_HIT/BITE_SNAP/THROW_RELEASE/ROAR_PEAK usados pelo jogo), `build_allosaurus.py` (`art/allosaurus.blend` fora do git).
  `possible_models/` (modelos extraídos de jogos comerciais) é só referência local, fora do git: nada dali entra no jogo.
- `tools/` — `make_textures.py` (atlas 512x512 da heroína: corpo pintado em 256 e ampliado) + `paint_clothes.py` (trama,
  rugas, costuras, zíper em 512) + `paint_face.py` (rosto e cabelo em 512, preenchimento das bordas),
  `make_raptor_texture.py` (atlas 512x512 do raptor), `make_allosaurus_texture.py` (atlas do alossauro com as mesmas ferramentas), `make_level_textures.py` (texturas 256x256 do cenário e dos baús,
  buracos de bala `bullet_holes.png`, quadros do clarão/fumaça `shot_fx.png` e do sangue `blood_fx.png`),
  `make_sounds.py` (efeitos sonoros em `game/assets/sounds/`; blocos de síntese em `sound_dsp.py`, vozes do raptor/avisos/
  ambientes em `sound_creatures.py`), `contact_sheet.py` / `game_sheet.py` (folhas de prévia), `run_godot_tests.mjs` (testes).
- `game/` — `scripts/` (jogadora + `player_moves.gd` + `player_stealth.gd`, inimigos `enemy.gd` (base) / `raptor.gd` / `soldier.gd`, câmera, modelo, ragdoll, alvos, raptor + modelo do raptor, cenário, pátio da mata `yard.gd`,
  portas `door.gd` (galpão→pátio, pátio→pedreira), pedreira `arena.gd` (última sala) + alossauro `allosaurus.gd`/`allosaurus_model.gd`, baú `chest.gd`, `moves.gd` (lê heroine_moves.json), efeitos `fx.gd` + sangue `blood.gd`, `gfx.gd`), `shaders/` (`psx_*` = PS1, `ps2_*` = PS2 do
  começo), `tests/run_tests.gd` (+ `raptor_tests.gd`, `gfx_tests.gd`, `moves_tests.gd`, `weapons_tests.gd`, `ai_tests.gd`, `soldier_tests.gd`, `blood_tests.gd`, `allosaurus_tests.gd`), `assets/` (gerados — não
  editar à mão; inclui `m16.glb`/`shotgun.glb` = armas dos baús e `heroine_moves.json` = caminhos/medidas dos movimentos).

## Comandos
- Regerar arte: `python tools/make_textures.py && python tools/make_sounds.py && python tools/make_level_textures.py && python tools/make_raptor_texture.py && python tools/make_allosaurus_texture.py && python tools/make_guerrilla_texture.py && blender --background --factory-startup --python art/build_heroine.py && blender --background --factory-startup --python art/build_raptor.py && blender --background --factory-startup --python art/build_allosaurus.py && blender --background --factory-startup --python art/build_guerrilla.py`
  (Blender em `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe`)
- Prévia no Blender: `blender --background art/heroine.blend --python art/preview.py -- <pasta> turntable|anims|Acao:f1,f2` (ou `art/raptor.blend`)
- Testes: `node tools/run_godot_tests.mjs` (passo fixo `--fixed-fps 60`: segundos em vez de minutos; o hook corta em 240 s)
- Rodar o jogo: `godot --path game` (F2 alterna o visual PS1/PS2; `-- --gfx=ps2` já começa no PS2)
- Captura do jogo: `godot --path game -- --capture=out.png --shot=idle|aim|run|crouch|roll|ragdoll|dummy [--yaw=graus] [--at=segundos]`
  Rosto: `--shot=face [--yaw=graus]`. Visual: `--gfx=ps1|ps2`.
  Movimentos: `--shot=walk|crouch_walk|crouch_aim|jump|hang|climb|mantle|pickup|rifle|rifle_aim`.
  Armas: `--shot=pickup_shotgun|shotgun|shotgun_aim|fire_pistol|fire_m16|fire_shotgun|pump` (tiros na pilha de caixas;
  a captura imprime `buracos=`).
  Raptor: `--shot=raptor_roar|raptor_study|raptor_bite|raptor_tail|raptor_leap|raptor_charge|raptor_dead|raptor_idle [--playercam]`
  Sangue: `--shot=soldier_headshot|soldier_wounded|raptor_blood [--playercam]`.
  Alossauro: `--shot=allo_idle|allo_roar|allo_roar_at|allo_stomp|allo_headbutt|allo_tail|allo_bite|allo_dead|allo_end [--playercam]`; pedreira: `--shot=arena`.
  Depois de regerar um .glb/.png, `godot --headless --path game --import` (rodar o jogo não reimporta sozinho).
  (a primeira execução depois de editar scripts reimporta o projeto e pode sair com a cena errada: rode de novo).

## Convenções
- Blender: Z para cima, personagem olha para -Y, lado esquerdo dela em +X. No Godot o modelo é girado 180° (frente = -Z).
- Ossos sem ponto no nome (`UpperArm_L`), para virarem nomes válidos no Godot.
- Ângulos das animações: ver cabeçalho de `art/heroine_anims.py` (X>0 dobra para a frente, joelho dobra com X<0).
- Orçamento (PS2 do começo): 800–5000 triângulos por personagem (o teste confere). Atlas 512x512 (heroína com alfa nas
  pontas do cabelo); o Godot usa os PNGs direto, não a cópia do .glb. Fundo dos atlas preenchido (sem magenta) para o filtro.
  Cenário: ladrilhos de 256 (~2 m cada), com mipmaps.
- Tronco da heroína: elipse por anel + `torso_volume` (busto, glúteos, escápulas); laterais na altura do ombro com peso
  parcial no braço (`_shoulder_share`) para não abrir vão ao erguer o braço. `loft` aceita `wfn` (pesos por vértice).
- Visual (`Gfx`, padrão "ps2"): materiais dos dois modos têm os mesmos parâmetros; trocar de modo só troca o shader. Material novo: `Gfx.shader()`.
  Luzes do cenário no grupo "lamps" (sombra no PS2).
- Camadas de física: 1 cenário, 2 personagens (cápsulas; o raptor também, com caixa no tronco para os tiros), 4 ragdoll (só colide com o cenário).
- IA e furtividade (`enemy.gd` = base de `Raptor` e `Soldier`; `Player.visibility()/make_noise()`): o inimigo patrulha `route` e percebe pela visão (cone de 150°, alcance
  `SIGHT_RANGE * Player.visibility()`: parada 0,7, andando 0,75, correndo/rolando/atirando 1, agachada 0,3–0,45, capim alto ×0,5 agachada)
  e pelo barulho (`hear_noise`: passos de corrida 10 m, andando 4 m, agachada 2 m, tiro 26 m). A atenção (`aware`) sobe → `suspicious`
  (para e olha, "?") → `investigate` (vai ao ponto do barulho) ou, se a vê, `spot()` = grito + `on_alarm` nos outros do grupo "raptors"
  (`hunt` até o último ponto + visão em volta toda, "!"; o grupo "enemies" mistura raptors e soldados). Em combate sem vê-la por `LOSE_TIME` → `hunt` → `search` → volta à rota.
  Soldado = guerrilheiro encapuzado (`soldier.gd`, `HeroineModel` com `guerrilla.glb`/`guerrilla_atlas.png` e M16): guardas do galpão em `Soldier.GUARDS`; `alert` (reage 0,7 s) → `engage` (mira, rajadas de 2–4
  tiros instantâneos, chance de acerto cai com distância/agachada/correndo, rolar esquiva; avança, recua ou anda de lado); morre em ragdoll. Revisão: `--shot=soldier|soldier_dead`.
  Caminhos: `NavigationServer3D` com a malha de `Yard.bake_nav` (sem malha, anda reto desviando com raios). Testes: `ai_tests.gd`.
- Pátio da mata (`Yard`): segunda sala a oeste do galpão (porta na parede oeste, z = `Yard.DOOR_Z`), clareira de capim com estrada de terra
  até um portão, árvores/arbustos/pedras/troncos, touceiras de capim alto (grupo "cover", meta "radius"), 3 raptors em `Yard.POSTS` com rotas.
  Texturas `grass/dirt/bark/leaves/rock/grass_card/fern_card` vêm de `tools/make_level_textures.py`. Revisão: `--shot=yard --pos=x,z[,graus]`.
- Raptor: ataques resolvidos em `raptor.gd` (`_strike` = dano + `knockback`); a mordida chama `Player.grab()`, que liga o ragdoll dela
  com o antebraço esquerdo puxado para a boca (`Ragdoll.drag`) e a luta dela por cima; rolar (`is_dodging`) esquiva de tudo.
  Salto (golpe sai das garras dos pés) e investida chamam `Player.launch()`: ragdoll arremessado em C em volta do golpe
  (`Ragdoll.fling` + `_hold_c`), depois ela levanta. A morte do raptor é ragdoll (`RaptorModel.RAGDOLL`), não animação.
  Andando, o raptor só se move para a frente do corpo e a velocidade da animação acompanha (`WALK_ANIM_SPEED`/`RUN_ANIM_SPEED`).
- Salas e portas (`Door`, `Level.room_of/connected`): 0 galpão, 1 pátio, 2 pedreira. As duas portas (de correr no galpão, portão de ferro no fundo do pátio) começam fechadas: bloqueiam corpo, tiro e visão e abrem com E perto delas (`Player.pick_door`; reiniciar fecha). `Enemy.hear_noise`/`on_alarm` só valem na mesma sala ou com todas as portas entre elas abertas: tiro e grito de uma sala não chamam os inimigos das outras. `Yard.bake_nav` desliga as portas na hora de assar a malha.
- Pedreira (`Arena`): última sala, depois do portão (fechado até abrir) no fundo do pátio; paredões de pedra, ruínas e pedras grandes
  (cobertura que o alossauro não atravessa), capim alto, postes (`Yard.lamp`). Alossauro em `Arena.ALLO` e 2 raptors em `Arena.POSTS`.
- Alossauro (`allosaurus.gd`, herda `Enemy`; modelo `AllosaurusModel` = `RaptorModel` com outro arquivo/atlas/ragdoll/sons graves):
  vê → ruge (`ROAR_RANGE`: `Player.daze(3 s)`, não fere; volta a rugir com `ROAR_COOLDOWN`) → persegue andando (`stalk`) e escolhe:
  pisada (perto: o pé que desce fere e arremessa, o tremor só empurra), mordida (à frente: `Player.grab`, sacode e arremessa para a
  esquerda dele com `release`) ou investida (longe). Rolar esquiva de pisada e mordida. Só reage a tiro depois de `FLINCH_DAMAGE`.
  Morte em ragdoll → sinal `killed` → tela de fim do `main` (FIM, tempo, tiros; R reinicia). Atordoada: estado "dazed" da
  heroína (animação Dazed), aviso "ATORDOADA" no HUD; golpe, mordida ou reinício acabam com ela.
- Controles novos: F / quadrado = pular (com borda à frente: escala até MANTLE_MAX ou pula e fica pendurada; pendurada,
  frente/pular sobe e trás/agachar solta), E / triângulo = pegar (baú), Q/Tab / Select = trocar arma. Espaço / X = cambalhota.
- Movimentos com deslocamento (cambalhota, subir, escalar, pegar): o caminho da raiz sai do Blender (`*_PATH` em
  `heroine_moves.py`, gravado em heroine_moves.json) e o Godot segue o mesmo caminho (`Moves.hermite`, igual ao Python).
  Mudou pose/caminho: regerar a arte e rodar os testes (conferem mãos na borda e pé sem deslizar).
  Andar/agachar/mirar andando usam `Moves.speed(...)` = a velocidade em que o ciclo foi resolvido.
- Armas: pistola, M16 e escopeta são malhas à parte presas a Hand_R; `HeroineModel.set_weapon`/`holster` mostram uma só.
  Com arma longa (`LONG_GUNS`), a parte de cima usa RifleHold/RifleAim e o tiro RifleShoot ou ShotgunShoot.
  Agachada com a pistola: guarda baixa com as duas mãos (`pistol_guard` em `heroine_anims.py`, IK sobre a pegada da mira).
  Mirando, ela vira para o ponto sob a retícula (`CameraRig.aim_point`) e `AimPitch` (SkeletonModifier3D) inclina coluna
  e peito até a altura dele: o cano aponta para onde o tiro vai. A pose modificada só aparece no desenho e nos
  BoneAttachment3D (cano); `get_bone_global_pose` lido de fora devolve a da animação. Captura: `--pitch=graus` com `--yaw`. A escopeta
  tem o cabo, a soleira e a telha nos mesmos pontos do M16 (mesmas poses, mesmo Pickup, mesmo RIFLE_CHEST). A arma do
  baú (`m16.glb`/`shotgun.glb`, `Chest.item` antes de entrar na árvore) já vem do build na posição em que as mãos a
  pegam (RIFLE_CHEST, em relação à raiz dela ajoelhada a `kneel_dist` da frente do baú).
  A telha da escopeta (`ShotgunPump`, BoneAttachment3D) é movida pelo Godot seguindo `PUMP_KEYS` (heroine_moves.json
  "shotgun"), o mesmo caminho da mão esquerda na animação; no fundo do curso sai o cartucho (`shell_ejected`).
- Tiros: `Player.WEAPON_STATS` (cadência, dano por projétil, chumbos, dispersão/abertura em rajada, alcance com queda
  de dano, tremida, cápsula); chumbos no mesmo alvo somam num `take_hit` só. Efeitos em `Fx` por arma e por superfície
  (meta "surface" do corpo = textura do `Level.block`); buraco de bala (`Fx.decal`) só em cenário, preso ao corpo,
  sem pendurar em quina, no máximo `MAX_DECALS`; "no_decals" no corpo desliga (baú). R apaga os buracos.
- Sons (`Sfx`, tabela `SOUNDS` em `sfx.gd` = nomes/variações de `make_sounds.py`; o teste confere que batem): o corpo toca os seus
  (`HeroineModel`: tiro da arma da mão, telha, troca, pancada, queda, cambalhota/pulo/aterrissagem/borda e passos quando o osso
  Foot_* desce até o chão; `RaptorModel`: voz/golpe de cada animação em `ANIM_SOUNDS`, passos pelos Toe_*, piados), `Fx` toca
  impacto por superfície e cápsula no chão, `Chest` a tampa. Chão com meta "step" = "grass" = passos na grama. `Soundscape`
  (criado no main): ambiente do galpão/pátio misturado pela posição dela e avisos "?"/"visto!" pelo `alert_level` dos inimigos.
- Depois de mudar arte/animação: renderizar prévia e olhar; depois de mudar o jogo: capturar e olhar.
- Sangue (`Blood`, jeito Dino Crisis): esguicho vermelho sem luz no golpe + gotas que viram respingo onde caem, respingo
  na parede/chão atrás (`SPATTER_RANGE`), rastro de gotas de quem está ferido (`Blood.Trail`, pelo `wound()` 0..1) e poça
  crescendo embaixo do corpo morto (`Blood.pool`). Respingos/poças são decalques presos ao cenário (sem personagem, ragdoll
  nem "no_decals"), no máximo `MAX_SPLATS`; `Blood.clear()` no reinício. Quem leva tiro de carne: o esguicho sai no tiro
  (`Player._pellet_hit`); dano na jogadora sai no `Player.take_hit`.
- Headshot: tiro que passa pela parte "Head" do ragdoll (as partes acompanham a animação; a cápsula é atravessada por
  `Player.body_part`) multiplica o dano por `head_mult` do alvo e chama `take_headshot` (HUD "HEADSHOT"). Soldado ×10 e `Soldier.take_headshot` mata sempre (qualquer arma/distância); a cabeça conta também por proximidade do raio (`HEAD_HIT_RADIUS`),
  alvo ×4; raptor `head_mult = 1` = sem headshot (cabeçudo).
