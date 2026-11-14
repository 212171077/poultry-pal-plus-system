import { E2E_DB_NAME, ports } from './env';

const DEFAULT_MONGO_PORT = 27017;

/**
 * Refuses to continue unless the target database is clearly the dedicated e2e one. Called before
 * the stack (which creates an empty database) is started and before any reset.
 */
export function assertSafeTestDatabase(env: NodeJS.ProcessEnv = process.env): void {
  const name = env['E2E_DB_NAME'] ?? E2E_DB_NAME;
  if (!/^poultry-pal-e2e/.test(name)) {
    throw new Error(
      `Refusing to use database "${name}": e2e databases must start with "poultry-pal-e2e".`,
    );
  }
  if (ports.mongo === DEFAULT_MONGO_PORT) {
    throw new Error(
      `Refusing to use Mongo port ${DEFAULT_MONGO_PORT}: it is the dev database port.`,
    );
  }
  const configured = env['SPRING_DATA_MONGODB_HOST'] ?? env['MONGODB_URI'];
  if (configured) {
    throw new Error(
      'SPRING_DATA_MONGODB_HOST/MONGODB_URI are set in the environment; unset them so the e2e stack cannot reach another database.',
    );
  }
}
