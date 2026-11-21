import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  signal,
} from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';
import { format } from 'date-fns';
import { AuthService } from '../../core/auth/auth.service';
import { APP_DB } from '../../data/db/app-db';
import { liveSignal } from '../../data/db/live-signal';
import { FarmContextRepository } from '../../data/repositories/repositories';
import { injectQuickActions } from '../../layout/quick-actions';
import { formatMoney } from '../../shared/format/money';
import { ChartMarker, LineChart } from '../../shared/ui/line-chart/line-chart';
import { BarChart, ChartSeries } from '../../shared/ui/bar-chart/bar-chart';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { CoopSummaryCard } from '../../shared/ui/coop-summary-card/coop-summary-card';
import { KpiCard, KpiTone } from '../../shared/ui/kpi-card/kpi-card';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { RangeFilter } from '../../shared/ui/range-filter/range-filter';
import {
  FarmData,
  RangeKey,
  loadFarmData,
  rangeFor,
  rangeSummaryLabel,
  summarize,
  summarizeByCoop,
} from '../analytics/farm-metrics';
import { EmailLogPanel } from './email-log-panel';
import { ReminderNotifications } from '../reminders/reminder-notifications';
import { groupReminders } from '../reminders/reminder-groups';
import { NORMAL_RATE, PEAK_RATE, eggProduction } from './egg-production';
import { recentActivity } from './activity';
import { greetingFor } from './greeting';

interface DashboardKpi {
  readonly label: string;
  readonly icon: string;
  readonly tone: KpiTone;
  readonly value: string | null;
  readonly hint: string;
}

const EMPTY: FarmData = { coops: [], sales: [], mortalities: [], expenses: [], eggRecords: [] };

