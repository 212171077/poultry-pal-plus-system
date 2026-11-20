import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { ApiError } from '../../../core/http/api-error';
import { AddressDto } from '../../../data/models/sync-api';
import { FarmSettingsApi } from '../farm-settings-api';

export interface AddressDialogData {
  /** Present when editing. */
  readonly address?: AddressDto;
}

/** Add or edit one farm address. Addresses are saved on the server, so this needs a connection. */
@Component({
  selector: 'app-address-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
  ],
  template: `
    <h2 mat-dialog-title>{{ editing ? 'Edit address' : 'Add address' }}</h2>
    <form [formGroup]="form" (ngSubmit)="save()" novalidate>
      <mat-dialog-content class="fields">
        <mat-form-field>
          <mat-label>Label</mat-label>
          <input matInput formControlName="label" placeholder="e.g. Main farm, Packing shed" />
          <mat-hint>Helps tell your addresses apart</mat-hint>
        </mat-form-field>
        <mat-form-field>
          <mat-label>Address line 1</mat-label>
          <input matInput formControlName="addressLine1" autocomplete="address-line1" />
          <mat-error>Enter the first line of the address</mat-error>
        </mat-form-field>
        <mat-form-field>
          <mat-label>Address line 2</mat-label>
          <input matInput formControlName="addressLine2" autocomplete="address-line2" />
        </mat-form-field>
        <div class="row">
          <mat-form-field>
            <mat-label>City / town</mat-label>
            <input matInput formControlName="city" autocomplete="address-level2" />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Province / state</mat-label>
            <input matInput formControlName="state" autocomplete="address-level1" />
          </mat-form-field>
        </div>
        <div class="row">
          <mat-form-field>
            <mat-label>Postal code</mat-label>
            <input matInput formControlName="postalCode" autocomplete="postal-code" />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Country</mat-label>
            <input matInput formControlName="country" autocomplete="country-name" />
          </mat-form-field>
        </div>
        @if (error(); as message) {
          <p class="error" role="alert">{{ message }}</p>
        }
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" mat-dialog-close>Cancel</button>
        <button mat-flat-button type="submit" [disabled]="saving()">
          {{ editing ? 'Save changes' : 'Add address' }}
        </button>
      </mat-dialog-actions>
    </form>
  `,
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AddressDialog {
  private readonly data = inject<AddressDialogData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<AddressDialog, boolean>);
  private readonly api = inject(FarmSettingsApi);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly editing = !!this.data.address?.id;
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly form = this.fb.group({
    label: [this.data.address?.label ?? '', Validators.maxLength(50)],
    addressLine1: [
      this.data.address?.addressLine1 ?? '',
      [Validators.required, Validators.maxLength(100)],
    ],
    addressLine2: [this.data.address?.addressLine2 ?? '', Validators.maxLength(100)],
    city: [this.data.address?.city ?? '', Validators.maxLength(60)],
    state: [this.data.address?.state ?? '', Validators.maxLength(60)],
    postalCode: [this.data.address?.postalCode ?? '', Validators.maxLength(20)],
    country: [this.data.address?.country ?? '', Validators.maxLength(80)],
  });

  protected async save(): Promise<void> {
    const value = this.form.getRawValue();
    if (this.form.invalid || !value.addressLine1.trim()) {
      this.form.markAllAsTouched();
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      const id = this.data.address?.id;
      await (id ? this.api.updateAddress(id, value) : this.api.addAddress(value));
      this.dialogRef.close(true);
    } catch (err) {
      this.error.set(err instanceof ApiError ? err.message : 'Could not save the address.');
      this.saving.set(false);
    }
  }
}
