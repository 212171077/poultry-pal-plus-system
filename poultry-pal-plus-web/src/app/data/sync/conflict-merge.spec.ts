import { OutboxOperation } from '../models/local';
import { mergeConflict, sameValue } from './conflict-merge';
import { EXPENSE_ENTITY, EntityDef } from './entities';

const def = EXPENSE_ENTITY as unknown as EntityDef;

const base = {
  id: 'e1',
  coopId: 'c1',
  version: 3,
  expenseDate: '2026-01-10T00:00:00.000Z',
  expenseType: 'Feed Costs',
  amount: 100,
  additionalInfo: 'Mash',
  syncStatus: 'synced',
};

function op(fields: string[], changes: Record<string, unknown>): OutboxOperation {
  return {
    opId: 'op1',
    entityType: 'EXPENSE',
    operation: 'UPSERT',
    entityId: 'e1',
    coopId: 'c1',
    baseVersion: 3,
    payload: { ...base, ...changes },
    status: 'inflight',
    attempts: 1,
    fields,
    baseRecord: base,
    label: 'Expense',
    createdAt: '2026-01-10T00:00:00.000Z',
  };
}

describe('mergeConflict', () => {
  it('keeps both sides when different fields changed', () => {
    const result = mergeConflict(def, op(['additionalInfo'], { additionalInfo: 'Pellets' }), {
      ...base,
      amount: 250,
      version: 4,
    });
    expect(result.kind).toBe('merged');
    if (result.kind !== 'merged') return;
    expect(result.payload).toEqual(
      jasmine.objectContaining({ amount: 250, additionalInfo: 'Pellets' }),
    );
    expect(result.server.version).toBe(4);
  });

  it('reports fields both sides changed to different values', () => {
    const result = mergeConflict(def, op(['amount'], { amount: 150 }), {
      ...base,
      amount: 250,
      version: 4,
    });
    expect(result).toEqual({ kind: 'conflict', fields: ['amount'] });
  });

  it('treats identical edits as no conflict', () => {
    const result = mergeConflict(def, op(['amount'], { amount: 250 }), {
      ...base,
      amount: 250,
      version: 4,
    });
    expect(result.kind).toBe('merged');
  });

  it('needs the user when the server record was deleted', () => {
    expect(mergeConflict(def, op(['amount'], { amount: 1 }), null)).toEqual({
      kind: 'conflict',
      fields: [],
    });
  });
});

describe('sameValue', () => {
  it('treats null and undefined as equal', () => {
    expect(sameValue(null, undefined)).toBeTrue();
    expect(sameValue('', null)).toBeFalse();
  });

  it('compares dates by instant', () => {
    expect(sameValue('2026-01-10T00:00:00Z', '2026-01-10T00:00:00.000Z')).toBeTrue();
    expect(sameValue('2026-01-10T00:00:00Z', '2026-01-11T00:00:00Z')).toBeFalse();
  });

  it('compares numbers and objects by value', () => {
    expect(sameValue(1, 1)).toBeTrue();
    expect(sameValue({ a: 1 }, { a: 1 })).toBeTrue();
    expect(sameValue('10', '10.0')).toBeFalse();
  });
});
