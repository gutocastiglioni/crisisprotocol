#!/usr/bin/env node
// Hook "Stop" (qualquer stack): antes do Claude encerrar o turno, procura segredos nos arquivos alterados e roda
// os comandos da lista "hook" de .claude/quality.json (tipos, lint, unitários) + o limite de 600 linhas. Se algo falhar, devolve o erro (exit 2) e o Claude continua
// corrigindo — no máximo MAX_BLOCKS vezes seguidas, para nunca entrar em loop.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const MAX_BLOCKS = 3;
const MAX_LINES = 600;
const CODE = /\.(ts|tsx|js|jsx|mjs|cjs|vue|svelte|astro|css|scss|html|dart|py|go|rs|java|kt|kts|swift|cs|php|rb|sql|rules)$/;
const EXEMPT = /(^|\/)(extensions|node_modules|dist|build|\.next|\.dart_tool|\.venv|vendor|supabase\/migrations)\/|\.d\.ts$|database\.types\.ts$|\.generated\.|\.g\.dart$|\.freezed\.dart$|_pb2\.py$/;

const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const input = (() => { try { return JSON.parse(readFileSync(0, 'utf8') || '{}'); } catch { return {}; } })();
const counterFile = join(tmpdir(), `claude-stop-check-${input.session_id || 'default'}.txt`);

/** Executa um comando no projeto e devolve sucesso + o fim da saída. */
function run(cmd) {
  const r = spawnSync(cmd, { cwd, shell: true, encoding: 'utf8', timeout: 240_000 });
  return { ok: r.status === 0, stdout: r.stdout || '', out: `${r.stdout || ''}${r.stderr || ''}`.trimEnd().slice(-2500) };
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
if (!status.ok || allChanged.length === 0) process.exit(0);

const failures = allChanged.flatMap(secretProblems);

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
if (changed.length) {
  for (const [name, cmd] of checks) {
    const r = run(cmd);
    if (!r.ok) failures.push(`${name} (${cmd}):\n${r.out}`);
  }
}

for (const file of changed) {
  const full = join(cwd, file);
  if (EXEMPT.test(file.replace(/\\/g, '/')) || !existsSync(full)) continue;
  const lines = readFileSync(full, 'utf8').split('\n').length;
  if (lines > MAX_LINES) failures.push(`${file} tem ${lines} linhas (limite ${MAX_LINES}): divida em módulos.`);
}

if (failures.length === 0) {
  rmSync(counterFile, { force: true });
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
