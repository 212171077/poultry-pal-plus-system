import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { OUTPUT_DIR } from './env';
import { waitForEmail } from './mailpit';

/** The backend creates this admin on first start (random password, emailed). */
export const SYSTEM_ADMIN_EMAIL = 'systemnotification.cs@gmail.com';

/**
 * Reads the generated system-admin password from the welcome email in Mailpit. This also proves the
 * database-driven mail settings deliver to Mailpit. Further users are created per spec through the API.
 */
export async function seedSystemAdmin(): Promise<{ email: string; password: string }> {
  const html = await waitForEmail({ to: SYSTEM_ADMIN_EMAIL, subject: 'system admin account' });
  const match = /Password:<\/strong>\s*([^<\s]+)/.exec(html);
  if (!match) throw new Error('System admin password not found in the welcome email.');
  const credentials = { email: SYSTEM_ADMIN_EMAIL, password: match[1] };

  process.env['E2E_ADMIN_EMAIL'] = credentials.email;
  process.env['E2E_ADMIN_PASSWORD'] = credentials.password;
  mkdirSync(OUTPUT_DIR, { recursive: true });
  writeFileSync(resolve(OUTPUT_DIR, '.seed.json'), JSON.stringify(credentials, null, 2));
  return credentials;
}
