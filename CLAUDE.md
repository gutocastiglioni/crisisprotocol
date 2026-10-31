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
  `heroine_head.py` (cabeça esculpida de 16 lados, nariz; cabelo por `HAIR_STYLE`: "braid" = calota puxada + franja + trança única
  nas costas (retângulo "braid" do atlas, pintado em `paint_face.paint_braid`), "loose" = calota/franja/laterais/cortina com pontas por alfa),
  `build_heroine.py` (monta tudo e exporta), `solve_run.py` (resolve pernas/quadril da corrida para o pé de apoio não
  deslizar; imprime `RUN_HALF` para `heroine_anims.py` — rodar com `art/heroine.blend` ao mudar a pose da corrida), `preview.py` (renders de conferência, serve para os dois), `atlas.py` (layout da textura).
  `heroine_ik.py` (FK pelas matrizes de repouso + IK numérica), `heroine_gait.py` (caminhada, agachada e passos
  laterais com o pé de apoio preso no chão por IK), `heroine_moves.py` (cambalhota, pulo/queda, pendurar, subir da
  borda, escalar obstáculo baixo, sair da escada pelo topo = LadderOut (mãos na beirada viradas para a frente, joelho na beira) e entrar = LadderIn (a mesma ao contrário; versões `Low` para beirada sem rebordo): poses + apoios presos + caminho da raiz), `heroine_strike.py` (golpes furtivos Assassinate/CritStrike, mesmo jeito), `heroine_rifle.py` (malha do M16, poses
  com o fuzil e a animação de pegar no baú), `heroine_shotgun.py` (malha da escopeta, telha à parte e a animação de
  tiro com coice e bombeamento), `heroine_m79.py` (malha do lança-granadas M79, cano octogonal, e a animação M79Shoot), `heroine_drop.py` (PickupPistol = ajoelhada, a direita pega a pistola com silenciador na caixa de paraquedas; posição dela na caixa = `crate_frame`, exportada em `pistol_crate.glb`), `heroine_hurt.py` (golpes: HitFront/HitBack/HitL/HitR aditivas, StaggerBack/StaggerFwd, GetUpFront/GetUpBack com mãos/joelho/pés presos por IK), `heroine_cutscene.py` (HatchOpen = abrir o
  alçapão do telhado, Shocked = o susto na sala dos clones; quadros HATCH_GRAB/HATCH_UP usados pelo `hatch.gd`).
  Guerrilheiro (inimigo humano, de balaclava e colete; medidas da referência em `guerrilla_spec.py`, imagem em `art/ref/`):
  `guerrilla_body.py` (monta a pele única: tronco de moletom `BARE`, toco do ombro, união `_self_union`, braços e cabeça
  costurados; `PARTS` = o aprovado), `guerrilla_arms.py` (braços do modelo padrão `art/base_body`, manga medida),
  `guerrilla_head.py` (cabeça do modelo padrão em escala de homem, sem orelhas, pescoço encaixado no anel do tronco, vão
  do olho aberto), `guerrilla_paint.py` (balaclava, janela dos olhos com textura própria "Body_window" e a amêndoa do olho
  pintada no globo), `guerrilla_vest.py` (colete `CARRIER_*`: placas, alças com almofada, faixa, bolsas; peças unidas na
  pele), `guerrilla_lower.py` (calça e coturnos), `guerrilla_atlas.py` (layout dela + `cargo`/`cord`/`vest`),
  `build_guerrilla.py` (mesmo esqueleto/animações; gera `guerrilla.glb`; `-- <pasta> [partes]` = prévia; `art/guerrilla.blend` fica fora do git) e
  `tools/make_guerrilla_texture.py` (atlas 512 com o layout da heroína).
  Raptor: `raptor_spec.py`, `raptor_mesh.py` (usa o MeshBuilder da heroína; pele única: cadeias com anel de emenda
  soldado + união booleana `_self_union` das peças que se cruzam), `raptor_rig.py` (aceita `spec`/`mesh`/`name`),
  `raptor_anims.py` (IK nas pernas; convenção de ângulos no cabeçalho), `raptor_atlas.py`, `build_raptor.py`.
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
  `make_raptor_texture.py` (atlas 512x512 do raptor), `make_allosaurus_texture.py` (atlas 1024 do alossauro com as mesmas ferramentas; cabeça/mandíbula pintadas pela
  posição 3D nos anéis de `allosaurus_rings`: mancha do olho e barra pós-orbital medidas na textura da referência,
  mandíbula e bloco da bochecha claros, listras do corpo jeito Dino Crisis 2 também no pescoço), `make_level_textures.py` (texturas 256x256 do cenário e dos baús,
  buracos de bala `bullet_holes.png`, quadros do clarão/fumaça `shot_fx.png` e do sangue `blood_fx.png`),
  `make_sounds.py` (efeitos sonoros em `game/assets/sounds/`; blocos de síntese em `sound_dsp.py`, vozes do raptor/avisos/
  ambientes em `sound_creatures.py`), `contact_sheet.py` / `game_sheet.py` (folhas de prévia), `run_godot_tests.mjs` (testes).
