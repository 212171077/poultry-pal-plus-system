import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Settings',
    loadComponent: () => import('./settings-page'),
  },
] satisfies Routes;
