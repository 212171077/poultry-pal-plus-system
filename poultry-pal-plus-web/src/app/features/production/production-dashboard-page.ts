import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { ProductionRepository } from '../../data/repositories/production-repository';
import { DateField } from '../../shared/ui/date-field/date-field';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { OfflineDataNote } from '../../shared/ui/offline-data-note/offline-data-note';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { KpiCard, KpiTone } from '../../shared/ui/kpi-card/kpi-card';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { DashboardInput, TimelineKind, buildTimeline, buildTotals } from './production-dashboard';
import { describeError } from './production-settings-page';

const KIND_LABELS: Record<TimelineKind, string> = {
  TRANSFER: 'Transfers',
  HATCH: 'Hatch dates',
  PLACEMENT: 'Placements',
  TASK: 'Tasks',
  SALE_READY: 'Sale-ready',
};

interface Card {
  readonly label: string;
  readonly value: string | number;
  readonly icon: string;
  readonly tone: KpiTone;
  readonly note?: string;
}

@Component({
  selector: 'app-production-dashboard-page',
  imports: [
    PageHeader,
    EmptyState,
    OfflineDataNote,
    DateField,
    DatePipe,
    KpiCard,
    MatFormFieldModule,
    MatSelectModule,
  ],
  templateUrl: './production-dashboard-page.html',
  styleUrl: './production-dashboard-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ProductionDashboardPage {
  protected readonly repo = inject(ProductionRepository);
  protected readonly data = signal<DashboardInput | null>(null);
  protected readonly error = signal<string | null>(null);
  protected readonly kinds = Object.entries(KIND_LABELS) as [TimelineKind, string][];
  protected readonly kind = signal<TimelineKind | ''>('');
  protected readonly from = signal('');
  protected readonly to = signal('');
  protected readonly equipmentId = signal('');
  protected readonly equipment = signal<readonly { id: string; name: string }[]>([]);

  protected readonly totals = computed(() => {
    const d = this.data();
    return d ? buildTotals(d) : null;
  });

  protected readonly usedPercent = computed(() => {
    const t = this.totals();
    return t && t.houseCapacity > 0
      ? Math.min(100, Math.round((t.birdsInHouses / t.houseCapacity) * 100))
      : 0;
  });

  protected readonly cards = computed<readonly Card[]>(() => {
    const t = this.totals();
    if (!t) return [];
    return [
      { label: 'Active batches', value: t.activeBatches, icon: 'egg_alt', tone: 'brand' },
      {
        label: 'Eggs incubating',
        value: t.eggsIncubating,
        icon: 'device_thermostat',
        tone: 'brand',
      },
      { label: 'Eggs in hatcher', value: t.eggsInHatcher, icon: 'egg', tone: 'info' },
      {
        label: 'Eggs not yet assigned',
        value: t.eggsUnassigned,
        icon: 'inventory_2',
        tone: 'accent',
      },
      {
        label: 'Birds in houses',
        value: `${t.birdsInHouses} / ${t.houseCapacity}`,
        icon: 'home',
        tone: 'info',
      },
      { label: 'Mortality', value: t.mortality, icon: 'heart_broken', tone: 'error' },
      { label: 'Sold', value: t.sold, icon: 'payments', tone: 'accent' },
      {
        label: 'Open tasks',
        value: t.openTasks,
        icon: 'checklist',
        tone: t.overdueTasks ? 'error' : 'brand',
        note: t.overdueTasks ? `${t.overdueTasks} overdue` : undefined,
      },
      { label: 'Plans to review', value: t.plansNeedingReview, icon: 'event_note', tone: 'accent' },
    ];
  });

  protected readonly events = computed(() => {
    const d = this.data();
    if (!d) return [];
    const [kind, from, to, equipment] = [this.kind(), this.from(), this.to(), this.equipmentId()];
    return buildTimeline(d).filter(
      (e) =>
        (!kind || e.kind === kind) &&
        (!from || e.date >= from) &&
        (!to || e.date <= to) &&
        (!equipment || e.equipmentId === equipment),
    );
  });

  constructor() {
    void this.load();
  }

  protected label(kind: TimelineKind): string {
    return KIND_LABELS[kind];
  }

  private async load(): Promise<void> {
    try {
      const [batches, reminders, placements, occupancy, plans, equipment] = await Promise.all([
        this.repo.batches(),
        this.repo.reminders(),
        this.repo.placements(),
        this.repo.occupancy(),
        this.repo.plans(),
        this.repo.equipment(),
      ]);
      this.data.set({ batches, reminders, placements, occupancy, plans });
      this.equipment.set(equipment.map((e) => ({ id: e.id, name: e.name })));
    } catch (error) {
      this.error.set(describeError(error, 'Could not load the production dashboard.'));
    }
  }
}
