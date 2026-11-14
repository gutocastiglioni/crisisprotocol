#!/usr/bin/env node
// Roda os testes headless do Godot (game/tests/run_tests.gd) em qualquer SO, as partes divididas em vários processos
// ao mesmo tempo (GODOT_TEST_JOBS, padrão 5).
// Godot: variável GODOT_BIN, ou `godot` no PATH, ou a instalação do winget no Windows.
//
// Várias sessões do Claude (e o hook de cada uma) rodam isto ao mesmo tempo no mesmo projeto. Por isso:
// - uma execução por vez na máquina (trava em LOCK); as outras esperam na fila em vez de disputar o Godot;
// - o resultado fica guardado pela "impressão" dos arquivos de game/ + as partes pedidas: quem chega depois com
//   o mesmo projeto recebe o resultado pronto, sem rodar de novo (inclusive quem estava esperando na fila).
// Saída 75 = não rodou porque a fila não andou a tempo (o hook avisa em vez de bloquear).
import { spawn, spawnSync } from 'node:child_process';
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
  if (process.env.GODOT_TEST_FRESH) return null; // GODOT_TEST_FRESH=1 = roda de novo mesmo com resultado guardado
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

const ALL = ['core', ...[...readFileSync(join(game, 'tests/run_tests.gd'), 'utf8').matchAll(/^\t\["(\w+)",/gm)].map((m) => m[1])];

/** Partes que os arquivos mudados tocam (CHANGED_FILES, mandado pelo hook): o teste da própria parte, ou as partes cujo
 *  teste cita a classe (`class_name`) ou o nome do arquivo mudado. Arquivo do jogo que nenhum teste cita = suíte inteira.
 *  Fora de game/ não há teste do Godot (só o próprio runner). Devolve null = tudo. */
function partsFor(files) {
  const texts = Object.fromEntries(ALL.map((n) =>
    [n, readFileSync(join(game, 'tests', n === 'core' ? 'run_tests.gd' : `${n}_tests.gd`), 'utf8')]));
  const sceneDir = join(game, 'scenes');
  const scenesText = Object.fromEntries(readdirSync(sceneDir).filter((n) => n.endsWith('.tscn'))
    .map((n) => [n, readFileSync(join(sceneDir, n), 'utf8')]));
  const picked = new Set();
  for (const raw of files) {
    const f = raw.replace(/\\/g, '/');
    if (f === 'tools/run_godot_tests.mjs' || f === 'game/tests/run_tests.gd' || f === 'game/project.godot') return null;
    if (!f.startsWith('game/') || /\.(import|uid)$/.test(f)) continue;
    const test = f.match(/^game\/tests\/(\w+)_tests\.gd$/);
    if (test && ALL.includes(test[1])) { picked.add(test[1]); continue; }
    if (f.startsWith('game/tests/')) continue; // ajudante solto dos testes
    if (f.startsWith('game/assets/voices/')) { picked.add('voice'); continue; }
    if (f.startsWith('game/assets/sounds/')) { picked.add('sfx'); continue; }
    if (f.startsWith('game/assets/')) return null;
    const name = f.split('/').pop();
    let cls = null;
    try { cls = readFileSync(join(root, f), 'utf8').match(/^class_name (\w+)/m)?.[1] ?? null; } catch { /* apagado */ }
    const word = cls && new RegExp(`\\b${cls}\\b`);
    // cena (.tscn) que usa o script: teste que abre a cena também conta (main.gd -> main.tscn)
    const res = `res://${f.slice('game/'.length)}`;
    const scenes = Object.entries(scenesText).filter(([, txt]) => txt.includes(res)).map(([n]) => n);
    const hits = ALL.filter((n) => texts[n].includes(name) || (word && word.test(texts[n])) ||
      scenes.some((sc) => texts[n].includes(sc)));
    if (!hits.length) return null;
    hits.forEach((n) => picked.add(n));
  }
  return [...picked];
}

let only = process.argv.slice(2);
if (!only.length && process.env.CHANGED_FILES) {
  const sel = partsFor(process.env.CHANGED_FILES.split('\n').filter(Boolean));
  if (sel && !sel.length) {
    console.log('nada que os testes do Godot cobrem mudou: sem testes.');
    process.exit(0);
  }
  if (sel && sel.length < ALL.length) {
    only = ALL.filter((n) => sel.includes(n));
    console.log(`partes escolhidas pelos arquivos mudados: ${only.join(', ')} (a suíte inteira roda no CI)`);
  }
}
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
// o relógio do Godot começa aqui, depois da fila: a espera não come o tempo da suíte (fila + Godot cabem no hook)
const godotStart = Date.now();
const opts = { cwd: game, encoding: 'utf8', timeout: GODOT_TIMEOUT, maxBuffer: 16 * 1024 * 1024 };
const imp = spawnSync(godot, ['--headless', '--import', '--path', '.'], opts);
if (imp.status !== 0) {
  const why = imp.error?.message ?? `código ${imp.status}, sinal ${imp.signal}`;
  console.error(`falha ao importar o projeto (${why}):\n${imp.stdout ?? ''}${imp.stderr ?? ''}`);
  process.exit(1);
}

// Partes em paralelo: JOBS processos do Godot, cada um com um lote de partes. Os lotes são montados pelo tempo
// que cada parte levou da última vez (timings.json, linhas "@@tempo" do run_tests.gd): a maior vai para o lote mais leve.
// "ai=test_a+test_b" na linha de comando = só esses testes da parte
const unknown = only.filter((n) => !ALL.includes(n.split('=')[0]));
if (unknown.length) {
  console.log(`parte desconhecida: ${unknown.join(', ')} (válidas: ${ALL.join(', ')})`);
  process.exit(1);
}
const picked = Object.fromEntries(only.filter((n) => n.includes('=')).map((n) => n.split('=')).map(([n, l]) => [n, l.split('+')]));
const wanted = only.length ? ALL.filter((n) => only.some((o) => o.split('=')[0] === n)) : ALL;
const TIMINGS = join(state, 'timings.json');
const timings = (() => { try { return JSON.parse(readFileSync(TIMINGS, 'utf8')); } catch { return {}; } })();
const known = Object.values(timings);
const guess = known.length ? known.reduce((a, b) => a + b, 0) / known.length : 20_000;
// parte com `const TESTS := [...]` no *_tests.gd (a ai, longa) vira um pedaço por teste ("ai=test_x")
const testsOf = Object.fromEntries(wanted.map((n) => {
  if (n === 'core') return [n, null];
  const list = readFileSync(join(game, `tests/${n}_tests.gd`), 'utf8').match(/^const TESTS := \[([\s\S]*?)\]/m);
  return [n, list ? [...list[1].matchAll(/"(\w+)"/g)].map((m) => m[1]) : null];
}));
const units = wanted.flatMap((n) => (testsOf[n] ? (picked[n] ?? testsOf[n]).map((x) => `${n}=${x}`) : [n]));
const cost = (u) => timings[u] ?? (u.includes('=') && timings[u.split('=')[0]] ? timings[u.split('=')[0]] / 20 : guess);
// Lotes = trechos SEGUIDOS da ordem normal da suíte: cada parte roda depois da mesma de sempre ou abre um processo
// limpo. (Embaralhar a ordem quebrava testes que dependem do que a parte anterior deixou: hurt -> trail, ai -> voice.)
// Menor teto de tempo por lote que ainda cabe em JOBS trechos (busca binária + enchimento guloso).
const JOBS = Math.max(1, Math.min(Number(process.env.GODOT_TEST_JOBS) || 5, units.length));
const fill = (cap) => {
  const out = [{ ms: 0, units: [] }];
  for (const u of units) {
    let lot = out[out.length - 1];
    if (lot.units.length && lot.ms + cost(u) > cap) out.push(lot = { ms: 0, units: [] });
    lot.ms += cost(u);
    lot.units.push(u);
  }
  return out;
};
let lo = Math.max(...units.map(cost));
let hi = units.reduce((a, u) => a + cost(u), 0);
while (hi - lo > 500) {
  const mid = (lo + hi) / 2;
  if (fill(mid).length <= JOBS) hi = mid; else lo = mid;
}
const lots = fill(hi);
// "ai=a", "ai=b" no mesmo lote -> "ai=a+b"; a parte inteira no lote -> só "ai"; na ordem da suíte
for (const lot of lots) {
  lot.parts = wanted.flatMap((n) => {
    const mine = lot.units.filter((u) => u === n || u.startsWith(`${n}=`));
    if (!mine.length) return [];
    return !testsOf[n] || mine.length === testsOf[n].length ? [n] : [`${n}=${mine.map((u) => u.split('=')[1]).join('+')}`];
  });
}

// passo fixo de 1/60 s: o tempo de jogo é o mesmo, mas sem esperar o relógio (minutos -> segundos)
function runLot(lot, i) {
  return new Promise((done) => {
    const args = ['--headless', '--fixed-fps', '60', '--log-file', join(state, `godot-${i}.log`), '--path', '.',
      '--script', 'res://tests/run_tests.gd', '--', `--only=${lot.parts.join(',')}`, `--shard=_${i}`];
    const child = spawn(godot, args, { cwd: game });
    let raw = '';
    child.stdout.on('data', (d) => { raw += d; });
    child.stderr.on('data', (d) => { raw += d; });
    const left = Math.max(30_000, GODOT_TIMEOUT - (Date.now() - godotStart));
    const timer = setTimeout(() => { raw += `\nTEMPO ESGOTADO (${Math.round(left / 1000)} s): processo morto`; child.kill(); }, left);
    child.on('error', (e) => { clearTimeout(timer); done({ lot, code: 1, raw: `não foi possível rodar o Godot: ${e.message}`, killed: false }); });
    child.on('close', (code) => { clearTimeout(timer); done({ lot, code: code ?? 1, raw, killed: code === null }); });
  });
}
const results = await Promise.all(lots.map(runLot));
const label = (lot) => lot.parts.map((p) => p.replace(/=(.*)/, (_, l) => ` (${l.split('+').length} testes)`)).join(', ');

// o Godot imprime avisos de vazamento ao sair do modo --script; só o resultado dos testes interessa
const noise = /leaked|RID allocations|PagedAllocator|ObjectDB|resources still|^\s+at: |Parameter "material"/;
let passed = 0;
const failed = [];
const blocks = [];
for (const r of results) {
  const lines = r.raw.split(/\r?\n/).filter((l) => l.trim() && !noise.test(l));
  const body = [];
  let summary = false;
  const before = failed.length;
  for (const l of lines) {
    const tm = l.match(/^@@tempo (\S+) (\d+)/);
    if (tm) { timings[tm[1]] = Number(tm[2]); continue; }
    const sm = l.match(/^(\d+) ok, (\d+) falharam/);
    if (sm) { passed += Number(sm[1]); summary = true; continue; }
    if (summary && /^\s+- /.test(l)) { failed.push(l.trim().slice(2)); continue; }
    body.push(l);
  }
  // processo que caiu (erro de script, tempo esgotado) sem chegar ao resumo também é falha
  if (!summary || (r.code !== 0 && failed.length === before)) failed.push(`processo ${label(r.lot)} saiu com ${r.killed ? 'tempo esgotado' : `código ${r.code}`} sem terminar`);
  blocks.push(`--- ${label(r.lot)}\n${body.join('\n')}`);
}
writeFileSync(TIMINGS, JSON.stringify(timings, null, 1));
const secs = Math.round((Date.now() - godotStart) / 1000);
const out = `${blocks.join('\n')}\n\n${passed} ok, ${failed.length} falharam (${lots.length} processos, ${secs} s)` +
  failed.map((f) => `\n  - ${f}`).join('');
const code = failed.length ? 1 : 0;
// só guarda resultado de execução que terminou sozinha e com o projeto igual ao do começo
if (!results.some((r) => r.killed) && tree() === t) {
  writeFileSync(cacheFile(keyOf(t, only)), JSON.stringify({ at: Date.now(), code, out }));
  for (const f of readdirSync(state).filter((n) => n.startsWith('result-'))) {
    try { if (Date.now() - statSync(join(state, f)).mtimeMs > CACHE_TTL) rmSync(join(state, f), { force: true }); } catch { /* outra execução limpou */ }
  }
}
console.log(out);
process.exit(code);
