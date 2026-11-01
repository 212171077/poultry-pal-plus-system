import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { APP_CONFIG } from '../config/app-config';
import { ApiResponse } from '../http/api-response';
import { ApiError, unwrapApi } from '../http/api-error';
import { UserInfo } from '../../data/models/sync-api';

export interface SignInRequest {
  readonly username: string;
  readonly password: string;
  readonly rememberMe: boolean;
}

/** Mirrors `SignupRequest.java`: registers a farm owner together with their farm. */
export interface SignUpRequest {
  readonly name: string;
  readonly surname: string;
  readonly email: string;
  readonly phoneNumber: string;
  readonly password: string;
  readonly farmName: string;
  readonly farmAddressLine1?: string | null;
  readonly farmAddressLine2?: string | null;
  readonly farmCity?: string | null;
  readonly farmState?: string | null;
  readonly farmPostalCode?: string | null;
  readonly farmCountry?: string | null;
}

/** Client for `/api/v1/auth`. Session tokens live in HttpOnly cookies set by the server. */
@Injectable({ providedIn: 'root' })
export class AuthApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/auth`;

  async signIn(request: SignInRequest): Promise<UserInfo> {
    const user = await unwrapApi(
      this.http.post<ApiResponse<UserInfo>>(`${this.baseUrl}/signin`, request),
    );
    if (!user) throw new ApiError('server', 200, 'Unexpected response');
    return user;
  }

  async signUp(request: SignUpRequest): Promise<void> {
    await unwrapApi(this.http.post<ApiResponse<null>>(`${this.baseUrl}/signup`, request));
  }

  /** Emails a 6-digit reset code. The server answers the same whether or not the email exists. */
  async forgotPassword(email: string): Promise<void> {
    await unwrapApi(
      this.http.post<ApiResponse<null>>(`${this.baseUrl}/forgot-password`, { email }),
    );
  }

  async resetPassword(email: string, code: string, newPassword: string): Promise<void> {
    await unwrapApi(
      this.http.post<ApiResponse<null>>(`${this.baseUrl}/reset-password`, {
        email,
        code,
        newPassword,
      }),
    );
  }

  /** Revokes the refresh token and clears the auth cookies. */
  async signOut(): Promise<void> {
    await unwrapApi(this.http.post<ApiResponse<null>>(`${this.baseUrl}/logout`, null));
  }
}
