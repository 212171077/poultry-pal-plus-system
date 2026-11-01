import { Injectable, inject } from '@angular/core';
import { Table } from 'dexie';
import { APP_DB } from '../db/app-db';
import { flockAgeLabel, isCoopActive } from '../models/coop-rules';
import {
  GrowthPhase,
  LocalCoop,
  LocalEggRecord,
  LocalExpense,
  LocalFarm,
  LocalMortality,
  LocalReminder,
  LocalSale,
  LocalSettings,
  LocalUser,
} from '../models/local';
import {
  COOP_ENTITY,
  EGG_ENTITY,
  EXPENSE_ENTITY,
  MORTALITY_ENTITY,
  EntityDef,
  SALE_ENTITY,
  toPayload,
} from '../sync/entities';
import { BOX_SIZES, SALE_PACKAGING } from '../models/record-options';
import { SyncQueue } from '../sync/sync-queue';
import { CoopChildRepository, RecordRepository } from './record-repository';

/** The fields that describe a flock; used to create a coop and to start a new batch. */
export type CoopBatch = Pick<
  LocalCoop,
  'coopName' | 'coopType' | 'growthPhase' | 'numberOfChickens' | 'chickenArrivalDate'
>;

@Injectable({ providedIn: 'root' })
export class CoopRepository extends RecordRepository<LocalCoop> {
  protected readonly def = COOP_ENTITY;

  /** Coops sorted by name, the order every picker uses. */
  async listSorted(): Promise<LocalCoop[]> {
    const coops = await this.list();
    return coops.sort((a, b) => a.coopName.localeCompare(b.coopName));
  }

  /**
   * Archives the current flock and starts a new one in the same coop. The server keeps the old
   * records in the farm history; on this device they are removed so the coop starts empty. Changes
   * still queued for those records are sent first, so they end up in the archive too.
   */
  async startNewBatch(id: string, batch: CoopBatch): Promise<LocalCoop> {
    let updated!: LocalCoop;
    await this.db.transaction('rw', this.lifecycleTables(), async () => {
      const coop = await this.db.coops.get(id);
      if (!coop) throw new Error('Coop not found');
      updated = this.derive({
        ...coop,
        ...batch,
        phaseTransition: null,
        syncStatus: coop.syncStatus === 'conflict' ? 'conflict' : 'pending',
      });
      await this.db.coops.put(updated);
      await this.deleteChildren(id);
      await this.queue.enqueueCoopAction(
        id,
        { action: 'NEW_BATCH', batch: toPayload(COOP_ENTITY as unknown as EntityDef, updated) },
        `Coop · ${batch.coopName} · new batch`,
      );
    });
    this.queue.notify();
    return updated;
  }

  /**
   * Moves a flock to its next growth phase, either in place or into an empty coop of the same type
   * (its records and reminders move with it; the source coop is left empty, ready for a new flock).
   */
  async transitionPhase(
    id: string,
    newPhase: GrowthPhase,
    targetId?: string | null,
  ): Promise<void> {
    const target = targetId && targetId !== id ? targetId : null;
    await this.db.transaction('rw', this.lifecycleTables(), async () => {
      const coop = await this.db.coops.get(id);
      if (!coop) throw new Error('Coop not found');
      const pending = (status: LocalCoop['syncStatus']) =>
        status === 'conflict' ? status : ('pending' as const);
      if (!target) {
        await this.db.coops.put(
          this.derive({
            ...coop,
            growthPhase: newPhase,
            phaseTransition: null,
            syncStatus: pending(coop.syncStatus),
          }),
        );
      } else {
        const into = await this.db.coops.get(target);
        if (!into) throw new Error('Choose a coop that exists on this device');
        if (into.coopType !== coop.coopType) {
          throw new Error('The flock can only move into a coop of the same type');
        }
        if (into.numberOfChickens > 0) {
          throw new Error(
            `${into.coopName} still has chickens. Empty it or start a new batch first.`,
          );
        }
        await this.db.coops.put(
          this.derive({
            ...into,
            growthPhase: newPhase,
            numberOfChickens: coop.numberOfChickens,
            chickenArrivalDate: coop.chickenArrivalDate ?? null,
            phaseTransition: null,
            syncStatus: pending(into.syncStatus),
          }),
        );
        await this.db.coops.put(
          this.derive({
            ...coop,
            growthPhase: 'BROODING_PHASE',
            numberOfChickens: 0,
            chickenArrivalDate: null,
            phaseTransition: null,
            syncStatus: pending(coop.syncStatus),
          }),
        );
        for (const table of this.childTables()) {
          await table.where('coopId').equals(id).modify({ coopId: target });
        }
        await this.db.reminders.where('coopId').equals(target).delete();
        await this.db.reminders.where('coopId').equals(id).modify({ coopId: target });
      }
      await this.queue.enqueueCoopAction(
        id,
        { action: 'PHASE_TRANSITION', newGrowthPhase: newPhase, targetCoopId: target },
        `Coop · ${coop.coopName} · ${target ? 'flock moved' : 'phase changed'}`,
      );
    });
    this.queue.notify();
  }

  /** Deletes the coop together with its records and reminders. */
  override async remove(id: string): Promise<void> {
    await this.db.transaction('rw', this.lifecycleTables(), async () => {
      const coop = await this.db.coops.get(id);
      if (!coop) return;
      await this.deleteChildren(id);
      if (coop.version === null) {
        // Never reached the server, so neither did its records: drop all their queued changes.
        await this.db.outbox.where('coopId').equals(id).delete();
        await this.db.coops.delete(id);
        return;
      }
      await super.remove(id);
    });
  }

