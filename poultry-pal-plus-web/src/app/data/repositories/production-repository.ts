import { Injectable, inject } from '@angular/core';
import { ApiError, ApiErrorKind } from '../../core/http/api-error';
import { ApiErrorCode } from '../../core/http/api-response';
import { ConnectivityService } from '../../core/network/connectivity.service';
import {
  BirdMovementInput,
  BirdPlacementInput,
  HatchResultInput,
  IncubationBatch,
  IncubationBatchInput,
  PlanInput,
  ProductionApi,
  ProductionSnapshot,
  SnapshotSection,
  ProductionPlan,
  ProductionReminder,
  BirdPlacement,
  BirdMovement,
  HatchResult,
  HouseOccupancy,
  ProductionEquipment,
} from '../../features/production/production-api';
import { APP_DB } from '../db/app-db';
import { SyncOperationDto, SyncOperationResult } from '../models/sync-api';
import { newId } from '../sync/entities';
import { ProductionSnapshotStore } from '../sync/production-snapshot';
import { SyncApi, SyncHttpError } from '../sync/sync-api';
import { SyncQueue } from '../sync/sync-queue';

export type ProductionCommand =
  | 'BATCH_CREATE'
  | 'BATCH_START'
  | 'BATCH_CANCEL'
  | 'CYCLE_RESERVE'
  | 'CYCLE_TRANSFER'
  | 'CYCLE_CANCEL'
  | 'REMINDER_COMPLETE'
  | 'RESULT_RECORD'
  | 'PLACEMENT_CREATE'
  | 'MOVEMENT_ADD'
  | 'PLAN_SAVE'
  | 'PLAN_COMMIT'
  | 'PLAN_ACCEPT'
  | 'PLAN_CANCEL';

const REJECTION_KINDS: Readonly<Record<string, ApiErrorKind>> = {
  VALIDATION_ERROR: 'validation',
  BAD_REQUEST: 'validation',
  FORBIDDEN: 'forbidden',
  CONFLICT: 'conflict',
  CAPACITY_CONFLICT: 'conflict',
  NOT_FOUND: 'conflict',
};

/**
 * Production reads (cached for offline use) and commands. A command is sent straight away when the
 * server is reachable, so validation and capacity errors appear on the spot. Otherwise it is queued
 * in the outbox and the sync engine sends it later; a `null` result means "queued".
 */
@Injectable({ providedIn: 'root' })
export class ProductionRepository {
  private readonly api = inject(ProductionApi);
  private readonly syncApi = inject(SyncApi);
  private readonly store = inject(ProductionSnapshotStore);
  private readonly queue = inject(SyncQueue);
  private readonly db = inject(APP_DB);
  private readonly connectivity = inject(ConnectivityService);

  readonly offlineSince = this.store.offlineSince;
  readonly changed = this.store.changed;

  batches(): Promise<readonly IncubationBatch[]> {
    return this.read('batches', () => this.api.batches());
  }

  equipment(): Promise<readonly ProductionEquipment[]> {
    return this.read('equipment', () => this.api.equipment());
  }

  reminders(): Promise<readonly ProductionReminder[]> {
    return this.read('reminders', () => this.api.reminders());
  }

  placements(): Promise<readonly BirdPlacement[]> {
    return this.read('placements', () => this.api.placements());
  }

  occupancy(): Promise<readonly HouseOccupancy[]> {
    return this.read('occupancy', () => this.api.occupancy());
  }

  plans(): Promise<readonly ProductionPlan[]> {
    return this.read('plans', () => this.api.plans());
  }

  createBatch(input: IncubationBatchInput): Promise<IncubationBatch | null> {
    return this.command('BATCH_CREATE', newId(), input, `New batch · ${input.eggsSet} eggs`);
  }

  startBatch(id: string, actualDate?: string): Promise<IncubationBatch | null> {
    return this.command(
      'BATCH_START',
      id,
      actualDate ? { actualDate } : {},
      'Start incubation batch',
    );
  }

  cancelBatch(id: string): Promise<IncubationBatch | null> {
    return this.command('BATCH_CANCEL', id, {}, 'Cancel incubation batch');
  }

  reserveCycle(
    batchId: string,
    hatcherId: string,
    quantity: number,
  ): Promise<IncubationBatch | null> {
    return this.command(
      'CYCLE_RESERVE',
      batchId,
      { hatcherId, quantity },
      `Reserve hatcher · ${quantity} eggs`,
    );
  }

