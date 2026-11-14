import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { DateField } from '../../shared/ui/date-field/date-field';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { ProductionApi, ScheduleOptions } from './production-api';
import { describeError } from './production-settings-page';

export function addDaysIso(iso: string, days: number): string {
  const [y, m, d] = iso.split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d + days));
  return date.toISOString().slice(0, 10);
}

export function todayIso(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

@Component({
  selector: 'app-schedule-page',
  imports: [PageHeader, DateField, MatButtonModule, MatFormFieldModule, MatInputModule],
  templateUrl: './schedule-page.html',
  styleUrl: './schedule-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class SchedulePage {
  private readonly api = inject(ProductionApi);
  protected readonly connectivity = inject(ConnectivityService);
  protected readonly options = signal<ScheduleOptions | null>(null);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);
  protected readonly today = todayIso();
  protected readonly from = signal(this.today);
  protected readonly to = signal(addDaysIso(this.today, 30));

  protected async search(eggs: string): Promise<void> {
    const count = Number(eggs);
    if (!Number.isInteger(count) || count < 1 || !this.from() || !this.to()) {
      this.error.set('Enter the number of eggs and a start date range.');
      return;
    }
    this.error.set(null);
    this.busy.set(true);
    try {
      this.options.set(
        await this.api.searchSchedule({
          eggs: count,
          earliestStart: this.from(),
          latestStart: this.to(),
        }),
      );
    } catch (error) {
      this.error.set(describeError(error, 'Could not calculate start dates.'));
    } finally {
      this.busy.set(false);
    }
  }
}
