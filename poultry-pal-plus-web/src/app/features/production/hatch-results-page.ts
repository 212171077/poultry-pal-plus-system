import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { DateField } from '../../shared/ui/date-field/date-field';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { HatchingReport, ProductionApi } from './production-api';
import { describeError } from './production-settings-page';

export function formatRate(rate: number | null): string {
  return rate === null ? 'n/a' : `${rate.toFixed(1)}%`;
}

@Component({
  selector: 'app-hatch-results-page',
  imports: [PageHeader, EmptyState, DateField, MatButtonModule],
  templateUrl: './hatch-results-page.html',
  styleUrl: './hatch-results-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class HatchResultsPage {
  private readonly api = inject(ProductionApi);
  protected readonly connectivity = inject(ConnectivityService);
  protected readonly report = signal<HatchingReport | null>(null);
  protected readonly error = signal<string | null>(null);
  protected readonly format = formatRate;
  protected readonly from = signal('');
  protected readonly to = signal('');

  constructor() {
    void this.load();
  }

  protected apply(): Promise<void> {
    return this.load();
  }

  protected async download(): Promise<void> {
    this.error.set(null);
    try {
      const blob = await this.api.hatchingCsv(this.filter());
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'hatching-report.csv';
      link.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      this.error.set(describeError(error, 'Could not download the report.'));
    }
  }

  private async load(): Promise<void> {
    this.error.set(null);
    try {
      this.report.set(await this.api.hatchingReport(this.filter()));
    } catch (error) {
      this.error.set(describeError(error, 'Could not load the hatching report.'));
    }
  }

  private filter(): { from?: string; to?: string } {
    return { from: this.from() || undefined, to: this.to() || undefined };
  }
}
