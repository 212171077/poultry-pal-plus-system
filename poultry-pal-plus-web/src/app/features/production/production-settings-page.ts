import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ApiError } from '../../core/http/api-error';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { ProductionApi, ProductionEquipment, ProductionSettings } from './production-api';

export const EQUIPMENT_LABELS = {
  INCUBATOR: 'Incubator',
  HATCHER: 'Hatcher',
  CHICKEN_HOUSE: 'Chicken house',
} as const;

export function toPercent(rate: number): number {
  return Math.round(rate * 10000) / 100;
}

export function fromPercent(percent: number): number {
  return Math.round(percent * 100) / 10000;
}

export function describeError(error: unknown, fallback: string): string {
  if (error instanceof ApiError) {
    if (error.status === 409) {
      return error.code === 'CAPACITY_CONFLICT'
        ? `${error.message} Reduce the planned usage first.`
        : 'These settings changed elsewhere. Reload and try again.';
    }
    return error.message;
  }
  return fallback;
}

@Component({
  selector: 'app-production-settings-page',
  imports: [
    PageHeader,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSlideToggleModule,
  ],
  templateUrl: './production-settings-page.html',
  styleUrl: './production-settings-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ProductionSettingsPage {
  private readonly api = inject(ProductionApi);
  private readonly fb = inject(FormBuilder);
  private readonly snackBar = inject(MatSnackBar);
  protected readonly connectivity = inject(ConnectivityService);
  protected readonly labels = EQUIPMENT_LABELS;
  protected readonly settings = signal<ProductionSettings | null>(null);
  protected readonly equipment = signal<readonly ProductionEquipment[]>([]);
  protected readonly error = signal<string | null>(null);
  protected readonly saving = signal(false);

  protected readonly form = this.fb.nonNullable.group({
    timeZone: ['', Validators.required],
    incubationDays: [21, [Validators.required, Validators.min(1), Validators.max(60)]],
    transferDay: [18, [Validators.required, Validators.min(1), Validators.max(59)]],
    broodingDays: [0, [Validators.required, Validators.min(0), Validators.max(60)]],
    hatchRatePercent: [80, [Validators.required, Validators.min(0), Validators.max(100)]],
    mortalityPercent: [5, [Validators.required, Validators.min(0), Validators.max(100)]],
    defaultGrowOutDays: [42, [Validators.required, Validators.min(1), Validators.max(365)]],
    supplierLeadTimeDays: this.fb.control<number | null>(null, [
      Validators.min(0),
      Validators.max(365),
    ]),
  });

  constructor() {
    void this.load();
  }

  protected async load(): Promise<void> {
    this.error.set(null);
    try {
      const [settings, equipment] = await Promise.all([this.api.settings(), this.api.equipment()]);
      this.applySettings(settings);
      this.equipment.set(equipment);
    } catch (error) {
      this.error.set(describeError(error, 'Could not load production settings.'));
    }
  }

  protected async saveSettings(): Promise<void> {
    const current = this.settings();
    if (!current || this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const v = this.form.getRawValue();
    this.saving.set(true);
    try {
      this.applySettings(
        await this.api.updateSettings({
          timeZone: v.timeZone.trim(),
          incubationDays: v.incubationDays,
          transferDay: v.transferDay,
          broodingDays: v.broodingDays,
          expectedHatchRate: fromPercent(v.hatchRatePercent),
          expectedMortalityRate: fromPercent(v.mortalityPercent),
          defaultGrowOutDays: v.defaultGrowOutDays,
          supplierLeadTimeDays: v.supplierLeadTimeDays,
          version: current.version,
        }),
      );
      this.snackBar.open('Production settings saved.', 'OK');
    } catch (error) {
      this.error.set(describeError(error, 'Could not save the settings.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async saveEquipment(
    item: ProductionEquipment,
    capacity: string,
    enabled: boolean,
  ): Promise<void> {
    const value = Number(capacity);
    if (!Number.isInteger(value) || value < 1) {
      this.error.set('Capacity must be a whole number of at least 1.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      const updated = await this.api.updateEquipment(item.id, {
        name: item.name,
        capacity: value,
        enabled,
        hatcherOccupancyDays: item.hatcherOccupancyDays,
        notes: item.notes,
        version: item.version,
      });
      this.equipment.update((list) => list.map((e) => (e.id === updated.id ? updated : e)));
      this.snackBar.open(`${updated.name} updated.`, 'OK');
    } catch (error) {
      this.error.set(describeError(error, 'Could not update this equipment.'));
    } finally {
      this.saving.set(false);
    }
  }

  private applySettings(settings: ProductionSettings): void {
    this.settings.set(settings);
    this.form.setValue({
      timeZone: settings.timeZone,
      incubationDays: settings.incubationDays,
      transferDay: settings.transferDay,
      broodingDays: settings.broodingDays,
      hatchRatePercent: toPercent(settings.expectedHatchRate),
      mortalityPercent: toPercent(settings.expectedMortalityRate),
      defaultGrowOutDays: settings.defaultGrowOutDays,
      supplierLeadTimeDays: settings.supplierLeadTimeDays,
    });
  }
}
