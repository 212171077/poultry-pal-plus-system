import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { format, subDays } from 'date-fns';
import { filter } from 'rxjs';
import { liveSignal } from '../../data/db/live-signal';
import { LocalMortality } from '../../data/models/local';
import { MortalityRepository } from '../../data/repositories/repositories';
import { RecordListPage } from '../../shared/records/record-page';
import { CoopFilter } from '../../shared/ui/coop-filter/coop-filter';
import { KpiCard } from '../../shared/ui/kpi-card/kpi-card';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { SyncChip } from '../../shared/ui/sync-chip/sync-chip';
import {
  MortalityFormData,
  MortalityFormDialog,
} from './mortality-form-dialog/mortality-form-dialog';

interface MortalityRow {
  readonly record: LocalMortality;
  readonly title: string;
  readonly meta: string;
}

@Component({
  selector: 'app-mortality-page',
  imports: [
    PageHeader,
    EmptyState,
    SyncChip,
    CoopFilter,
    KpiCard,
    MatButtonModule,
    MatIconModule,
    MatMenuModule,
  ],
  templateUrl: './mortality-page.html',
  styleUrl: '../../shared/records/record-list.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class MortalityPage extends RecordListPage<LocalMortality> {
  private readonly repo = inject(MortalityRepository);
  private readonly allRecords = liveSignal(() => this.repo.listRecent());
  protected readonly coopId = signal<string | null>(null);
  private readonly records = computed(() => {
    const coopId = this.coopId();
    const all = this.allRecords();
    return coopId && all ? all.filter((record) => record.coopId === coopId) : all;
  });

  protected readonly loading = computed(() => this.allRecords() === undefined);
  protected readonly hasRecords = computed(() => (this.allRecords()?.length ?? 0) > 0);

  protected readonly rows = computed<MortalityRow[]>(() => {
    const names = new Map(this.coops().map((coop) => [coop.id, coop.coopName]));
    return (this.records() ?? []).map((record) => ({
      record,
      title: `${record.numberOfDeaths} ${record.numberOfDeaths === 1 ? 'bird' : 'birds'} lost`,
      meta: [
        names.get(record.coopId) ?? 'Unknown coop',
        format(new Date(record.dateOccurred), 'd MMM yyyy'),
        record.recordedBy,
      ]
        .filter(Boolean)
        .join(' · '),
    }));
  });

  protected readonly summary = computed(() => {
    const records = this.records() ?? [];
    const weekAgo = subDays(new Date(), 7).getTime();
    const month = format(new Date(), 'yyyy-MM');
    const sum = (list: readonly LocalMortality[]) =>
      list.reduce((total, record) => total + record.numberOfDeaths, 0);
    const counts = new Map<string, number>();
    records.forEach((r) => counts.set(r.reason, (counts.get(r.reason) ?? 0) + r.numberOfDeaths));
    const top = [...counts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? '—';
    return {
      week: sum(records.filter((r) => new Date(r.dateOccurred).getTime() >= weekAgo)),
      month: sum(records.filter((r) => format(new Date(r.dateOccurred), 'yyyy-MM') === month)),
      topReason: top,
    };
  });

  protected async openForm(mortality?: LocalMortality, coopId?: string | null): Promise<void> {
    const context = await this.formContext(coopId);
    if (!context) return;
    this.dialog
      .open<MortalityFormDialog, MortalityFormData, LocalMortality>(MortalityFormDialog, {
        data: { ...context, mortality },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .pipe(filter(Boolean))
      .subscribe(() =>
        this.saved(mortality ? 'Record updated' : 'Mortality saved. It will sync automatically.'),
      );
  }

  protected remove(record: LocalMortality): void {
    this.confirmDelete(
      'Delete mortality record?',
      `${record.numberOfDeaths} ${record.reason} on ${format(new Date(record.dateOccurred), 'd MMM yyyy')} will be removed from all devices.`,
      () => this.repo.remove(record.id),
      'Record deleted',
    );
  }
}
