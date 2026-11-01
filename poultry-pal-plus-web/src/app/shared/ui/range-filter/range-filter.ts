import { ChangeDetectionStrategy, Component, input, model } from '@angular/core';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { RANGE_OPTIONS, RangeKey } from '../../../features/analytics/farm-metrics';

/** Date-range picker shared by the dashboard and reports. */
@Component({
  selector: 'app-range-filter',
  imports: [MatButtonToggleModule],
  template: `
    <mat-button-toggle-group
      hideSingleSelectionIndicator
      [value]="value()"
      (change)="value.set($event.value)"
      [attr.aria-label]="label()"
    >
      @for (option of options; track option.key) {
        <mat-button-toggle [value]="option.key">{{ option.label }}</mat-button-toggle>
      }
    </mat-button-toggle-group>
  `,
  styles: `
    :host {
      display: block;
      max-width: 100%;
      overflow-x: auto;
    }
    mat-button-toggle {
      min-height: 48px;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RangeFilter {
  readonly value = model.required<RangeKey>();
  readonly label = input('Date range');
  protected readonly options = RANGE_OPTIONS;
}
