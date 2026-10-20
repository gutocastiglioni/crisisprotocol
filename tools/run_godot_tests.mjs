#!/usr/bin/env node
// Roda os testes headless do Godot (game/tests/run_tests.gd) em qualquer SO.
// Godot: variável GODOT_BIN, ou `godot` no PATH, ou a instalação do winget no Windows.
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const game = join(root, 'game');

function findGodot() {
  if (process.env.GODOT_BIN) return process.env.GODOT_BIN;
  for (const name of ['godot', 'godot4']) {
    const r = spawnSync(name, ['--version'], { encoding: 'utf8', shell: process.platform === 'win32' });
    if (r.status === 0) return name;
  }
  const winget = join(homedir(), 'AppData/Local/Microsoft/WinGet/Packages');
  if (existsSync(winget)) {
    for (const dir of readdirSync(winget).filter((d) => d.startsWith('GodotEngine.GodotEngine_'))) {
      const exe = readdirSync(join(winget, dir)).find((f) => /^Godot_v4.*_console\.exe$/.test(f));
      if (exe) return join(winget, dir, exe);
    }
  }
  return null;
}

const godot = findGodot();
if (!godot) {
  console.error('Godot 4 não encontrado: instale (winget install GodotEngine.GodotEngine) ou defina GODOT_BIN.');
  process.exit(1);
}
const opts = { cwd: game, encoding: 'utf8', timeout: 300_000, maxBuffer: 16 * 1024 * 1024 };
const imp = spawnSync(godot, ['--headless', '--import', '--path', '.'], opts);
if (imp.status !== 0) {
  const why = imp.error?.message ?? `código ${imp.status}, sinal ${imp.signal}`;
  console.error(`falha ao importar o projeto (${why}):\n${imp.stdout ?? ''}${imp.stderr ?? ''}`);
  process.exit(1);
}
// passo fixo de 1/60 s: o tempo de jogo é o mesmo, mas sem esperar o relógio (minutos -> segundos)
const r = spawnSync(godot, ['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'res://tests/run_tests.gd'], opts);
if (r.error) {
  console.error(`não foi possível rodar o Godot: ${r.error.message}`);
  process.exit(1);
}
const out = `${r.stdout || ''}${r.stderr || ''}`;
// o Godot imprime avisos de vazamento ao sair do modo --script; só o resultado dos testes interessa
const noise = /leaked|RID allocations|PagedAllocator|ObjectDB|resources still|^\s+at: |Parameter "material"/;
console.log(out.split('\n').filter((l) => l.trim() && !noise.test(l)).join('\n'));
process.exit(r.status ?? 1);