- `game/` — `scripts/` (jogadora + `player_moves.gd` + `player_stealth.gd`, inimigos `enemy.gd` (base) / `raptor.gd` / `soldier.gd`, câmera, modelo, ragdoll, alvos, raptor + modelo do raptor, granada da M79 `grenade.gd`, pés presos dos dinossauros `foot_plant.gd` + inércia ao virar `turn_sway.gd`, chave `key_item.gd`, telas de inspeção `inspect.gd`, cenário, pátio da mata `yard.gd`,
  portas `door.gd` (galpão→pátio, pátio→pedreira), pedreira `arena.gd` (última sala) + alossauro `allosaurus.gd`/`allosaurus_model.gd`, telhado `roof.gd` + alçapão `hatch.gd` + caixa de paraquedas `supply_drop.gd`, sala dos clones `clone_lab.gd` + plaquetas dos tubos `subject_plate.gd`, cenas `cutscene.gd` (choque dos clones e emboscada do pátio), guerrilheiro morto `corpse.gd`, torres de guarda do portão do pátio `guard_tower.gd`, baú `chest.gd`, `moves.gd` (lê heroine_moves.json), efeitos `fx.gd` + sangue `blood.gd`, `gfx.gd`), `shaders/` (`psx_*` = PS1, `ps2_*` = PS2 do
  começo), `game_mode.gd` (perfil de jogo), `pickup.gd` (munição e kits no chão), `pause_menu.gd` (menu de pausa) + `showroom.gd` (palco dos dinossauros), HUD `hud_bar.gd` (barra) + `danger_meter.gd` (sensor de perigo) + `radar.gd` + `weapon_icon.gd` (modelo da arma), `tests/run_tests.gd` (+ `raptor_tests.gd`, `gfx_tests.gd`, `moves_tests.gd`, `weapons_tests.gd`, `ai_tests.gd`, `soldier_tests.gd`, `blood_tests.gd`, `allosaurus_tests.gd`, `survival_tests.gd`, `key_tests.gd`, `start_tests.gd`, `hurt_tests.gd`, `ambush_tests.gd`, `supply_drop_tests.gd`, `lab_gate_tests.gd`, `tower_tests.gd`, `pause_tests.gd`, `hud_tests.gd`), `assets/` (gerados — não
  editar à mão; inclui `m16.glb`/`shotgun.glb`/`m79.glb` = armas dos baús, `pistol_sd.glb` = pistola com silenciador sozinha, `pistol_crate.glb` = a mesma deitada na caixa e `heroine_moves.json` = caminhos/medidas dos movimentos).

## Comandos
- Regerar arte: `python tools/make_textures.py && python tools/make_sounds.py && python tools/make_level_textures.py && python tools/make_raptor_texture.py && python tools/make_allosaurus_texture.py && python tools/make_guerrilla_texture.py && blender --background --factory-startup --python art/build_heroine.py && blender --background --factory-startup --python art/build_raptor.py && blender --background --factory-startup --python art/build_allosaurus.py && blender --background --factory-startup --python art/build_guerrilla.py`
  (Blender em `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe`)
- Prévia no Blender: `blender --background art/heroine.blend --python art/preview.py -- <pasta> turntable|anims|Acao:f1,f2` (ou `art/raptor.blend`)
- Testes: `node tools/run_godot_tests.mjs` (passo fixo `--fixed-fps 60`: segundos em vez de minutos; o hook corta em 240 s)
- Rodar o jogo: `godot --path game` (F2 alterna o visual PS1/PS2; `-- --gfx=ps2` já começa no PS2; F3 alterna o perfil SOBREVIVENCIA/ARCADE e reinicia; `-- --mode=arcade` já começa no arcade)
- Captura do jogo: `godot --path game -- --capture=out.png --shot=idle|aim|run|crouch|roll|ragdoll|dummy [--yaw=graus] [--at=segundos]`
  Rosto: `--shot=face [--yaw=graus]`. Visual: `--gfx=ps1|ps2`.
  Movimentos: `--shot=walk|crouch_walk|crouch_aim|jump|hang|climb|mantle|pickup|rifle|rifle_aim|dodge_l|dodge_r|dodge_back|dodge_roll`.
  Armas: `--shot=pickup_shotgun|shotgun|shotgun_aim|fire_pistol|fire_m16|fire_shotgun|pump` (tiros na pilha de caixas;
  a captura imprime `buracos=`).
  Ela e o guerrilheiro lado a lado: `--shot=idle_compare|carry_compare|walk_compare [--yaw=graus]` (sem arma / M16 parados / M16 andando).
  Raptor: `--shot=raptor_roar|raptor_study|raptor_bite|raptor_tail|raptor_leap|raptor_charge|raptor_dead|raptor_idle [--playercam]`
  Sangue: `--shot=soldier_headshot|soldier_wounded|raptor_blood [--playercam]`.
  Container/chave/M79: `--shot=locked|unlock|corpse|key_get|m79_aim|fire_m79|pickup_m79` (locked/unlock/key_get salvam quando a
  tela de inspeção termina de aparecer; fire_m79 com `--at=0.9` pega a explosão; corpse = o morto com a chave, `--yaw` gira em volta).
  Emboscada: `--shot=ambush` (ela anda até o morto e a cena toca; `--at` escolhe o quadro: ~3 a mão, ~7 a roda, ~9,6 o rugido).
  Começo da fase: `--shot=roof|hatch|ladder_mount|ladder_out|ladder_roof|sniper_ladder|maze|gate|lab|clones` (hatch/ladder_mount/ladder_out/clones/sniper_ladder: `--at` escolhe o quadro).
  Sala dos clones e portão da pedreira: `--shot=tank|plate|plate_allo|keypad|keypad_on|keypad_ok|gate_open` (plate/plate_allo/
  keypad/keypad_on/keypad_ok salvam quando a tela aparece; keypad = sem o cartão; gate_open: `--at` escolhe o quadro).
  Torres do portão do pátio: `--shot=towers|tower_fall|gate_card` (towers = vistas da estrada com os snipers; tower_fall = o último
  cambaleia, debruça na cerca e cai, câmera de lado, `--at` escolhe o quadro, `--yaw` gira; gate_card = pega o cartão que ele derrubou).
  Caixa de paraquedas: `--shot=drop [--dist=m]|drop_get|drop_pick|fire_sd` (drop_get salva quando a tela do item aparece; drop_pick = câmera de lado
  enquanto ela pega, `--at` escolhe o quadro, `--yaw` gira; fire_sd = tiro com silenciador).
  Golpes: `--shot=hit_crouch|stagger|getup|getup_fwd` (câmera de revisão de lado; getup = desaba de costas e levanta girando,
  getup_fwd = arremessada pelas costas, levanta de bruços; `--at` escolhe o quadro).
  HUD: `--shot=danger|danger_roll` (no galpão na mira dos guardas da porta do pátio; danger_roll rola em 2,6 s; `--at` escolhe o quadro).
  Alossauro: `--shot=allo_idle|allo_roar|allo_roar_at|allo_stomp|allo_headbutt|allo_tail|allo_bite|allo_dead|allo_end [--playercam]`; pedreira: `--shot=arena`.
  Depois de regerar um .glb/.png, `godot --headless --path game --import` (rodar o jogo não reimporta sozinho).
  (a primeira execução depois de editar scripts reimporta o projeto e pode sair com a cena errada: rode de novo).

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
- **Não polir por cima de modelo errado.** Se o personagem existente quebra estas regras, dizer isso primeiro e propor
  refazer, em vez de ajustar proporção/cor por cima.
