import { Routes } from '@angular/router';

export default [
  {
    path: '',
    title: 'Reminders',
    loadComponent: () => import('./reminders-page'),
  },
] satisfies Routes;
