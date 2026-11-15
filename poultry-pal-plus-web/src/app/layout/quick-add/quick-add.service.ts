import { Injectable, Injector, inject } from '@angular/core';

/** Opens the Quick add dialog; loaded on demand to keep it out of the initial bundle. */
@Injectable({ providedIn: 'root' })
export class QuickAddService {
  private readonly injector = inject(Injector);

  async open(): Promise<void> {
    const [{ MatDialog }, { QuickAddDialog }] = await Promise.all([
      import('@angular/material/dialog'),
      import('./quick-add-dialog'),
    ]);
    this.injector.get(MatDialog).open(QuickAddDialog, {
      width: '420px',
      maxWidth: '92vw',
      position: { bottom: '88px' },
      autoFocus: 'first-tabbable',
    });
  }
}
