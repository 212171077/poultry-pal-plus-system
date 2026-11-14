import { APIRequestContext, expect } from '@playwright/test';
import { Account, Farm, newApi, signInApi } from './api';

export type EntityType = 'COOP' | 'SALE' | 'MORTALITY' | 'EXPENSE' | 'EGG_PACKAGING';

type Rec = Record<string, unknown> & { id: string; coopId?: string };

export interface Snapshot {
  coops: Rec[];
  sales: Rec[];
  mortalities: Rec[];
  expenses: Rec[];
  eggPackagingRecords: Rec[];
}

let opCounter = 0;
const opId = (): string => `e2e-${Date.now().toString(36)}-${(opCounter++).toString(36)}`;

export interface CoopInput {
  coopName: string;
  coopType?: 'BROILER' | 'LAYERS';
  growthPhase?: 'BROODING_PHASE' | 'GROWING_REARING_PHASE' | 'PRODUCTION_FINISHING_PHASE';
  numberOfChickens?: number;
  chickenArrivalDate?: string;
}

export const isoDaysAgo = (days: number): string =>
  new Date(Date.now() - days * 86_400_000).toISOString();

/** Talks to the real backend as a signed-in user, the same way the sync engine does. */
export class FarmApi {
  private constructor(readonly api: APIRequestContext) {}

  static async as(account: Pick<Account, 'email' | 'password'>): Promise<FarmApi> {
    const api = await newApi();
    await signInApi(api, account);
    return new FarmApi(api);
  }

  dispose(): Promise<void> {
    return this.api.dispose();
  }

  async push(
    entityType: EntityType,
    payload: Record<string, unknown>,
    options: {
      coopId?: string;
      entityId?: string;
      baseVersion?: number | null;
      operation?: 'UPSERT' | 'DELETE';
    } = {},
  ): Promise<string> {
    const entityId = options.entityId ?? opId();
    const response = await this.api.post('/api/v1/sync/push', {
      data: {
        operations: [
          {
            opId: opId(),
            entityType,
            operation: options.operation ?? 'UPSERT',
            entityId,
            coopId: options.coopId,
            baseVersion: options.baseVersion ?? null,
            payload,
          },
        ],
      },
    });
    expect(response.status(), await response.text()).toBe(200);
    const body = (await response.json()) as {
      data: { results: { status: string; message?: string; errors?: string[] }[] };
    };
    const result = body.data.results[0];
    expect(result.status, `push ${entityType}: ${JSON.stringify(result)}`).toBe('APPLIED');
    return entityId;
  }

  /** Changes an existing record the way a second device would, based on its current version. */
  async update(
    entityType: EntityType,
    record: Rec,
    changes: Record<string, unknown>,
    payloadFields: string[],
  ): Promise<void> {
    const payload = Object.fromEntries(payloadFields.map((f) => [f, record[f]]));
    await this.push(
      entityType,
      { ...payload, ...changes },
      { entityId: record.id, coopId: record.coopId, baseVersion: record['version'] as number },
    );
  }

  async remove(entityType: EntityType, entityId: string, coopId?: string): Promise<void> {
    await this.push(entityType, {}, { entityId, coopId, operation: 'DELETE' });
  }

  createCoop(input: CoopInput): Promise<string> {
    return this.push('COOP', {
      coopType: 'LAYERS',
      growthPhase: 'PRODUCTION_FINISHING_PHASE',
      numberOfChickens: 100,
      chickenArrivalDate: isoDaysAgo(60),
      ...input,
    });
  }

  addSale(coopId: string, payload: Record<string, unknown>): Promise<string> {
    return this.push(
      'SALE',
      { saleDate: isoDaysAgo(1), paymentStatus: 'PAID', ...payload },
      { coopId },
    );
  }

  addMortality(coopId: string, deaths: number, reason: string, daysAgo = 1): Promise<string> {
    return this.push(
      'MORTALITY',
      { dateOccurred: isoDaysAgo(daysAgo), numberOfDeaths: deaths, reason },
      { coopId },
    );
  }

  addExpense(coopId: string, type: string, amount: number, info = ''): Promise<string> {
    return this.push(
      'EXPENSE',
      { expenseDate: isoDaysAgo(2), expenseType: type, amount, additionalInfo: info },
      { coopId },
    );
  }

