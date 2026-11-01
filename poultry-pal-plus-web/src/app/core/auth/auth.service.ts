import { DOCUMENT, DestroyRef, Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { liveQuery } from 'dexie';
import { APP_DB } from '../../data/db/app-db';
import { LocalUser } from '../../data/models/local';
import { UserInfo } from '../../data/models/sync-api';
import {
  clearLocalData,
  currentUser,
  getMeta,
  setMeta,
  toLocalUser,
} from '../../data/sync/local-store';
import { SyncEngine } from '../../data/sync/sync-engine';
import { ApiError } from '../http/api-error';
import { ConnectivityService } from '../network/connectivity.service';
import { AuthApi, SignUpRequest } from './auth-api';
import { Permission, fullName, hasPermission } from './permissions';

/** Session cookie (no expiry) that marks "this browser session has signed in". */
const SESSION_COOKIE = 'pp_session';
const CHANNEL_NAME = 'pp-auth';
const SYNC_BEFORE_SIGN_OUT_MS = 10_000;

export interface Credentials {
  readonly email: string;
  readonly password: string;
  readonly rememberMe: boolean;
}

/** Signing in as someone else would discard the previous user's unsynced changes. */
export interface AccountSwitch {
  readonly unsyncedCount: number;
  readonly previousName: string;
}

export type SignInOutcome = 'signed-in' | 'cancelled';

interface AuthMessage {
  readonly type: 'signed-in' | 'signed-out';
}

/**
 * The session on this device. The signed-in profile is cached in IndexedDB, so someone who signed
 * in before can open the app and keep working offline; the server session (HttpOnly cookies) only
 * matters for syncing. When it expires the sync engine pauses and the shell asks the user to sign
 * in again, without touching unsynced work. Local data is wiped only on an explicit sign-out or
 * when a different account signs in on this device (after a warning).
 *
 * "Keep me signed in" off: the refresh cookie and a marker cookie last for the browser session
 * only, so the next browser session starts at the sign-in page (unsynced data is kept for that
 * same user).
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly db = inject(APP_DB);
  private readonly api = inject(AuthApi);
  private readonly engine = inject(SyncEngine);
  private readonly connectivity = inject(ConnectivityService);
  private readonly router = inject(Router);
  private readonly document = inject(DOCUMENT);
  private readonly window = this.document.defaultView;

  private readonly userState = signal<LocalUser | null>(null);
  private restored: Promise<boolean> | null = null;
  private readonly channel =
    typeof BroadcastChannel === 'function' ? new BroadcastChannel(CHANNEL_NAME) : null;

  readonly user = this.userState.asReadonly();
  readonly signedIn = computed(() => this.userState() !== null);
  readonly displayName = computed(
    () => fullName(this.userState()) || this.userState()?.email || '',
  );
  readonly canManageFarm = computed(() => hasPermission(this.userState(), 'FARM_MANAGER'));

  constructor() {
    // Bootstrap and later pulls refresh the cached profile (roles, assigned coops).
    const profile = liveQuery(() => currentUser(this.db)).subscribe({
      next: (user) => {
        if (user && this.userState()?.id === user.id) this.userState.set(user);
      },
      error: (error: unknown) => console.error('Profile query failed', error),
    });
    if (this.channel) {
      this.channel.onmessage = ({ data }: MessageEvent<AuthMessage>) => void this.onOtherTab(data);
    }
    inject(DestroyRef).onDestroy(() => {
      profile.unsubscribe();
      this.channel?.close();
    });
  }

  /** Loads the cached session once at start-up. Resolves to whether someone is signed in. */
  restore(): Promise<boolean> {
    this.restored ??= this.loadSession();
    return this.restored;
  }

  can(permission: Permission): boolean {
    return hasPermission(this.userState(), permission);
  }

  /**
   * Signs in online. When a different account than the cached one signs in, the local data is
   * replaced; if it holds unsynced changes, `confirmSwitch` must agree first.
   */
  async signIn(
    credentials: Credentials,
    confirmSwitch: (info: AccountSwitch) => Promise<boolean>,
  ): Promise<SignInOutcome> {
    const info = await this.api.signIn({
      username: credentials.email.trim(),
      password: credentials.password,
      rememberMe: credentials.rememberMe,
    });
    const previousId =
      (await getMeta<string>(this.db, 'userId')) ?? (await currentUser(this.db))?.id ?? null;
    if (previousId && previousId !== info.id) {
      const unsyncedCount = await this.db.outbox.count();
      if (unsyncedCount > 0) {
        const previous = await this.db.users.get(previousId);
        const previousName = fullName(previous) || previous?.email || 'another user';
        if (!(await confirmSwitch({ unsyncedCount, previousName }))) {
          await this.api.signOut().catch(() => undefined);
          return 'cancelled';
        }
      }
      this.engine.suspend();
      await clearLocalData(this.db);
    }
    await this.startSession(info, credentials.rememberMe);
    return 'signed-in';
  }

  /** Registers a new farm owner and their farm; an administrator must approve it before sign-in. */
  async signUp(request: SignUpRequest): Promise<void> {
    await this.api.signUp(request);
  }

  /** Renews an expired server session for the signed-in user; local data stays as it is. */
  async reauthenticate(password: string): Promise<void> {
    const user = this.userState();
    if (!user?.email) {
      throw new ApiError('unauthorized', 401, 'Please sign out and sign in again.');
    }
    const rememberMe = (await getMeta<number>(this.db, 'rememberMe')) !== 0;
    const info = await this.api.signIn({ username: user.email, password, rememberMe });
    if (info.id !== user.id) {
      await this.api.signOut().catch(() => undefined);
      throw new ApiError('forbidden', 403, 'That is a different account. Sign out first.');
    }
    this.markBrowserSession();
    this.broadcast('signed-in');
    void this.engine.syncNow();
  }

  /**
   * Signs out and wipes this device. Tries to sync first; if changes are still unsynced,
   * `confirmLoss` decides. Resolves to `false` when the user cancelled.
   */
  async signOut(confirmLoss: (unsyncedCount: number) => Promise<boolean>): Promise<boolean> {
    if (this.connectivity.browserOnline() && (await this.db.outbox.count()) > 0) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      await Promise.race([
        this.engine.syncNow(),
        new Promise((resolve) => (timer = setTimeout(resolve, SYNC_BEFORE_SIGN_OUT_MS))),
      ]);
      clearTimeout(timer);
    }
    const unsynced = await this.db.outbox.count();
    if (unsynced > 0 && !(await confirmLoss(unsynced))) return false;

    this.engine.suspend();
    try {
      await this.api.signOut();
    } catch {
      // Offline: the server session simply expires; this device no longer uses it.
    }
    await clearLocalData(this.db);
    this.endSession();
    this.broadcast('signed-out');
    await this.router.navigateByUrl('/login');
    return true;
  }

  private async loadSession(): Promise<boolean> {
    const user = await currentUser(this.db);
    if (!user) return false;
    const rememberMe = await getMeta<number>(this.db, 'rememberMe');
    if (rememberMe === 0 && !this.hasBrowserSession()) return false;
    this.userState.set(user);
    return true;
  }

  private async startSession(info: UserInfo, rememberMe: boolean): Promise<void> {
    const user = toLocalUser(info, info.id);
    await this.db.transaction('rw', this.db.users, this.db.syncMeta, async () => {
      await this.db.users
        .filter((other) => other.current === true && other.id !== info.id)
        .modify({ current: false });
      const cached = await this.db.users.get(info.id);
      await this.db.users.put({ ...cached, ...user });
      await setMeta(this.db, 'userId', info.id);
      await setMeta(this.db, 'farmId', info.farmId ?? null);
      await setMeta(this.db, 'rememberMe', rememberMe ? 1 : 0);
    });
    this.markBrowserSession();
    this.userState.set(user);
    this.restored = Promise.resolve(true);
    this.broadcast('signed-in');
    void this.engine.resume();
  }

  private endSession(): void {
    this.userState.set(null);
    this.restored = Promise.resolve(false);
    this.document.cookie = `${SESSION_COOKIE}=; path=/; max-age=0; SameSite=Lax`;
  }

  private async onOtherTab(message: AuthMessage | undefined): Promise<void> {
    if (message?.type === 'signed-out' && this.userState()) {
      this.engine.suspend();
      this.endSession();
      await this.router.navigateByUrl('/login');
    } else if (message?.type === 'signed-in') {
      const wasSignedIn = this.userState() !== null;
      this.restored = null;
      if (!(await this.restore())) return;
      void this.engine.resume();
      if (!wasSignedIn && this.router.url.startsWith('/login')) {
        await this.router.navigateByUrl('/dashboard');
      }
    }
  }

  private broadcast(type: AuthMessage['type']): void {
    this.channel?.postMessage({ type } satisfies AuthMessage);
  }

  private markBrowserSession(): void {
    const secure = this.window?.location.protocol === 'https:' ? '; Secure' : '';
    this.document.cookie = `${SESSION_COOKIE}=1; path=/; SameSite=Lax${secure}`;
  }

  private hasBrowserSession(): boolean {
    return this.document.cookie.split(';').some((part) => part.trim() === `${SESSION_COOKIE}=1`);
  }
}

/** Only same-app paths are allowed as a post-login redirect (no `//evil.com` or full URLs). */
export function safeReturnUrl(url: string | null | undefined): string {
  return url && url.startsWith('/') && !url.startsWith('//') && !url.startsWith('/login')
    ? url
    : '/dashboard';
}
