import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { Toast } from '../../shared/ui/toast/toast.service';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { ProductionRepository } from '../../data/repositories/production-repository';
import { OfflineDataNote } from '../../shared/ui/offline-data-note/offline-data-note';
import { DateField } from '../../shared/ui/date-field/date-field';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import {
  PlanCalculation,
  PlanInput,
  PlanStatus,
  ProductionApi,
  ProductionPlan,
  SourceMethod,
} from './production-api';
import { describeError } from './production-settings-page';

export const PLAN_STATUS_LABELS: Record<PlanStatus, string> = {
  DRAFT: 'Draft',
  COMMITTED: 'Committed',
  NEEDS_REVIEW: 'Needs review',
  COMPLETED: 'Completed',
  CANCELLED: 'Cancelled',
};

export function describeCalculation(calc: PlanCalculation): string {
  const source =
    calc.sourceMethod === 'INCUBATE_EGGS'
      ? `Set ${calc.eggsRequired} eggs on ${calc.incubationStartDate}`
      : `Buy ${calc.chicksRequired} day-old chicks for ${calc.hatchOrArrivalDate}`;
  return `${source}. House on ${calc.housePlacementDate}, ready ${calc.targetReadyDate}.`;
}

@Component({
  selector: 'app-plans-page',
  imports: [
    OfflineDataNote,
    PageHeader,
    EmptyState,
    DateField,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
  ],
  templateUrl: './plans-page.html',
  styleUrl: './plans-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class PlansPage {
  private readonly api = inject(ProductionApi);
  protected readonly repo = inject(ProductionRepository);
  private readonly snackBar = inject(Toast);
  protected readonly connectivity = inject(ConnectivityService);
  protected readonly plans = signal<readonly ProductionPlan[]>([]);
  protected readonly preview = signal<PlanCalculation | null>(null);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);
  protected readonly ready = signal('');
  protected readonly labels = PLAN_STATUS_LABELS;
  protected readonly describe = describeCalculation;
  private lastInput: PlanInput | null = null;

  constructor() {
    void this.load();
  }

  protected calculate(
    method: string,
    ready: string,
    quantity: string,
    age: string,
    name: string,
  ): Promise<void> {
    const count = Number(quantity);
    if (!ready || !Number.isInteger(count) || count < 1) {
      this.error.set('Enter the date you want birds ready and how many.');
      return Promise.resolve();
    }
    const input: PlanInput = {
      sourceMethod: method as SourceMethod,
      targetReadyDate: ready,
      targetQuantity: count,
      targetAgeDays: age ? Number(age) : undefined,
      name: name || undefined,
    };
    return this.run(async () => {
      this.preview.set(await this.api.calculatePlan(input));
      this.lastInput = input;
    }, 'Could not calculate this plan.');
  }

  protected save(): Promise<void> {
    const input = this.lastInput;
    if (!input) return Promise.resolve();
    return this.run(async () => {
      const saved = await this.repo.savePlan(input);
      this.preview.set(null);
      this.lastInput = null;
      this.snackBar.open(
        saved
          ? 'Plan saved as a draft. Nothing is reserved.'
          : 'Saved on this device. It will sync when you are online.',
        'OK',
      );
      await this.load();
    }, 'Could not save this plan.');
  }

  protected command(
    id: string,
    command: 'commit' | 'recalculate' | 'accept-recalculation' | 'cancel',
    reason = '',
  ): Promise<void> {
    if (command === 'accept-recalculation' && !reason.trim()) {
      this.error.set('Give a reason for accepting the new dates.');
      return Promise.resolve();
    }
    return this.run(async () => {
      if (command === 'recalculate') await this.api.planCommand(id, command);
      else await this.repo.planCommand(id, command, reason.trim());
      await this.load();
    }, 'Could not update this plan.');
  }

  private async run(action: () => Promise<void>, fallback: string): Promise<void> {
    this.error.set(null);
    this.busy.set(true);
    try {
      await action();
    } catch (error) {
      this.error.set(describeError(error, fallback));
    } finally {
      this.busy.set(false);
    }
  }

  private async load(): Promise<void> {
    try {
      this.plans.set(await this.repo.plans());
    } catch (error) {
      this.error.set(describeError(error, 'Could not load plans.'));
    }
  }
}
