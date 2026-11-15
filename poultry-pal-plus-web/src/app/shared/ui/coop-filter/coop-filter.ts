import { ChangeDetectionStrategy, Component, input, model } from '@angular/core';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';

export interface CoopOption {
  readonly id: string;
  readonly coopName: string;
}

/** "All coops" or one coop; hidden when there is only one coop to choose from. */
@Component({
  selector: 'app-coop-filter',
  imports: [MatFormFieldModule, MatSelectModule],
  template: `
    @if (coops().length > 1) {
      <mat-form-field subscriptSizing="dynamic">
        <mat-label>Coop</mat-label>
        <mat-select [value]="value()" (selectionChange)="value.set($event.value)">
          <mat-option [value]="null">All coops</mat-option>
          @for (coop of coops(); track coop.id) {
            <mat-option [value]="coop.id">{{ coop.coopName }}</mat-option>
          }
        </mat-select>
      </mat-form-field>
    }
  `,
  styles: `
    :host {
      display: block;
      margin-bottom: var(--pp-space-md);
    }

    mat-form-field {
      width: min(100%, 280px);
    }

    @media (max-width: 599.98px) {
      mat-form-field {
        width: 100%;
      }
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CoopFilter {
  readonly coops = input.required<readonly CoopOption[]>();
  readonly value = model<string | null>(null);
}
