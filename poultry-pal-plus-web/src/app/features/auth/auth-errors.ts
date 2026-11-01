import { ApiError } from '../../core/http/api-error';

/** Turns a failed auth call into wording a farmer can act on. */
export function authErrorMessage(error: unknown): string {
  const apiError = ApiError.from(error);
  if (apiError.code === 'INVALID_CREDENTIALS' || apiError.kind === 'unauthorized') {
    return 'Email or password is incorrect.';
  }
  if (apiError.kind === 'forbidden') {
    return apiError.message || 'This account is not allowed to sign in.';
  }
  return apiError.message;
}
