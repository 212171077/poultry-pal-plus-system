import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Sales',
    loadComponent: () => import('./sales-page'),
  },
] satisfies Routes;
