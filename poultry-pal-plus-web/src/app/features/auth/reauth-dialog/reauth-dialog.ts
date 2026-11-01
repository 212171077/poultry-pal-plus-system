import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { AuthService } from '../../../core/auth/auth.service';
import { ConnectivityService } from '../../../core/network/connectivity.service';
import { authErrorMessage } from '../auth-errors';

/** Renews an expired server session with the password only; unsynced work stays on the device. */
@Component({
  selector: 'app-reauth-dialog',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatDialogModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
  ],
  template: `
    <h2 mat-dialog-title>Sign in again</h2>
    <form [formGroup]="form" (ngSubmit)="submit()" novalidate>
      <mat-dialog-content class="fields">
        <p class="lead">
          Your session has expired. Enter your password to keep syncing. Nothing on this device has
          been lost.
        </p>
        <mat-form-field>
          <mat-label>Email</mat-label>
          <input matInput [value]="email" disabled autocomplete="username" />
        </mat-form-field>
        <mat-form-field>
          <mat-label>Password</mat-label>
          <input
            matInput
            type="password"
            formControlName="password"
            autocomplete="current-password"
            cdkFocusInitial
          />
          <mat-error>Enter your password</mat-error>
        </mat-form-field>
        @if (!online()) {
          <p class="error" role="status">You are offline. Connect to the internet to sign in.</p>
        }
        @if (error(); as message) {
          <p class="error" role="alert">{{ message }}</p>
        }
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" mat-dialog-close>Later</button>
        <button mat-flat-button type="submit" [disabled]="submitting() || !online()">
          Sign in
        </button>
      </mat-dialog-actions>
    </form>
  `,
  styles: `
    .fields {
      display: flex;
      flex-direction: column;
      gap: var(--pp-space-xs);
      min-width: min(400px, 80vw);
    }
    .lead {
      margin: 0 0 var(--pp-space-md);
      color: var(--mat-sys-on-surface-variant);
    }
    mat-form-field {
      width: 100%;
    }
    .error {
      margin: 0;
      padding: var(--pp-space-sm) var(--pp-space-md);
      border-radius: var(--pp-radius-md);
      background: var(--pp-error-container);
      color: var(--pp-error);
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ReauthDialog {
  private readonly auth = inject(AuthService);
  private readonly dialogRef = inject(MatDialogRef<ReauthDialog, boolean>);

  protected readonly email = this.auth.user()?.email ?? '';
  protected readonly online = inject(ConnectivityService).browserOnline;
  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly form = inject(NonNullableFormBuilder).group({
    password: ['', Validators.required],
  });

  protected async submit(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.submitting.set(true);
    this.error.set(null);
    try {
      await this.auth.reauthenticate(this.form.getRawValue().password);
      this.dialogRef.close(true);
    } catch (error) {
      this.error.set(authErrorMessage(error));
      this.form.reset();
      this.submitting.set(false);
    }
  }
}
