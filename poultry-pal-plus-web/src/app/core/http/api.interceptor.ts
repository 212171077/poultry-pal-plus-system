import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { APP_CONFIG } from '../config/app-config';

/**
 * Sends the HttpOnly auth cookies with every backend request. Third-party URLs are left untouched
 * so credentials never leak to other origins.
 */
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const { apiBaseUrl } = inject(APP_CONFIG);
  if (!isApiUrl(req.url, apiBaseUrl)) {
    return next(req);
  }
  return next(req.clone({ withCredentials: true }));
};

export function isApiUrl(url: string, apiBaseUrl: string): boolean {
  return url === apiBaseUrl || url.startsWith(`${apiBaseUrl}/`);
}