- **Prévia antes de gravar.** Mudança estrutural no modelo: mostrar a prévia lado a lado com a referência e só gravar os
  .glb/.png do jogo depois do "ok" do usuário. Depois, conferir também no jogo (`--shot`), com a luz do jogo.

## Convenções
- Perfil de jogo (`GameMode`, padrão `survival`; F3 ou `--mode=arcade|survival`): **os dois perfis ficam vivos e testados**, nada do
  jogo de ação de antes foi apagado, para servir de base a outro jogo. `arcade` = o jogo de antes (câmera livre que volta atrás dela,
  munição infinita, tiro do quadril liga a mira temporária, inimigos com o dano base, sem itens). `survival` (RE4 Remake + Dino
  Crisis 2): câmera por cima do ombro direito sem voltar sozinha (`CameraRig.SHOULDER`: 1,35 m atrás, pivô na altura da cabeça, ela no terço esquerdo da coxa para cima; mirando 1,1 m; coice `kick`), anda/corre a 80%
  (`move_scale`; SHIFT/L3 = corrida forte `Player.SPRINT_SPEED` 4,2 m/s, andar devagar passa para ALT; no arcade SHIFT segue sendo andar), esquiva = pulinho curto em vez da cambalhota (`GameMode.short_dodge`, `PlayerMoves.start_dodge`: parada ou direcional para trás = DodgeBack ~1,5 m, senão de lado DodgeL/DodgeR ~1,8 m virando o mínimo; invulnerável até `dodge.guard` do heroine_moves.json; poses em `heroine_moves.dodge_*_keys`; o primeiro X espera `PlayerMoves.DOUBLE_TAP` = 0,2 s (`dodge_wait`, já invulnerável, no embalo de antes): veio o segundo = cambalhota direto, sem pulinho; não veio = pulinho) com intervalo de 1,4 s, a retícula só existe com o botão de mirar apertado e só atira mirando (sem
  mira apertada não há tiro), inimigos machucam ×2 (`GameMode.enemy_damage`, usado em todo `take_hit` de inimigo na jogadora),
  munição limitada sem recarga (`Player.ammo`, HUD "PISTOLA 10", clique `dry_fire` e aviso quando acaba; `START_AMMO`/`WEAPON_AMMO`
  do baú/`AMMO_CAP`) e itens no chão (`Pickup.LAYOUT`: caixas de munição pela cor da arma e kits de vida, pegos ao passar por cima;
  o teste confere que estão em chão livre). Cada arma manda no movimento enquanto o botão de mirar está apertado, sem a jogadora
  precisar parar (`aim_speed`/`lock`/`lock_slow` em `GameMode.SURVIVAL_WEAPONS`, `Player._armed_locomotion`): pistola corre e atira
  (coice mínimo), M16 vira andar devagar e atira (coice médio, o tiro a desacelera mais), escopeta trava o movimento sozinha (só gira
  a mira; também agachada). Soltou a mira, volta a andar/correr normal.
  Os números das armas lidos pelo jogo vêm de `Player.weapon_stats(kind)` (o `WEAPON_STATS` é o do arcade). Teste novo nos dois
  perfis: `run_tests.gd` roda tudo no `arcade` (comportamento antigo intacto) e `survival_tests.gd` cobre o novo.
- Blender: Z para cima, personagem olha para -Y, lado esquerdo dela em +X. No Godot o modelo é girado 180° (frente = -Z).
- Ossos sem ponto no nome (`UpperArm_L`), para virarem nomes válidos no Godot.
- Ângulos das animações: ver cabeçalho de `art/heroine_anims.py` (X>0 dobra para a frente, joelho dobra com X<0).
- Orçamento (PS2 do começo): 800–5000 triângulos por personagem (o teste confere). Atlas 512x512 (heroína com alfa nas
  pontas do cabelo). Exceção decidida pelo usuário: o chefe (alossauro) tem teto de 12000 triângulos e atlas 1024; o Godot usa os PNGs direto, não a cópia do .glb. Fundo dos atlas preenchido (sem magenta) para o filtro.
  Cenário: ladrilhos de 256 (~2 m cada), com mipmaps.
