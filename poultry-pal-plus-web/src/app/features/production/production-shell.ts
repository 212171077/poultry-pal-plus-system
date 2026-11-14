import { ChangeDetectionStrategy, Component, ViewEncapsulation } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatIcon } from '@angular/material/icon';

interface Tab {
  readonly path: string;
  readonly label: string;
  readonly icon: string;
  readonly exact: boolean;
}

const TABS: readonly Tab[] = [
  { path: 'dashboard', label: 'Dashboard', icon: 'dashboard', exact: false },
  { path: 'batches', label: 'Batches', icon: 'egg_alt', exact: false },
  { path: 'schedule', label: 'Plan a batch', icon: 'edit_calendar', exact: false },
  { path: 'plans', label: 'Plans', icon: 'event_note', exact: false },
  { path: 'placements', label: 'Chicken houses', icon: 'home', exact: false },
  { path: 'results', label: 'Hatch results', icon: 'insights', exact: false },
  { path: 'settings', label: 'Settings', icon: 'tune', exact: false },
];

/** Sticky section menu shared by every production page; the open page's tab is highlighted. */
@Component({
  selector: 'app-production-shell',
  imports: [RouterLink, RouterLinkActive, RouterOutlet, MatIcon],
  template: `
    <nav class="production-nav" aria-label="Production sections">
      @for (tab of tabs; track tab.path) {
        <a
          class="production-tab"
          [routerLink]="tab.path"
          routerLinkActive="active"
          [routerLinkActiveOptions]="{ exact: tab.exact }"
          ariaCurrentWhenActive="page"
        >
          <mat-icon aria-hidden="true">{{ tab.icon }}</mat-icon>
          <span>{{ tab.label }}</span>
        </a>
      }
    </nav>
    <router-outlet />
  `,
  styleUrl: './production-shell.scss',
  encapsulation: ViewEncapsulation.None,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ProductionShell {
  protected readonly tabs = TABS;
}
