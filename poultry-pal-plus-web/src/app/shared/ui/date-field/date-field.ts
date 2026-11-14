import { ChangeDetectionStrategy, Component, computed, input, model } from '@angular/core';
import { provideNativeDateAdapter } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

/** Parses an ISO `YYYY-MM-DD` string as a local date; null when empty or invalid. */
export function parseIsoDate(iso: string | null | undefined): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso ?? '');
  if (!match) return null;
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

export function toIsoDate(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

/** Calendar date picker bound to an ISO `YYYY-MM-DD` string. */
@Component({
  selector: 'app-date-field',
  imports: [MatFormFieldModule, MatInputModule, MatDatepickerModule],
  providers: [provideNativeDateAdapter()],
  template: `
    <mat-form-field class="field">
      <mat-label>{{ label() }}</mat-label>
      <input
        matInput
        [matDatepicker]="picker"
        [min]="minDate()"
        [max]="maxDate()"
        [value]="date()"
        [required]="required()"
        (dateChange)="onChange($event.value)"
      />
      <mat-datepicker-toggle matIconSuffix [for]="picker" />
      <mat-datepicker #picker />
      @if (hint()) {
        <mat-hint>{{ hint() }}</mat-hint>
      }
    </mat-form-field>
  `,
  styles: `
    :host {
      display: block;
    }
    .field {
      width: 100%;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DateField {
  readonly label = input.required<string>();
  readonly hint = input<string>();
  readonly min = input<string>();
  readonly max = input<string>();
  readonly required = input(false);
  readonly value = model<string>('');

  protected readonly date = computed(() => parseIsoDate(this.value()));
  protected readonly minDate = computed(() => parseIsoDate(this.min()));
  protected readonly maxDate = computed(() => parseIsoDate(this.max()));

  protected onChange(date: Date | null): void {
    this.value.set(date ? toIsoDate(date) : '');
  }
}