- Tronco da heroína: elipse por anel + `torso_volume` (busto, glúteos, escápulas); laterais na altura do ombro com peso
  parcial no braço (`_shoulder_share`) para não abrir vão ao erguer o braço. `loft` aceita `wfn` (pesos por vértice).
- Visual (`Gfx`, padrão "ps2"): materiais dos dois modos têm os mesmos parâmetros; trocar de modo só troca o shader. Material novo: `Gfx.shader()`.
  Luzes do cenário no grupo "lamps" (sombra no PS2).
  Ar pesado do galpão (`Haze`, grupo "haze"): debaixo de cada luminária de `Level.LAMPS` um feixe de luz falso (cone aberto somado à
  cena, `shaders/light_shaft.gdshader`, da cor da lâmpada) e um halo no painel, e névoa rala no galpão inteiro (`Haze.air`, FogVolume `AIR_DENSITY`, acesa só pelas lâmpadas); sem corpo, luz, sombra nem partículas (a poeira em
  partículas foi tentada e recusada: virava quadradinhos de luz). Igual no PS1 e no PS2 (fora da troca do `Gfx`).
- Camadas de física: 1 cenário, 2 personagens (cápsulas; o raptor também, com caixa no tronco para os tiros), 4 ragdoll (só colide com o cenário).
- IA e furtividade (`enemy.gd` = base de `Raptor` e `Soldier`; `Player.visibility()/make_noise()`): o inimigo patrulha `route` e percebe pela visão (cone de 150°, alcance
  `SIGHT_RANGE * Player.visibility()`: parada 0,7, andando 0,75, correndo/rolando/atirando 1, agachada 0,3–0,45, capim alto ×0,5 agachada)
  e pelo barulho (`hear_noise`: passos de corrida 10 m, andando 4 m, agachada 2 m, tiro 26 m). A atenção (`aware`) sobe → `suspicious`
  (para e olha, "?") → `investigate` (vai ao ponto do barulho) ou, se a vê, `spot()` = grito + `on_alarm` nos outros do grupo "raptors"
  (`hunt` até o último ponto, "!"; o grupo "enemies" mistura raptors e soldados). Alertado (`alert_t`, `ALERT_TIME` 15 s) vê com cone
  mais aberto (`ALERT_FOV_BONUS`, nunca nas costas) e alcance `ALERT_SIGHT * visibility()` (agachada/capim ainda esconde). Em combate só
  sabe onde ela está com linha livre (`_combat_sees`, `COMBAT_SENSE`): parede/caixa corta o rastro; sem vê-la por `LOSE_TIME` (3 s) →
  `hunt` → `search` → esquece (`alert_t`/`aware` = 0) e volta à rota.
  Soldado = guerrilheiro encapuzado (`soldier.gd`, `HeroineModel` com `guerrilla.glb`/`guerrilla_atlas.png` e M16): guardas do galpão em `Soldier.GUARDS`, os 5 de sempre (2 de ronda, 2 sentinelas na porta do pátio, 1 no baú da M16) + 4 de posto (`"hold"`) na porta do pátio, dentro do canto cercado pelas paredes de caixas `Level.DIVIDERS` (o galpão não tem mais bonecos de treino, `TargetDummy` só nos testes e no `--shot=dummy|ragdoll`) os de posto têm `Enemy.hold_post`: barulho/vulto só os faz parar e olhar ("?"), sem sair do lugar, até alguém vê-la (`alert_t` > 0); depois da busca voltam ao posto; `alert` (reage 0,45 s) → `engage` (mira, rajadas de 4–7
  tiros instantâneos com descanso de 0,3–0,7 s, chance de acerto cai com distância/agachada/correndo e a cada tiro da rajada (`BURST_DECAY`),
  rolar esquiva; ela some atrás de algo = `SUPPRESS_TIME` de fogo de supressão onde ela estava, que não acerta; avança, recua ou anda de lado); morre em ragdoll. Revisão: `--shot=soldier|soldier_dead`.
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
- Pátio da mata (`Yard`): segunda sala a oeste do galpão (porta na parede oeste, z = `Yard.DOOR_Z`), clareira de capim com estrada de terra
  até um portão, árvores/arbustos/pedras/troncos, touceiras de capim alto (grupo "cover", meta "radius"), 3 raptors em `Yard.POSTS` (rotas usadas só depois da emboscada).
  O portão do fundo (`Yard._gate`) é de chapa cheia (`GATE_H`) com viga de concreto até `Arena.CLIFF_H`: nem pela frente nem do
  telhado se vê a pedreira. Neblina rasteira sobre o pátio (`Yard._mist`, FogVolume; `Level` liga `volumetric_fog` com densidade 0 fora dele).
  Guerrilheiro morto (`Corpse` em `Yard.CORPSE`, clareira de `Yard.CLEARING` m sem nada sólido): `HeroineModel` do guerrilheiro com a
  árvore de animação desligada e `Corpse.POSE` posta no esqueleto (convenção do heroine_anims; deitado, X>0 = para o céu, Z<0 abre
  braço/perna), sangue por `Blood.splat` (refeito no R), chave do container presa na mão direita (`KeyItem.hold`, estado "held").
  Emboscada: os 3 raptors do pátio começam escondidos nas moitas sem colisão de `Yard.LURK` (`Raptor.lurk`: `Enemy.lurking` = sem
  corpo, sem IA, não ouvem nem recebem alarme). Ela a `Corpse.NOTICE_RANGE` do morto, com linha livre → `Cutscene.play_ambush`
  (anda até a mão, close do punho com a chave + "ELE ESTÁ SEGURANDO ALGUMA COISA...", eles saem e rodeiam a `AMB_RING` m
  (`start_ambush`, estado "ambush"), o da frente ruge; E pula). No fim `end_ambush` = em luta, um de cada vez (`AMB_STAGGER`).
  A chave fica sem brilho (`KeyItem.shine` falso) até os 3 morrerem; dá para pegá-la antes. R: moitas, chave e cena de volta.
  A etiqueta vermelha da chave tem "0M79" escrito (`KeyItem.tag`, Label3D na etiqueta, também na tela do item): parece um código e
  engana (não é o do portão).
  Torres de guarda (`GuardTower`, `Yard.TOWERS`): uma de cada lado do portão do fundo, encostadas na parede, frente (+X local) para o
  pátio; plataforma em `FLOOR_Y` 4,2, parapeito de tábuas atrás/dos lados, guarda-corpo vazado na frente cuja barra de cima
  (`RAIL_H` 1,1 = abdome) só segura o corpo mole (`RAIL_LAYER`, a cápsula viva não encosta), telhado e lâmpada; sem escada
  (ninguém sobe). Em volta delas `Yard._off_towers` tira árvore (`TOWER_TREES`) e o resto sólido (`TOWER_CLEAR`) depois de montar a
  mata (o sorteio do resto fica igual). Um sniper em cada (`main._build_towers`: `Sniper.perch` = retângulo da plataforma,
  `floor_y`, `home_yaw` = vigia o pátio, `ledge` = alto da barra), fora de cena (`Sniper.lurk`) até os 3 raptors da emboscada
  morrerem (`appear`). Morreu um: o outro fica com o cartão do painel (`main.gate_card`, `loot`) e `falls`. O que cai: morto ainda
  em pé toca StaggerFwd e cambaleia até a barriga bater na barra (`_stagger_to_rail`), amolece com o embalo num corpo firme
  (`_firm`: juntas a `FIRM_JOINTS` do normal e giro amortecido em `FIRM_DAMP`, sem chacoalho de boneco mole; só a coluna vai a
  `SLUMP_WAIST`), o quadril fica na altura da barra, atrás dela, enquanto o tronco pende para fora (`_tip_over`: dobra no
  abdome, pernas esticadas), depois passa por cima e a gravidade leva; o fuzil fica na mão até o corpo parar no chão e só então
  o fuzil (pickup) e o cartão aparecem um de cada lado do corpo (`_drop_when_landed`, `DROP_SIDE`). O que morre lá em cima (não cai) fica com o fuzil na mão e não larga nada. R: snipers fora de
  cena de novo, cartão escondido. Testes: `tower_tests.gd`.
  Texturas `grass/dirt/bark/leaves/rock/grass_card/fern_card` vêm de `tools/make_level_textures.py`. Revisão: `--shot=yard --pos=x,z[,graus]`.
