import { LocalUser } from '../../data/models/local';

/**
 * What a user may do, mirroring the backend rules in `SyncService.PushContext`: the farm owner,
 * farm managers and admins manage the farm (coops, team, farm details); workers record data for
 * the coops they are assigned to.
 */
/** `SYSTEM_ADMIN` is the application operator (`ROLE_ADMIN`), independent of any farm. */
export type Permission = 'FARM_MANAGER' | 'FARM_OWNER' | 'SYSTEM_ADMIN' | 'PRODUCTION_MANAGE';

const MANAGER_ROLES: readonly string[] = ['ROLE_FARM_MANAGER', 'ROLE_ADMIN'];

export function hasPermission(user: LocalUser | null | undefined, permission: Permission): boolean {
  if (!user) return false;
  if (permission === 'SYSTEM_ADMIN') return (user.roles ?? []).includes('ROLE_ADMIN');
  if (user.farmOwner) return true;
  if (permission === 'FARM_OWNER') return false;
  if (permission === 'PRODUCTION_MANAGE') {
    return (user.permissions ?? []).includes('PRODUCTION_MANAGE');
  }
  return (user.roles ?? []).some((role) => MANAGER_ROLES.includes(role));
}

/** Short role description for the account menu. */
export function roleLabel(user: LocalUser | null | undefined): string {
  if (!user) return '';
  if (user.farmOwner) return 'Farm owner';
  if (hasPermission(user, 'FARM_MANAGER')) return 'Farm manager';
  return 'Farm worker';
}

export function fullName(user: LocalUser | null | undefined): string {
  return [user?.name, user?.surname].filter(Boolean).join(' ').trim();
}
