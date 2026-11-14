import { ValidatorFn } from '@angular/forms';

/** Mirrors the server rule (`ValidationUtil.isValidPassword`). */
export const PASSWORD_RULES_HINT =
  'Use at least 8 characters with an upper-case letter, a lower-case letter, a number and one of !@#$%^&*()';

export const strongPassword: ValidatorFn = (control) => {
  const value = String(control.value ?? '');
  if (!value) return null;
  const ok =
    value.length >= 8 &&
    /[A-Z]/.test(value) &&
    /[a-z]/.test(value) &&
    /[0-9]/.test(value) &&
    /[!@#$%^&*()]/.test(value);
  return ok ? null : { weakPassword: true };
};
