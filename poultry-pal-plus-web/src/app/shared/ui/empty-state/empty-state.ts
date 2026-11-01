import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

/** Friendly placeholder for empty lists. Project call-to-action buttons into it. */
@Component({
  selector: 'app-empty-state',
  imports: [MatIconModule],
  template: `
    <div class="icon" aria-hidden="true">
      <mat-icon>{{ icon() }}</mat-icon>
    </div>
    <h2 class="title">{{ heading() }}</h2>
    @if (message()) {
      <p class="message">{{ message() }}</p>
    }
    <div class="actions"><ng-content /></div>
  `,
  styles: `
    :host {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: var(--pp-space-sm);
      padding: var(--pp-space-xl) var(--pp-space-md);
      text-align: center;
    }
    .icon {
      display: grid;
      place-items: center;
      width: 72px;
      height: 72px;
      margin-bottom: var(--pp-space-sm);
      border-radius: 50%;
      background: var(--pp-surface-warm);
      color: var(--pp-brand);
    }
    .icon mat-icon {
      width: 36px;
      height: 36px;
      font-size: 36px;
    }
    .title {
      font-size: 1.1rem;
      font-weight: 600;
    }
    .message {
      max-width: 42ch;
      color: var(--mat-sys-on-surface-variant);
    }
    .actions {
      display: flex;
      flex-wrap: wrap;
      justify-content: center;
      gap: var(--pp-space-sm);
      margin-top: var(--pp-space-sm);
    }
    .actions:empty {
      display: none;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class EmptyState {
  readonly icon = input('inbox');
  readonly heading = input.required<string>();
  readonly message = input<string>();
}
