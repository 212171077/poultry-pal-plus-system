/** Error codes returned by the backend `/api/v1` endpoints (see `ErrorCodes.java`). */
export type ApiErrorCode =
  | 'VALIDATION_ERROR'
  | 'BAD_REQUEST'
  | 'UNAUTHORIZED'
  | 'INVALID_CREDENTIALS'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'DUPLICATE'
  | 'UNSUPPORTED_OPERATION'
  | 'INTERNAL_ERROR';

export interface ApiFieldError {
  readonly field: string;
  readonly message: string;
}

/** Envelope used by every `/api/v1` response. */
export interface ApiResponse<T> {
  readonly success: boolean;
  readonly message: string;
  readonly data?: T;
  readonly errorCode?: ApiErrorCode;
  readonly errors?: readonly ApiFieldError[];
}

export function isApiResponse(value: unknown): value is ApiResponse<unknown> {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { success?: unknown }).success === 'boolean' &&
    typeof (value as { message?: unknown }).message === 'string'
  );
}
