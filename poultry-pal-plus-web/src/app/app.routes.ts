import { Routes } from '@angular/router';
import { authGuard, guestGuard, permissionGuard } from './core/auth/auth.guards';
import { Shell } from './layout/shell/shell';

export const routes: Routes = [
  {
    path: 'login',
    title: 'Sign in',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/login-page'),
  },
  {
    path: 'forgot-password',
    title: 'Reset your password',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/forgot-password-page'),
  },
  {
    path: 'register',
    title: 'Create your farm account',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/register-page'),
  },
  {
    path: '',
    component: Shell,
    canActivate: [authGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      {
        path: 'dashboard',
        loadChildren: () => import('./features/dashboard/dashboard.routes'),
      },
      { path: 'coops', loadChildren: () => import('./features/coops/coops.routes') },
      { path: 'sales', loadChildren: () => import('./features/sales/sales.routes') },
      {
        path: 'mortality',
        loadChildren: () => import('./features/mortality/mortality.routes'),
      },
      { path: 'expenses', loadChildren: () => import('./features/expenses/expenses.routes') },
      { path: 'eggs', loadChildren: () => import('./features/eggs/eggs.routes') },
      {
        path: 'reminders',
        loadChildren: () => import('./features/reminders/reminders.routes'),
      },
      { path: 'reports', loadChildren: () => import('./features/reports/reports.routes') },
      {
        path: 'team',
        canActivate: [permissionGuard('FARM_MANAGER')],
        loadChildren: () => import('./features/team/team.routes'),
      },
      {
        path: 'production',
        canActivate: [permissionGuard('PRODUCTION_MANAGE')],
        loadChildren: () => import('./features/production/production.routes'),
      },
      {
        path: 'admin/app-config',
        canActivate: [permissionGuard('SYSTEM_ADMIN')],
        loadChildren: () => import('./features/admin/app-config/app-config.routes'),
      },
      {
        path: 'admin/farms',
        canActivate: [permissionGuard('SYSTEM_ADMIN')],
        loadChildren: () => import('./features/admin/farms/admin-farms.routes'),
      },
      { path: 'sync', loadChildren: () => import('./features/sync/sync.routes') },
      { path: 'settings', loadChildren: () => import('./features/settings/settings.routes') },
      {
        path: '**',
        title: 'Page not found',
        loadComponent: () => import('./features/not-found/not-found-page'),
      },
    ],
  },
];
