import { OutboxOperation, SyncedRecord } from '../models/local';
import { ServerRecord } from '../models/sync-api';
import { EntityDef, fromServer, toPayload } from './entities';

export type MergeResult =
  | {
      readonly kind: 'merged';
      /** Payload to re-send with the server version as the new base. */
      readonly payload: Record<string, unknown>;
      /** Local record after merging: server values plus the user's changed fields. */
      readonly record: SyncedRecord;
      readonly server: SyncedRecord;
    }
  | { readonly kind: 'conflict'; readonly fields: readonly string[] };

/**
 * Field-level last-writer-wins for a rejected UPSERT. When the server changed different fields than
 * the user, both changes are kept automatically. Only fields changed on both sides to different
 * values need the user to decide.
 */
export function mergeConflict(
  def: EntityDef,
  op: OutboxOperation,
  serverRecord: ServerRecord | null | undefined,
): MergeResult {
  if (!serverRecord || op.operation !== 'UPSERT' || !op.payload) {
    return { kind: 'conflict', fields: [] };
  }
  const server = fromServer(def, serverRecord);
  const serverValues = server as unknown as Record<string, unknown>;
  const base = op.baseRecord ?? null;
  const local = op.payload;

  const serverChanged = (field: string) => !base || !sameValue(serverValues[field], base[field]);
  const overlap = op.fields.filter(
    (field) => serverChanged(field) && !sameValue(serverValues[field], local[field]),
  );
  if (overlap.length > 0) {
    return { kind: 'conflict', fields: overlap };
  }

  const mine = Object.fromEntries(op.fields.map((field) => [field, local[field] ?? null]));
  return {
    kind: 'merged',
    payload: { ...toPayload(def, server), ...mine },
    record: { ...server, ...mine, syncStatus: 'pending' } as SyncedRecord,
    server,
  };
}

/** Compares field values, treating null/undefined as equal and dates by instant. */
export function sameValue(a: unknown, b: unknown): boolean {
  const left = a ?? null;
  const right = b ?? null;
  if (left === right) return true;
  if (typeof left === 'string' && typeof right === 'string') {
    const l = Date.parse(left);
    const r = Date.parse(right);
    return looksLikeDate(left) && looksLikeDate(right) && !Number.isNaN(l) && l === r;
  }
  return JSON.stringify(left) === JSON.stringify(right);
}

function looksLikeDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}/.test(value);
}
