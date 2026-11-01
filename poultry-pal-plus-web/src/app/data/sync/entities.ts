import { Table } from 'dexie';
import { AppDb } from '../db/app-db';
import {
  LocalCoop,
  LocalEggRecord,
  LocalExpense,
  LocalMortality,
  LocalReminder,
  LocalSale,
  ReminderType,
  SyncedRecord,
} from '../models/local';
import { ServerRecord, SyncEntityType, WireDate } from '../models/sync-api';

export type ChildEntityType = 'SALE' | 'MORTALITY' | 'EXPENSE' | 'EGG_PACKAGING';
export type RecordEntityType = 'COOP' | ChildEntityType;

/** Describes how one synced entity is stored locally and sent to the server. */
export interface EntityDef<T extends SyncedRecord = SyncedRecord> {
  readonly type: RecordEntityType;
  readonly noun: string;
  table(db: AppDb): Table<T, string>;
  /** Fields sent in UPSERT payloads (see the backend `*Payload` classes). */
  readonly payloadFields: readonly string[];
  readonly dateFields: readonly string[];
  describe(record: T): string;
}

const SYNC_DATE_FIELDS = ['updatedAt', 'createdDate'] as const;

const formatAmount = (value: unknown) =>
  typeof value === 'number' ? value.toLocaleString(undefined, { maximumFractionDigits: 2 }) : '';

export const COOP_ENTITY: EntityDef<LocalCoop> = {
  type: 'COOP',
  noun: 'Coop',
  table: (db) => db.coops,
  payloadFields: ['coopName', 'coopType', 'growthPhase', 'numberOfChickens', 'chickenArrivalDate'],
  dateFields: [...SYNC_DATE_FIELDS, 'chickenArrivalDate'],
  describe: (r) => `Coop · ${r.coopName}`,
};

export const SALE_ENTITY: EntityDef<LocalSale> = {
  type: 'SALE',
  noun: 'Sale',
  table: (db) => db.sales,
  payloadFields: [
    'numberOfDozensSold',
    'salePricePerDozen',
    'eggSize',
    'eggPackaging',
    'quantitySold',
    'pricePerUnit',
    'numberOfChickensSold',
    'salePricePerChicken',
    'additionalInfo',
    'recordedBy',
    'paymentStatus',
    'saleDate',
  ],
  dateFields: [...SYNC_DATE_FIELDS, 'saleDate'],
  describe: (r) =>
    ['Sale', r.additionalInfo, formatAmount(r.totalSaleAmount)].filter(Boolean).join(' · '),
};

export const MORTALITY_ENTITY: EntityDef<LocalMortality> = {
  type: 'MORTALITY',
  noun: 'Mortality',
  table: (db) => db.mortalities,
  payloadFields: ['dateOccurred', 'numberOfDeaths', 'reason', 'recordedBy'],
  dateFields: [...SYNC_DATE_FIELDS, 'dateOccurred'],
  describe: (r) => `Mortality · ${r.numberOfDeaths} · ${r.reason}`,
};

export const EXPENSE_ENTITY: EntityDef<LocalExpense> = {
  type: 'EXPENSE',
  noun: 'Expense',
  table: (db) => db.expenses,
  payloadFields: ['expenseDate', 'expenseType', 'amount', 'additionalInfo', 'recordedBy'],
  dateFields: [...SYNC_DATE_FIELDS, 'expenseDate'],
  describe: (r) => `Expense · ${r.expenseType} · ${formatAmount(r.amount)}`,
};

export const EGG_ENTITY: EntityDef<LocalEggRecord> = {
  type: 'EGG_PACKAGING',
  noun: 'Egg packaging',
  table: (db) => db.eggRecords,
  payloadFields: ['eggSize', 'boxSize', 'numberOfBoxes', 'additionalInfo', 'createdDate'],
  dateFields: [...SYNC_DATE_FIELDS],
  describe: (r) => `Egg packaging · ${r.numberOfBoxes} × ${r.boxSize}`,
};

