import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { provideNativeDateAdapter } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { startOfDay } from 'date-fns';
import { LocalSale, PaymentStatus } from '../../../data/models/local';
import {
  DEFAULT_EGG_SIZE,
  SALE_EGG_SIZES,
  SALE_PACKAGING,
} from '../../../data/models/record-options';
import { SaleRepository } from '../../../data/repositories/repositories';
import { formatMoney } from '../../../shared/format/money';
import { RecordFormContext } from '../../../shared/records/record-page';

export interface SaleFormData extends RecordFormContext {
  readonly sale?: LocalSale;
  readonly currency?: string | null;
}

/**
 * Create or edit a sale. Layer coops sell eggs by size and packaging (trays, boxes or single eggs),
 * broiler coops sell chickens; the total is computed as the farmer types (the server computes the
 * same).
 */
@Component({
  selector: 'app-sale-form-dialog',
  providers: [provideNativeDateAdapter()],
  imports: [
    MatDatepickerModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatButtonToggleModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './sale-form-dialog.html',
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SaleFormDialog {
  private readonly data = inject<SaleFormData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<SaleFormDialog, LocalSale>);
  private readonly sales = inject(SaleRepository);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly coops = this.data.coops;
  protected readonly editing = !!this.data.sale;
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly eggSizes = SALE_EGG_SIZES;
  protected readonly packagings = SALE_PACKAGING;
  protected readonly today = new Date();

  private readonly sale = this.data.sale;
  protected readonly form = this.fb.group({
    coopId: [
      {
        value:
          this.sale?.coopId ??
          this.data.coopId ??
          (this.coops.length === 1 ? this.coops[0].id : ''),
        disabled: !!this.sale,
      },
      Validators.required,
    ],
    saleDate: [
      this.sale ? new Date(this.sale.saleDate) : this.today,
      Validators.required,
    ],
    eggSize: [
      SALE_EGG_SIZES.find((s) => s.toLowerCase() === this.sale?.eggSize?.toLowerCase()) ??
        DEFAULT_EGG_SIZE,
    ],
    eggPackaging: [this.sale?.eggPackaging ?? '', this.sale ? [] : [Validators.required]],
    quantity: [
      this.sale?.quantitySold || this.sale?.numberOfChickensSold || (null as number | null),
      [Validators.required, Validators.min(1)],
    ],
    price: [
      this.sale?.pricePerUnit || this.sale?.salePricePerChicken || (null as number | null),
      [Validators.required, Validators.min(0.01)],
    ],
    additionalInfo: [this.sale?.additionalInfo ?? '', [Validators.maxLength(250)]],
    paymentStatus: [(this.sale?.paymentStatus ?? 'PAID') as PaymentStatus],
  });

  private readonly value = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  /** Layer coops sell packaged eggs; broiler coops sell chickens. */
  protected readonly sellsEggs = computed(() => {
    const coopId = this.value().coopId ?? this.form.getRawValue().coopId;
    return this.coops.find((coop) => coop.id === coopId)?.coopType !== 'BROILER';
  });

  private readonly unit = computed(
    () => this.packagings.find((p) => p.value === this.value().eggPackaging)?.unit,
  );

  protected readonly quantityLabel = computed(() => {
    if (!this.sellsEggs()) return 'Chickens sold';
    const unit = this.unit();
    return unit ? `Number of ${unit}s sold` : 'Quantity sold';
  });

  protected readonly priceLabel = computed(() => {
    if (!this.sellsEggs()) return 'Price per chicken';
    const unit = this.unit();
    return unit ? `Price per ${unit}` : 'Price per unit';
  });

  protected readonly total = computed(() => {
    const { quantity, price } = this.value();
    return formatMoney((Number(quantity) || 0) * (Number(price) || 0), this.data.currency);
  });

  protected async save(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const value = this.form.getRawValue();
    const quantity = Number(value.quantity);
    const price = Number(value.price);
    const eggs = this.sellsEggs();
    const fields = {
      saleDate: startOfDay(value.saleDate).toISOString(),
      eggSize: eggs ? value.eggSize : null,
      eggPackaging: eggs ? value.eggPackaging : null,
      quantitySold: eggs ? quantity : null,
      pricePerUnit: eggs ? price : null,
      numberOfDozensSold: null,
      salePricePerDozen: null,
      numberOfChickensSold: eggs ? null : quantity,
      salePricePerChicken: eggs ? null : price,
      additionalInfo: value.additionalInfo.trim() || null,
      paymentStatus: value.paymentStatus,
    };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved = this.sale
        ? await this.sales.update(this.sale.id, fields)
        : await this.sales.create({
            ...fields,
            coopId: value.coopId,
            recordedBy: this.data.recordedBy ?? null,
          });
      this.dialogRef.close(saved);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Could not save the sale.');
      this.saving.set(false);
    }
  }
}
