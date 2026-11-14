import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';

export interface InfoDialogData {
  readonly title: string;
  readonly message: string;
}

@Component({
  selector: 'app-info-dialog',
  imports: [MatDialogModule, MatButton],
  template: `
    <h2 mat-dialog-title>{{ data.title }}</h2>
    <mat-dialog-content>{{ data.message }}</mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-flat-button type="button" mat-dialog-close>Got it</button>
    </mat-dialog-actions>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class InfoDialog {
  protected readonly data = inject<InfoDialogData>(MAT_DIALOG_DATA);
}