export const ENTITIES: Readonly<Record<RecordEntityType, EntityDef>> = {
  COOP: COOP_ENTITY as unknown as EntityDef,
  SALE: SALE_ENTITY as unknown as EntityDef,
  MORTALITY: MORTALITY_ENTITY as unknown as EntityDef,
  EXPENSE: EXPENSE_ENTITY as unknown as EntityDef,
  EGG_PACKAGING: EGG_ENTITY as unknown as EntityDef,
};

export function entityDef(type: SyncEntityType): EntityDef | null {
  return type in ENTITIES ? ENTITIES[type as RecordEntityType] : null;
}

export function toIsoDate(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'number') return new Date(value).toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

/** Server-only fields that are stored separately (reminders) or recomputed locally. */
const COOP_DROPPED_FIELDS = [
  'reminder',
  'overdueTasks',
  'upcomingReminders',
  'sales',
  'mortalities',
  'expenses',
  'eggPackagingRecords',
];

/** Converts a server record into the local shape, marked as synced. */
export function fromServer<T extends SyncedRecord>(def: EntityDef<T>, node: ServerRecord): T {
  const record: Record<string, unknown> = { ...node };
  for (const field of def.dateFields) {
    if (field in record) record[field] = toIsoDate(record[field]);
  }
  if (def.type === 'COOP') {
    COOP_DROPPED_FIELDS.forEach((field) => delete record[field]);
  }
  record['version'] = typeof node['version'] === 'number' ? node['version'] : 0;
  record['syncStatus'] = 'synced';
  return record as unknown as T;
}

/** Picks the payload fields of a local record, ready to send to the server. */
export function toPayload(def: EntityDef, record: object): Record<string, unknown> {
  const source = record as Record<string, unknown>;
  const payload: Record<string, unknown> = {};
  for (const field of def.payloadFields) {
    payload[field] = source[field] ?? null;
  }
  return payload;
}

interface ServerReminderItem {
  readonly id?: string;
  readonly vaccineName?: string;
  readonly feedType?: string;
  readonly medicineName?: string;
  readonly purpose?: string | null;
  readonly notes?: string | null;
  readonly dueDate?: WireDate | null;
  readonly doneDate?: WireDate | null;
  readonly done?: boolean;
  readonly action?: string | null;
  readonly actionComment?: string | null;
}

const REMINDER_GROUPS: readonly [string, ReminderType, keyof ServerReminderItem][] = [
  ['vaccines', 'VACCINE', 'vaccineName'],
  ['feeds', 'FEED', 'feedType'],
  ['medicines', 'MEDICINE', 'medicineName'],
];

/** Flattens a coop's embedded reminder schedule into one row per task. */
export function remindersFromCoop(node: ServerRecord): LocalReminder[] {
  const coopId = String(node['id']);
  const reminder = node['reminder'] as Record<string, unknown> | null | undefined;
  if (!reminder) return [];
  const result: LocalReminder[] = [];
  for (const [group, reminderType, nameField] of REMINDER_GROUPS) {
    const items = (reminder[group] as ServerReminderItem[] | null | undefined) ?? [];
    for (const item of items) {
      if (!item?.id) continue;
      const doneDate = toIsoDate(item.doneDate);
      result.push({
        id: item.id,
        coopId,
        reminderType,
        name: String(item[nameField] ?? reminderType.toLowerCase()),
        purpose: item.purpose ?? null,
        notes: item.notes ?? null,
        dueDate: toIsoDate(item.dueDate),
        doneDate,
        done: Boolean(item.done) || doneDate !== null,
        action: item.action ?? null,
        actionComment: item.actionComment ?? null,
        syncStatus: 'synced',
      });
    }
  }
  return result;
}

/** Key identifying one record across entity types, e.g. `EXPENSE:abc`. */
export function recordKey(type: SyncEntityType, id: string): string {
  return `${type}:${id}`;
}

const ID_FALLBACK_ALPHABET = '0123456789abcdef';

/** UUID v4. Falls back to `getRandomValues` where `randomUUID` is unavailable (plain HTTP on a LAN). */
export function newId(): string {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => ID_FALLBACK_ALPHABET[b >> 4] + ID_FALLBACK_ALPHABET[b & 15]);
  return [0, 4, 6, 8, 10]
    .map((start, i, all) => hex.slice(start, all[i + 1] ?? 16).join(''))
    .join('-');
}