  protected override derive(coop: LocalCoop): LocalCoop {
    return {
      ...coop,
      chickenAge: flockAgeLabel(coop.chickenArrivalDate),
      active: isCoopActive(coop),
    };
  }

  private childTables(): Table<{ id: string; coopId: string }, string>[] {
    return [this.db.sales, this.db.mortalities, this.db.expenses, this.db.eggRecords] as never;
  }

  private lifecycleTables(): Table[] {
    return [this.db.coops, ...this.childTables(), this.db.reminders, this.db.outbox] as Table[];
  }

  private async deleteChildren(coopId: string): Promise<void> {
    for (const table of this.childTables()) {
      await table.where('coopId').equals(coopId).delete();
    }
    await this.db.reminders.where('coopId').equals(coopId).delete();
  }
}

@Injectable({ providedIn: 'root' })
export class SaleRepository extends CoopChildRepository<LocalSale> {
  protected readonly def = SALE_ENTITY;

  /** Newest first. */
  listRecent(): Promise<LocalSale[]> {
    return this.db.sales.orderBy('saleDate').reverse().toArray();
  }

  protected override derive(sale: LocalSale): LocalSale {
    const byPackaging = (sale.quantitySold ?? 0) * (sale.pricePerUnit ?? 0);
    const byDozen = (sale.numberOfDozensSold ?? 0) * (sale.salePricePerDozen ?? 0);
    const byChicken = (sale.numberOfChickensSold ?? 0) * (sale.salePricePerChicken ?? 0);
    const perUnit = SALE_PACKAGING.find((p) => p.value === sale.eggPackaging)?.eggs;
    return {
      ...sale,
      totalSaleAmount: byPackaging || byDozen || byChicken,
      totalEggsSold: perUnit ? (sale.quantitySold ?? 0) * perUnit : null,
    };
  }
}

@Injectable({ providedIn: 'root' })
export class MortalityRepository extends CoopChildRepository<LocalMortality> {
  protected readonly def = MORTALITY_ENTITY;

  /** Newest first. */
  listRecent(): Promise<LocalMortality[]> {
    return this.db.mortalities.orderBy('dateOccurred').reverse().toArray();
  }
}

@Injectable({ providedIn: 'root' })
export class ExpenseRepository extends CoopChildRepository<LocalExpense> {
  protected readonly def = EXPENSE_ENTITY;

  /** Newest first. */
  async listRecent(): Promise<LocalExpense[]> {
    const expenses = await this.db.expenses.orderBy('expenseDate').reverse().toArray();
    return expenses;
  }
}

/** Eggs per box, keyed by lower-case box size (the backend matches case-insensitively). */
export const EGG_BOX_SIZES: Readonly<Record<string, number>> = Object.fromEntries(
  BOX_SIZES.map(({ value, eggs }) => [value.toLowerCase(), eggs]),
);

@Injectable({ providedIn: 'root' })
export class EggRecordRepository extends CoopChildRepository<LocalEggRecord> {
  protected readonly def = EGG_ENTITY;

  /** Newest first. */
  listRecent(): Promise<LocalEggRecord[]> {
    return this.db.eggRecords.orderBy('createdDate').reverse().toArray();
  }

  protected override derive(record: LocalEggRecord): LocalEggRecord {
    const perBox = EGG_BOX_SIZES[record.boxSize.trim().toLowerCase()] ?? 0;
    return { ...record, totalEggs: perBox * record.numberOfBoxes };
  }

  protected override async validate(record: LocalEggRecord): Promise<void> {
    await super.validate(record);
    const coop = await this.db.coops.get(record.coopId);
    if (coop?.coopType !== 'LAYERS') {
      throw new Error('Egg packaging can only be recorded for layer coops');
    }
  }
}

export interface ReminderAction {
  /** What was done, e.g. `DONE` or `NOT_APPLICABLE`. */
  readonly action: string;
  readonly actionComment?: string | null;
}

/** Reminder tasks are generated by the server; the client only records actions on them. */
@Injectable({ providedIn: 'root' })
export class ReminderRepository {
  private readonly db = inject(APP_DB);
  private readonly queue = inject(SyncQueue);

  listByCoop(coopId: string): Promise<LocalReminder[]> {
    return this.db.reminders.where('coopId').equals(coopId).sortBy('dueDate');
  }

  async complete(id: string, { action, actionComment }: ReminderAction): Promise<void> {
    await this.db.transaction('rw', [this.db.reminders, this.db.outbox], async () => {
      const reminder = await this.db.reminders.get(id);
      if (!reminder) throw new Error('Reminder not found');
      await this.db.reminders.put({
        ...reminder,
        done: true,
        doneDate: new Date().toISOString(),
        action,
        actionComment: actionComment ?? null,
        syncStatus: 'pending',
      });
      await this.queue.enqueueReminderAction(
        id,
        reminder.coopId,
        { reminderType: reminder.reminderType, action, actionComment: actionComment ?? null },
        `Reminder · ${reminder.name} · ${action.toLowerCase()}`,
      );
    });
    this.queue.notify();
  }
}

/** Signed-in user, team and settings cached by the last bootstrap (read-only until Phase 3/6). */
@Injectable({ providedIn: 'root' })
export class FarmContextRepository {
  private readonly db = inject(APP_DB);

  async currentUser(): Promise<LocalUser | undefined> {
    return this.db.users.filter((user) => user.current === true).first();
  }

  async settings(): Promise<LocalSettings | undefined> {
    const user = await this.currentUser();
    return user ? this.db.settings.get(user.id) : undefined;
  }

  async farm(): Promise<LocalFarm | undefined> {
    return this.db.farms.toCollection().first();
  }
}
