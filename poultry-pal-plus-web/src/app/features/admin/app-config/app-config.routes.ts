import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'App config',
    loadComponent: () => import('./app-config-page'),
  },
] satisfies Routes;
