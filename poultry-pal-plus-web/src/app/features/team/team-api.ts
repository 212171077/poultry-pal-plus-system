import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { APP_CONFIG } from '../../core/config/app-config';
import { ApiError, unwrapApi } from '../../core/http/api-error';
import { ApiResponse } from '../../core/http/api-response';
import { UserInfo } from '../../data/models/sync-api';

export type FarmRole = 'ROLE_FARM_MANAGER' | 'ROLE_FARM_WORKER';

export interface NewTeamMember {
  readonly name: string;
  readonly surname: string;
  readonly email: string;
  readonly phoneNumber: string;
  readonly role: FarmRole;
}

@Injectable({ providedIn: 'root' })
export class TeamApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/team`;

  members(): Promise<UserInfo[]> {
    return this.unwrap(this.http.get<ApiResponse<UserInfo[]>>(this.baseUrl));
  }

  addMember(member: NewTeamMember): Promise<UserInfo[]> {
    return this.unwrap(
      this.http.post<ApiResponse<UserInfo[]>>(this.baseUrl, {
        ...member,
        name: member.name.trim(),
        surname: member.surname.trim(),
        email: member.email.trim(),
        phoneNumber: member.phoneNumber.trim(),
      }),
    );
  }

  updateRole(userId: string, role: FarmRole): Promise<UserInfo[]> {
    return this.unwrap(
      this.http.patch<ApiResponse<UserInfo[]>>(`${this.baseUrl}/${enc(userId)}/role`, { role }),
    );
  }

  assignCoops(userId: string, coopIds: readonly string[]): Promise<UserInfo[]> {
    return this.unwrap(
      this.http.put<ApiResponse<UserInfo[]>>(`${this.baseUrl}/${enc(userId)}/coops`, { coopIds }),
    );
  }

  setActive(userId: string, active: boolean): Promise<UserInfo[]> {
    return this.unwrap(
      this.http.patch<ApiResponse<UserInfo[]>>(`${this.baseUrl}/${enc(userId)}/activation`, {
        active,
      }),
    );
  }

  removeMember(userId: string): Promise<UserInfo[]> {
    return this.unwrap(
      this.http.delete<ApiResponse<UserInfo[]>>(`${this.baseUrl}/${enc(userId)}`),
    );
  }

  private async unwrap<T>(request: Observable<ApiResponse<T>>): Promise<T> {
    const data = await unwrapApi(request);
    if (data === undefined) throw new ApiError('server', 200, 'Unexpected response');
    return data;
  }
}

function enc(value: string): string {
  return encodeURIComponent(value);
}
