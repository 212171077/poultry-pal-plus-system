import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { APP_CONFIG } from '../../../core/config/app-config';
import { ApiError, unwrapApi } from '../../../core/http/api-error';
import { ApiResponse } from '../../../core/http/api-response';

export interface AppConfigEntry {
  readonly id: string;
  readonly code: string;
  readonly description: string;
  /** Secrets arrive masked; leave the value blank on update to keep it. */
  readonly sensitive: boolean;
  readonly protectedEntry: boolean;
  readonly lastUpdateDate?: string;
}

export interface AppConfigInput {
  readonly code?: string;
  readonly description: string;
}

/** System-admin endpoints; online only, never synced or cached offline. */
@Injectable({ providedIn: 'root' })
export class AppConfigApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/admin/app-config`;

  list(): Promise<AppConfigEntry[]> {
    return this.unwrap(this.http.get<ApiResponse<AppConfigEntry[]>>(this.baseUrl));
  }

  create(input: AppConfigInput): Promise<AppConfigEntry> {
    return this.unwrap(this.http.post<ApiResponse<AppConfigEntry>>(this.baseUrl, input));
  }

  update(id: string, input: AppConfigInput): Promise<AppConfigEntry> {
    return this.unwrap(
      this.http.put<ApiResponse<AppConfigEntry>>(
        `${this.baseUrl}/${encodeURIComponent(id)}`,
        input,
      ),
    );
  }

  async remove(id: string): Promise<void> {
    await unwrapApi(
      this.http.delete<ApiResponse<void>>(`${this.baseUrl}/${encodeURIComponent(id)}`),
    );
  }

  private async unwrap<T>(request: Observable<ApiResponse<T>>): Promise<T> {
    const data = await unwrapApi(request);
    if (data === undefined) throw new ApiError('server', 200, 'Unexpected response');
    return data;
  }
}
