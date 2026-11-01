import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Expenses',
    loadComponent: () => import('./expenses-page'),
  },
] satisfies Routes;
