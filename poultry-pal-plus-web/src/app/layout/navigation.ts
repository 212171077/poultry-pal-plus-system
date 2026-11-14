import { Permission } from '../core/auth/permissions';

export interface NavItem {
  readonly label: string;
  readonly icon: string;
  readonly path: string;
  /** Short label for the tablet rail and bottom bar. */
  readonly shortLabel?: string;
  /** Hidden from users without this permission (the route is guarded too). */
  readonly requires?: Permission;
}

export interface QuickAction {
  readonly label: string;
  readonly icon: string;
  readonly path: string;
  readonly requires?: Permission;
}

export const PRIMARY_NAV: readonly NavItem[] = [
  { label: 'Dashboard', shortLabel: 'Home', icon: 'space_dashboard', path: '/dashboard' },
  { label: 'Coops & batches', shortLabel: 'Coops', icon: 'home_work', path: '/coops' },
  { label: 'Sales', icon: 'point_of_sale', path: '/sales' },
  { label: 'Mortality', icon: 'monitor_heart', path: '/mortality' },
  { label: 'Expenses', icon: 'receipt_long', path: '/expenses' },
  { label: 'Egg production', shortLabel: 'Eggs', icon: 'egg', path: '/eggs' },
  { label: 'Reminders', icon: 'notifications_active', path: '/reminders' },
  { label: 'Reports', icon: 'insights', path: '/reports' },
  { label: 'Team', icon: 'groups', path: '/team', requires: 'FARM_MANAGER' },
  { label: 'Production', icon: 'egg_alt', path: '/production', requires: 'PRODUCTION_MANAGE' },
];

export const SECONDARY_NAV: readonly NavItem[] = [
  { label: 'Sync center', shortLabel: 'Sync', icon: 'sync', path: '/sync' },
  { label: 'Settings', icon: 'settings', path: '/settings' },
  { label: 'App config', icon: 'tune', path: '/admin/app-config', requires: 'SYSTEM_ADMIN' },
];

/**
 * Most frequent daily tasks, reachable from the bottom bar's "+" button, the top bar's "Quick add"
 * menu and the `N` shortcut. Each opens its page with `?action=new`, which opens the form.
 */
export const QUICK_ACTIONS: readonly QuickAction[] = [
  { label: 'Log egg collection', icon: 'egg', path: '/eggs' },
  { label: 'Record a sale', icon: 'point_of_sale', path: '/sales' },
  { label: 'Record mortality', icon: 'monitor_heart', path: '/mortality' },
  { label: 'Add an expense', icon: 'receipt_long', path: '/expenses' },
  { label: 'Add a coop', icon: 'home_work', path: '/coops', requires: 'FARM_MANAGER' },
];
