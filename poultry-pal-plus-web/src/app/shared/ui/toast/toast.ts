import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MAT_SNACK_BAR_DATA, MatSnackBarRef } from '@angular/material/snack-bar';

export type ToastKind = 'success' | 'error' | 'info';

export interface ToastData {
  readonly message: string;
  readonly action?: string;
  readonly kind: ToastKind;
}

const ICONS: Record<ToastKind, string> = {
  success: 'M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z',
  error: 'M12 2 1 21h22L12 2zm1 15h-2v-2h2v2zm0-4h-2V9h2v4z',
  info: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z',
};

const TITLES: Record<ToastKind, string> = {
  success: 'Success',
  error: 'Something went wrong',
  info: 'Heads up',
};

/** Body of every toast: a tinted icon badge, a short title, the message and the action. */
@Component({
  selector: 'app-toast',
  template: `
    <div class="toast" [class]="'toast toast-' + data.kind">
      <span class="toast-badge" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="22" height="22" focusable="false">
          <path [attr.d]="icon" fill="currentColor" />
        </svg>
      </span>
      <span class="toast-text">
        <span class="toast-title" aria-hidden="true">{{ title }}</span>
        <span class="toast-message">{{ data.message }}</span>
      </span>
      @if (data.action) {
        <button type="button" class="toast-action" (click)="ref.dismissWithAction()">
          {{ data.action }}
        </button>
      }
      <button type="button" class="toast-close" aria-label="Dismiss" (click)="ref.dismiss()">
        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" focusable="false">
          <path
            d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12z"
            fill="currentColor"
          />
        </svg>
      </button>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ToastComponent {
  protected readonly data = inject<ToastData>(MAT_SNACK_BAR_DATA);
  protected readonly ref = inject(MatSnackBarRef);
  protected readonly icon = ICONS[this.data.kind];
  protected readonly title = TITLES[this.data.kind];
}
