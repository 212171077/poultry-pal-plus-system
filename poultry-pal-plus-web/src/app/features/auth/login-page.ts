import { ChangeDetectionStrategy, Component, inject, input, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AccountSwitch, AuthService, safeReturnUrl } from '../../core/auth/auth.service';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ConfirmDialogService } from '../../shared/ui/confirm-dialog/confirm-dialog.service';
import { AuthLayout } from './auth-layout/auth-layout';
import { authErrorMessage } from './auth-errors';

@Component({
  selector: 'app-login-page',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatButtonModule,
    MatCheckboxModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressSpinnerModule,
    AuthLayout,
  ],
  templateUrl: './login-page.html',
  styleUrl: './auth-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class LoginPage {
  /** Where to go after signing in (bound from the query string). */
  readonly returnUrl = input<string>();

  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly confirm = inject(ConfirmDialogService);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly online = inject(ConnectivityService).browserOnline;
  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly showPassword = signal(false);

  protected readonly form = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required],
    rememberMe: [true],
  });

  protected async submit(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    if (!this.online()) {
      this.error.set('You are offline. Connect to the internet to sign in.');
      return;
    }
    this.submitting.set(true);
    this.error.set(null);
    try {
      const outcome = await this.auth.signIn(this.form.getRawValue(), (info) =>
        this.confirmSwitch(info),
      );
      if (outcome === 'signed-in') {
        await this.router.navigateByUrl(safeReturnUrl(this.returnUrl()));
        return;
      }
    } catch (error) {
      this.error.set(authErrorMessage(error));
      this.form.controls.password.reset();
    }
    this.submitting.set(false);
  }

  private confirmSwitch(info: AccountSwitch): Promise<boolean> {
    const changes = info.unsyncedCount === 1 ? '1 change' : `${info.unsyncedCount} changes`;
    return firstValueFrom(
      this.confirm.confirm({
        title: 'Discard unsynced work?',
        message:
          `${info.previousName} has ${changes} on this device that never reached the server. ` +
          'Signing in with a different account removes them. To keep them, cancel and sign in ' +
          `as ${info.previousName} while online.`,
        confirmText: 'Discard and sign in',
        cancelText: 'Cancel',
        destructive: true,
      }),
    );
  }
}
