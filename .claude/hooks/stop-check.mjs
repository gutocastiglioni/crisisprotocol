#!/usr/bin/env node
// Hook "Stop" (qualquer stack): antes do Claude encerrar o turno, procura segredos nos arquivos alterados e roda
// os comandos da lista "hook" de .claude/quality.json (tipos, lint, unitários) + o limite de 600 linhas. Se algo falhar, devolve o erro (exit 2) e o Claude continua
// corrigindo — no máximo MAX_BLOCKS vezes seguidas, para nunca entrar em loop.
// Só conta o que mudou DESDE A ÚLTIMA VEZ QUE PASSOU nesta sessão (base gravada no SessionStart e a cada turno aprovado):
// arquivos que já estavam alterados no git quando a sessão abriu não disparam nada. A lista vai aos comandos em
// CHANGED_FILES (o runner do Godot escolhe só as partes da suíte que esses arquivos tocam).
// `node stop-check.mjs --baseline` (hook SessionStart) só grava a base e sai.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const MAX_BLOCKS = 3;
const MAX_LINES = 600;
const CODE = /\.(ts|tsx|js|jsx|mjs|cjs|vue|svelte|astro|css|scss|html|dart|py|go|rs|java|kt|kts|swift|cs|php|rb|sql|rules)$/;
// Godot: mudança aqui dispara os testes, mas fica fora do limite de linhas (vários scripts do jogo já passam dele)
const ENGINE = /\.(gd|gdshader|tscn)$/;
const EXEMPT =/(^|\/)(extensions|node_modules|dist|build|\.next|\.dart_tool|\.venv|vendor|supabase\/migrations)\/|\.d\.ts$|database\.types\.ts$|\.generated\.|\.g\.dart$|\.freezed\.dart$|_pb2\.py$/;

const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const input = (() => { try { return JSON.parse(readFileSync(0, 'utf8') || '{}'); } catch { return {}; } })();
const counterFile = join(tmpdir(), `claude-stop-check-${input.session_id || 'default'}.txt`);
const baseFile = join(tmpdir(), `claude-stop-base-${input.session_id || 'default'}.json`);

/** Executa um comando no projeto e devolve sucesso + o fim da saída. */
function run(cmd, env = process.env) {
  // a suíte do Godot leva ~3,5 min e pode esperar na fila de outra sessão (tools/run_godot_tests.mjs); o hook todo tem 600 s (settings.json)
  const r = spawnSync(cmd, { cwd, shell: true, encoding: 'utf8', timeout: 590_000, env });
  return { ok: r.status === 0, status: r.status, stdout: r.stdout || '', out: `${r.stdout || ''}${r.stderr || ''}`.trimEnd().slice(-2500) };
}

// Segredos que nunca podem ir para o repositório (chaves públicas como anon/publishable ficam de fora).
const SECRET_PATTERNS = [
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, 'chave privada'],
  [/\bsb_secret_[A-Za-z0-9_-]{20,}/, 'chave secreta do Supabase (sb_secret_)'],
  [/\bsk_live_[0-9a-zA-Z]{20,}/, 'chave live do Stripe'],
  [/\bAKIA[0-9A-Z]{16}\b/, 'chave de acesso AWS'],
  [/\b(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{60,})\b/, 'token do GitHub'],
  [/\bxox[abprs]-[A-Za-z0-9-]{10,}/, 'token do Slack'],
];
const SECRET_FILE = /(^|\/)\.env(\.(?!example$|sample$|template$)[^/]+)?$/;

/** Devolve os problemas de segredo de um arquivo alterado. */
function secretProblems(file) {
  const problems = [];
  if (SECRET_FILE.test(file)) problems.push(`${file}: arquivo de segredos fora do .gitignore`);
  const full = join(cwd, file);
  if (!existsSync(full) || /\.(png|jpe?g|gif|webp|ico|pdf|zip|woff2?|lock)$/i.test(file)) return problems;
  const text = readFileSync(full, 'utf8');
  if (text.length > 1_000_000) return problems;
  for (const [re, label] of SECRET_PATTERNS) if (re.test(text)) problems.push(`${file}: contém ${label}`);
  for (const jwt of text.match(/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g) ?? []) {
    try {
      const payload = JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString('utf8'));
      if (payload.role === 'service_role') problems.push(`${file}: contém a chave service_role do Supabase`);
    } catch { /* não é JWT */ }
  }
  return problems;
}

// Só roda quando há algo alterado (perguntas e conversas não pagam o custo)
const status = run('git status --porcelain -uall');
const allChanged = status.stdout.split('\n')
  .map((l) => l.slice(3).replace(/^.* -> /, '').replace(/^"|"$/g, '').trim())
  .filter(Boolean);
