import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { strongPassword, PASSWORD_RULES_HINT } from '../../shared/validators/password-rules';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { Router, RouterLink } from '@angular/router';
import { AuthApi } from '../../core/auth/auth-api';
import { ApiError } from '../../core/http/api-error';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { AuthLayout } from './auth-layout/auth-layout';

/** Two steps: email a 6-digit code, then set a new password with it. */
@Component({
  selector: 'app-forgot-password-page',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressSpinnerModule,
    AuthLayout,
  ],
  templateUrl: './forgot-password-page.html',
  styleUrl: './auth-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ForgotPasswordPage {
  protected readonly passwordHint = PASSWORD_RULES_HINT;
  private readonly api = inject(AuthApi);
  private readonly router = inject(Router);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly online = inject(ConnectivityService).browserOnline;
  protected readonly step = signal<'request' | 'reset'>('request');
  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly showPassword = signal(false);

  protected readonly requestForm = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
  });
  protected readonly resetForm = this.fb.group({
    code: ['', [Validators.required, Validators.pattern(/^\d{6}$/)]],
    newPassword: [
      '',
      [Validators.required, Validators.minLength(8), strongPassword, Validators.maxLength(100)],
    ],
  });

  protected async requestCode(): Promise<void> {
    if (this.requestForm.invalid) {
      this.requestForm.markAllAsTouched();
      return;
    }
    await this.run(async () => {
      await this.api.forgotPassword(this.requestForm.getRawValue().email.trim());
      this.step.set('reset');
    });
  }

  protected async resetPassword(): Promise<void> {
    if (this.resetForm.invalid) {
      this.resetForm.markAllAsTouched();
      return;
    }
    const { code, newPassword } = this.resetForm.getRawValue();
    await this.run(async () => {
      await this.api.resetPassword(this.requestForm.getRawValue().email.trim(), code, newPassword);
      await this.router.navigateByUrl('/login');
    });
  }

  private async run(action: () => Promise<void>): Promise<void> {
    if (!this.online()) {
      this.error.set('You are offline. Connect to the internet to reset your password.');
      return;
    }
    this.submitting.set(true);
    this.error.set(null);
    try {
      await action();
    } catch (error) {
      this.error.set(ApiError.from(error).message);
    }
    this.submitting.set(false);
  }
}
