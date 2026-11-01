import { DestroyRef, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ActivatedRoute, Router } from '@angular/router';
import { filter, switchMap } from 'rxjs';
import { AuthService } from '../../core/auth/auth.service';
import { liveSignal } from '../../data/db/live-signal';
import { LocalCoop } from '../../data/models/local';
import { CoopRepository, FarmContextRepository } from '../../data/repositories/repositories';
import { ConfirmDialogService } from '../ui/confirm-dialog/confirm-dialog.service';

/** What every record form needs: the coops to choose from and who is recording. */
export interface RecordFormContext {
  readonly coops: readonly LocalCoop[];
  readonly recordedBy: string | null;
  /** Coop to preselect (from `?coop=<id>`, e.g. when coming from a coop card). */
  readonly coopId?: string | null;
}

/**
 * Shared behaviour of the record list pages (sales, mortality, eggs): opening the form from
 * `?action=new` (Quick Add, coop cards), checking that a coop exists, and confirming deletes.
 */
export abstract class RecordListPage<T> {
  protected readonly coopsRepo = inject(CoopRepository);
  protected readonly context = inject(FarmContextRepository);
  protected readonly auth = inject(AuthService);
  protected readonly dialog = inject(MatDialog);
  protected readonly snackBar = inject(MatSnackBar);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  protected readonly coops = liveSignal(() => this.coopsRepo.listSorted(), []);
  protected readonly settings = liveSignal(() => this.context.settings());

  constructor() {
    this.route.queryParamMap
      .pipe(
        filter((params) => params.get('action') === 'new'),
        takeUntilDestroyed(inject(DestroyRef)),
      )
      .subscribe((params) => {
        const coopId = params.get('coop');
        void this.router.navigate([], {
          queryParams: { action: null, coop: null },
          queryParamsHandling: 'merge',
          replaceUrl: true,
        });
        void this.openForm(undefined, coopId);
      });
  }

  /** Opens the create (no record) or edit form. */
  protected abstract openForm(record?: T, coopId?: string | null): Promise<void>;

  /**
   * Coops the user may record against, or `null` (after telling the user why) when there are none.
   * `only` narrows the coops, e.g. to layer coops for egg packaging.
   */
  protected async formContext(
    coopId?: string | null,
    only?: { readonly filter: (coop: LocalCoop) => boolean; readonly emptyMessage: string },
  ): Promise<RecordFormContext | null> {
    const all = await this.coopsRepo.listSorted();
    const coops = only ? all.filter(only.filter) : all;
    if (coops.length === 0) {
      const message =
        all.length > 0 && only
          ? only.emptyMessage
          : this.auth.canManageFarm()
            ? 'Add a coop first. Coops sync from your farm when you are online.'
            : 'No coops are assigned to you yet. Ask your farm manager to assign one.';
      this.snackBar.open(message, 'OK', { duration: 5000 });
      return null;
    }
    const user = await this.context.currentUser();
    const recordedBy = user ? [user.name, user.surname].filter(Boolean).join(' ') || null : null;
    return { coops, recordedBy, coopId: coops.some((c) => c.id === coopId) ? coopId : null };
  }

  protected confirmDelete(
    title: string,
    message: string,
    remove: () => Promise<void>,
    done: string,
  ): void {
    this.confirmDialog
      .confirm({ title, message, confirmText: 'Delete', destructive: true })
      .pipe(
        filter(Boolean),
        switchMap(() => remove()),
      )
      .subscribe(() => this.snackBar.open(done, undefined, { duration: 3000 }));
  }

  protected saved(message: string): void {
    this.snackBar.open(message, undefined, { duration: 3000 });
  }
}