- Golpes na heroína (`art/heroine_hurt.py`): a reação ao tiro/dano é **aditiva** (`HeroineModel.hit(dir, força)` → nó Add2 por
  cima de tudo; HitFront/HitBack/HitL/HitR pelo lado atingido, `hit_side`; duas entradas por direção que se alternam): agachada
  continua agachada, mirando continua mirando (nada de pose inteira em pé). `knockback` toca StaggerBack/StaggerFwd conforme o
  empurrão. Caída em ragdoll (arremesso, mordida, `knock_down` = queda que machuca ou derrubada da escada), `Player._get_up` vira a
  cápsula para o lado da cabeça do corpo, encaixa o quadril do quadro 0 no do ragdoll e toca GetUpFront (de bruços) ou GetUpBack
  (de costas: gira de lado até ficar de bruços) a `GETUP_SPEED`: flexão, quatro apoios, um pé à frente, depois o outro, sem pulo;
  `PoseFade` (modificador depois do Ragdoll) parte da pose em que o corpo ficou. Levantando (`is_getting_up`) = sem controle,
  sem arma na mão e sem levar golpe.
- Raptor: ataques resolvidos em `raptor.gd` (`_strike` = dano + `knockback`); a mordida chama `Player.grab()`, que liga o ragdoll dela
  com o antebraço esquerdo puxado para a boca (`Ragdoll.drag`) e a luta dela por cima; rolar (`is_dodging`) esquiva de tudo.
  Salto (golpe sai das garras dos pés) e investida chamam `Player.launch()`: ragdoll arremessado em C em volta do golpe
  (`Ragdoll.fling` + `_hold_c`), depois ela levanta. A morte do raptor é ragdoll (`RaptorModel.RAGDOLL`), não animação.
  Andando, o raptor só se move para a frente do corpo e a velocidade da animação acompanha (`WALK_ANIM_SPEED`/`RUN_ANIM_SPEED`).
  Pés presos (`FootPlant`, SkeletonModifier3D do `RaptorModel`, vale para o alossauro; medidas pela perna do esqueleto): o pé
  que a animação põe no chão fica onde tocou no mundo (IK de coxa/canela, metatarso e dedos como na animação) até a animação
  levantá-lo; girando no lugar ou andando mais devagar que a animação, o corpo se afasta do pé preso e ele dá um passo (um pé
  de cada vez, som de passo pelo sinal `stepped`). No ar e no ragdoll segue a animação; clone do tubo (dono não é
  CharacterBody3D) não usa. Inércia (`TurnSway`, modificador antes do `FootPlant`): virando, pescoço/cabeça entram na curva antes
  (`LEAD`), a cauda fica para trás no mundo e volta com mola (base e ponta com molas próprias, a ponta chicoteia), o quadril
  inclina para dentro da curva pela velocidade (`BANK`). Ciclos (`raptor_anims.gait`, `WALK`/`RUN`/`STALK`; o alossauro passa os
  dele) com gingado: quadril desce depois de cada toque, leva o peso para cima da perna de apoio (`shift` de lado + `roll`) e gira
  com a passada (`yaw`), a onda sobe pelo tronco/pescoço atrasada (`wave`) e desce pela cauda larga (`sway`), a cabeça desfaz o
  giro e dá o bote de ave a cada passo (`thrust`), braços atrasados, calcanhar sobe no fim do apoio; o IK abre a coxa pelo rolar
  e pelo quadril de lado; uma chave por quadro (chave a cada 2 quadros fazia o pé andar aos trancos). Espreita (`Stalk`,
  `Raptor.STALK_SPEED`/`STALK_ANIM_SPEED`, só raptor): corpo baixo, cabeça rente ao chão varrendo os lados, passo alto que para no
  ar (`plateau`); usada ao rodear a presa (`_study`). Parado = `idle_keys` (5 s: troca de peso de lado, cabeça vigia em estalos).
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
  escada do mezanino num beco que só abre para o corredor de cima; vigas do mezanino com colisão). Raptors não navegam no labirinto
  (raio da malha 0,75 m); soldados usam a malha de gente (`Yard.bake_people_nav`: raio 0,25 m, célula de 5 cm, só no galpão) e entram
  em todo corredor do labirinto e no nicho da escada do mezanino (passam debaixo das mãos-francesas do mezanino, `Catwalk.BRACE_Y` acima da cabeça); o sniper anda reto no mezanino (`Sniper._steer`: a malha mais perto é a do topo das caixas/telhado).
  Na escada, entrando/saindo pelo topo e nos `Hatch.HIDDEN_RUNGS` degraus abaixo do alto do ciclo (`Ladder.hidden_top`, `PlayerMoves.hidden_on_ladder`) fica escondida de todos, mesmo alertados; abaixo, o sniper a vê se estiver olhando para o canto: o tiro
  derruba da escada (`PlayerMoves.knock_off_ladder`) e a queda sem controle mata (`Player.KNOCKED_*`).
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
- Queda (`Player.fall_damage`): sem dano até `FALL_SAFE` (3,6 m: pular do mezanino não machuca), morte a partir de `FALL_LETHAL`
  (5 m); derrubada da escada usa `KNOCKED_SAFE/KNOCKED_LETHAL`. `death_cause` "fall" → Game Over "VOCÊ MORREU NA QUEDA".
  Fora do galpão/pátio/pedreira não há chão: caindo abaixo de `Player.VOID_Y` (-10 m) ela morre na queda (não cai para sempre).
