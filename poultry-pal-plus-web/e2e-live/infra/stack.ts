import { execFileSync, spawnSync } from 'node:child_process';
import { createServer } from 'node:net';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { assertSafeTestDatabase } from './db-guard';
import { COMPOSE_FILE, COMPOSE_PROJECT, OUTPUT_DIR, composeEnv, ports, urls } from './env';

const compose = (args: string[], env: NodeJS.ProcessEnv, inherit = false) =>
  spawnSync('docker', ['compose', '-p', COMPOSE_PROJECT, '-f', COMPOSE_FILE, ...args], {
    env,
    encoding: 'utf8',
    stdio: inherit ? 'inherit' : 'pipe',
  });

function assertDockerAvailable(): void {
  const result = spawnSync('docker', ['info'], { encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(
      'Docker is not available or the daemon is not running. Start Docker and retry.',
    );
  }
}

function isPortFree(port: number): Promise<boolean> {
  return new Promise((resolvePort) => {
    const server = createServer();
    server.once('error', () => resolvePort(false));
    server.once('listening', () => server.close(() => resolvePort(true)));
    server.listen(port, '127.0.0.1');
  });
}

async function assertPortsFree(): Promise<void> {
  for (const [name, port] of Object.entries(ports)) {
    if (!(await isPortFree(port))) {
      throw new Error(
        `Port ${port} (${name}) is already in use. Stop whatever uses it or set E2E_${name.toUpperCase()}_PORT.`,
      );
    }
  }
}

export async function waitFor(
  description: string,
  check: () => Promise<boolean>,
  timeoutMs: number,
  intervalMs = 2_000,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  let lastError = '';
  while (Date.now() < deadline) {
    try {
      if (await check()) return;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error(
    `Timed out after ${timeoutMs / 1000}s waiting for ${description}. ${lastError}`.trim(),
  );
}

const httpOk = async (url: string): Promise<boolean> => (await fetch(url)).ok;

/** Removes any previous e2e stack (containers, networks, anonymous volumes) so the database is empty. */
export function resetStack(env = composeEnv()): void {
  compose(['down', '--volumes', '--remove-orphans'], env);
}

export async function startStack(): Promise<void> {
  assertSafeTestDatabase();
  assertDockerAvailable();
  const env = composeEnv();
  resetStack(env);
  await assertPortsFree();

  mkdirSync(resolve(OUTPUT_DIR, 'logs'), { recursive: true });
  console.log('[e2e] Building and starting mongo, mailpit, backend and web...');
  const up = compose(['up', '--build', '--detach', '--wait', '--wait-timeout', '600'], env, true);
  if (up.status !== 0) {
    saveLogs(env);
    resetStack(env);
    throw new Error('docker compose up failed; see test-results/logs/stack.log');
  }

  try {
    await waitFor('backend API docs', () => httpOk(`${urls.backend}/v3/api-docs`), 180_000);
    await waitFor('web app', () => httpOk(`${urls.web}/`), 60_000);
    await waitFor(
      'web -> backend proxy',
      async () => (await fetch(`${urls.web}/api/v1/auth/me`)).status === 401,
      30_000,
    );
  } catch (error) {
    saveLogs(env);
    resetStack(env);
    throw error;
  }
  // Teardown needs the same compose env; the secrets are only used to satisfy interpolation.
  process.env['E2E_STACK_STARTED'] = '1';
  console.log('[e2e] Stack is healthy.');
}

export function saveLogs(env = composeEnv()): void {
  const logs = compose(['logs', '--no-color', '--timestamps'], env);
  mkdirSync(resolve(OUTPUT_DIR, 'logs'), { recursive: true });
  writeFileSync(resolve(OUTPUT_DIR, 'logs', 'stack.log'), `${logs.stdout}${logs.stderr}`);
}

export function stopStack(): void {
  const env = composeEnv();
  saveLogs(env);
  resetStack(env);
  console.log('[e2e] Stack stopped and removed.');
}

export function dockerVersion(): string {
  return execFileSync('docker', ['--version'], { encoding: 'utf8' }).trim();
}
