import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Team',
    loadComponent: () => import('./team-page'),
  },
] satisfies Routes;
