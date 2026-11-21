import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { Toast } from '../../shared/ui/toast/toast.service';
import { format } from 'date-fns';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ApiError } from '../../core/http/api-error';
import { APP_DB } from '../../data/db/app-db';
import { liveSignal } from '../../data/db/live-signal';
import { FarmContextRepository } from '../../data/repositories/repositories';
import {
  downloadBlob,
  downloadCsv,
  downloadExcel,
  fileSafe,
} from '../../shared/export/table-export';
import { formatMoney } from '../../shared/format/money';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { KpiCard } from '../../shared/ui/kpi-card/kpi-card';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { RangeFilter } from '../../shared/ui/range-filter/range-filter';
import {
  FarmData,
  RangeKey,
  loadFarmData,
  rangeFor,
  rangeLabel,
  summarize,
  summarizeByCoop,
} from '../analytics/farm-metrics';
import { ReportQueue } from './report-queue';
import { ReportsApi } from './reports-api';
import { reportTables } from './report-tables';

const EMPTY: FarmData = { coops: [], sales: [], mortalities: [], expenses: [], eggRecords: [] };

@Component({
  selector: 'app-reports-page',
  imports: [
    PageHeader,
    EmptyState,
    KpiCard,
    RangeFilter,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatSelectModule,
  ],
  templateUrl: './reports-page.html',
  styleUrl: './reports-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ReportsPage {
  private readonly db = inject(APP_DB);
  private readonly context = inject(FarmContextRepository);
  private readonly api = inject(ReportsApi);
  private readonly queue = inject(ReportQueue);
  private readonly snackBar = inject(Toast);
  protected readonly connectivity = inject(ConnectivityService);

  private readonly now = new Date();
  protected readonly rangeKey = signal<RangeKey>('all');
  protected readonly scheduleCoopId = signal<string | null>(null);
  protected readonly busy = signal(false);

  private readonly data = liveSignal(async () => {
    const [farmData, farm, user, settings] = await Promise.all([
      loadFarmData(this.db),
      this.context.farm(),
      this.context.currentUser(),
      this.context.settings(),
    ]);
    return { farmData, farm, user, currency: settings?.currency };
  });
  protected readonly pending = this.queue.watchPending();

  protected readonly loading = computed(() => this.data() === undefined);
  private readonly farmData = computed(() => this.data()?.farmData ?? EMPTY);
  protected readonly coopOptions = computed(() =>
    [...this.farmData().coops].sort((a, b) => a.coopName.localeCompare(b.coopName)),
  );
  protected readonly selectedCoop = computed(
    () => this.scheduleCoopId() ?? this.coopOptions()[0]?.id ?? null,
  );

  protected readonly range = computed(() => rangeFor(this.rangeKey(), this.now, this.farmData()));
  protected readonly period = computed(() => rangeLabel(this.range()));
  protected readonly summary = computed(() => summarize(this.farmData(), this.range()));
  protected readonly coops = computed(() => summarizeByCoop(this.farmData(), this.range()));

  protected readonly rows = computed(() => {
    const currency = this.data()?.currency;
    const money = (value: number) => formatMoney(value, currency);
    return this.coops().map((coop) => ({
      ...coop,
      salesText: money(coop.sales),
      expensesText: money(coop.expenses),
      profitText: money(coop.profit),
      lossMaking: coop.profit < 0,
      rateText: `${coop.mortalityRate.toFixed(1)}%`,
    }));
  });

  protected readonly totals = computed(() => {
    const currency = this.data()?.currency;
    const summary = this.summary();
    return {
      sales: formatMoney(summary.sales, currency),
      expenses: formatMoney(summary.expenses, currency),
      profit: formatMoney(summary.profit, currency),
      eggs: summary.eggs.toLocaleString(),
      deaths: summary.deaths.toLocaleString(),
      lossMaking: summary.profit < 0,
    };
  });

  private filename(): string {
    const farmName = fileSafe(this.data()?.farm?.farmName ?? 'farm');
    return `${farmName}-report-${format(this.range().from, 'yyyyMMdd')}-${format(this.range().to, 'yyyyMMdd')}`;
  }

  protected exportCsv(): void {
    const [summary] = reportTables(this.farmData(), this.coops(), this.range());
    downloadCsv(summary, this.filename());
  }

  protected exportExcel(): void {
    downloadExcel(reportTables(this.farmData(), this.coops(), this.range()), this.filename());
  }

  protected async downloadPdf(kind: 'report' | 'schedule'): Promise<void> {
    const { farm, user } = this.data() ?? {};
    const coopId = this.selectedCoop();
    if (!farm || !user || (kind === 'schedule' && !coopId)) return;
    this.busy.set(true);
    try {
      const blob =
        kind === 'report'
          ? await this.api.downloadReport(farm.id, user.id)
          : await this.api.downloadSchedule(farm.id, coopId!, user.id);
      const base = fileSafe(farm.farmName);
      downloadBlob(
        new Blob([blob], { type: 'application/pdf' }),
        kind === 'report' ? `${base}-report.pdf` : `${base}-schedule.pdf`,
      );
    } catch (error) {
      this.snackBar.open(
        error instanceof ApiError ? error.message : 'Could not download the PDF.',
        'OK',
        { duration: 5000 },
      );
    } finally {
      this.busy.set(false);
    }
  }

  protected async email(kind: 'report' | 'schedule'): Promise<void> {
    const coopId = kind === 'schedule' ? this.selectedCoop() : null;
    if (kind === 'schedule' && !coopId) return;
    const coopName = this.coopOptions().find((coop) => coop.id === coopId)?.coopName;
    await this.queue.enqueue({
      kind: kind === 'report' ? 'REPORT' : 'SCHEDULE',
      coopId,
      label: kind === 'report' ? 'Farm report' : `Schedule · ${coopName ?? 'coop'}`,
    });
    if (!this.connectivity.online()) {
      this.snackBar.open('Saved. It will be emailed when you are back online.', 'OK', {
        duration: 5000,
      });
      return;
    }
    this.busy.set(true);
    try {
      const sent = await this.queue.flush();
      this.snackBar.open(
        sent > 0 ? 'Email sent to your address.' : 'Saved. It will be emailed shortly.',
        'OK',
        { duration: 4000 },
      );
    } finally {
      this.busy.set(false);
    }
  }

  protected discard(id: string): void {
    void this.queue.discard(id);
  }

  protected retry(id: string): void {
    void this.queue.retry(id).then(() => this.queue.flush());
  }
}
