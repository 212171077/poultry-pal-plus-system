import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatAutocompleteModule } from '@angular/material/autocomplete';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { provideNativeDateAdapter } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { startOfDay } from 'date-fns';
import { LocalMortality } from '../../../data/models/local';
import { MORTALITY_REASONS } from '../../../data/models/record-options';
import { MortalityRepository } from '../../../data/repositories/repositories';
import { RecordFormContext } from '../../../shared/records/record-page';

export interface MortalityFormData extends RecordFormContext {
  readonly mortality?: LocalMortality;
}

/** Record birds lost and why. Reasons are suggested, but any reason can be typed. */
@Component({
  selector: 'app-mortality-form-dialog',
  providers: [provideNativeDateAdapter()],
  imports: [
    MatDatepickerModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatAutocompleteModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './mortality-form-dialog.html',
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class MortalityFormDialog {
  private readonly data = inject<MortalityFormData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<MortalityFormDialog, LocalMortality>);
  private readonly mortalities = inject(MortalityRepository);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly coops = this.data.coops;
  protected readonly editing = !!this.data.mortality;
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly today = new Date();

  private readonly record = this.data.mortality;
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
    dateOccurred: [
      this.record ? new Date(this.record.dateOccurred) : this.today,
      Validators.required,
    ],
    numberOfDeaths: [
      this.record?.numberOfDeaths ?? (null as number | null),
      [Validators.required, Validators.min(1)],
    ],
    reason: [this.record?.reason ?? '', [Validators.required, Validators.maxLength(200)]],
  });

  private readonly reasonText = toSignal(this.form.controls.reason.valueChanges, {
    initialValue: this.form.controls.reason.value,
  });

  protected readonly reasons = computed(() => {
    const text = this.reasonText().trim().toLowerCase();
    // A value that already is a suggestion (e.g. when editing) must not hide the other options.
    const exact = MORTALITY_REASONS.some((reason) => reason.toLowerCase() === text);
    return text && !exact
      ? MORTALITY_REASONS.filter((reason) => reason.toLowerCase().includes(text))
      : MORTALITY_REASONS;
  });

  protected async save(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const value = this.form.getRawValue();
    const fields = {
      dateOccurred: startOfDay(value.dateOccurred).toISOString(),
      numberOfDeaths: Number(value.numberOfDeaths),
      reason: value.reason.trim(),
    };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved = this.record
        ? await this.mortalities.update(this.record.id, fields)
        : await this.mortalities.create({
            ...fields,
            coopId: value.coopId,
            recordedBy: this.data.recordedBy ?? null,
          });
      this.dialogRef.close(saved);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Could not save the record.');
      this.saving.set(false);
    }
  }
}
