import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { format, isSameDay, subDays } from 'date-fns';
import { filter } from 'rxjs';
import { liveSignal } from '../../data/db/live-signal';
import { LocalEggRecord } from '../../data/models/local';
import { EggRecordRepository } from '../../data/repositories/repositories';
import { RecordListPage } from '../../shared/records/record-page';
import { CoopFilter } from '../../shared/ui/coop-filter/coop-filter';
import { KpiCard } from '../../shared/ui/kpi-card/kpi-card';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { SyncChip } from '../../shared/ui/sync-chip/sync-chip';
import { EggFormData, EggFormDialog } from './egg-form-dialog/egg-form-dialog';

interface EggRow {
  readonly record: LocalEggRecord;
  readonly title: string;
  readonly meta: string;
  readonly detail: string;
}

@Component({
  selector: 'app-eggs-page',
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
  templateUrl: './eggs-page.html',
  styleUrl: '../../shared/records/record-list.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class EggsPage extends RecordListPage<LocalEggRecord> {
  private readonly repo = inject(EggRecordRepository);
  private readonly allRecords = liveSignal(() => this.repo.listRecent());
  protected readonly coopId = signal<string | null>(null);
  private readonly records = computed(() => {
    const coopId = this.coopId();
    const all = this.allRecords();
    return coopId && all ? all.filter((record) => record.coopId === coopId) : all;
  });
  protected readonly layerCoops = computed(() =>
    this.coops().filter((coop) => coop.coopType === 'LAYERS'),
  );

  protected readonly loading = computed(() => this.allRecords() === undefined);
  protected readonly hasRecords = computed(() => (this.allRecords()?.length ?? 0) > 0);
  protected readonly hasLayers = computed(() => this.coops().some((c) => c.coopType === 'LAYERS'));

  protected readonly rows = computed<EggRow[]>(() => {
    const names = new Map(this.coops().map((coop) => [coop.id, coop.coopName]));
    return (this.records() ?? []).map((record) => ({
      record,
      title: `${(record.totalEggs ?? 0).toLocaleString()} eggs`,
      meta: `${names.get(record.coopId) ?? 'Unknown coop'} · ${format(new Date(record.createdDate), 'd MMM yyyy')}`,
      detail: `${record.numberOfBoxes} × ${record.boxSize}`,
    }));
  });

  protected readonly summary = computed(() => {
    const records = this.records() ?? [];
    const now = new Date();
    const weekAgo = subDays(now, 7).getTime();
    const sum = (list: readonly LocalEggRecord[]) =>
      list.reduce((total, record) => total + (record.totalEggs ?? 0), 0);
    return {
      today: sum(records.filter((r) => isSameDay(new Date(r.createdDate), now))).toLocaleString(),
      week: sum(
        records.filter((r) => new Date(r.createdDate).getTime() >= weekAgo),
      ).toLocaleString(),
      boxes: records
        .filter((r) => new Date(r.createdDate).getTime() >= weekAgo)
        .reduce((total, r) => total + r.numberOfBoxes, 0)
        .toLocaleString(),
    };
  });

  protected async openForm(record?: LocalEggRecord, coopId?: string | null): Promise<void> {
    const context = await this.formContext(coopId, {
      filter: (coop) => coop.coopType === 'LAYERS',
      emptyMessage: 'Egg packaging is recorded for layer coops. None of your coops are layers.',
    });
    if (!context) return;
    this.dialog
      .open<EggFormDialog, EggFormData, LocalEggRecord>(EggFormDialog, {
        data: { ...context, record },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .pipe(filter(Boolean))
      .subscribe(() =>
        this.saved(record ? 'Record updated' : 'Eggs saved. They will sync automatically.'),
      );
  }

  protected remove(record: LocalEggRecord): void {
    this.confirmDelete(
      'Delete egg record?',
      `${record.numberOfBoxes} × ${record.boxSize} on ${format(new Date(record.createdDate), 'd MMM yyyy')} will be removed from all devices.`,
      () => this.repo.remove(record.id),
      'Record deleted',
    );
  }
}
