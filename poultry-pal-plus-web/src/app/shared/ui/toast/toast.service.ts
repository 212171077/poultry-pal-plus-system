import { Injectable, inject } from '@angular/core';
import { MatSnackBar, MatSnackBarRef } from '@angular/material/snack-bar';
import { ToastComponent, ToastData, ToastKind } from './toast';

export interface ToastOptions {
  readonly duration?: number;
  readonly kind?: ToastKind;
}

const ERROR =
  /could not|couldn't|cannot|can't|failed|not match|do not|only .* can|unable|invalid|error/i;
const INFO =
  /online|offline|sync when|will sync|will be emailed|saved on this device|waiting|latest available|reload|new version/i;

/** Picks the toast style from the wording when the caller did not choose one. */
export function toastKind(message: string): ToastKind {
  if (ERROR.test(message)) return 'error';
  if (INFO.test(message)) return 'info';
  return 'success';
}

/** Shows feedback toasts. Same call shape as MatSnackBar.open so call sites stay simple. */
@Injectable({ providedIn: 'root' })
export class Toast {
  private readonly snackBar = inject(MatSnackBar);

  open(
    message: string,
    action?: string,
    options: ToastOptions = {},
  ): MatSnackBarRef<ToastComponent> {
    const kind = options.kind ?? toastKind(message);
    const data: ToastData = { message, action, kind };
    return this.snackBar.openFromComponent(ToastComponent, {
      data,
      duration: options.duration ?? (kind === 'error' ? 6000 : 4000),
      panelClass: ['pp-toast', `pp-toast-${kind}`],
      politeness: kind === 'error' ? 'assertive' : 'polite',
    });
  }
}
