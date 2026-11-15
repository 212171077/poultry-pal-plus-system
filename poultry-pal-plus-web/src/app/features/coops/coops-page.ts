import { NgOptimizedImage, NgTemplateOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { RouterLink } from '@angular/router';
import { filter, switchMap } from 'rxjs';
import { liveSignal } from '../../data/db/live-signal';
import {
  MORTALITY_ALERT_RATE,
  coopTypeLabel,
  duePhaseChange,
  flockAgeLabel,
  growthPhaseLabel,
  isCoopActive,
  mortalityRate,
} from '../../data/models/coop-rules';
import { GrowthPhase, LocalCoop } from '../../data/models/local';
import { MortalityRepository } from '../../data/repositories/repositories';
import { RecordListPage } from '../../shared/records/record-page';
import { ConfirmDialogService } from '../../shared/ui/confirm-dialog/confirm-dialog.service';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { SyncChip } from '../../shared/ui/sync-chip/sync-chip';
import { CoopFormData, CoopFormDialog, CoopFormMode } from './coop-form-dialog/coop-form-dialog';
import { PhaseDialog, PhaseDialogData } from './phase-dialog/phase-dialog';

export interface CoopCard {
  readonly coop: LocalCoop;
  readonly typeLabel: string;
  readonly phaseLabel: string;
  readonly age: string;
  readonly status: 'active' | 'arriving' | 'empty';
  readonly deaths: number;
  /** Birds placed minus recorded deaths. */
  readonly alive: number;
  readonly rate: string;
  readonly rateAlert: boolean;
  readonly due: GrowthPhase | null;
  readonly dueLabel: string | null;
}

type CoopView = 'cards' | 'table';
const VIEW_KEY = 'pp.coops.view';

@Component({
  selector: 'app-coops-page',
  imports: [
    PageHeader,
    EmptyState,
    SyncChip,
    MatButtonModule,
    MatButtonToggleModule,
    MatIconModule,
    MatMenuModule,
    NgTemplateOutlet,
    NgOptimizedImage,
    RouterLink,
  ],
  templateUrl: './coops-page.html',
  styleUrls: ['../../shared/records/record-list.scss', './coops-page.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class CoopsPage extends RecordListPage<LocalCoop> {
  private readonly mortalityRepo = inject(MortalityRepository);
  private readonly confirm = inject(ConfirmDialogService);

  private readonly allCoops = liveSignal(() => this.coopsRepo.listSorted());
  private readonly mortalities = liveSignal(() => this.mortalityRepo.list(), []);

  protected readonly canManage = this.auth.canManageFarm;
  protected readonly statusLabel: Record<CoopCard['status'], string> = {
    active: 'Active',
    arriving: 'Flock arriving',
    empty: 'Empty',
  };
  protected readonly loading = computed(() => this.allCoops() === undefined);
  protected readonly view = signal<CoopView>(
    localStorage.getItem(VIEW_KEY) === 'table' ? 'table' : 'cards',
  );

  protected readonly cards = computed<CoopCard[]>(() => {
    const deaths = new Map<string, number>();
    for (const record of this.mortalities()) {
      deaths.set(record.coopId, (deaths.get(record.coopId) ?? 0) + record.numberOfDeaths);
    }
    const now = new Date();
    return (this.allCoops() ?? []).map((coop) => {
      const lost = deaths.get(coop.id) ?? 0;
      const rate = mortalityRate(coop.numberOfChickens, lost);
      const due = duePhaseChange(coop, now);
      return {
        coop,
        typeLabel: coopTypeLabel(coop.coopType),
        phaseLabel: growthPhaseLabel(coop.growthPhase),
        age: coop.chickenArrivalDate ? flockAgeLabel(coop.chickenArrivalDate, now) : '—',
        status: isCoopActive(coop, now)
          ? 'active'
          : coop.numberOfChickens > 0
            ? 'arriving'
            : 'empty',
        deaths: lost,
        alive: Math.max(0, coop.numberOfChickens - lost),
        rate: `${rate.toFixed(1)}%`,
        rateAlert: rate > MORTALITY_ALERT_RATE,
        due,
        dueLabel: due ? growthPhaseLabel(due) : null,
      };
    });
  });

  protected readonly summary = computed(() => {
    const cards = this.cards();
    const active = cards.filter((card) => card.status === 'active');
    return {
      coops: cards.length,
      active: active.length,
      alive: active.reduce((sum, card) => sum + card.alive, 0).toLocaleString(),
      due: cards.filter((card) => card.due),
    };
  });

  protected setView(view: CoopView): void {
    this.view.set(view);
    localStorage.setItem(VIEW_KEY, view);
  }

  /** `?action=new` adds a coop (managers only). */
  protected async openForm(coop?: LocalCoop): Promise<void> {
    if (!coop && !this.canManage()) {
      this.snackBar.open('Only farm managers can add coops.', 'OK', { duration: 4000 });
      return;
    }
    this.openCoopForm(coop ? 'edit' : 'create', coop);
  }

  protected startNewBatch(coop: LocalCoop): void {
    this.confirm
      .confirm({
        title: 'Confirm New Batch Addition',
        message:
          'Are you sure you want to add a new batch? All previous batch records will be archived and are accessible in your farm’s history for reporting purposes.',
        confirmText: 'Continue',
      })
      .pipe(filter(Boolean))
      .subscribe(() => this.openCoopForm('batch', coop));
  }

  protected changePhase(coop: LocalCoop): void {
    this.dialog
      .open<PhaseDialog, PhaseDialogData, boolean>(PhaseDialog, {
        data: { coop, coops: this.allCoops() ?? [] },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .pipe(filter(Boolean))
      .subscribe(() => this.saved('Growth phase updated. It will sync automatically.'));
  }

  /** Moves every coop that is due for a phase change to its expected phase, in place. */
  protected applyDuePhases(): void {
    const due = this.summary().due;
    this.confirm
      .confirm({
        title: `Update ${due.length} ${due.length === 1 ? 'coop' : 'coops'}?`,
        message:
          due
            .map((card) => `${card.coop.coopName}: ${card.phaseLabel} → ${card.dueLabel}`)
            .join('; ') + '. Flocks stay in their coops.',
        confirmText: 'Update phases',
      })
      .pipe(
        filter(Boolean),
        switchMap(async () => {
          for (const card of due) {
            await this.coopsRepo.transitionPhase(card.coop.id, card.due!);
          }
        }),
      )
      .subscribe(() => this.saved('Growth phases updated'));
  }

  protected remove(coop: LocalCoop): void {
    this.confirmDelete(
      `Delete ${coop.coopName}?`,
      'The coop and all of its sales, mortality, expense and egg records will be removed from all devices. To keep the history, start a new batch instead.',
      () => this.coopsRepo.remove(coop.id),
      'Coop deleted',
    );
  }

  private openCoopForm(mode: CoopFormMode, coop?: LocalCoop): void {
    const messages: Record<CoopFormMode, string> = {
      create: 'Coop added. It will sync automatically.',
      edit: 'Coop updated',
      batch: 'New batch started. The previous batch is archived.',
    };
    this.dialog
      .open<CoopFormDialog, CoopFormData, LocalCoop>(CoopFormDialog, {
        data: { mode, coop },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .pipe(filter(Boolean))
      .subscribe(() => this.saved(messages[mode]));
  }
}