- Sala dos clones (`CloneLab`): anexo atrás da plataforma de carga (piso na altura da doca, `FLOOR_Y` 1,3), portão de enrolar (`Door`
  com `room` -1, fora da corrente de salas) aberto com E. Seis tubos com raptors (`RaptorModel` com a animação travada, azulados, sem
  piar). Ao entrar pela primeira vez: `Cutscene.play_clones` (faixas pretas, sem HUD; `Player.cutscene` = sem controle nem dano;
  anda, close no clone, rosto dela com Shocked e "O QUE...?!", plano geral; E pula; R reinicia e a cena volta a valer).
  Cada tubo tem uma plaqueta num pedestal (`SubjectPlate`, "SUBJECT XXXX" de `CloneLab.SUBJECTS`, grupo "plates"): E na frente dela
  (`Player.pick_plate` → sinal `read_plate`) = `Inspect.plate_zoom` (pausa, câmera até a plaqueta, ficha embaixo). No canto do fundo à
  esquerda (`CloneLab.TANK`; a sala foi até `Z_FAR` -32 para caber) o tanque do alossauro: vidro de `TANK_SIDES` lados inteiro,
  drenado, porta de vidro aberta, mangueiras soltas, luz vermelha; a plaqueta dele (`ALLO_SUBJECT`, "VAZIO / TRANSFERIDO") é o
  código do portão da pedreira. O console não tem mais a chave do painel: o cartão (`main.gate_card`, keycard cor de ferrugem, id
  `Yard.GATE_KEY`, "No verso: CÓDIGO = SUBJECT DO PROTÓTIPO") cai do último sniper das torres do pátio.
- Salas e portas (`Door`, `Level.room_of/connected`): 0 galpão, 1 pátio, 2 pedreira. As duas portas (de correr no galpão, portão de ferro no fundo do pátio) começam fechadas: bloqueiam corpo, tiro e visão e abrem com E perto delas (`Player.pick_door`; reiniciar fecha). `Enemy.hear_noise`/`on_alarm` só valem na mesma sala ou com todas as portas entre elas abertas: tiro e grito de uma sala não chamam os inimigos das outras. `Yard.bake_nav` desliga as portas na hora de assar a malha.
  Porta trancada: `Door.lock` = id da chave/cartão. Com leitor (`add_card_reader`, porta do galpão) abre com o cartão no bolso. Com
  teclado (`add_keypad` + `Door.code`, portão da pedreira: cartão `Yard.GATE_KEY` na fenda do lado do teclado + código
  `CloneLab.ALLO_SUBJECT`): E emite
  `Player.keypad` → `main._on_keypad` → `Inspect.keypad` (pausa, câmera no painel; sem o cartão "PAINEL DESLIGADO"; com ele o visor
  acende e ela digita 4 algarismos: 0-9 ou setas/direcional, E confirma, C sai; errado = `keypad_error` e zera; certo = `keypad_ok`,
  o cartão é gasto e a porta abre). `Inspect.auto_code` digita sozinho (testes/capturas). R tranca de novo e apaga o visor.
