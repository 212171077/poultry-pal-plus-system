import { NgOptimizedImage } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  Injector,
  computed,
  inject,
  input,
  signal,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { MatTooltipModule } from '@angular/material/tooltip';
import { RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth/auth.service';
import { roleLabel } from '../../core/auth/permissions';
import { APP_DB } from '../../data/db/app-db';
import { liveSignal } from '../../data/db/live-signal';
import { ThemePreference, ThemeService } from '../../core/theme/theme.service';
import { SyncBadge } from '../../shared/ui/sync-badge/sync-badge';
import { QuickAddService } from '../quick-add/quick-add.service';

interface ThemeOption {
  readonly value: ThemePreference;
  readonly label: string;
  readonly icon: string;
}

@Component({
  selector: 'app-top-bar',
  imports: [
    NgOptimizedImage,
    RouterLink,
    MatButtonModule,
    MatDividerModule,
    MatIconModule,
    MatMenuModule,
    MatTooltipModule,
    SyncBadge,
  ],
  templateUrl: './top-bar.html',
  styleUrl: './top-bar.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TopBar {
  readonly showBrand = input(false);
  readonly compact = input(false);
  /** Shows the "Quick add" menu (tablet and desktop; phones use the bottom bar's FAB). */
  readonly quickAdd = input(false);
  private readonly quickAddService = inject(QuickAddService);

  /** Opens the "Quick add" dialog; returns false when it is not shown. */
  openQuickAdd(): boolean {
    if (!this.quickAdd()) return false;
    void this.quickAddService.open();
    return true;
  }

  private readonly theme = inject(ThemeService);
  protected readonly themePreference = this.theme.preference;
  protected readonly themeIcon = computed(() => {
    if (this.theme.preference() === 'sunlight') {
      return 'wb_sunny';
    }
    return this.theme.isDark() ? 'dark_mode' : 'light_mode';
  });
  protected readonly themeOptions: readonly ThemeOption[] = [
    { value: 'system', label: 'Dawn & Dusk', icon: 'brightness_auto' },
    { value: 'meadow', label: 'Meadow', icon: 'eco' },
    { value: 'dark', label: 'Farm night', icon: 'dark_mode' },
    { value: 'sunlight', label: 'Sunlight (high contrast)', icon: 'wb_sunny' },
  ];

  private readonly auth = inject(AuthService);
  private readonly injector = inject(Injector);
  private readonly db = inject(APP_DB);

  protected readonly user = this.auth.user;
  protected readonly displayName = this.auth.displayName;
  protected readonly role = computed(() => roleLabel(this.auth.user()));
  protected readonly initials = computed(() => {
    const user = this.auth.user();
    const letters = [user?.name, user?.surname]
      .map((part) => part?.trim().charAt(0) ?? '')
      .join('');
    return (letters || user?.email?.charAt(0) || '').toUpperCase();
  });
  protected readonly farmName = liveSignal(
    async () => (await this.db.farms.toCollection().first())?.farmName ?? null,
    null,
  );
  protected readonly signingOut = signal(false);

  protected setTheme(preference: ThemePreference): void {
    this.theme.setPreference(preference);
  }

  protected async signOut(): Promise<void> {
    this.signingOut.set(true);
    try {
      await this.auth.signOut(async (count) => {
        // Loaded on demand: the confirm dialog is rarely needed from the top bar.
        const { ConfirmDialogService } =
          await import('../../shared/ui/confirm-dialog/confirm-dialog.service');
        return firstValueFrom(
          this.injector.get(ConfirmDialogService).confirm({
            title: 'Sign out and lose unsynced changes?',
            message:
              `${count === 1 ? '1 change has' : `${count} changes have`} not reached the server ` +
              'yet. Signing out removes all farm data from this device, including these changes. ' +
              'Connect to the internet and let them sync first to keep them.',
            confirmText: 'Sign out anyway',
            cancelText: 'Stay signed in',
            destructive: true,
          }),
        );
      });
    } finally {
      this.signingOut.set(false);
    }
  }
}
