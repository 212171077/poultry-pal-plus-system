import { rmSync } from 'node:fs';
import { SCREENSHOT_DIR } from './fixtures/screenshots';
import { seedSystemAdmin } from './infra/seed';
import { startStack } from './infra/stack';

export default async function globalSetup(): Promise<void> {
  rmSync(SCREENSHOT_DIR, { recursive: true, force: true });
  await startStack();
  await seedSystemAdmin();
}
