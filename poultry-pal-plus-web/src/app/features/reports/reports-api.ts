import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { APP_CONFIG } from '../../core/config/app-config';
import { ApiError } from '../../core/http/api-error';

/** Client for the report endpoints of the legacy `/api/farm` API (PDF download and email). */
@Injectable({ providedIn: 'root' })
export class ReportsApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/farm`;

  async downloadReport(farmId: string, userId: string): Promise<Blob> {
    return this.blob(`${this.baseUrl}/download-report/${enc(farmId)}/${enc(userId)}`);
  }

  async downloadSchedule(farmId: string, coopId: string, userId: string): Promise<Blob> {
    return this.blob(
      `${this.baseUrl}/download-schedule/${enc(farmId)}/${enc(coopId)}/${enc(userId)}`,
    );
  }

  async emailReport(farmId: string, userId: string): Promise<void> {
    await this.post('send-report', { farmId, userId });
  }

  async emailSchedule(farmId: string, userId: string, coopId: string): Promise<void> {
    await this.post('send-schedule', { farmId, userId, coopId });
  }

  private async blob(url: string): Promise<Blob> {
    try {
      return await firstValueFrom(this.http.get(url, { responseType: 'blob' }));
    } catch (error) {
      throw ApiError.from(error);
    }
  }

  private async post(path: string, body: Record<string, string>): Promise<void> {
    try {
      await firstValueFrom(this.http.post(`${this.baseUrl}/${path}`, body));
    } catch (error) {
      throw ApiError.from(error);
    }
  }
}

const enc = encodeURIComponent;