@Component({
  selector: 'app-dashboard-page',
  imports: [
    PageHeader,
    KpiCard,
    CoopSummaryCard,
    EmptyState,
    BarChart,
    LineChart,
    RangeFilter,
    EmailLogPanel,
    MatButtonModule,
    MatIconModule,
    RouterLink,
    DecimalPipe,
  ],
  templateUrl: './dashboard-page.html',
  styleUrl: './dashboard-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class DashboardPage {
  private readonly now = new Date();

  private readonly auth = inject(AuthService);
  protected readonly isAdmin = computed(() => this.auth.can('SYSTEM_ADMIN'));
  protected readonly greeting = computed(() => {
    const firstName = this.auth.user()?.name?.trim();
    const greeting = greetingFor(this.now.getHours());
    return firstName ? `${greeting}, ${firstName}` : greeting;
  });
  protected readonly today = format(this.now, 'EEEE, d MMMM yyyy');
  protected readonly quickActions = injectQuickActions();

  private readonly db = inject(APP_DB);
  private readonly context = inject(FarmContextRepository);
  private readonly notifications = inject(ReminderNotifications);

  protected readonly rangeKey = signal<RangeKey>('all');

  /** All figures come from IndexedDB, so the dashboard works without a network connection. */
  private readonly data = liveSignal(async () => {
    const [farm, reminders, settings] = await Promise.all([
      loadFarmData(this.db),
      this.db.reminders.toArray(),
      this.context.settings(),
    ]);
    return { farm, reminders, names: new Map(farm.coops.map((c) => [c.id, c.coopName])), settings };
  });

  protected readonly loading = computed(() => this.data() === undefined);
  private readonly range = computed(() =>
    rangeFor(this.rangeKey(), this.now, this.data()?.farm ?? EMPTY),
  );
  private readonly summary = computed(() => summarize(this.data()?.farm ?? EMPTY, this.range()));
  protected readonly summaryLabel = computed(() => rangeSummaryLabel(this.rangeKey()));
  protected readonly currency = computed(() => this.data()?.settings?.currency);

  /** Coops that hold (or held) birds, with figures for the selected period. */
  protected readonly coopCards = computed(() =>
    summarizeByCoop(this.data()?.farm ?? EMPTY, this.range()).filter((coop) => coop.totalBirds > 0),
  );

  protected readonly eggs = computed(() => {
    const production = eggProduction(this.data()?.farm ?? EMPTY, this.range(), this.now);
    if (!production) return null;
    const verdicts = {
      peak: { text: 'At peak production', icon: 'trending_up', tone: 'success' },
      normal: { text: 'Normal production', icon: 'check_circle', tone: 'info' },
      below: { text: 'Below average production', icon: 'trending_down', tone: 'error' },
    } as const;
    return { ...production, verdict: production.level ? verdicts[production.level] : null };
  });
  protected readonly eggMarkers = computed<readonly ChartMarker[]>(() => {
    const hens = this.eggs()?.hens ?? 0;
    return [
      {
        value: Math.round((hens * PEAK_RATE) / 100),
        label: 'Peak level',
        color: 'var(--pp-success)',
      },
      {
        value: Math.round((hens * NORMAL_RATE) / 100),
        label: 'Normal level',
        color: 'var(--pp-warning)',
      },
    ];
  });
  protected readonly kpis = computed<readonly DashboardKpi[]>(() => {
    const ready = !this.loading();
    const summary = this.summary();
    const count = (value: number) => (ready ? value.toLocaleString() : null);
    const money = (value: number) => (ready ? formatMoney(value, this.currency()) : null);
    return [
      {
        label: 'Live birds',
        icon: 'flutter_dash',
        tone: 'brand',
        value: count(summary.liveBirds),
        hint: 'Across all coops',
      },
      {
        label: 'Eggs packaged',
        icon: 'egg',
        tone: 'accent',
        value: count(summary.eggs),
        hint: 'In the selected period',
      },
      {
        label: 'Sales',
        icon: 'payments',
        tone: 'success',
        value: money(summary.sales),
        hint: `${money(summary.unpaidSales) ?? ''} unpaid`,
      },
      {
        label: 'Expenses',
        icon: 'receipt_long',
        tone: 'warning',
        value: money(summary.expenses),
        hint: 'In the selected period',
      },
      {
        label: 'Profit',
        icon: 'account_balance',
        tone: summary.profit < 0 ? 'error' : 'info',
        value: money(summary.profit),
        hint: 'Sales minus expenses',
      },
      {
        label: 'Losses',
        icon: 'monitor_heart',
        tone: 'error',
        value: count(summary.deaths),
        hint: 'Mortality records',
      },
    ];
  });

  protected readonly chartLabels = computed(() => this.summary().series.map((p) => p.label));
  protected readonly moneySeries = computed<readonly ChartSeries[]>(() => [
    {
      name: 'Sales',
      color: 'var(--pp-success)',
      values: this.summary().series.map((p) => p.sales),
    },
    {
      name: 'Expenses',
      color: 'var(--pp-warning)',
      values: this.summary().series.map((p) => p.expenses),
    },
  ]);
  protected readonly lossSeries = computed<readonly ChartSeries[]>(() => [
    {
      name: 'Losses',
      color: 'var(--pp-error)',
      values: this.summary().series.map((p) => p.deaths),
    },
  ]);
  protected readonly hasActivityInRange = computed(() =>
    this.summary().series.some((p) => p.sales || p.expenses || p.deaths || p.eggs),
  );

  private readonly groups = computed(() => groupReminders(this.data()?.reminders ?? [], this.now));
  protected readonly dueReminders = computed(() => {
    const names = this.data()?.names ?? new Map<string, string>();
    const { overdue, today } = this.groups();
    return [
      ...overdue.map((reminder) => ({ reminder, overdue: true })),
      ...today.map((reminder) => ({ reminder, overdue: false })),
    ]
      .slice(0, 5)
      .map((entry) => ({ ...entry, coopName: names.get(entry.reminder.coopId) ?? 'Unknown coop' }));
  });
  protected readonly dueCount = computed(
    () => this.groups().overdue.length + this.groups().today.length,
  );

  protected readonly activity = computed(() => {
    const names = this.data()?.names ?? new Map<string, string>();
    return recentActivity(this.data()?.farm ?? EMPTY).map((item) => ({
      ...item,
      coopName: names.get(item.coopId) ?? 'Unknown coop',
      when: format(new Date(item.date), 'd MMM yyyy'),
    }));
  });

  constructor() {
    effect(() => {
      if (!this.loading()) this.notifications.notifyDue(this.dueCount());
    });
  }
}
