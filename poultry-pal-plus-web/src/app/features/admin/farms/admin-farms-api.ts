import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { APP_CONFIG } from '../../../core/config/app-config';
import { unwrapApi } from '../../../core/http/api-error';
import { ApiResponse } from '../../../core/http/api-response';

export type AccessStatus = 'ACTIVE' | 'PENDING' | 'DISABLED';

export interface AdminFarmMember {
  readonly id: string;
  readonly name: string;
  readonly surname?: string;
  readonly email: string;
  readonly phoneNumber?: string;
  readonly owner: boolean;
  readonly roles: readonly string[];
  readonly status: AccessStatus;
}

export interface AdminFarm {
  readonly id: string;
  readonly farmName: string;
  readonly city?: string;
  readonly createdDate?: string;
  readonly coopCount: number;
  readonly members: readonly AdminFarmMember[];
}

export interface AdminFarmPage {
  readonly items: readonly AdminFarm[];
  readonly page: number;
  readonly size: number;
  readonly total: number;
}

/** System-admin endpoints; online only, never synced or cached offline. */
@Injectable({ providedIn: 'root' })
export class AdminFarmsApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/admin/farms`;

  list(search: string, page: number, size: number): Promise<AdminFarmPage> {
    return this.unwrap(
      this.http.get<ApiResponse<AdminFarmPage>>(this.baseUrl, { params: { search, page, size } }),
    );
  }

  grant(userId: string): Promise<AdminFarmMember> {
    return this.unwrap(
      this.http.post<ApiResponse<AdminFarmMember>>(
        `${this.baseUrl}/users/${encodeURIComponent(userId)}/grant-access`,
        {},
      ),
    );
  }

  disable(userId: string): Promise<AdminFarmMember> {
    return this.unwrap(
      this.http.post<ApiResponse<AdminFarmMember>>(
        `${this.baseUrl}/users/${encodeURIComponent(userId)}/disable-access`,
        {},
      ),
    );
  }

  async remove(farmId: string): Promise<void> {
    await unwrapApi(
      this.http.delete<ApiResponse<void>>(`${this.baseUrl}/${encodeURIComponent(farmId)}`),
    );
  }

  private async unwrap<T>(request: Observable<ApiResponse<T>>): Promise<T> {
    const data = await unwrapApi(request);
    if (data === undefined) throw new Error('Empty response');
    return data;
  }
}
