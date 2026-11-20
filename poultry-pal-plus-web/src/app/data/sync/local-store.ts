import { AppDb } from '../db/app-db';
import { LocalUser, SyncMetaKey } from '../models/local';
import {
  ServerRecord,
  SyncBootstrapResponse,
  SyncChangesResponse,
  SyncEntityType,
  SyncTombstone,
  UserInfo,
  UserSettings,
} from '../models/sync-api';
import {
  COOP_ENTITY,
  EGG_ENTITY,
  ENTITIES,
  EXPENSE_ENTITY,
  EntityDef,
  MORTALITY_ENTITY,
  SALE_ENTITY,
  entityDef,
  fromServer,
  recordKey,
  remindersFromCoop,
  toIsoDate,
} from './entities';

/**
 * Writes server data into IndexedDB. All functions must run inside a `rw` transaction over
 * `db.tables`. Records with queued local changes (`pending` keys) are never overwritten, so a pull
 * cannot silently drop unsynced work — the push of those changes decides what happens to them.
 */

export async function pendingKeys(db: AppDb): Promise<Set<string>> {
  const ops = await db.outbox.toArray();
  return new Set(ops.map((op) => recordKey(op.entityType, op.entityId)));
}

export async function applyServerRecord(
  db: AppDb,
  type: SyncEntityType,
  node: ServerRecord,
  pending: ReadonlySet<string>,
): Promise<void> {
  const id = String(node['id']);
  if (type === 'COOP' || type === 'REMINDER') {
    if (!pending.has(recordKey('COOP', id))) {
      await db.coops.put(fromServer(COOP_ENTITY, node));
    }
    if (node['reminder'] !== undefined) {
      const reminders = remindersFromCoop(node).filter(
        (reminder) => !pending.has(recordKey('REMINDER', reminder.id)),
      );
      await db.reminders
        .where('coopId')
        .equals(id)
        .filter((reminder) => !pending.has(recordKey('REMINDER', reminder.id)))
        .delete();
      await db.reminders.bulkPut(reminders);
    }
    return;
  }
  const def = entityDef(type);
  if (def && !pending.has(recordKey(type, id))) {
    await def.table(db).put(fromServer(def, node));
  }
}

export async function applyTombstone(
  db: AppDb,
  tombstone: SyncTombstone,
  pending: ReadonlySet<string>,
): Promise<void> {
  const { entityType, entityId } = tombstone;
  if (pending.has(recordKey(entityType, entityId))) return;
  if (entityType === 'COOP') {
    await db.coops.delete(entityId);
    const children: readonly EntityDef[] = [
      SALE_ENTITY,
      MORTALITY_ENTITY,
      EXPENSE_ENTITY,
      EGG_ENTITY,
    ].map((def) => def as unknown as EntityDef);
    for (const def of children) {
      await def
        .table(db)
        .where('coopId')
        .equals(entityId)
        .filter((record) => !pending.has(recordKey(def.type, record.id)))
        .delete();
    }
    await db.reminders
      .where('coopId')
      .equals(entityId)
      .filter((reminder) => !pending.has(recordKey('REMINDER', reminder.id)))
      .delete();
    return;
  }
  await entityDef(entityType)?.table(db).delete(entityId);
}

/** Applies one page of `/sync/changes` (or a bootstrap snapshot when `reset` is set). */
export async function applyChanges(
  db: AppDb,
  changes: SyncChangesResponse,
  reset = false,
): Promise<void> {
  const pending = await pendingKeys(db);
  if (reset) {
    await db.farms.clear();
    for (const def of Object.values(ENTITIES)) {
      await def
        .table(db)
        .filter((record) => !pending.has(recordKey(def.type, record.id)))
        .delete();
    }
    await db.reminders.filter((r) => !pending.has(recordKey('REMINDER', r.id))).delete();
  }
  if (changes.farm) {
    const { farm } = changes;
    await db.farms.put({
      id: farm.id,
      farmName: farm.farmName,
      address: farm.address ?? null,
      addresses: farm.addresses ?? null,
      createdDate: toIsoDate(farm.createdDate),
      updatedAt: toIsoDate(farm.updatedAt),
      version: farm.version,
      syncStatus: 'synced',
    });
  }
  const groups: readonly [SyncEntityType, readonly ServerRecord[] | undefined][] = [
    ['COOP', changes.coops],
    ['SALE', changes.sales],
    ['MORTALITY', changes.mortalities],
    ['EXPENSE', changes.expenses],
    ['EGG_PACKAGING', changes.eggPackagingRecords],
  ];
  for (const [type, records] of groups) {
    for (const node of records ?? []) {
      await applyServerRecord(db, type, node, pending);
    }
  }
  for (const tombstone of changes.tombstones ?? []) {
    await applyTombstone(db, tombstone, pending);
  }
  await setMeta(db, 'cursor', changes.cursor);
}

export async function applyBootstrap(db: AppDb, data: SyncBootstrapResponse): Promise<void> {
  await applyChanges(db, data.snapshot, true);
  const { user } = data;
  const team = (data.team ?? []).filter((member) => member.id !== user.id);
  await db.users.clear();
  await db.users.bulkPut([user, ...team].map((member) => toLocalUser(member, user.id)));
  await db.settings.clear();
  if (data.settings) {
    const settings: { -readonly [K in keyof UserSettings]?: UserSettings[K] } = {
      ...data.settings,
    };
    delete settings.id;
    await db.settings.put({ ...settings, userId: settings.userId ?? user.id });
  }
  await setMeta(db, 'userId', user.id);
  await setMeta(db, 'farmId', user.farmId ?? null);
}

/** The signed-in user cached on this device, if any. */
export function currentUser(db: AppDb): Promise<LocalUser | undefined> {
  return db.users.filter((user) => user.current === true).first();
}

/** Wipes every table, including unsynced changes. Only for sign-out and switching accounts. */
export async function clearLocalData(db: AppDb): Promise<void> {
  await db.transaction('rw', db.tables, async () => {
    for (const table of db.tables) {
      await table.clear();
    }
  });
}

export function toLocalUser(member: UserInfo, currentUserId: string): LocalUser {
  return {
    id: member.id,
    farmId: member.farmId ?? null,
    name: member.name ?? null,
    surname: member.surname ?? null,
    email: member.email ?? null,
    phoneNumber: member.phoneNumber ?? null,
    farmOwner: member.farmOwner ?? false,
    active: member.active ?? true,
    roles: member.roles ?? [],
    roleFriendlyNames: member.roleFriendlyNames ?? [],
    userCoopIds: member.userCoopIds ?? [],
    permissions: member.permissions ?? [],
    current: member.id === currentUserId,
  };
}

export async function getMeta<T extends string | number>(
  db: AppDb,
  key: SyncMetaKey,
): Promise<T | null> {
  return ((await db.syncMeta.get(key))?.value as T | undefined) ?? null;
}

export async function setMeta(
  db: AppDb,
  key: SyncMetaKey,
  value: string | number | null,
): Promise<void> {
  await db.syncMeta.put({ key, value });
}
