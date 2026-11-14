import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { LocalReminder } from '../../../data/models/local';
import { ReminderRepository } from '../../../data/repositories/repositories';
import { REMINDER_ACTIONS } from '../reminder-groups';

export interface ReminderActionData {
  readonly reminder: LocalReminder;
  readonly kind: 'completed' | 'notApplicable' | 'removed';
}

/** Marks a reminder completed or not applicable, with an optional comment. Saved on the device first. */
@Component({
  selector: 'app-reminder-action-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
  ],
  template: `
    <h2 mat-dialog-title>{{ title }}</h2>
    <form [formGroup]="form" (ngSubmit)="save()" novalidate>
      <mat-dialog-content class="fields">
        <p>{{ data.reminder.name }}</p>
        @if (data.kind === 'removed') {
          <p>
            This task will no longer be due. It moves to Completed with the action “Remove Task”.
          </p>
        }
        <mat-form-field>
          <mat-label>Comment (optional)</mat-label>
          <textarea matInput rows="3" maxlength="500" formControlName="comment"></textarea>
        </mat-form-field>
        @if (error()) {
          <p class="error" role="alert">{{ error() }}</p>
        }
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" mat-dialog-close>Cancel</button>
        <button mat-flat-button type="submit" [disabled]="saving()">
          {{ submitLabel }}
        </button>
      </mat-dialog-actions>
    </form>
  `,
  styleUrl: '../../../shared/records/record-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ReminderActionDialog {
  protected readonly data = inject<ReminderActionData>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<ReminderActionDialog, boolean>);
  private readonly reminders = inject(ReminderRepository);
  protected readonly title = {
    completed: 'Mark as completed',
    notApplicable: 'Mark as not applicable',
    removed: 'Remove task',
  }[this.data.kind];
  protected readonly submitLabel = {
    completed: 'Mark completed',
    notApplicable: 'Mark not applicable',
    removed: 'Remove task',
  }[this.data.kind];

  protected readonly form = inject(NonNullableFormBuilder).group({
    comment: ['', [Validators.maxLength(500)]],
  });
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected async save(): Promise<void> {
    if (this.form.invalid) return;
    this.saving.set(true);
    try {
      await this.reminders.complete(this.data.reminder.id, {
        action: REMINDER_ACTIONS[this.data.kind],
        actionComment: this.form.controls.comment.value.trim() || null,
      });
      this.dialogRef.close(true);
    } catch (error) {
      this.error.set(error instanceof Error ? error.message : 'Could not save. Try again.');
      this.saving.set(false);
    }
  }
}
