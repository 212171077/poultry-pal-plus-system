import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Registered farms',
    loadComponent: () => import('./admin-farms-page'),
  },
] satisfies Routes;
