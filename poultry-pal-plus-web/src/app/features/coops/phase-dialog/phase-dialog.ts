import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import {
  GROWTH_PHASES,
  coopTypeLabel,
  duePhaseChange,
  growthPhaseLabel,
  transitionTargets,
} from '../../../data/models/coop-rules';
import { GrowthPhase, LocalCoop } from '../../../data/models/local';
import { CoopRepository } from '../../../data/repositories/repositories';

export interface PhaseDialogData {
  readonly coop: LocalCoop;
  readonly coops: readonly LocalCoop[];
}

/** Moves a flock to another growth phase, in its coop or into an empty coop of the same type. */
@Component({
  selector: 'app-phase-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatSelectModule,
  ],
  templateUrl: './phase-dialog.html',
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PhaseDialog {
  private readonly data = inject<PhaseDialogData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<PhaseDialog, boolean>);
  private readonly coopsRepo = inject(CoopRepository);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly coop = this.data.coop;
  protected readonly phases = GROWTH_PHASES.filter((p) => p.value !== this.coop.growthPhase);
  protected readonly targets = transitionTargets(this.coop, this.data.coops);
  protected readonly currentPhase = growthPhaseLabel(this.coop.growthPhase);
  protected readonly typeLabel = coopTypeLabel(this.coop.coopType).toLowerCase();
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly form = this.fb.group({
    newPhase: [
      (duePhaseChange(this.coop) ?? this.phases[0]?.value) as GrowthPhase,
      Validators.required,
    ],
    /** Empty string keeps the flock where it is. */
    targetCoopId: [''],
  });

  protected async save(): Promise<void> {
    if (this.form.invalid) return;
    const { newPhase, targetCoopId } = this.form.getRawValue();
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.coopsRepo.transitionPhase(this.coop.id, newPhase, targetCoopId || null);
      this.dialogRef.close(true);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Could not change the phase.');
      this.saving.set(false);
    }
  }
}
