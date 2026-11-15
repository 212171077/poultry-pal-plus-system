import { ChangeDetectionStrategy, Component, input, model } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { RANGE_OPTIONS, RangeKey } from '../../../features/analytics/farm-metrics';

/** Date-range picker shared by the dashboard and reports. */
@Component({
  selector: 'app-range-filter',
  imports: [MatButtonToggleModule, MatIconModule],
  template: `
    <mat-button-toggle-group
      hideSingleSelectionIndicator
      [value]="value()"
      (change)="value.set($event.value)"
      [attr.aria-label]="label()"
    >
      @for (option of options; track option.key) {
        <mat-button-toggle [value]="option.key">
          <span class="option">
            <mat-icon aria-hidden="true">{{ option.icon }}</mat-icon>
            <span class="text">{{ option.label }}</span>
          </span>
        </mat-button-toggle>
      }
    </mat-button-toggle-group>
  `,
  styles: `
    :host {
      display: block;
      max-width: 100%;
      overflow-x: auto;
    }
    mat-button-toggle-group {
      display: flex;
      width: 100%;
    }
    mat-button-toggle {
      flex: 1 1 0;
      min-width: 0;
      min-height: 48px;
    }
    .option {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 2px;
      padding: 4px 2px;
      line-height: 1;
    }
    .option mat-icon {
      width: 20px;
      height: 20px;
      font-size: 20px;
    }
    .text {
      font-size: 0.7rem;
      white-space: nowrap;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RangeFilter {
  readonly value = model.required<RangeKey>();
  readonly label = input('Date range');
  protected readonly options = RANGE_OPTIONS;
}
