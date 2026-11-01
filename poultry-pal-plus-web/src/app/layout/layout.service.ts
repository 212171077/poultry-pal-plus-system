import { BreakpointObserver } from '@angular/cdk/layout';
import { Injectable, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs';

export type LayoutMode = 'handset' | 'tablet' | 'desktop';

export const TABLET_QUERY = '(min-width: 600px)';
export const DESKTOP_QUERY = '(min-width: 1024px)';

/** Responsive layout mode: bottom bar on phones, navigation rail on tablets, sidebar on desktops. */
@Injectable({ providedIn: 'root' })
export class LayoutService {
  private readonly breakpoints = toSignal(
    inject(BreakpointObserver)
      .observe([TABLET_QUERY, DESKTOP_QUERY])
      .pipe(map((state) => state.breakpoints)),
    { requireSync: true },
  );

  readonly mode = computed<LayoutMode>(() => {
    const breakpoints = this.breakpoints();
    if (breakpoints[DESKTOP_QUERY]) return 'desktop';
    if (breakpoints[TABLET_QUERY]) return 'tablet';
    return 'handset';
  });
}
