import { Injector } from '@angular/core';
import { firstValueFrom } from 'rxjs';

/**
 * Opens the sign-in-again dialog. The shell needs it rarely, so the dialog, Material dialog and
 * forms code load on first use instead of in the initial bundle.
 */
export async function openReauthDialog(injector: Injector): Promise<boolean> {
  const [{ MatDialog }, { ReauthDialog }] = await Promise.all([
    import('@angular/material/dialog'),
    import('./reauth-dialog'),
  ]);
  const ref = injector.get(MatDialog).open(ReauthDialog, { autoFocus: 'dialog', maxWidth: '95vw' });
  return (await firstValueFrom(ref.afterClosed(), { defaultValue: false })) === true;
}