- Pedreira (`Arena`): última sala, depois do portão (fechado até abrir) no fundo do pátio; paredões de pedra, ruínas e pedras grandes
  (cobertura que o alossauro não atravessa), capim alto, postes (`Yard.lamp`). Alossauro em `Arena.ALLO` e 2 raptors em `Arena.POSTS`.
- Alossauro (`allosaurus.gd`, herda `Enemy`; modelo `AllosaurusModel` = `RaptorModel` com outro arquivo/atlas/ragdoll/sons graves):
  vê → ruge (`ROAR_RANGE`: `Player.daze(3 s)`, não fere; volta a rugir com `ROAR_COOLDOWN`) → persegue andando (`stalk`) e escolhe:
  pisada (perto: o pé que desce fere e arremessa, o tremor só empurra), mordida (à frente: `Player.grab`, sacode e arremessa para a
  esquerda dele com `release`) ou investida (longe). Rolar esquiva de pisada e mordida. Só reage a tiro depois de `FLINCH_DAMAGE`.
  Morte em ragdoll → sinal `killed` → tela de fim do `main` (FIM, tempo, tiros; R reinicia). Atordoada: estado "dazed" da
  heroína (animação Dazed), aviso "ATORDOADA" no HUD; golpe, mordida ou reinício acabam com ela.
- Tela 16:9: resolução interna `Gfx.RES` 854x480 (PS2) / 427x240 (PS1), janela padrão 1280x720 (as capturas saem em 16:9);
  `stretch/aspect="expand"` e câmeras com `KEEP_HEIGHT`: outra proporção só muda a largura vista, a altura fica igual.
  HUD/telas de inspeção/pausa usam a área visível em unidades de 240 de altura (cantos e centro acompanham a largura).
- HUD (unidades de 240 de altura ampliadas, `main._build_hud`): no alto à esquerda a vida em barra (`HudBar`, número ao lado) e logo abaixo o sensor
  de perigo (`DangerMeter`, jeito Syphon Filter); no alto à direita o radar (`Radar`); embaixo à direita o modelo da arma na mão
  (`WeaponIcon`: SubViewport ortográfica, .glb soltos de perfil, pistola comum = malha "Pistol" do corpo dela, `pistol_sd` com o
  silenciador; giro em `WeaponIcon.TURN`) com a munição ao lado só no survival; a ajuda (F1) quebra antes do radar.
  Mira (`Crosshair`, jeito Syphon Filter, camada sem escala no centro): cruz com um retângulo no meio, colchetes "[ ]" dos lados e tracinho no meio de cima/baixo. Tamanho
  dinâmico: `AREA_R` m na distância do que está sob ela pela lente da câmera (perto = maior, até `LOOSE_MAX`) + cone do
  próximo tiro (`Player.aim_spread`: arma, tiros seguidos, andando); focada no mesmo inimigo com tiro livre fecha em
  `FOCUS_TIME` até `FOCUS_HALF` (`focus_t`), saiu dele abre; na cabeça de quem tem headshot (`Player.body_part`) uma linha
  sai do canto de cima até "HEADSHOT". Corre para o tamanho (`SMOOTH`); verde, vermelha no alvo, cinza bloqueada.
  Furtividade no radar: fundo e moldura pulsam na cor do maior `alert_level` (mais rápido quanto pior) e embaixo dele um olho +
  VISÍVEL/INVISÍVEL (`Radar.INVISIBLE_AT` da `visibility()`, telhado ou alto da escada; nunca com alguém a vendo, `Enemy.has_eyes_on`)
  e o estado (DESCONFIADOS / BUSCA ATIVA / ALERTA!); o olho fecha escondida, olha para os lados na busca e fica vermelho no alerta.
  Perigo: cada inimigo diz `Enemy.threat()` (0..1, só em combate; esquivando = 0): soldado = chance de pelo menos um tiro da rajada
  acertar (`Soldier._hit_chance`, a mesma do `_fire`), sniper = sobe com a mira do laser, raptor/alossauro = golpe ao alcance
  (`_melee_threat`). O sensor junta tudo (1 - produto(1 - chance)), sobe rápido e desce devagar, rolando desce depressa e volta a subir
  se ela segue na mira; de `WARN` para cima pisca com "!!". Radar: centrado nela, girado com a câmera, contorno das salas
  (`Radar.ROOMS`) e portas (verde aberta/amarela fechada/vermelha trancada); inimigo só aparece depois de avistado uma vez (na tela, a
  `SPOT_RANGE` m, sem cenário no meio) e daí é rastreado (cor = `alert_level`; fora do alcance, preso na borda); morto some; R esquece.
