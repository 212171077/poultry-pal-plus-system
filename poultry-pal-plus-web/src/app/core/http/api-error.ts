import { HttpErrorResponse } from '@angular/common/http';
import { Observable, firstValueFrom } from 'rxjs';
import { ApiErrorCode, ApiFieldError, ApiResponse, isApiResponse } from './api-response';

export type ApiErrorKind =
  'network' | 'unauthorized' | 'forbidden' | 'validation' | 'conflict' | 'server';

/** A failed `/api/v1` call mapped to something the UI can explain to a farmer. */
export class ApiError extends Error {
  constructor(
    readonly kind: ApiErrorKind,
    readonly status: number,
    message: string,
    readonly code: ApiErrorCode | null = null,
    readonly fieldErrors: readonly ApiFieldError[] = [],
  ) {
    super(message);
    this.name = 'ApiError';
  }

  static from(error: unknown): ApiError {
    if (error instanceof ApiError) return error;
    if (!(error instanceof HttpErrorResponse)) {
      return new ApiError('server', -1, 'Something went wrong. Please try again.');
    }
    const body: unknown = error.error;
    const envelope = isApiResponse(body) ? body : null;
    const { status } = error;
    const code = envelope?.errorCode ?? null;
    const fields = envelope?.errors ?? [];
    // A proxy without a running backend answers 502–504: for the user that is "can't reach it".
    if (status === 0 || status === 502 || status === 503 || status === 504) {
      return new ApiError(
        'network',
        status,
        "Can't reach Poultry Pal Plus. Check your internet connection and try again.",
      );
    }
    const message = envelope?.message || 'Something went wrong. Please try again.';
    if (status === 401) return new ApiError('unauthorized', status, message, code);
    if (status === 403) return new ApiError('forbidden', status, message, code);
    if (status === 409) return new ApiError('conflict', status, message, code);
    if (status === 400 || status === 422) {
      return new ApiError('validation', status, message, code, fields);
    }
    return new ApiError('server', status, message, code);
  }
}

/** Awaits an `/api/v1` call and unwraps the `{success, message, data}` envelope. */
export async function unwrapApi<T>(request: Observable<ApiResponse<T>>): Promise<T | undefined> {
  let response: ApiResponse<T>;
  try {
    response = await firstValueFrom(request);
  } catch (error) {
    throw ApiError.from(error);
  }
  if (!response.success) {
    throw new ApiError('server', 200, response.message || 'Unexpected response', null);
  }
  return response.data;
}
