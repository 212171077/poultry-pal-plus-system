import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { APP_CONFIG } from '../../core/config/app-config';
import { ApiResponse } from '../../core/http/api-response';
import { unwrapApi } from '../../core/http/api-error';
import { FarmSnapshot, UserInfo, UserSettings } from '../../data/models/sync-api';

@Injectable({ providedIn: 'root' })
export class FarmSettingsApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1`;

  async updateProfile(profile: ProfileUpdate): Promise<UserInfo> {
    const user = await unwrapApi(
      this.http.patch<ApiResponse<UserInfo>>(`${this.baseUrl}/auth/profile`, {
        name: profile.name.trim(),
        surname: profile.surname.trim(),
        email: profile.email.trim(),
        phoneNumber: profile.phoneNumber.trim(),
      }),
    );
    if (!user) throw new Error('The server did not return the updated profile.');
    return user;
  }

  async changePassword(currentPassword: string, newPassword: string): Promise<void> {
    await unwrapApi(
      this.http.patch<ApiResponse<null>>(`${this.baseUrl}/account/password`, {
        currentPassword,
        newPassword,
      }),
    );
  }

  async updateFarm(details: FarmDetailsUpdate): Promise<FarmSnapshot> {
    const farm = await unwrapApi(
      this.http.patch<ApiResponse<FarmSnapshot>>(`${this.baseUrl}/farm/details`, {
        farmName: details.farmName.trim(),
        addressLine1: details.addressLine1.trim(),
        addressLine2: details.addressLine2.trim(),
        state: details.state.trim(),
        city: details.city.trim(),
        postalCode: details.postalCode.trim(),
        country: details.country.trim(),
      }),
    );
    if (!farm) throw new Error('The server did not return the updated farm.');
    return farm;
  }

  async updateCurrency(currency: string): Promise<UserSettings> {
    const settings = await unwrapApi(
      this.http.put<ApiResponse<UserSettings>>(`${this.baseUrl}/account/settings/currency`, {
        currency,
      }),
    );
    if (!settings) throw new Error('The server did not return the updated currency preference.');
    return settings;
  }
}

export interface ProfileUpdate {
  readonly name: string;
  readonly surname: string;
  readonly email: string;
  readonly phoneNumber: string;
}

export interface FarmDetailsUpdate {
  readonly farmName: string;
  readonly addressLine1: string;
  readonly addressLine2: string;
  readonly state: string;
  readonly city: string;
  readonly postalCode: string;
  readonly country: string;
}
