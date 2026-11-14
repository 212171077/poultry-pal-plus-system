import { BATCH_STATUS_LABELS, todayIso } from './batches-page';

describe('batches page helpers', () => {
  it('formats today as an ISO date', () => {
    expect(todayIso()).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('labels every status', () => {
    expect(BATCH_STATUS_LABELS.TRANSFERRED).toBe('In hatcher');
    expect(Object.keys(BATCH_STATUS_LABELS).length).toBe(5);
  });
});