- Controles novos: F / quadrado = pular (com borda à frente: escala até MANTLE_MAX ou pula e fica pendurada; pendurada,
  frente/pular sobe e trás/agachar solta), E / triângulo = pegar (baú), Q/Tab / Select = trocar arma. Espaço / X = cambalhota (survival: pulinho de esquiva).
  ESC / START = menu de pausa (`PauseMenu`, ação "pause": CONTINUAR / REINICIAR / SAIR DO JOGO; árvore pausada, não abre por
  cima de tela de inspeção nem no game over; volta ao jogo dois passos de física depois para o botão não chegar nela).
  START não reinicia mais; R no teclado segue reiniciando. Captura: `--shot=pause`. Testes: `pause_tests.gd`.
  SHOWROOM (item do menu, `Showroom`, `showroom.gd`): palco 3D próprio (SubViewport com mundo à parte numa camada sem escala,
  chão quadriculado, luz com sombra) com o raptor ou o alossauro (`RaptorModel.showroom` = pés presos e inércia sem corpo de
  física) e a lista das animações dele (ciclos primeiro, nome em português de `Showroom.NAMES` + o do arquivo; as que não são
  ciclo repetem). Cima/baixo ou clique escolhe, A/D/analógico direito/arrastar gira a câmera, roda/Z/X/L1/R1 zoom, Q/TAB/SELECT
  troca o bicho, F/quadrado o modo (NO LUGAR = animação pura sem FootPlant/TurnSway; EM CÍRCULO = os ciclos de `GAITS` andam
  numa roda na velocidade do jogo; GIRANDO = vira no lugar a `TURN_RATE`), ESPAÇO/X a velocidade (1x, 1/2, 1/4, parado),
  ESC/START/C/bola volta ao menu. Captura: `--shot=showroom [--creature=raptor|allosaurus] [--anim=Walk]
  [--move=lugar|circulo|girando] [--yaw=graus] [--at=s]` (o `--at` conta num relógio que roda com o jogo pausado).
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
  Mirando, ela vira para o ponto sob a retícula (`CameraRig.aim_point`) e `AimPitch` (SkeletonModifier3D) inclina coluna
  e peito até a altura dele: o cano aponta para onde o tiro vai. A pose modificada só aparece no desenho e nos
  BoneAttachment3D (cano); `get_bone_global_pose` lido de fora devolve a da animação. Captura: `--pitch=graus` com `--yaw`. A escopeta
  tem o cabo, a soleira e a telha nos mesmos pontos do M16 (mesmas poses, mesmo Pickup, mesmo RIFLE_CHEST). A arma do
  baú (`m16.glb`/`shotgun.glb`, `Chest.item` antes de entrar na árvore) já vem do build na posição em que as mãos a
  pegam (RIFLE_CHEST, em relação à raiz dela ajoelhada a `kneel_dist` da frente do baú).
  A telha da escopeta (`ShotgunPump`, BoneAttachment3D) é movida pelo Godot seguindo `PUMP_KEYS` (heroine_moves.json
  "shotgun"), o mesmo caminho da mão esquerda na animação; no fundo do curso sai o cartucho (`shell_ejected`).
- M79 (lança-granadas, `heroine_m79.py`; mesmas poses/Pickup/RIFLE_CHEST das armas longas, tiro `M79Shoot`): `WEAPON_STATS.m79.grenade`
  troca o raio por `Grenade.launch` (arco baixo que cai no ponto da retícula, `aim_velocity`). Antes de `ARM_DIST` só dá a pancada;
  armada explode (`Grenade.explode`: dano em área até `RADIUS`, só em quem está à vista — parede/porta protegem —, empurra corpos,
  arremessa a jogadora perto e ela leva `PLAYER_SHARE` do dano; barulho `NOISE`; `Fx.explosion` + mancha `Fx.scorch`, que conta em
  `MAX_DECALS` e some com o R). Survival: 4 granadas no baú, caixa verde em `Pickup.LAYOUT`.
- Container trancado e chave (jeito RE/Dino Crisis): `Chest.lock` = id da chave (ferrolho + cadeado na frente). A M79 fica no
  container sem estêncil (surpresa) atrás de onde ela começa (`main.LOCKER_POS`); a chave (`KeyItem`) está na mão do guerrilheiro
  morto no meio do pátio (`Corpse`, ver Pátio da mata); `TargetDummy.loot` (cai do alvo morto, brilhando) segue valendo para
  outros itens e testes. Pega com E ao chegar perto (`Player.keys`). Interagir no
  trancado emite `Player.locked` → `Inspect.lock_zoom` (jogo pausado, câmera vai até o cadeado; sem chave chacoalha e avisa, com
  chave ele cai e a chave é gasta). Pegar a chave → `Inspect.show_item` (item girando numa SubViewport). As telas de inspeção
  pausam a árvore e rodam com `PROCESS_MODE_ALWAYS` (sons delas por `Sfx.ui`); `auto_close`/`on_shown` para testes e capturas.
  Reiniciar tranca de novo e devolve a chave ao morto. Testes: `key_tests.gd`, `ambush_tests.gd`.
  Caixa de texto das telas (`Inspect._layout_box`): título amarelo no alto com respiro (`BOX_PAD`), botões no pé (`UiStyle.Hint`: `OK_ITEMS` ou
  os do teclado, `KEYPAD_ITEMS`) e o texto centralizado no meio; a caixa cresce com o texto e o item fica acima dela, nada se sobrepõe.
- Textos do jogo em português com acento (a fonte padrão do Godot tem os glifos).
- Design system dos textos (`UiStyle`, `ui_style.gd`): cores INK/ACCENT/ACTION/WARN/DANGER/MUTED, tamanhos S 8 / M 12 / L 24 (unidades
  do HUD de 240 de altura; a munição ao lado da arma é M), fundos SHADE/DEATH_SHADE/BAND, `UiStyle.label`/`rect`. Botão nunca vai escrito no texto ("(E)", "E:"): usa
  `UiStyle.Hint` (fileira "<glifo> VERBO"; glifo do mapa do `InputSetup` pelo último aparelho, `UiStyle.pad` via `UiStyle.Watcher`:
  tecla numa moldura ou triângulo/bola/X/quadrado/direcional desenhados). Prompt de ação (`main._prompt`) junta pegar/abrir e o
  abate furtivo (atirar). Captura com os glifos do controle: `--pad`. O teste `ui_style_tests.gd` barra cor/tamanho solto nos scripts.
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
