import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
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
      }),
    );
    if (!farm) throw new Error('The server did not return the updated farm.');
    return farm;
  }

  addAddress(address: FarmAddressInput): Promise<FarmSnapshot> {
    return this.addressCall(
      this.http.post<ApiResponse<FarmSnapshot>>(`${this.baseUrl}/farm/addresses`, body(address)),
    );
  }

  updateAddress(id: string, address: FarmAddressInput): Promise<FarmSnapshot> {
    return this.addressCall(
      this.http.put<ApiResponse<FarmSnapshot>>(
        `${this.baseUrl}/farm/addresses/${encodeURIComponent(id)}`,
        body(address),
      ),
    );
  }

  deleteAddress(id: string): Promise<FarmSnapshot> {
    return this.addressCall(
      this.http.delete<ApiResponse<FarmSnapshot>>(
        `${this.baseUrl}/farm/addresses/${encodeURIComponent(id)}`,
      ),
    );
  }

  private async addressCall(request: Observable<ApiResponse<FarmSnapshot>>): Promise<FarmSnapshot> {
    const farm = await unwrapApi(request);
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
}

export interface FarmAddressInput {
  readonly label: string;
  readonly addressLine1: string;
  readonly addressLine2: string;
  readonly city: string;
  readonly state: string;
  readonly postalCode: string;
  readonly country: string;
}

function body(address: FarmAddressInput): FarmAddressInput {
  return {
    label: address.label.trim(),
    addressLine1: address.addressLine1.trim(),
    addressLine2: address.addressLine2.trim(),
    city: address.city.trim(),
    state: address.state.trim(),
    postalCode: address.postalCode.trim(),
    country: address.country.trim(),
  };
}
