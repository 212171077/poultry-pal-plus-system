import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import {
  AbstractControl,
  NonNullableFormBuilder,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatExpansionModule } from '@angular/material/expansion';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { RouterLink } from '@angular/router';
import { SignUpRequest } from '../../core/auth/auth-api';
import { AuthService } from '../../core/auth/auth.service';
import { ApiError } from '../../core/http/api-error';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { AuthLayout } from './auth-layout/auth-layout';
import { passwordStrength } from './password-strength';

function matchesPassword(control: AbstractControl): ValidationErrors | null {
  const password = control.parent?.get('password')?.value as string | undefined;
  return control.value && control.value !== password ? { mismatch: true } : null;
}

const STRENGTH_LABELS = { weak: 'Weak', fair: 'Fair', good: 'Good', strong: 'Strong' } as const;

/** Registers a farm owner with their farm (mirrors the mobile app's sign-up). */
@Component({
  selector: 'app-register-page',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatButtonModule,
    MatExpansionModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressSpinnerModule,
    AuthLayout,
  ],
  templateUrl: './register-page.html',
  styleUrl: './auth-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class RegisterPage {
  private readonly auth = inject(AuthService);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly online = inject(ConnectivityService).browserOnline;
  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly showPassword = signal(false);
  protected readonly submitted = signal(false);

  protected readonly form = this.fb.group({
    farmName: ['', [Validators.required, Validators.maxLength(100)]],
    farmAddressLine1: ['', Validators.maxLength(255)],
    farmAddressLine2: ['', Validators.maxLength(255)],
    farmCity: ['', Validators.maxLength(100)],
    farmState: ['', Validators.maxLength(100)],
    farmPostalCode: ['', Validators.maxLength(20)],
    farmCountry: ['', Validators.maxLength(100)],
    name: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
    surname: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(50)]],
    phoneNumber: ['', [Validators.required, Validators.pattern(/^\d{7,15}$/)]],
    password: ['', [Validators.required, Validators.minLength(6), Validators.maxLength(120)]],
    confirmPassword: ['', [Validators.required, matchesPassword]],
  });

  private readonly password = toSignal(this.form.controls.password.valueChanges, {
    initialValue: '',
  });
  protected readonly strength = computed(() => {
    const value = this.password();
    if (!value) return null;
    const { level, score } = passwordStrength(value);
    return { level, score, label: STRENGTH_LABELS[level] };
  });
  protected readonly bars = [1, 2, 3, 4] as const;

  constructor() {
    this.form.controls.password.valueChanges.subscribe(() =>
      this.form.controls.confirmPassword.updateValueAndValidity({ emitEvent: false }),
    );
  }

  protected serverError(control: keyof typeof this.form.controls): string | null {
    const errors = this.form.controls[control].errors;
    return typeof errors?.['server'] === 'string' ? errors['server'] : null;
  }

  protected async submit(): Promise<void> {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.submitting.set(true);
    this.error.set(null);
    const value = this.form.getRawValue();
    const optional = (text: string) => text.trim() || null;
    const request: SignUpRequest = {
      name: value.name.trim(),
      surname: value.surname.trim(),
      email: value.email.trim(),
      phoneNumber: value.phoneNumber.trim(),
      password: value.password,
      farmName: value.farmName.trim(),
      farmAddressLine1: optional(value.farmAddressLine1),
      farmAddressLine2: optional(value.farmAddressLine2),
      farmCity: optional(value.farmCity),
      farmState: optional(value.farmState),
      farmPostalCode: optional(value.farmPostalCode),
      farmCountry: optional(value.farmCountry),
    };
    try {
      await this.auth.signUp(request);
      this.submitted.set(true);
      this.submitting.set(false);
    } catch (error) {
      this.showError(ApiError.from(error));
      this.submitting.set(false);
    }
  }

  private showError(error: ApiError): void {
    if (error.kind === 'conflict') {
      this.setServerError('email', 'An account with this email already exists. Sign in instead.');
      return;
    }
    let mapped = false;
    for (const field of error.fieldErrors) {
      if (field.field in this.form.controls) {
        this.setServerError(field.field as keyof typeof this.form.controls, field.message);
        mapped = true;
      }
    }
    this.error.set(mapped ? 'Please fix the highlighted fields.' : error.message);
  }

  private setServerError(control: keyof typeof this.form.controls, message: string): void {
    const target = this.form.controls[control];
    target.setErrors({ ...target.errors, server: message });
    target.markAsTouched();
  }
}
