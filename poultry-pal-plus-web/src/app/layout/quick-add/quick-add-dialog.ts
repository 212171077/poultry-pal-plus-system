import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';
import { injectQuickActions } from '../quick-actions';

const TONES: Readonly<Record<string, string>> = {
  '/eggs': 'accent',
  '/sales': 'success',
  '/mortality': 'error',
  '/expenses': 'warning',
  '/coops': 'brand',
};

/** Centred "Quick add" picker: one large, colour-coded tile per frequent task. */
@Component({
  selector: 'app-quick-add-dialog',
  imports: [MatDialogModule, MatIconModule, RouterLink],
  template: `
    <h2 mat-dialog-title>Quick add</h2>
    <mat-dialog-content>
      <p class="hint">What would you like to record?</p>
      <ul class="tiles">
        @for (action of actions(); track action.path) {
          <li>
            <a
              class="tile"
              [routerLink]="action.path"
              [queryParams]="{ action: 'new' }"
              [attr.data-tone]="tone(action.path)"
              (click)="ref.close()"
            >
              <span class="icon" aria-hidden="true"
                ><mat-icon>{{ action.icon }}</mat-icon></span
              >
              <span class="label">{{ action.label }}</span>
              <mat-icon class="go" aria-hidden="true">chevron_right</mat-icon>
            </a>
          </li>
        }
      </ul>
    </mat-dialog-content>
  `,
  styles: `
    h2 {
      text-align: center;
    }
    .hint {
      margin: 0 0 var(--pp-space-md);
      color: var(--mat-sys-on-surface-variant);
      text-align: center;
    }
    .tiles {
      display: grid;
      gap: var(--pp-space-sm);
      margin: 0;
      padding: 0;
      list-style: none;
    }
    .tile {
      display: flex;
      align-items: center;
      gap: var(--pp-space-md);
      min-height: 56px;
      padding: var(--pp-space-sm) var(--pp-space-md);
      border: 1px solid var(--pp-border);
      border-radius: var(--pp-radius-md);
      background: var(--pp-surface-warm);
      color: var(--mat-sys-on-surface);
      font: var(--mat-sys-title-small);
      text-decoration: none;
      transition:
        transform 0.12s ease,
        box-shadow 0.12s ease;

      &:hover,
      &:focus-visible {
        box-shadow: var(--mat-sys-level2);
        transform: translateY(-1px);
      }
    }
    .icon {
      display: grid;
      flex: none;
      place-items: center;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: var(--mat-sys-surface);
      color: var(--tone, var(--pp-brand));
    }
    .tile[data-tone='accent'] {
      --tone: var(--pp-accent-strong, var(--pp-brand));
    }
    .tile[data-tone='success'] {
      --tone: var(--pp-success);
    }
    .tile[data-tone='error'] {
      --tone: var(--pp-error);
    }
    .tile[data-tone='warning'] {
      --tone: var(--pp-warning);
    }
    .label {
      flex: 1;
    }
    .go {
      color: var(--mat-sys-on-surface-variant);
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class QuickAddDialog {
  protected readonly ref = inject(MatDialogRef<QuickAddDialog>);
  protected readonly actions = injectQuickActions();
  protected tone(path: string): string {
    return TONES[path] ?? 'brand';
  }
}
