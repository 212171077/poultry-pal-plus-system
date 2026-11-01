import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Sync center',
    loadComponent: () => import('./sync-center-page'),
  },
] satisfies Routes;
