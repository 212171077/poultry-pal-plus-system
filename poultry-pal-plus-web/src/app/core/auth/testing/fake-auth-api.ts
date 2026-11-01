import { Provider } from '@angular/core';
import { UserInfo } from '../../../data/models/sync-api';
import { ApiError } from '../../http/api-error';
import { AuthApi, SignInRequest, SignUpRequest } from '../auth-api';

interface Account {
  readonly user: UserInfo;
  readonly password: string;
}

/** In-memory `/api/v1/auth` for unit tests. */
export class FakeAuthApi implements Pick<AuthApi, 'signIn' | 'signUp' | 'signOut'> {
  readonly accounts = new Map<string, Account>();
  readonly signIns: SignInRequest[] = [];
  signOutCalls = 0;
  /** When set, the next call fails with this error. */
  failWith: ApiError | null = null;

  addAccount(user: UserInfo, password = 'secret1'): void {
    this.accounts.set(user.email ?? user.id, { user, password });
  }

  async signIn(request: SignInRequest): Promise<UserInfo> {
    this.throwIfFailing();
    this.signIns.push(request);
    const account = this.accounts.get(request.username);
    if (!account || account.password !== request.password) {
      throw new ApiError('unauthorized', 401, 'Bad credentials', 'INVALID_CREDENTIALS');
    }
    return account.user;
  }

  async signUp(request: SignUpRequest): Promise<void> {
    this.throwIfFailing();
    if (this.accounts.has(request.email)) {
      throw new ApiError('conflict', 409, 'Email is already in use', 'CONFLICT');
    }
    const n = this.accounts.size + 1;
    this.addAccount(
      {
        id: `user-${n}`,
        name: request.name,
        surname: request.surname,
        email: request.email,
        farmId: `farm-${n}`,
        farmOwner: true,
        active: true,
        roles: ['ROLE_USER', 'ROLE_FARM_MANAGER'],
      },
      request.password,
    );
  }

  async signOut(): Promise<void> {
    this.signOutCalls++;
    this.throwIfFailing();
  }

  private throwIfFailing(): void {
    const error = this.failWith;
    this.failWith = null;
    if (error) throw error;
  }
}

export function provideFakeAuthApi(api: FakeAuthApi): Provider {
  return { provide: AuthApi, useValue: api };
}
