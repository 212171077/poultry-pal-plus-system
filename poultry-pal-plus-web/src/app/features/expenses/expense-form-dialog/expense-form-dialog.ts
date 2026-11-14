import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { provideNativeDateAdapter } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { startOfDay } from 'date-fns';
import { LocalCoop, LocalExpense } from '../../../data/models/local';
import { ExpenseRepository } from '../../../data/repositories/repositories';
import { EXPENSE_TYPES } from '../expense-types';

export interface ExpenseFormData {
  readonly coops: readonly LocalCoop[];
  /** Present when editing. */
  readonly expense?: LocalExpense;
  readonly recordedBy?: string | null;
}

/** Create or edit an expense. Saves to the device first; the sync engine sends it later. */
@Component({
  selector: 'app-expense-form-dialog',
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
  templateUrl: './expense-form-dialog.html',
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ExpenseFormDialog {
  private readonly data = inject<ExpenseFormData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<ExpenseFormDialog, LocalExpense>);
  private readonly expenses = inject(ExpenseRepository);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly coops = this.data.coops;
  protected readonly types = EXPENSE_TYPES;
  protected readonly editing = !!this.data.expense;
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly today = new Date();

  protected readonly form = this.fb.group({
    // Records cannot move between coops once saved (the server keys them by coop).
    coopId: [
      {
        value: this.data.expense?.coopId ?? (this.coops.length === 1 ? this.coops[0].id : ''),
        disabled: !!this.data.expense,
      },
      Validators.required,
    ],
    expenseDate: [
      this.data.expense ? new Date(this.data.expense.expenseDate) : this.today,
      Validators.required,
    ],
    expenseType: [
      this.data.expense?.expenseType ?? '',
      [Validators.required, Validators.maxLength(100)],
    ],
    amount: [
      this.data.expense?.amount ?? (null as number | null),
      [Validators.required, Validators.min(0)],
    ],
    additionalInfo: [this.data.expense?.additionalInfo ?? '', Validators.maxLength(500)],
  });

  protected async save(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const value = this.form.getRawValue();
    const fields = {
      // Local midnight keeps the chosen calendar day in every time zone the farmer sees it.
      expenseDate: startOfDay(value.expenseDate).toISOString(),
      expenseType: value.expenseType,
      amount: Number(value.amount),
      additionalInfo: value.additionalInfo.trim() || null,
    };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved = this.data.expense
        ? await this.expenses.update(this.data.expense.id, fields)
        : await this.expenses.create({
            ...fields,
            coopId: value.coopId,
            recordedBy: this.data.recordedBy ?? null,
          });
      this.dialogRef.close(saved);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Could not save the expense.');
      this.saving.set(false);
    }
  }
}
