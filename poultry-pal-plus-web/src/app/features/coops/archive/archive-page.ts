import { DatePipe } from '@angular/common';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { RouterLink } from '@angular/router';
import { ApiError } from '../../../core/http/api-error';
import { ConnectivityService } from '../../../core/network/connectivity.service';
import { FarmContextRepository } from '../../../data/repositories/repositories';
import { formatMoney } from '../../../shared/format/money';
import { EmptyState } from '../../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../../shared/ui/page-header/page-header';
import { ArchiveApi, ArchivedBatch, batchMortalityRate, batchProfit } from './archive-api';

@Component({
  selector: 'app-archive-page',
  imports: [
    DatePipe,
    PageHeader,
    EmptyState,
    MatButtonModule,
    MatIconModule,
    MatProgressBarModule,
    RouterLink,
  ],
  templateUrl: './archive-page.html',
  styleUrl: './archive-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ArchivePage {
  private readonly api = inject(ArchiveApi);
  private readonly context = inject(FarmContextRepository);
  protected readonly connectivity = inject(ConnectivityService);

  protected readonly batches = signal<readonly ArchivedBatch[] | null>(null);
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);
  private currency: string | null | undefined;

  constructor() {
    void this.load();
  }

  protected async load(): Promise<void> {
    if (!this.connectivity.online()) {
      this.error.set('Archived batches are only available while you are online.');
      return;
    }
    this.loading.set(true);
    this.error.set(null);
    try {
      this.currency = (await this.context.settings())?.currency;
      this.batches.set(await this.api.archivedBatches());
    } catch (error) {
      this.error.set(
        error instanceof ApiError ? error.message : 'Could not load archived batches.',
      );
    } finally {
      this.loading.set(false);
    }
  }

  protected money(amount: number): string {
    return formatMoney(amount, this.currency);
  }

  protected profit(batch: ArchivedBatch): number {
    return batchProfit(batch);
  }

  protected mortality(batch: ArchivedBatch): string {
    return batchMortalityRate(batch).toFixed(1);
  }
}
