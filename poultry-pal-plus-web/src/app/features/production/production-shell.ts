import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  ViewEncapsulation,
  afterNextRender,
  signal,
  viewChild,
} from '@angular/core';
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
    <div class="production-nav-wrap" [class.scrollable]="scrollable()">
      <nav #nav class="production-nav" aria-label="Production sections" (scroll)="measure()">
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
      @if (scrollable()) {
        <mat-icon class="edge edge-start" [class.visible]="canScrollStart()" aria-hidden="true">
          chevron_left
        </mat-icon>
        <mat-icon class="edge edge-end" [class.visible]="canScrollEnd()" aria-hidden="true">
          chevron_right
        </mat-icon>
        <div class="production-dots" aria-hidden="true" data-testid="production-dots">
          @for (tab of tabs; track tab.path; let i = $index) {
            <span class="dot" [class.on]="i === position()"></span>
          }
        </div>
      }
    </div>
    <router-outlet />
  `,
  styleUrl: './production-shell.scss',
  encapsulation: ViewEncapsulation.None,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ProductionShell {
  protected readonly tabs = TABS;
  protected readonly scrollable = signal(false);
  protected readonly canScrollStart = signal(false);
  protected readonly canScrollEnd = signal(false);
  protected readonly position = signal(0);
  private readonly nav = viewChild.required<ElementRef<HTMLElement>>('nav');

  constructor() {
    afterNextRender(() => {
      this.measure();
      const observer = new ResizeObserver(() => this.measure());
      observer.observe(this.nav().nativeElement);
    });
  }

  protected measure(): void {
    const el = this.nav().nativeElement;
    const max = el.scrollWidth - el.clientWidth;
    this.scrollable.set(max > 1);
    this.canScrollStart.set(el.scrollLeft > 1);
    this.canScrollEnd.set(el.scrollLeft < max - 1);
    // The dot follows how far the menu is scrolled, so the last dot lights at the far end.
    const ratio = max > 0 ? el.scrollLeft / max : 0;
    this.position.set(Math.round(ratio * (this.tabs.length - 1)));
  }
}
