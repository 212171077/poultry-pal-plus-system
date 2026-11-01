import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { provideNativeDateAdapter } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { startOfDay } from 'date-fns';
import {
  COOP_TYPES,
  GROWTH_PHASES,
  expectedGrowthPhase,
  growthPhaseLabel,
} from '../../../data/models/coop-rules';
import { CoopType, GrowthPhase, LocalCoop } from '../../../data/models/local';
import { CoopBatch, CoopRepository } from '../../../data/repositories/repositories';

export type CoopFormMode = 'create' | 'edit' | 'batch';

export interface CoopFormData {
  readonly mode: CoopFormMode;
  /** The coop to edit or restock. */
  readonly coop?: LocalCoop;
}

const TITLES: Record<CoopFormMode, string> = {
  create: 'Add a coop',
  edit: 'Edit coop',
  batch: 'Start a new batch',
};

/** Create or edit a coop, or start a new batch in it (the old batch is archived). */
@Component({
  selector: 'app-coop-form-dialog',
  providers: [provideNativeDateAdapter()],
  imports: [
    MatDatepickerModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './coop-form-dialog.html',
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CoopFormDialog {
  private readonly data = inject<CoopFormData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<CoopFormDialog, LocalCoop>);
  private readonly coops = inject(CoopRepository);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly mode = this.data.mode;
  protected readonly title = TITLES[this.mode];
  protected readonly types = COOP_TYPES;
  protected readonly phases = GROWTH_PHASES;
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  private readonly coop = this.data.coop;
  private readonly batch = this.mode === 'batch';
  protected readonly form = this.fb.group({
    coopName: [this.coop?.coopName ?? '', [Validators.required, Validators.maxLength(50)]],
    coopType: [(this.coop?.coopType ?? 'LAYERS') as CoopType, Validators.required],
    growthPhase: [
      (this.batch ? 'BROODING_PHASE' : (this.coop?.growthPhase ?? 'BROODING_PHASE')) as GrowthPhase,
      Validators.required,
    ],
    numberOfChickens: [
      this.batch ? (null as number | null) : (this.coop?.numberOfChickens ?? null),
      [Validators.required, Validators.min(0)],
    ],
    chickenArrivalDate: [
      this.batch
        ? new Date()
        : this.coop?.chickenArrivalDate
          ? new Date(this.coop.chickenArrivalDate)
          : (null as Date | null),
    ],
  });

  private readonly value = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  /** Suggests the phase that matches the flock's age, as the mobile app does. */
  protected readonly phaseHint = computed(() => {
    const { chickenArrivalDate, coopType, growthPhase } = this.value();
    if (!chickenArrivalDate || !coopType) return null;
    const expected = expectedGrowthPhase(startOfDay(chickenArrivalDate).toISOString(), coopType);
    return expected && expected !== growthPhase
      ? `A flock of this age is usually in the ${growthPhaseLabel(expected)}.`
      : null;
  });

  protected async save(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const value = this.form.getRawValue();
    const fields: CoopBatch = {
      coopName: value.coopName.trim(),
      coopType: value.coopType,
      growthPhase: value.growthPhase,
      numberOfChickens: Number(value.numberOfChickens),
      chickenArrivalDate: value.chickenArrivalDate
        ? startOfDay(value.chickenArrivalDate).toISOString()
        : null,
    };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved =
        this.mode === 'create'
          ? await this.coops.create({ ...fields, createdDate: new Date().toISOString() })
          : this.mode === 'batch'
            ? await this.coops.startNewBatch(this.coop!.id, fields)
            : await this.coops.update(this.coop!.id, fields);
      this.dialogRef.close(saved);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Could not save the coop.');
      this.saving.set(false);
    }
  }
}