  transferCycle(cycleId: string, actualDate?: string): Promise<IncubationBatch | null> {
    return this.command(
      'CYCLE_TRANSFER',
      cycleId,
      actualDate ? { actualDate } : {},
      'Transfer eggs to hatcher',
    );
  }

  cancelCycle(cycleId: string): Promise<IncubationBatch | null> {
    return this.command('CYCLE_CANCEL', cycleId, {}, 'Cancel hatcher cycle');
  }

  completeReminder(id: string): Promise<ProductionReminder | null> {
    return this.command('REMINDER_COMPLETE', id, {}, 'Complete production task');
  }

  recordResult(cycleId: string, input: HatchResultInput): Promise<HatchResult | null> {
    return this.command(
      'RESULT_RECORD',
      cycleId,
      input,
      `Hatch result · ${input.hatchedChicks} hatched`,
    );
  }

  placeChicks(input: BirdPlacementInput): Promise<BirdPlacement | null> {
    return this.command('PLACEMENT_CREATE', newId(), input, `Place ${input.quantity} chicks`);
  }

  addMovement(placementId: string, input: BirdMovementInput): Promise<BirdMovement | null> {
    return this.command(
      'MOVEMENT_ADD',
      placementId,
      input,
      `Record ${input.type.toLowerCase().replace('_', ' ')} · ${input.count} birds`,
    );
  }

  savePlan(input: PlanInput): Promise<ProductionPlan | null> {
    return this.command('PLAN_SAVE', newId(), input, `Save plan · ${input.targetQuantity} birds`);
  }

  planCommand(
    id: string,
    command: 'commit' | 'accept-recalculation' | 'cancel',
    reason?: string,
  ): Promise<ProductionPlan | null> {
    const mapped = {
      commit: ['PLAN_COMMIT', 'Commit plan'],
      'accept-recalculation': ['PLAN_ACCEPT', 'Accept plan recalculation'],
      cancel: ['PLAN_CANCEL', 'Cancel plan'],
    } as const;
    const [type, label] = mapped[command];
    return this.command(type, id, reason ? { reason } : {}, label);
  }

  private read<K extends SnapshotSection>(
    section: K,
    fetch: () => Promise<ProductionSnapshot[K]>,
  ): Promise<ProductionSnapshot[K]> {
    return this.store.read(section, fetch);
  }

  private async command<T>(
    command: ProductionCommand,
    entityId: string,
    body: object,
    label: string,
  ): Promise<T | null> {
    const op: SyncOperationDto = {
      opId: newId(),
      entityType: 'PRODUCTION',
      operation: 'ACTION',
      entityId,
      coopId: null,
      baseVersion: null,
      payload: { command, body },
    };

    if (this.connectivity.online() && !(await this.hasBacklog())) {
      try {
        const [result] = (await this.syncApi.push([op])).results;
        if (result?.status === 'APPLIED') {
          void this.store.refresh();
          return (result.serverRecord ?? null) as T | null;
        }
        throw rejection(result);
      } catch (error) {
        if (error instanceof ApiError) throw error;
        const failure = SyncHttpError.from(error);
        if (failure.kind === 'invalid' || failure.kind === 'forbidden')
          throw new ApiError('server', failure.status, failure.message);
      }
    }

    await this.db.outbox.add({
      opId: op.opId,
      entityType: 'PRODUCTION',
      operation: 'ACTION',
      entityId,
      coopId: null,
      baseVersion: null,
      payload: op.payload,
      status: 'pending',
      attempts: 0,
      fields: [],
      baseRecord: null,
      label,
      createdAt: new Date().toISOString(),
    });
    this.queue.notify();
    return null;
  }

  /** Earlier queued production changes must reach the server first, so later ones queue behind them. */
  private async hasBacklog(): Promise<boolean> {
    return (await this.db.outbox.filter((op) => op.entityType === 'PRODUCTION').count()) > 0;
  }
}

function rejection(result: SyncOperationResult | undefined): ApiError {
  const code = result?.errorCode ?? null;
  const kind = (code && REJECTION_KINDS[code]) || 'server';
  const detail = result?.errors?.length ? ` (${result.errors.join('; ')})` : '';
  return new ApiError(
    kind,
    kind === 'validation' ? 400 : 409,
    `${result?.message ?? 'The server rejected this change.'}${detail}`,
    code as ApiErrorCode | null,
  );
}
