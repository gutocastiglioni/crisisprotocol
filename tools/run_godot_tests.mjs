#!/usr/bin/env node
// Roda os testes headless do Godot (game/tests/run_tests.gd) em qualquer SO.
// Godot: variável GODOT_BIN, ou `godot` no PATH, ou a instalação do winget no Windows.
//
// Várias sessões do Claude (e o hook de cada uma) rodam isto ao mesmo tempo no mesmo projeto. Por isso:
// - uma execução por vez na máquina (trava em LOCK); as outras esperam na fila em vez de disputar o Godot;
// - o resultado fica guardado pela "impressão" dos arquivos de game/ + as partes pedidas: quem chega depois com
//   o mesmo projeto recebe o resultado pronto, sem rodar de novo (inclusive quem estava esperando na fila).
// Saída 75 = não rodou porque a fila não andou a tempo (o hook avisa em vez de bloquear).
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, openSync, closeSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const game = join(root, 'game');
const GODOT_TIMEOUT = 390_000; // importar e rodar; o hook dá 590 s ao comando todo (.claude/hooks/stop-check.mjs)
const LOCK_WAIT = 180_000; // espera máxima na fila (390 + 180 cabem nos 590 do hook)
const LOCK_STALE = 15 * 60_000; // trava mais velha que isto é de uma execução que morreu
const CACHE_TTL = 2 * 3600_000;
const BUSY = 75;

const state = join(tmpdir(), `godot-tests-${createHash('sha1').update(root.toLowerCase()).digest('hex').slice(0, 10)}`);
const LOCK = join(state, 'lock.json');
mkdirSync(state, { recursive: true });

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

/** Impressão do projeto: caminho + tamanho + data de cada arquivo de game/ (fora a pasta .godot e os gerados pelo import). */
function tree() {
  const h = createHash('sha1');
  const walk = (dir) => {
    for (const e of readdirSync(dir, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      const full = join(dir, e.name);
      if (e.isDirectory()) { if (e.name !== '.godot') walk(full); continue; }
      if (/\.(import|uid)$/.test(e.name)) continue;
      const s = statSync(full);
      h.update(`${relative(game, full)}|${s.size}|${Math.round(s.mtimeMs)}\n`);
    }
  };
  walk(game);
  return h.digest('hex');
}
const keyOf = (t, parts) => createHash('sha1').update(`${t}|${parts.join(',')}`).digest('hex');

const cacheFile = (key) => join(state, `result-${key}.json`);
function cachedOne(key) {
  try {
    const c = JSON.parse(readFileSync(cacheFile(key), 'utf8'));
    return Date.now() - c.at < CACHE_TTL ? c : null;
  } catch { return null; }
}
/** Resultado pronto para este projeto: o das mesmas partes, ou a suíte inteira que passou (cobre qualquer parte). */
function cached(t, parts) {
  const same = cachedOne(keyOf(t, parts));
  if (same || !parts.length) return same;
  const full = cachedOne(keyOf(t, []));
  return full && full.code === 0 ? full : null;
}

function alive(pid) {
  try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; }
}
function holder() {
  try { return JSON.parse(readFileSync(LOCK, 'utf8')); } catch { return null; }
}
/** Tenta pegar a trava; tira a de quem morreu. */
function tryLock(key, only) {
  try {
    const fd = openSync(LOCK, 'wx');
    writeFileSync(fd, JSON.stringify({ pid: process.pid, at: Date.now(), key, only }));
    closeSync(fd);
    return true;
  } catch {
    const h = holder();
    if (h === null) return false; // sendo escrita agora
    if (!alive(h.pid) || Date.now() - h.at > LOCK_STALE) rmSync(LOCK, { force: true });
    return false;
  }
}
let locked = false;
process.on('exit', () => {
  if (locked && holder()?.pid === process.pid) rmSync(LOCK, { force: true });
});
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => process.exit(130));

function report(c, reused) {
  if (reused) console.log(`(resultado reaproveitado da execução de ${new Date(c.at).toLocaleTimeString()}: projeto igual, sem rodar de novo)`);
  console.log(c.out);
  process.exit(c.code);
}

const only = process.argv.slice(2);
let t = tree();
const hit = cached(t, only);
if (hit) report(hit, true);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const start = Date.now();
let told = false;
while (!(locked = tryLock(keyOf(t, only), only))) {
  const h = holder();
  if (!told && h) {
    console.error(`outra execução dos testes em andamento (pid ${h.pid}, ${Math.round((Date.now() - h.at) / 1000)} s); esperando na fila...`);
    told = true;
  }
  if (Date.now() - start > LOCK_WAIT) {
    console.log(`NÃO RODADO: a fila dos testes não andou em ${LOCK_WAIT / 1000} s (pid ${h?.pid}). Rode de novo depois.`);
    process.exit(BUSY);
  }
  await sleep(1500);
  t = tree();
  const done = cached(t, only); // quem estava na frente pode ter testado o mesmo projeto
  if (done) report(done, true);
}
t = tree(); // o projeto pode ter mudado enquanto esperava
const late = cached(t, only);
if (late) report(late, true);

const godot = findGodot();
if (!godot) {
  console.error('Godot 4 não encontrado: instale (winget install GodotEngine.GodotEngine) ou defina GODOT_BIN.');
  process.exit(1);
}
const opts = { cwd: game, encoding: 'utf8', timeout: GODOT_TIMEOUT, maxBuffer: 16 * 1024 * 1024 };
const imp = spawnSync(godot, ['--headless', '--import', '--path', '.'], opts);
if (imp.status !== 0) {
  const why = imp.error?.message ?? `código ${imp.status}, sinal ${imp.signal}`;
  console.error(`falha ao importar o projeto (${why}):\n${imp.stdout ?? ''}${imp.stderr ?? ''}`);
  process.exit(1);
}
// passo fixo de 1/60 s: o tempo de jogo é o mesmo, mas sem esperar o relógio (minutos -> segundos)
// nomes depois do comando = só essas partes da suíte (ex.: `node tools/run_godot_tests.mjs raptor ai`)
const args = ['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'res://tests/run_tests.gd'];
if (only.length) args.push('--', `--only=${only.join(',')}`);
opts.timeout = Math.max(30_000, GODOT_TIMEOUT - (Date.now() - start));
const r = spawnSync(godot, args, opts);
if (r.error) {
  console.error(`não foi possível rodar o Godot: ${r.error.message}`);
  process.exit(1);
}
const raw = `${r.stdout || ''}${r.stderr || ''}`;
// o Godot imprime avisos de vazamento ao sair do modo --script; só o resultado dos testes interessa
const noise = /leaked|RID allocations|PagedAllocator|ObjectDB|resources still|^\s+at: |Parameter "material"/;
const out = raw.split('\n').filter((l) => l.trim() && !noise.test(l)).join('\n');
const code = r.status ?? 1;
// só guarda resultado de execução que terminou sozinha e com o projeto igual ao do começo
if (r.status !== null && tree() === t) {
  writeFileSync(cacheFile(keyOf(t, only)), JSON.stringify({ at: Date.now(), code, out }));
  for (const f of readdirSync(state).filter((n) => n.startsWith('result-'))) {
    try { if (Date.now() - statSync(join(state, f)).mtimeMs > CACHE_TTL) rmSync(join(state, f), { force: true }); } catch { /* outra execução limpou */ }
  }
}
console.log(out);
process.exit(code);
