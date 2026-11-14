import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { firstValueFrom } from 'rxjs';
import { liveSignal } from '../../data/db/live-signal';
import { APP_DB } from '../../data/db/app-db';
import { LocalUser } from '../../data/models/local';
import { toLocalUser } from '../../data/sync/local-store';
import { AuthService } from '../../core/auth/auth.service';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ApiError } from '../../core/http/api-error';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { ConfirmDialogService } from '../../shared/ui/confirm-dialog/confirm-dialog.service';
import { FarmRole, TeamApi } from './team-api';

@Component({
  selector: 'app-team-page',
  imports: [
    PageHeader,
    EmptyState,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
  ],
  templateUrl: './team-page.html',
  styleUrl: './team-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class TeamPage {
  private readonly db = inject(APP_DB);
  private readonly auth = inject(AuthService);
  private readonly api = inject(TeamApi);
  private readonly confirm = inject(ConfirmDialogService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly connectivity = inject(ConnectivityService);
  private readonly fb = inject(FormBuilder);
  protected readonly user = this.auth.user;
  protected readonly canManage = this.auth.canManageFarm;
  protected readonly canGrantProduction = computed(
    () => this.auth.can('FARM_OWNER') || this.auth.can('SYSTEM_ADMIN'),
  );
  protected readonly saving = signal(false);
  protected readonly showForm = signal(false);
  protected readonly teamError = signal<string | null>(null);
  protected readonly members = liveSignal(
    () =>
      this.db.users
        .toArray()
        .then((users) => users.sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '')))
        .then((users) => users.filter((member) => member.id !== this.user()?.id)),
    [],
  );
  protected readonly coops = liveSignal(
    () =>
      this.db.coops
        .toArray()
        .then((coops) => coops.sort((a, b) => a.coopName.localeCompare(b.coopName))),
    [],
  );
  protected readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
    surname: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(50)]],
    phoneNumber: ['', [Validators.required, Validators.maxLength(15)]],
    role: ['ROLE_FARM_WORKER' as FarmRole, Validators.required],
  });

  constructor() {
    if (this.connectivity.online()) {
      void this.refreshTeam().catch((error: unknown) => {
        const message =
          error instanceof ApiError ? error.message : 'Could not refresh the farm team.';
        this.teamError.set(message);
      });
    }
  }

  protected role(member: LocalUser): FarmRole {
    return member.roles?.includes('ROLE_FARM_MANAGER') ? 'ROLE_FARM_MANAGER' : 'ROLE_FARM_WORKER';
  }

  protected async addMember(): Promise<void> {
    const actor = this.user();
    if (!actor?.id || !this.connectivity.online()) {
      this.snackBar.open('Adding a team member requires an online connection.', 'OK');
      return;
    }
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.saving.set(true);
    try {
      await this.refreshTeam(await this.api.addMember(this.form.getRawValue()));
      this.form.reset({
        name: '',
        surname: '',
        email: '',
        phoneNumber: '',
        role: 'ROLE_FARM_WORKER',
      });
      this.showForm.set(false);
      this.snackBar.open('Team member added. They will receive account setup instructions.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not add this team member.');
    } finally {
      this.saving.set(false);
    }
  }

  protected async changeRole(member: LocalUser, role: FarmRole): Promise<void> {
    if (!this.connectivity.online()) return;
    this.saving.set(true);
    try {
      await this.refreshTeam(await this.api.updateRole(member.id, role));
      this.snackBar.open('Team role updated.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not update this role.');
    } finally {
      this.saving.set(false);
    }
  }

  protected async assign(member: LocalUser, coopIds: readonly string[]): Promise<void> {
    if (!this.connectivity.online()) return;
    this.saving.set(true);
    try {
      await this.refreshTeam(await this.api.assignCoops(member.id, coopIds));
      this.snackBar.open('Coop assignment updated.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not update coop assignment.');
    } finally {
      this.saving.set(false);
    }
  }

  protected async setProductionAccess(member: LocalUser, granted: boolean): Promise<void> {
    if (!this.connectivity.online()) return;
    this.saving.set(true);
    try {
      await this.refreshTeam(await this.api.setProductionAccess(member.id, granted));
      this.snackBar.open(
        granted ? 'Production access granted.' : 'Production access revoked.',
        'OK',
      );
    } catch (error) {
      this.showError(error, 'Could not update production access.');
    } finally {
      this.saving.set(false);
    }
  }

  protected hasProductionAccess(member: LocalUser): boolean {
    return member.permissions?.includes('PRODUCTION_MANAGE') ?? false;
  }

  protected async setActive(member: LocalUser, active: boolean): Promise<void> {
    if (!this.connectivity.online()) return;
    this.saving.set(true);
    try {
      await this.refreshTeam(await this.api.setActive(member.id, active));
      this.snackBar.open(active ? 'Team member activated.' : 'Team member deactivated.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not change this member’s status.');
    } finally {
      this.saving.set(false);
    }
  }

  protected async remove(member: LocalUser): Promise<void> {
    if (!this.connectivity.online()) return;
    const accepted = await firstValueFrom(
      this.confirm.confirm({
        title: 'Remove team member?',
        message: `${member.name ?? member.email ?? 'This member'} will no longer have access to this farm.`,
        confirmText: 'Remove',
        destructive: true,
      }),
    );
    if (!accepted) return;
    this.saving.set(true);
    try {
      await this.refreshTeam(await this.api.removeMember(member.id));
      this.snackBar.open('Team member removed.', 'OK');
    } catch (error) {
      this.showError(error, 'Could not remove this team member.');
    } finally {
      this.saving.set(false);
    }
  }

  private async refreshTeam(members?: Awaited<ReturnType<TeamApi['members']>>): Promise<void> {
    const response = members ?? (await this.api.members());
    const self = this.user();
    const returned = new Set(response.map((member) => member.id));
    await this.db.transaction('rw', this.db.users, async () => {
      // Members the server no longer returns (removed) must leave the local list too.
      const gone = (await this.db.users.toArray()).filter(
        (member) =>
          member.farmId === self?.farmId && member.id !== self?.id && !returned.has(member.id),
      );
      await this.db.users.bulkDelete(gone.map((member) => member.id));
      await this.db.users.bulkPut(response.map((member) => toLocalUser(member, self?.id ?? '')));
    });
    this.teamError.set(null);
  }

  private showError(error: unknown, fallback: string): void {
    this.snackBar.open(error instanceof ApiError ? error.message : fallback, 'OK');
  }
}