  addEggs(coopId: string, boxes: number, boxSize = '30 Eggs Box', info = ''): Promise<string> {
    return this.push(
      'EGG_PACKAGING',
      {
        eggSize: 'Large',
        boxSize,
        numberOfBoxes: boxes,
        additionalInfo: info,
        createdDate: isoDaysAgo(1),
      },
      { coopId },
    );
  }

  /** Sets the coops a team member is responsible for (workers only see assigned coops). */
  async assignCoops(memberEmail: string, coopIds: string[]): Promise<void> {
    const list = await this.api.get('/api/v1/team');
    const team = ((await list.json()) as { data: { id: string; email: string }[] }).data;
    const member = team.find((m) => m.email.toLowerCase() === memberEmail.toLowerCase());
    expect(member, `team member ${memberEmail}`).toBeTruthy();
    const response = await this.api.put(`/api/v1/team/${member!.id}/coops`, { data: { coopIds } });
    expect(response.status(), await response.text()).toBe(200);
  }

  async farmName(): Promise<string | undefined> {
    const response = await this.api.get('/api/v1/sync/bootstrap');
    const body = (await response.json()) as {
      data: { snapshot: { farm?: { farmName?: string } } };
    };
    return body.data.snapshot.farm?.farmName;
  }

  async snapshot(): Promise<Snapshot> {
    const response = await this.api.get('/api/v1/sync/bootstrap');
    expect(response.status(), await response.text()).toBe(200);
    const body = (await response.json()) as { data: { snapshot: Snapshot } };
    const s = body.data.snapshot;
    return {
      coops: s.coops ?? [],
      sales: s.sales ?? [],
      mortalities: s.mortalities ?? [],
      expenses: s.expenses ?? [],
      eggPackagingRecords: s.eggPackagingRecords ?? [],
    };
  }

  /** Polls the backend until the predicate finds a matching record (the UI syncs asynchronously). */
  async eventually<T>(
    pick: (snapshot: Snapshot) => T | undefined,
    description: string,
    timeoutMs = 30_000,
  ): Promise<T> {
    let found: T | undefined;
    await expect
      .poll(
        async () => {
          found = pick(await this.snapshot());
          return found !== undefined;
        },
        {
          message: `backend should contain ${description}`,
          timeout: timeoutMs,
          intervals: [500, 1000],
        },
      )
      .toBe(true);
    return found as T;
  }
}

export interface SeededFarmData {
  layers: { id: string; name: string };
  broilers: { id: string; name: string };
}

/** A realistic baseline: one layer coop and one broiler coop with a few records each. The worker is assigned to the layer coop only. */
export async function seedFarmData(farmAccounts: Farm): Promise<SeededFarmData> {
  const farm = await FarmApi.as(farmAccounts.owner);
  try {
    const layersName = 'Layer House A';
    const broilersName = 'Broiler House B';
    const layers = await farm.createCoop({ coopName: layersName, numberOfChickens: 500 });
    const broilers = await farm.createCoop({
      coopName: broilersName,
      coopType: 'BROILER',
      growthPhase: 'GROWING_REARING_PHASE',
      numberOfChickens: 1000,
    });
    await farm.addSale(layers, {
      eggPackaging: 'TRAY_30',
      eggSize: 'Large',
      quantitySold: 10,
      pricePerUnit: 45,
      additionalInfo: 'Seed buyer: Spar',
    });
    await farm.addSale(broilers, {
      numberOfChickensSold: 50,
      salePricePerChicken: 80,
      paymentStatus: 'PENDING',
      additionalInfo: 'Seed buyer: Butcher',
    });
    await farm.addMortality(layers, 5, 'Seed: heat stress');
    await farm.addMortality(broilers, 12, 'Seed: disease');
    await farm.addExpense(layers, 'Feed Costs', 1250, 'Seed feed order');
    await farm.addExpense(broilers, 'Vaccination and Medications', 300, 'Seed vaccines');
    await farm.addEggs(layers, 20, '30 Eggs Box', 'Seed packaging');
    await farm.assignCoops(farmAccounts.worker.email, [layers]);
    return {
      layers: { id: layers, name: layersName },
      broilers: { id: broilers, name: broilersName },
    };
  } finally {
    await farm.dispose();
  }
}
