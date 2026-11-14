import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSnackBar } from '@angular/material/snack-bar';
import { firstValueFrom } from 'rxjs';
import { ApiError } from '../../../core/http/api-error';
import { ConnectivityService } from '../../../core/network/connectivity.service';
import { ConfirmDialogService } from '../../../shared/ui/confirm-dialog/confirm-dialog.service';
import { EmptyState } from '../../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../../shared/ui/page-header/page-header';
import { AppConfigApi, AppConfigEntry } from './app-config-api';

@Component({
  selector: 'app-app-config-page',
  imports: [
    PageHeader,
    EmptyState,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
  ],
  templateUrl: './app-config-page.html',
  styleUrl: './app-config-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class AppConfigPage {
  private readonly api = inject(AppConfigApi);
  private readonly confirm = inject(ConfirmDialogService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly fb = inject(FormBuilder);
  protected readonly connectivity = inject(ConnectivityService);

  protected readonly entries = signal<readonly AppConfigEntry[]>([]);
  protected readonly loading = signal(false);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formOpen = signal(false);
  protected readonly editing = signal<AppConfigEntry | null>(null);

  protected readonly form = this.fb.nonNullable.group({
    code: [
      '',
      [Validators.required, Validators.maxLength(50), Validators.pattern(/^[A-Za-z0-9_]+$/)],
    ],
    description: ['', [Validators.maxLength(250)]],
  });

  constructor() {
    void this.load();
  }

  protected async load(): Promise<void> {
    this.loading.set(true);
    try {
      this.entries.set(await this.api.list());
      this.loadError.set(null);
    } catch (error) {
      this.loadError.set(this.message(error, 'Could not load the configuration.'));
    } finally {
      this.loading.set(false);
    }
  }

  protected openCreate(): void {
    this.editing.set(null);
    this.form.reset({ code: '', description: '' });
    this.form.controls.code.enable();
    this.formOpen.set(true);
  }

  protected openEdit(entry: AppConfigEntry): void {
    this.editing.set(entry);
    this.form.reset({ code: entry.code, description: entry.sensitive ? '' : entry.description });
    this.form.controls.code.disable();
    this.formOpen.set(true);
  }

  protected closeForm(): void {
    this.formOpen.set(false);
    this.editing.set(null);
  }

  protected async save(): Promise<void> {
    const current = this.editing();
    const { code, description } = this.form.getRawValue();
    // A secret may stay blank on edit (keeps the stored value); everything else needs a value.
    if (!description.trim() && !(current?.sensitive ?? false)) {
      this.form.controls.description.setErrors({ required: true });
    }
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.saving.set(true);
    try {
      if (current) {
        await this.api.update(current.id, { description });
      } else {
        await this.api.create({ code, description });
      }
      this.closeForm();
      this.snackBar.open(current ? 'Configuration updated.' : 'Configuration created.', 'OK');
      await this.load();
    } catch (error) {
      this.snackBar.open(this.message(error, 'Could not save the configuration.'), 'OK');
    } finally {
      this.saving.set(false);
    }
  }

  protected async remove(entry: AppConfigEntry): Promise<void> {
    const accepted = await firstValueFrom(
      this.confirm.confirm({
        title: 'Delete configuration?',
        message: `${entry.code} will be permanently removed.`,
        confirmText: 'Delete',
        destructive: true,
      }),
    );
    if (!accepted) return;
    this.saving.set(true);
    try {
      await this.api.remove(entry.id);
      this.snackBar.open('Configuration deleted.', 'OK');
      await this.load();
    } catch (error) {
      this.snackBar.open(this.message(error, 'Could not delete the configuration.'), 'OK');
    } finally {
      this.saving.set(false);
    }
  }

  private message(error: unknown, fallback: string): string {
    return error instanceof ApiError ? error.message : fallback;
  }
}
