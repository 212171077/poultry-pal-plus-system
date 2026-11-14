import { Routes } from '@angular/router';
import { MAT_FORM_FIELD_DEFAULT_OPTIONS } from '@angular/material/form-field';

export default [
  {
    path: '',
    loadComponent: () => import('./production-shell'),
    providers: [
      { provide: MAT_FORM_FIELD_DEFAULT_OPTIONS, useValue: { subscriptSizing: 'dynamic' } },
    ],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      {
        path: 'batches',
        title: 'Incubation batches',
        loadComponent: () => import('./batches-page'),
      },
      {
        path: 'dashboard',
        title: 'Production dashboard',
        loadComponent: () => import('./production-dashboard-page'),
      },
      {
        path: 'results',
        title: 'Hatch results',
        loadComponent: () => import('./hatch-results-page'),
      },
      {
        path: 'placements',
        title: 'Chicken houses',
        loadComponent: () => import('./placements-page'),
      },
      {
        path: 'schedule',
        title: 'Plan a batch',
        loadComponent: () => import('./schedule-page'),
      },
      {
        path: 'plans',
        title: 'Production plans',
        loadComponent: () => import('./plans-page'),
      },
      {
        path: 'settings',
        title: 'Production settings',
        loadComponent: () => import('./production-settings-page'),
      },
    ],
  },
] satisfies Routes;
