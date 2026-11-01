import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Mortality',
    loadComponent: () => import('./mortality-page'),
  },
] satisfies Routes;
