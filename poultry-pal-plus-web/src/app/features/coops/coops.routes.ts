import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Coops & batches',
    loadComponent: () => import('./coops-page'),
  },
  {
    path: 'archive',
    title: 'Archived batches',
    loadComponent: () => import('./archive/archive-page'),
  },
] satisfies Routes;
