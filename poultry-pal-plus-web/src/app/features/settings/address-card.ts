import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AddressDto } from '../../data/models/sync-api';

/** One farm address as a card, with edit and delete actions. */
@Component({
  selector: 'app-address-card',
  imports: [MatButtonModule, MatIconModule],
  template: `
    <article class="card" [class.primary]="primary()">
      <span class="pin" aria-hidden="true"><mat-icon>location_on</mat-icon></span>
      <div class="body">
        <header>
          <h3>{{ title() }}</h3>
          @if (primary()) {
            <span class="badge">Primary</span>
          }
        </header>
        @for (line of lines(); track $index) {
          <p>{{ line }}</p>
        }
      </div>
      @if (editable()) {
        <div class="actions">
          <button
            mat-icon-button
            type="button"
            [attr.aria-label]="'Edit ' + title()"
            (click)="edit.emit()"
          >
            <mat-icon>edit</mat-icon>
          </button>
          <button
            mat-icon-button
            type="button"
            class="delete"
            [attr.aria-label]="'Delete ' + title()"
            (click)="remove.emit()"
          >
            <mat-icon>delete</mat-icon>
          </button>
        </div>
      }
    </article>
  `,
  styles: `
    :host {
      display: block;
    }
    .card {
      display: flex;
      align-items: flex-start;
      gap: var(--pp-space-md);
      height: 100%;
      padding: var(--pp-space-md);
      border: 1px solid var(--pp-border);
      border-top: 4px solid var(--mat-sys-outline-variant);
      border-radius: var(--pp-radius-lg);
      background: var(--mat-sys-surface-container-lowest);
      box-shadow: var(--pp-shadow);
    }
    .card.primary {
      border-top-color: var(--pp-brand);
    }
    .pin {
      display: grid;
      flex: none;
      place-items: center;
      width: 40px;
      height: 40px;
      border-radius: var(--pp-radius-pill);
      background: color-mix(in srgb, var(--pp-brand) 14%, transparent);
      color: var(--pp-brand);
    }
    .body {
      flex: 1;
      min-width: 0;
    }
    header {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: var(--pp-space-sm);
      margin-bottom: var(--pp-space-xs, 4px);
    }
    h3 {
      margin: 0;
      font-size: 1rem;
      font-weight: 600;
      overflow-wrap: anywhere;
    }
    .badge {
      padding: 2px 10px;
      border-radius: var(--pp-radius-pill);
      background: var(--pp-brand);
      color: var(--mat-sys-on-primary);
      font-size: 0.72rem;
      font-weight: 600;
    }
    p {
      margin: 0;
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.9rem;
      overflow-wrap: anywhere;
    }
    .actions {
      display: flex;
      flex: none;
      margin: calc(var(--pp-space-xs, 4px) * -1);
    }
    .delete {
      color: var(--mat-sys-error);
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AddressCard {
  readonly address = input.required<AddressDto>();
  readonly primary = input(false);
  readonly editable = input(false);
  readonly edit = output();
  readonly remove = output();

  protected readonly title = computed(
    () => this.address().label?.trim() || this.address().addressLine1?.trim() || 'Address',
  );
  protected readonly lines = computed(() => {
    const { addressLine1, addressLine2, city, state, postalCode, country } = this.address();
    const place = [city, state, postalCode].filter((part) => part?.trim()).join(', ');
    return [addressLine1, addressLine2, place, country].filter(
      (line): line is string => !!line?.trim(),
    );
  });
}
