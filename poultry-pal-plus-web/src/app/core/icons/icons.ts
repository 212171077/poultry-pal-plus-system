import { inject, provideAppInitializer } from '@angular/core';
import { MatIconRegistry } from '@angular/material/icon';

/** Uses the self-hosted "Material Icons Round" font (works offline) for every <mat-icon>. */
export function provideIcons() {
  return provideAppInitializer(() => {
    inject(MatIconRegistry).setDefaultFontSetClass('material-icons-round');
  });
}
