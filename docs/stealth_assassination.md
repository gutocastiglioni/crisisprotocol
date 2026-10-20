# Abate Furtivo e Golpe Crítico em Sequência

## Visão Geral
Sistema de execução corpo a corpo silenciosa acionado pelo mesmo botão de ataque (`shoot`) **sem mirar** (`not aiming` e `not Input.is_action_pressed("aim")`).

## Regras de Jogo
- **Gatilho**: Botão de ataque (`shoot`) sem mirar, a até `Enemy.ASSASSINATE_RANGE` (`2.2 m`) pelas costas / fora do cone de visão de um inimigo fora de combate (`not in_combat()`, `alert_t <= 0.0`, linha de visão livre). O `Allosaurus` é excluído (`can_stealth = false`).
- **Aviso no HUD (`main.gd` / `player_stealth.gd`)**:
  - `"ABATE FURTIVO DISPONIVEL (ATIRAR)"` quando posicionada atrás de um `Soldier` ou `Raptor` elegível.
  - `"GOLPE CRITICO DISPONIVEL (ATIRAR)"` quando próxima (`<= Enemy.CRIT_RANGE = 2.5 m`) de um `Raptor` caído (`state == "down"`).
  - O aviso desaparece imediatamente assim que o golpe é iniciado ou o alvo deixa de estar elegível.
- **Humanos (`Soldier`) e Bonecos de Teste (`TargetDummy`)**:
  - Abate 100% letal e silencioso (`health = 0`, ragdoll imediato + impacto/sangue, sem gasto de munição e sem alertar outros inimigos; nos `TargetDummy`, também derruba o `loot` se possuir a chave).
- **Velociraptors (`Raptor`)**:
  - **1º Golpe (`assassinate`)**: Causa **70% da vida máxima** (`roundi(MAX_HEALTH * 0.7) = 119` de `170` HP), silencioso, derrubando o velociraptor no chão (`state = "down"`, animação `"Death"`) por `DOWN_TIME = 3.0 s`.
  - **2º Golpe em Sequência (`crit_strike`)**: Mesmo botão de ataque sem mirar enquanto `state == "down"`. Trava o cronômetro de levante e finaliza o velociraptor com dano crítico letal.
  - **Contra-ataque ao Levantar (`counter`)**: Se não for finalizado em `DOWN_TIME = 3.0 s`, o velociraptor levanta dando o alarme (`_raise_alarm()`) num giro de cauda (`state = "counter"`) que causa dano (`DAMAGE.counter = 18`) e derruba a heroína (`target.launch(...)`) se ela estiver a até `COUNTER_REACH = 2.8 m`.

## Arquivos Principais
- Arte / Blender: `art/heroine_moves.py`, `art/heroine_anims.py` (`Assassinate`, `CritStrike`).
- Gameplay / Godot: `game/scripts/enemy.gd`, `game/scripts/soldier.gd`, `game/scripts/raptor.gd`, `game/scripts/player_stealth.gd`, `game/scripts/player_moves.gd`, `game/scripts/player.gd`, `game/scripts/main.gd`.
- Testes Automatizados: `game/tests/stealth_kill_tests.gd` (integrado em `game/tests/run_tests.gd`).
