import { DOCUMENT } from '@angular/common';
import { strongPassword, PASSWORD_RULES_HINT } from '../../shared/validators/password-rules';
import { ChangeDetectionStrategy, Component, effect, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { SwUpdate } from '@angular/service-worker';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth/auth.service';
import { ApiError } from '../../core/http/api-error';
import { AppUpdateService } from '../../core/pwa/app-update.service';
import { InstallPromptService } from '../../core/pwa/install-prompt.service';
import { ThemePreference, ThemeService } from '../../core/theme/theme.service';
import { APP_DB } from '../../data/db/app-db';
import { liveSignal } from '../../data/db/live-signal';
import { LocalFarm, LocalSettings } from '../../data/models/local';
import { SyncEngine } from '../../data/sync/sync-engine';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ConfirmDialogService } from '../../shared/ui/confirm-dialog/confirm-dialog.service';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { FarmDetailsUpdate, FarmSettingsApi, ProfileUpdate } from './farm-settings-api';

const CURRENCIES = ['ZAR', 'BWP', 'KES', 'NGN', 'TZS', 'UGX', 'USD', 'EUR', 'GBP'] as const;

@Component({
  selector: 'app-settings-page',
  imports: [
    PageHeader,
    ReactiveFormsModule,
    MatButtonModule,
    MatButtonToggleModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './settings-page.html',
  styleUrl: './settings-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class SettingsPage {
  protected readonly passwordHint = PASSWORD_RULES_HINT;
  private readonly db = inject(APP_DB);
  private readonly auth = inject(AuthService);
  private readonly api = inject(FarmSettingsApi);
  private readonly engine = inject(SyncEngine);
  private readonly connectivity = inject(ConnectivityService);
  private readonly confirm = inject(ConfirmDialogService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly theme = inject(ThemeService);
  private readonly installPrompt = inject(InstallPromptService);
  private readonly updates = inject(AppUpdateService);
  protected readonly updatesEnabled = inject(SwUpdate).isEnabled;
  private readonly document = inject(DOCUMENT);
  private readonly fb = inject(FormBuilder);
  protected readonly user = this.auth.user;
  protected readonly canManage = this.auth.canManageFarm;
  protected readonly themePreference = this.theme.preference;
  protected readonly canInstall = this.installPrompt.canInstall;
  protected readonly updateState = this.updates.state;
  protected readonly currencies = CURRENCIES;
  protected readonly savingProfile = signal(false);
  protected readonly savingPassword = signal(false);
  protected readonly savingFarm = signal(false);
  protected readonly savingCurrency = signal(false);
  protected readonly clearing = signal(false);
  protected readonly storageUsage = signal('Checking storage…');
  protected readonly localDataMessage = signal<string | null>(null);

  protected readonly profileForm = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
    surname: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(50)]],
    phoneNumber: ['', [Validators.required, Validators.maxLength(15)]],
  });
  protected readonly passwordForm = this.fb.nonNullable.group({
    currentPassword: ['', Validators.required],
    newPassword: ['', [Validators.required, Validators.minLength(8), strongPassword]],
    confirmPassword: ['', Validators.required],
  });
  protected readonly farmForm = this.fb.nonNullable.group({
    farmName: ['', Validators.required],
    addressLine1: [''],
    addressLine2: [''],
    state: [''],
    city: [''],
    postalCode: [''],
    country: [''],
  });
  protected readonly currencyForm = this.fb.nonNullable.group({
    currency: ['ZAR', Validators.required],
  });

  private currentFarm: LocalFarm | undefined;
  private currentSettings: LocalSettings | undefined;

  // The farm row and settings can arrive after the page opens (first sync), so follow the local
  // store and fill the forms until the user starts editing them.
  private readonly farmRow = liveSignal(() => {
    const farmId = this.user()?.farmId;
    return farmId ? this.db.farms.get(farmId) : undefined;
  });
  private readonly settingsRow = liveSignal(() => {
    const userId = this.user()?.id;
    return userId ? this.db.settings.get(userId) : undefined;
  });

  constructor() {
    void this.load();
    effect(() => {
      const farm = this.farmRow();
      if (!farm) return;
      this.currentFarm = farm;
      if (this.farmForm.dirty) return;
      this.farmForm.patchValue({
        farmName: farm.farmName,
        addressLine1: farm.address?.addressLine1 ?? '',
        addressLine2: farm.address?.addressLine2 ?? '',
        state: farm.address?.state ?? '',
        city: farm.address?.city ?? '',
        postalCode: farm.address?.postalCode ?? '',
        country: farm.address?.country ?? '',
      });
    });
    effect(() => {
      const settings = this.settingsRow();
      if (!settings) return;
      this.currentSettings = settings;
      if (!this.currencyForm.dirty) {
        this.currencyForm.patchValue({ currency: settings.currency || 'ZAR' });
      }
    });
  }

  protected setTheme(preference: ThemePreference): void {
    this.theme.setPreference(preference);
  }

  protected install(): void {
    void this.installPrompt.promptInstall();
  }

  protected async saveProfile(): Promise<void> {
    const user = this.user();
    const farmId = user?.farmId;
    if (!user || !farmId || !this.onlineOrWarn()) return;
    if (this.profileForm.invalid) {
      this.profileForm.markAllAsTouched();
      return;
    }
    this.savingProfile.set(true);
    try {
      const profile: ProfileUpdate = this.profileForm.getRawValue();
      const updatedProfile = await this.api.updateProfile(profile);
      await this.db.users.update(user.id, {
        name: updatedProfile.name ?? profile.name,
        surname: updatedProfile.surname ?? profile.surname,
        email: updatedProfile.email ?? profile.email,
        phoneNumber: updatedProfile.phoneNumber ?? profile.phoneNumber,
      });
      this.snackBar.open('Your profile was updated.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not update your profile.');
    } finally {
      this.savingProfile.set(false);
    }
  }

  protected async changePassword(): Promise<void> {
    const { currentPassword, newPassword, confirmPassword } = this.passwordForm.getRawValue();
    if (!this.user()?.id || !this.onlineOrWarn()) return;
    if (this.passwordForm.invalid || newPassword !== confirmPassword) {
      this.passwordForm.markAllAsTouched();
      if (newPassword !== confirmPassword) {
        this.snackBar.open('The new passwords do not match.', 'OK');
      }
      return;
    }
    this.savingPassword.set(true);
    try {
      await this.api.changePassword(currentPassword, newPassword);
      this.passwordForm.reset();
      this.snackBar.open('Your password was changed.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not change your password.');
    } finally {
      this.savingPassword.set(false);
    }
  }

  protected async saveFarm(): Promise<void> {
    if (!this.user()?.id || !this.currentFarm || !this.onlineOrWarn()) return;
    if (this.farmForm.invalid) {
      this.farmForm.markAllAsTouched();
      return;
    }
    this.savingFarm.set(true);
    try {
      const details: FarmDetailsUpdate = this.farmForm.getRawValue();
      await this.api.updateFarm(details);
      await this.engine.redownload();
      this.currentFarm = await this.db.farms.get(this.currentFarm.id);
      this.snackBar.open('Farm details were updated.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not update farm details.');
    } finally {
      this.savingFarm.set(false);
    }
  }

  protected async saveCurrency(): Promise<void> {
    const user = this.user();
    if (!user?.id || !user.farmId || !this.onlineOrWarn()) return;
    this.savingCurrency.set(true);
    try {
      const settings: LocalSettings = {
        ...this.currentSettings,
        userId: user.id,
        farmId: user.farmId,
        currency: this.currencyForm.controls.currency.value,
      };
      const savedSettings = await this.api.updateCurrency(settings.currency ?? 'ZAR');
      const updatedSettings: LocalSettings = { ...settings, ...savedSettings };
      await this.db.settings.put(updatedSettings);
      this.currentSettings = updatedSettings;
      this.snackBar.open('Currency preference saved.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not save your currency preference.');
    } finally {
      this.savingCurrency.set(false);
    }
  }

  protected async checkForUpdates(): Promise<void> {
    await this.updates.checkForUpdate();
    if (this.updateState() === 'current') {
      this.snackBar.open('You are using the latest available version.', 'OK');
    } else if (this.updateState() === 'error') {
      this.snackBar.open('Could not check for updates. Check your connection and try again.', 'OK');
    }
  }

  protected async clearLocalData(): Promise<void> {
    if (!this.connectivity.online()) {
      this.localDataMessage.set('Connect to the internet before clearing local data.');
      return;
    }
    const queued = await this.db.outbox.count();
    if (queued > 0) {
      this.localDataMessage.set(
        `${queued} unsynced change${queued === 1 ? '' : 's'} remain. Sync them in Sync Center before clearing local data.`,
      );
      return;
    }
    const queuedReports = await this.db.reportRequests.count();
    const accepted = await firstValueFrom(
      this.confirm.confirm({
        title: 'Clear local data?',
        message: `This removes farm records, saved report requests${queuedReports ? ` (${queuedReports} queued)` : ''} and app sync state stored on this device. The app will download a fresh copy from the server. Your account will remain signed in.`,
        confirmText: 'Clear local data',
        destructive: true,
      }),
    );
    if (!accepted) return;
    this.clearing.set(true);
    this.localDataMessage.set(null);
    try {
      await this.db.transaction('rw', this.db.tables, async () => {
        if (await this.db.outbox.count()) {
          throw new Error(
            'New unsynced changes were created. Sync them before clearing local data.',
          );
        }
        for (const table of this.db.tables) await table.clear();
      });
      const restored = await this.engine.redownload();
      if (!restored) throw new Error('The server could not restore the farm data.');
      await this.refreshStorageUsage();
      this.localDataMessage.set('Local data was cleared and downloaded again.');
    } catch (error) {
      this.localDataMessage.set(
        error instanceof Error ? error.message : 'Local data was cleared, but refresh failed.',
      );
    } finally {
      this.clearing.set(false);
    }
  }

  private async load(): Promise<void> {
    const user = this.user();
    if (user) {
      this.profileForm.patchValue({
        name: user.name ?? '',
        surname: user.surname ?? '',
        email: user.email ?? '',
        phoneNumber: user.phoneNumber ?? '',
      });
    }
    await this.refreshStorageUsage();
  }

  private async refreshStorageUsage(): Promise<void> {
    try {
      const estimate = await this.document.defaultView?.navigator.storage?.estimate();
      this.storageUsage.set(
        estimate?.usage === undefined
          ? 'Storage usage is not available in this browser.'
          : `${formatBytes(estimate.usage)} used${estimate.quota ? ` of ${formatBytes(estimate.quota)}` : ''}`,
      );
    } catch {
      this.storageUsage.set('Storage usage could not be read in this browser.');
    }
  }

  private onlineOrWarn(): boolean {
    if (this.connectivity.online()) return true;
    this.snackBar.open('This setting requires an online connection.', 'OK');
    return false;
  }

  private showError(error: unknown, fallback: string): void {
    this.snackBar.open(error instanceof ApiError ? error.message : fallback, 'OK');
  }
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KB', 'MB', 'GB'];
  let value = bytes / 1024;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(1)} ${units[unit]}`;
}