const changed = allChanged.filter((f) => CODE.test(f));
/** Assinatura (tamanho + data) de cada arquivo alterado no git; apagado = "-". */
const sigs = Object.fromEntries(allChanged.map((f) => {
  try { const s = statSync(join(cwd, f)); return [f, `${s.size}|${Math.round(s.mtimeMs)}`]; } catch { return [f, '-']; }
}));
if (process.argv.includes('--baseline')) {
  // só na sessão nova: ao retomar/compactar a mesma sessão a base fica (senão o que ainda não passou seria esquecido)
  if (status.ok && !existsSync(baseFile)) writeFileSync(baseFile, JSON.stringify(sigs));
  process.exit(0);
}
const base = (() => { try { return JSON.parse(readFileSync(baseFile, 'utf8')); } catch { return null; } })();
// mudou desde a base: assinatura nova, ou estava alterado e voltou ao do git (sem base: tudo que está alterado)
const fresh = base === null ? allChanged
  : [...allChanged.filter((f) => base[f] !== sigs[f]), ...Object.keys(base).filter((f) => !(f in sigs))];
if (!status.ok || fresh.length === 0) process.exit(0);
const tested = fresh.filter((f) => CODE.test(f) || ENGINE.test(f));

const failures = fresh.filter((f) => f in sigs).flatMap(secretProblems);
const BUSY = 75; // o comando não rodou porque outra sessão ocupava a fila: avisa, não bloqueia (senão as sessões ficam repetindo)
const warnings = [];

// Comandos do projeto: .claude/quality.json (qualquer stack; o bootstrap cria). Sem ele, cai no padrão npm.
const quality = (() => { try { return JSON.parse(readFileSync(join(cwd, '.claude/quality.json'), 'utf8')); } catch { return null; } })();
let checks = [];
if (quality) {
  checks = (quality.hook ?? ['typecheck', 'lint', 'unit'])
    .filter((k) => quality.commands?.[k]).map((k) => [k, quality.commands[k]]);
} else {
  const pkg = existsSync(join(cwd, 'package.json')) ? JSON.parse(readFileSync(join(cwd, 'package.json'), 'utf8')) : {};
  const scripts = pkg.scripts || {};
  if (scripts.typecheck) checks.push(['typecheck', 'npm run -s typecheck']);
  else if (existsSync(join(cwd, 'tsconfig.json'))) checks.push(['typecheck', 'npx --no-install tsc --noEmit']);
  if (scripts.lint) checks.push(['lint', 'npm run -s lint']);
  if (scripts['test:unit']) checks.push(['unit', 'npm run -s test:unit']);
}
if (tested.length) {
  const env = { ...process.env, CHANGED_FILES: tested.join('\n') };
  for (const [name, cmd] of checks) {
    const r = run(cmd, env);
    if (r.status === BUSY) { warnings.push(`${name}: ${r.out}`); continue; }
    if (!r.ok) failures.push(`${name} (${cmd}):\n${r.out}`);
  }
}

for (const file of changed.filter((f) => fresh.includes(f))) {
  const full = join(cwd, file);
  if (EXEMPT.test(file.replace(/\\/g, '/')) || !existsSync(full)) continue;
  const lines = readFileSync(full, 'utf8').split('\n').length;
  if (lines > MAX_LINES) failures.push(`${file} tem ${lines} linhas (limite ${MAX_LINES}): divida em módulos.`);
}

if (failures.length === 0) {
  rmSync(counterFile, { force: true });
  if (!warnings.length) writeFileSync(baseFile, JSON.stringify(sigs)); // aprovado: a próxima vez só olha o que mudar daqui
  if (warnings.length) console.log(JSON.stringify({ systemMessage: `stop-check: NÃO VERIFICADO — ${warnings.join(' | ')}` }));
  process.exit(0);
}

const blocks = existsSync(counterFile) ? Number(readFileSync(counterFile, 'utf8')) || 0 : 0;
if (blocks >= MAX_BLOCKS) {
  rmSync(counterFile, { force: true });
  console.log(JSON.stringify({ systemMessage: `stop-check: ainda há falhas após ${MAX_BLOCKS} tentativas — o Claude deve reportá-las.` }));
  process.exit(0);
}
writeFileSync(counterFile, String(blocks + 1));
console.error(`Verificações automáticas falharam — corrija antes de encerrar (tentativa ${blocks + 1}/${MAX_BLOCKS}):\n\n${failures.join('\n\n')}`);
process.exit(2);
