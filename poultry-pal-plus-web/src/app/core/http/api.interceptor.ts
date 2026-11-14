import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, from, switchMap, throwError } from 'rxjs';
import { APP_CONFIG } from '../config/app-config';
import { SessionRefresher } from '../auth/session-refresher';

/**
 * Sends the HttpOnly auth cookies with every backend request. Third-party URLs are left untouched
 * so credentials never leak to other origins.
 *
 * The access cookie is short-lived. When a request is answered with 401 the session is rotated
 * once through the refresh cookie and the request is retried, so pages that call the API directly
 * do not show "Authentication required" until the next sync happens to renew the session. If the
 * refresh itself fails, the original 401 is surfaced.
 */
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const { apiBaseUrl } = inject(APP_CONFIG);
  if (!isApiUrl(req.url, apiBaseUrl)) {
    return next(req);
  }
  const refresher = inject(SessionRefresher);
  const withCredentials = req.clone({ withCredentials: true });
  if (isAuthUrl(req.url, apiBaseUrl)) {
    return next(withCredentials);
  }
  return next(withCredentials).pipe(
    catchError((error: unknown) => {
      if (!(error instanceof HttpErrorResponse) || error.status !== 401) {
        return throwError(() => error);
      }
      return from(refresher.refresh()).pipe(
        catchError(() => throwError(() => error)),
        switchMap(() => next(withCredentials)),
      );
    }),
  );
};

export function isApiUrl(url: string, apiBaseUrl: string): boolean {
  return url === apiBaseUrl || url.startsWith(`${apiBaseUrl}/`);
}

/** Sign-in, refresh and sign-out answer 401 for their own reasons; they must never trigger a refresh. */
export function isAuthUrl(url: string, apiBaseUrl: string): boolean {
  return url.startsWith(`${apiBaseUrl}/v1/auth/`);
}
