import { randomBytes } from 'node:crypto';
import { resolve } from 'node:path';

export const REPO_ROOT = resolve(__dirname, '..', '..', '..');
export const COMPOSE_FILE = resolve(REPO_ROOT, 'docker-compose.e2e.yml');
export const COMPOSE_PROJECT = 'ppp-e2e';
export const OUTPUT_DIR = resolve(REPO_ROOT, 'test-results');
/** The only database name the runner will ever create or reset; see db-guard.ts. */
export const E2E_DB_NAME = 'poultry-pal-e2e';

const port = (name: string, fallback: number): number => Number(process.env[name] ?? fallback);

export const ports = {
  web: port('E2E_WEB_PORT', 4310),
  backend: port('E2E_BACKEND_PORT', 8190),
  mongo: port('E2E_MONGO_PORT', 27117),
  mailpit: port('E2E_MAILPIT_PORT', 8125),
};

export const urls = {
  web: `http://localhost:${ports.web}`,
  backend: `http://localhost:${ports.backend}`,
  mailpit: `http://localhost:${ports.mailpit}`,
};

/** Throw-away secrets generated per run; nothing is committed or reused. */
export function composeEnv(): NodeJS.ProcessEnv {
  return {
    ...process.env,
    E2E_DB_NAME,
    E2E_MONGO_PASSWORD: randomBytes(18).toString('hex'),
    E2E_JWT_SECRET: randomBytes(64).toString('base64'),
    E2E_WEB_PORT: String(ports.web),
    E2E_BACKEND_PORT: String(ports.backend),
    E2E_MONGO_PORT: String(ports.mongo),
    E2E_MAILPIT_PORT: String(ports.mailpit),
  };
}
