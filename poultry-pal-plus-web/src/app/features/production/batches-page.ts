import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  signal,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ProductionRepository } from '../../data/repositories/production-repository';
import { DateField } from '../../shared/ui/date-field/date-field';
import { OfflineDataNote } from '../../shared/ui/offline-data-note/offline-data-note';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import {
  BatchStatus,
  IncubationBatch,
  ProductionEquipment,
  ProductionReminder,
} from './production-api';
import { batchReference } from './batch-reference';
import { describeError } from './production-settings-page';

export const BATCH_STATUS_LABELS: Record<BatchStatus, string> = {
  PLANNED: 'Planned',
  INCUBATING: 'Incubating',
  TRANSFERRED: 'In hatcher',
  COMPLETED: 'Completed',
  CANCELLED: 'Cancelled',
};

export const CYCLE_STATUS_LABELS: Record<string, string> = {
  RESERVED: 'Reserved',
  IN_HATCHER: 'In hatcher',
  COMPLETED: 'Hatched',
  CANCELLED: 'Cancelled',
};

export function todayIso(): string {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${now.getFullYear()}-${month}-${day}`;
}

@Component({
  selector: 'app-batches-page',
  imports: [
    OfflineDataNote,
    PageHeader,
    EmptyState,
    ReactiveFormsModule,
    MatIconModule,
    DateField,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './batches-page.html',
  styleUrl: './batches-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class BatchesPage {
  protected readonly repo = inject(ProductionRepository);
  private readonly fb = inject(FormBuilder);
  private readonly snackBar = inject(MatSnackBar);
  protected readonly connectivity = inject(ConnectivityService);
  protected readonly statusLabels = BATCH_STATUS_LABELS;
  protected readonly cycleLabels = CYCLE_STATUS_LABELS;
  protected readonly today = todayIso();
  protected readonly batches = signal<readonly IncubationBatch[]>([]);
  protected readonly equipment = signal<readonly ProductionEquipment[]>([]);
  protected readonly reminders = signal<readonly ProductionReminder[]>([]);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);
  protected readonly loaded = signal(false);
  protected readonly showForm = signal(false);
  protected readonly resultDate = signal(todayIso());
  private readonly hatchedCounts = signal<Record<string, number>>({});
  protected readonly incubators = computed(() =>
    this.equipment().filter((e) => e.type === 'INCUBATOR' && e.enabled),
  );
  protected readonly hatchers = computed(() =>
    this.equipment().filter((e) => e.type === 'HATCHER' && e.enabled),
  );

  protected readonly form = this.fb.nonNullable.group({
    equipmentId: ['', Validators.required],
    eggsSet: [0, [Validators.required, Validators.min(1), Validators.max(1_000_000)]],
    plannedStartDate: [todayIso(), Validators.required],
    reference: ['', Validators.maxLength(40)],
    eggSource: ['', Validators.maxLength(100)],
  });

  constructor() {
    void this.load();
    this.form.valueChanges.subscribe(() => {
      // The control is already dirty when valueChanges fires for a keystroke in the field.
      const typed = this.form.controls.reference;
      if (typed.dirty && typed.value) return;
      const reference = batchReference(
        this.form.controls.plannedStartDate.value,
        this.form.controls.eggsSet.value,
      );
      if (reference !== this.form.controls.reference.value) {
        this.form.controls.reference.setValue(reference, { emitEvent: false });
      }
    });
    let seen = this.repo.changed();
    effect(() => {
      const now = this.repo.changed();
      if (now !== seen) {
        seen = now;
        void this.refreshBatches().catch(() => undefined);
      }
    });
  }

  protected setHatched(cycleId: string, value: string): void {
    this.hatchedCounts.update((m) => ({ ...m, [cycleId]: Number(value) || 0 }));
  }

  protected unhatchedFor(cycle: { id: string; quantity: number }): number {
    return Math.max(cycle.quantity - (this.hatchedCounts()[cycle.id] ?? 0), 0);
  }

  protected equipmentName(id: string): string {
    return this.equipment().find((e) => e.id === id)?.name ?? 'Unknown';
  }

  protected async load(): Promise<void> {
    this.error.set(null);
    try {
      const [batches, equipment, reminders] = await Promise.all([
        this.repo.batches(),
        this.repo.equipment(),
        this.repo.reminders(),
      ]);
      this.batches.set(batches);
      this.reminders.set(reminders);
      this.equipment.set(equipment);
      const first = equipment.find((e) => e.type === 'INCUBATOR' && e.enabled);
      if (first && !this.form.controls.equipmentId.value) {
        this.form.controls.equipmentId.setValue(first.id);
      }
    } catch (error) {
      this.error.set(describeError(error, 'Could not load incubation batches.'));
    } finally {
      this.loaded.set(true);
    }
  }

  protected async create(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const v = this.form.getRawValue();
    await this.run(async () => {
      const created = await this.repo.createBatch({
        equipmentId: v.equipmentId,
        eggsSet: v.eggsSet,
        plannedStartDate: v.plannedStartDate,
        reference: v.reference.trim() || undefined,
        eggSource: v.eggSource.trim() || undefined,
      });
      this.showForm.set(false);
      this.form.patchValue({ eggsSet: 0, reference: '', eggSource: '' });
      this.form.controls.reference.markAsPristine();
      await this.refreshBatches();
      if (!this.queued(created)) this.snackBar.open('Batch created.', 'OK');
    }, 'Could not create this batch.');
  }

  protected start(batch: IncubationBatch): Promise<void> {
    return this.run(async () => {
      this.replace(await this.repo.startBatch(batch.id, todayIso()));
    }, 'Could not start this batch.');
  }

  protected cancel(batch: IncubationBatch): Promise<void> {
    return this.run(async () => {
      this.replace(await this.repo.cancelBatch(batch.id));
    }, 'Could not cancel this batch.');
  }

  protected reserve(batch: IncubationBatch, hatcherId: string, quantity: string): Promise<void> {
    const value = Number(quantity);
    if (!hatcherId || !Number.isInteger(value) || value < 1) {
      this.error.set('Choose a hatcher and a whole number of eggs.');
      return Promise.resolve();
    }
    return this.run(async () => {
      this.replace(await this.repo.reserveCycle(batch.id, hatcherId, value));
    }, 'Could not reserve hatcher capacity.');
  }

  protected transfer(cycleId: string): Promise<void> {
    return this.run(async () => {
      this.replace(await this.repo.transferCycle(cycleId, todayIso()));
    }, 'Could not transfer these eggs.');
  }

  protected recordResult(
    cycleId: string,
    hatched: string,
    unhatched: string,
    weak: string,
    date: string,
  ): Promise<void> {
    const h = Number(hatched);
    const u = Number(unhatched);
    const w = weak === '' ? 0 : Number(weak);
    if (![h, u, w].every((n) => Number.isInteger(n) && n >= 0) || !date) {
      this.error.set('Enter whole numbers for the counts and a result date.');
      return Promise.resolve();
    }
    return this.run(async () => {
      const saved = await this.repo.recordResult(cycleId, {
        hatchedChicks: h,
        unhatchedEggs: u,
        weakChicks: w,
        resultDate: date,
      });
      await this.refreshBatches();
      if (!this.queued(saved)) this.snackBar.open('Hatch result saved.', 'OK');
    }, 'Could not save this hatch result.');
  }

  protected cancelCycle(cycleId: string): Promise<void> {
    return this.run(async () => {
      this.replace(await this.repo.cancelCycle(cycleId));
    }, 'Could not cancel this hatcher cycle.');
  }

  protected completeReminder(id: string): Promise<void> {
    return this.run(async () => {
      const done = await this.repo.completeReminder(id);
      if (this.queued(done)) return;
      this.reminders.update((list) => list.filter((r) => r.id !== id));
    }, 'Could not mark this task as done.');
  }

  private async refreshBatches(): Promise<void> {
    const [batches, reminders] = await Promise.all([this.repo.batches(), this.repo.reminders()]);
    this.batches.set(batches);
    this.reminders.set(reminders);
  }

  private replace(updated: IncubationBatch | null): void {
    if (this.queued(updated) || !updated) return;
    this.batches.update((list) => list.map((b) => (b.id === updated.id ? updated : b)));
    void this.repo.reminders().then(
      (r) => this.reminders.set(r),
      () => undefined,
    );
  }

  private queued(updated: unknown): boolean {
    if (updated !== null) return false;
    this.snackBar.open('Saved on this device. It will sync when you are online.', 'OK');
    return true;
  }

  private async run(action: () => Promise<void>, fallback: string): Promise<void> {
    this.busy.set(true);
    this.error.set(null);
    try {
      await action();
    } catch (error) {
      this.error.set(describeError(error, fallback));
    } finally {
      this.busy.set(false);
    }
  }
}
