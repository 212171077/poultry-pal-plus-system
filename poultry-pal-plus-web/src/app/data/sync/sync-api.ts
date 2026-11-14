import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, firstValueFrom } from 'rxjs';
import { APP_CONFIG } from '../../core/config/app-config';
import { ApiResponse, isApiResponse } from '../../core/http/api-response';
import type { ProductionSnapshot } from '../../features/production/production-api';
import {
  SyncBootstrapResponse,
  SyncChangesResponse,
  SyncOperationDto,
  SyncPushResponse,
  UserInfo,
} from '../models/sync-api';

export type SyncErrorKind = 'network' | 'auth' | 'forbidden' | 'invalid' | 'server';

/** A failed sync request, classified so the engine knows whether to retry, pause or give up. */
export class SyncHttpError extends Error {
  constructor(
    readonly kind: SyncErrorKind,
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'SyncHttpError';
  }

  /** The server could not be reached at all (no network, or a proxy without a backend). */
  get unreachable(): boolean {
    return this.status === 0 || this.status === 502 || this.status === 503 || this.status === 504;
  }

  static from(error: unknown): SyncHttpError {
    if (error instanceof SyncHttpError) return error;
    if (!(error instanceof HttpErrorResponse)) {
      return new SyncHttpError('server', -1, error instanceof Error ? error.message : 'Unknown');
    }
    const body: unknown = error.error;
    const message = isApiResponse(body) ? body.message : error.message;
    const { status } = error;
    if (status === 0 || status === 408 || status === 429 || status >= 500) {
      return new SyncHttpError(status === 0 ? 'network' : 'server', status, message);
    }
    if (status === 401) return new SyncHttpError('auth', status, message);
    if (status === 403) return new SyncHttpError('forbidden', status, message);
    return new SyncHttpError('invalid', status, message);
  }

  /** Network and 5xx problems are temporary; the rest need the user. */
  get retryable(): boolean {
    return this.kind === 'network' || this.kind === 'server';
  }
}

/** Thin client for `/api/v1/sync` and the auth refresh endpoint; unwraps the response envelope. */
@Injectable({ providedIn: 'root' })
export class SyncApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1`;

  push(operations: readonly SyncOperationDto[]): Promise<SyncPushResponse> {
    return this.unwrap(
      this.http.post<ApiResponse<SyncPushResponse>>(`${this.baseUrl}/sync/push`, { operations }),
    );
  }

  changes(since: number, limit = 500): Promise<SyncChangesResponse> {
    const params = new HttpParams().set('since', since).set('limit', limit);
    return this.unwrap(
      this.http.get<ApiResponse<SyncChangesResponse>>(`${this.baseUrl}/sync/changes`, { params }),
    );
  }

  bootstrap(): Promise<SyncBootstrapResponse> {
    return this.unwrap(
      this.http.get<ApiResponse<SyncBootstrapResponse>>(`${this.baseUrl}/sync/bootstrap`),
    );
  }

  /** Everything the production pages read; cached for offline use. */
  productionSnapshot(): Promise<ProductionSnapshot> {
    return this.unwrap(
      this.http.get<ApiResponse<ProductionSnapshot>>(`${this.baseUrl}/production/snapshot`),
    );
  }

  /** Rotates the refresh cookie and issues a new access cookie. */
  refresh(): Promise<UserInfo> {
    return this.unwrap(this.http.post<ApiResponse<UserInfo>>(`${this.baseUrl}/auth/refresh`, null));
  }

  private async unwrap<T>(request: Observable<ApiResponse<T>>): Promise<T> {
    let response: ApiResponse<T>;
    try {
      response = await firstValueFrom(request);
    } catch (error) {
      throw SyncHttpError.from(error);
    }
    if (!response.success || response.data === undefined) {
      throw new SyncHttpError('invalid', 200, response.message || 'Unexpected response');
    }
    return response.data;
  }
}
