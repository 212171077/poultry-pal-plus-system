import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { provideNativeDateAdapter } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { startOfDay } from 'date-fns';
import { LocalEggRecord } from '../../../data/models/local';
import {
  BOX_SIZES,
  DEFAULT_BOX_SIZE,
  DEFAULT_EGG_SIZE,
  EGG_SIZES,
} from '../../../data/models/record-options';
import { EGG_BOX_SIZES, EggRecordRepository } from '../../../data/repositories/repositories';
import { RecordFormContext } from '../../../shared/records/record-page';

export interface EggFormData extends RecordFormContext {
  readonly record?: LocalEggRecord;
}

/** Log packaged eggs for a layer coop; the egg count is worked out from the boxes. */
@Component({
  selector: 'app-egg-form-dialog',
  providers: [provideNativeDateAdapter()],
  imports: [
    MatDatepickerModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './egg-form-dialog.html',
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class EggFormDialog {
  private readonly data = inject<EggFormData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<EggFormDialog, LocalEggRecord>);
  private readonly eggs = inject(EggRecordRepository);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly coops = this.data.coops;
  protected readonly eggSizes = EGG_SIZES;
  protected readonly boxSizes = BOX_SIZES;
  protected readonly editing = !!this.data.record;
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly today = new Date();

  private readonly record = this.data.record;
  protected readonly form = this.fb.group({
    coopId: [
      {
        value:
          this.record?.coopId ??
          this.data.coopId ??
          (this.coops.length === 1 ? this.coops[0].id : ''),
        disabled: !!this.record,
      },
      Validators.required,
    ],
    createdDate: [
      this.record ? new Date(this.record.createdDate) : this.today,
      Validators.required,
    ],
    eggSize: [this.record?.eggSize ?? DEFAULT_EGG_SIZE, Validators.required],
    boxSize: [
      BOX_SIZES.find((b) => b.value.toLowerCase() === this.record?.boxSize.toLowerCase())?.value ??
        DEFAULT_BOX_SIZE,
      Validators.required,
    ],
    numberOfBoxes: [
      this.record?.numberOfBoxes ?? (null as number | null),
      [Validators.required, Validators.min(1)],
    ],
    additionalInfo: [this.record?.additionalInfo ?? '', Validators.maxLength(500)],
  });

  private readonly value = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  protected readonly totalEggs = computed(() => {
    const { boxSize, numberOfBoxes } = this.value();
    const perBox = EGG_BOX_SIZES[(boxSize ?? '').toLowerCase()] ?? 0;
    return (perBox * (Number(numberOfBoxes) || 0)).toLocaleString();
  });

  protected async save(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const value = this.form.getRawValue();
    const fields = {
      createdDate: startOfDay(value.createdDate).toISOString(),
      eggSize: value.eggSize,
      boxSize: value.boxSize,
      numberOfBoxes: Number(value.numberOfBoxes),
      additionalInfo: value.additionalInfo.trim() || null,
    };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved = this.record
        ? await this.eggs.update(this.record.id, fields)
        : await this.eggs.create({ ...fields, coopId: value.coopId });
      this.dialogRef.close(saved);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Could not save the record.');
      this.saving.set(false);
    }
  }
}
