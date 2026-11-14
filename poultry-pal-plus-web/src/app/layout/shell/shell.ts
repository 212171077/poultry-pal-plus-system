import { DOCUMENT } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  Injector,
  computed,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { MatSidenavModule } from '@angular/material/sidenav';
import { RouterOutlet } from '@angular/router';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ConnectivityBanner } from '../../shared/ui/connectivity-banner/connectivity-banner';
import { BottomNav } from '../bottom-nav/bottom-nav';
import { SessionNotice } from '../session-notice/session-notice';
import { LayoutService } from '../layout.service';
import { SideNav } from '../side-nav/side-nav';
import { TopBar } from '../top-bar/top-bar';

@Component({
  selector: 'app-shell',
  imports: [
    MatSidenavModule,
    RouterOutlet,
    SideNav,
    TopBar,
    BottomNav,
    ConnectivityBanner,
    SessionNotice,
  ],
  templateUrl: './shell.html',
  styleUrl: './shell.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[attr.data-layout]': 'mode()', '(document:keydown)': 'onKeydown($event)' },
})
export class Shell {
  private readonly document = inject(DOCUMENT);
  protected readonly mode = inject(LayoutService).mode;
  private readonly handsetDrawerOpen = signal(false);
  private readonly topBar = viewChild(TopBar);
  private readonly bottomNav = viewChild(BottomNav);

  constructor() {
    const connectivity = inject(ConnectivityService);
    const injector = inject(Injector);
    // Queued report emails go out as soon as the server is reachable (lazy-loaded: rarely needed).
    effect(() => {
      if (connectivity.online()) {
        void import('../../features/reports/report-queue').then(({ ReportQueue }) =>
          injector.get(ReportQueue).flush(),
        );
      }
    });
  }

  protected readonly drawerMode = computed(() => (this.mode() === 'handset' ? 'over' : 'side'));
  protected readonly drawerOpen = computed(
    () => this.mode() !== 'handset' || this.handsetDrawerOpen(),
  );

  /** `href="#main-content"` resolves against `<base href="/">`, so move focus ourselves. */
  protected skipToMain(event: Event): void {
    event.preventDefault();
    this.document.getElementById('main-content')?.focus();
  }

  protected onDrawerOpenedChange(opened: boolean): void {
    if (this.mode() === 'handset') {
      this.handsetDrawerOpen.set(opened);
    }
  }

  protected openDrawer(): void {
    this.handsetDrawerOpen.set(true);
  }

  protected onNavigated(): void {
    this.handsetDrawerOpen.set(false);
  }

  /** `N` opens Quick Add, unless the user is typing or a dialog is open. */
  protected onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'n' && event.key !== 'N') return;
    if (event.ctrlKey || event.metaKey || event.altKey || event.repeat) return;
    if (isEditable(event.target) || document.querySelector(OPEN_OVERLAY)) return;
    const opened = this.bottomNav()?.openQuickAdd() ?? this.topBar()?.openQuickAdd() ?? false;
    if (opened) event.preventDefault();
  }
}

/** An open dialog, menu or bottom sheet owns the keyboard. */
const OPEN_OVERLAY = '.mat-mdc-dialog-container, .mat-mdc-menu-panel, .mat-bottom-sheet-container';

function isEditable(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return (
    target.isContentEditable ||
    target instanceof HTMLInputElement ||
    target instanceof HTMLTextAreaElement ||
    target instanceof HTMLSelectElement ||
    target.getAttribute('role') === 'combobox'
  );
}
