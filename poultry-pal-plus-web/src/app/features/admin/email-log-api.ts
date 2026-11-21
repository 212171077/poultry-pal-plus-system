import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { APP_CONFIG } from '../../core/config/app-config';
import { unwrapApi } from '../../core/http/api-error';
import { ApiResponse } from '../../core/http/api-response';

export interface EmailLogEntry {
  readonly id: string;
  readonly sentAt?: string;
  readonly toEmail: string;
  readonly subject: string;
  readonly success: boolean;
  readonly errorMessage?: string;
}

/** System-admin endpoint; online only, never synced or cached offline. */
@Injectable({ providedIn: 'root' })
export class EmailLogApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/admin/email-logs`;

  recent(limit = 10, page = 0): Promise<EmailLogEntry[]> {
    return unwrapApi(
      this.http.get<ApiResponse<EmailLogEntry[]>>(this.baseUrl, { params: { limit, page } }),
    ).then((entries) => entries ?? []);
  }
}
