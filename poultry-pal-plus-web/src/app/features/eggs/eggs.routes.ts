import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Egg production',
    loadComponent: () => import('./eggs-page'),
  },
] satisfies Routes;
