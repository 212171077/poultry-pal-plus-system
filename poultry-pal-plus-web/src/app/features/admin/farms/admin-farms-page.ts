import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { firstValueFrom } from 'rxjs';
import { ApiError } from '../../../core/http/api-error';
import { ConnectivityService } from '../../../core/network/connectivity.service';
import { ConfirmDialogService } from '../../../shared/ui/confirm-dialog/confirm-dialog.service';
import { EmptyState } from '../../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../../shared/ui/page-header/page-header';
import { Toast } from '../../../shared/ui/toast/toast.service';
import { AdminFarm, AdminFarmMember, AdminFarmsApi } from './admin-farms-api';

const PAGE_SIZE = 10;

@Component({
  selector: 'app-admin-farms-page',
  imports: [
    PageHeader,
    EmptyState,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
  ],
  templateUrl: './admin-farms-page.html',
  styleUrl: './admin-farms-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class AdminFarmsPage {
  private readonly api = inject(AdminFarmsApi);
  private readonly confirm = inject(ConfirmDialogService);
  private readonly toast = inject(Toast);
  protected readonly connectivity = inject(ConnectivityService);

  protected readonly search = new FormControl('', { nonNullable: true });
  protected readonly farms = signal<readonly AdminFarm[]>([]);
  protected readonly page = signal(0);
  protected readonly total = signal(0);
  protected readonly loading = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly busyUser = signal<string | null>(null);
  protected readonly busyFarm = signal<string | null>(null);
  protected readonly pageCount = computed(() => Math.max(1, Math.ceil(this.total() / PAGE_SIZE)));

  constructor() {
    void this.load(0);
  }

  protected async find(): Promise<void> {
    await this.load(0);
  }

  protected async load(page: number): Promise<void> {
    this.loading.set(true);
    try {
      const result = await this.api.list(this.search.value.trim(), page, PAGE_SIZE);
      this.farms.set(result.items);
      this.page.set(result.page);
      this.total.set(result.total);
      this.loadError.set(null);
    } catch (error) {
      this.loadError.set(this.message(error, 'Could not load the farms.'));
    } finally {
      this.loading.set(false);
    }
  }

  protected async setAccess(member: AdminFarmMember, grant: boolean): Promise<void> {
    const name = `${member.name} ${member.surname ?? ''}`.trim();
    const confirmed = await firstValueFrom(
      this.confirm.confirm({
        title: grant ? 'Grant access?' : 'Disable access?',
        message: grant
          ? `${name} will be able to sign in and use the farm.`
          : `${name} will be signed out and unable to sign in until access is granted again.`,
        confirmText: grant ? 'Grant access' : 'Disable access',
      }),
    );
    if (!confirmed) return;
    this.busyUser.set(member.id);
    try {
      const updated = await (grant ? this.api.grant(member.id) : this.api.disable(member.id));
      this.farms.update((list) =>
        list.map((farm) => ({
          ...farm,
          members: farm.members.map((m) => (m.id === updated.id ? updated : m)),
        })),
      );
      this.toast.open(grant ? 'Access granted' : 'Access disabled');
    } catch (error) {
      this.toast.open(this.message(error, 'Could not update access.'), undefined, {
        kind: 'error',
      });
    } finally {
      this.busyUser.set(null);
    }
  }

  protected async deleteFarm(farm: AdminFarm): Promise<void> {
    const confirmed = await firstValueFrom(
      this.confirm.confirm({
        title: `Delete ${farm.farmName}?`,
        message:
          'This permanently deletes the farm, all its users and every record linked to it. This cannot be undone.',
        confirmText: 'Delete farm',
      }),
    );
    if (!confirmed) return;
    this.busyFarm.set(farm.id);
    try {
      await this.api.remove(farm.id);
      this.toast.open('Farm deleted');
      await this.load(this.farms().length === 1 && this.page() > 0 ? this.page() - 1 : this.page());
    } catch (error) {
      this.toast.open(this.message(error, 'Could not delete the farm.'), undefined, {
        kind: 'error',
      });
    } finally {
      this.busyFarm.set(null);
    }
  }

  protected label(status: string): string {
    return status === 'ACTIVE' ? 'Active' : status === 'PENDING' ? 'Pending' : 'Disabled';
  }

  private message(error: unknown, fallback: string): string {
    return error instanceof ApiError ? error.message : fallback;
  }
}
