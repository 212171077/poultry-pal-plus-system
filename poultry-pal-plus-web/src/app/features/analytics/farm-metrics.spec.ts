import { LocalCoop, LocalExpense, LocalMortality, LocalSale } from '../../data/models/local';
import { FarmData, rangeFor, summarize, summarizeByCoop } from './farm-metrics';

const base = { version: 1, syncStatus: 'synced' as const };
const NOW = new Date(2026, 5, 15, 10);

const coop = (id: string, name: string, birds: number): LocalCoop => ({
  ...base,
  id,
  coopName: name,
  coopType: 'LAYERS',
  growthPhase: 'PRODUCTION_FINISHING_PHASE',
  numberOfChickens: birds,
});
const sale = (id: string, coopId: string, date: Date, total: number, paid = true): LocalSale => ({
  ...base,
  id,
  coopId,
  saleDate: date.toISOString(),
  totalSaleAmount: total,
  paymentStatus: paid ? 'PAID' : 'PENDING',
});
const expense = (id: string, coopId: string, date: Date, amount: number): LocalExpense => ({
  ...base,
  id,
  coopId,
  expenseDate: date.toISOString(),
  expenseType: 'Feed',
  amount,
});
const loss = (id: string, coopId: string, date: Date, deaths: number): LocalMortality => ({
  ...base,
  id,
  coopId,
  dateOccurred: date.toISOString(),
  numberOfDeaths: deaths,
  reason: 'Disease',
});

const DATA: FarmData = {
  coops: [coop('a', 'Alpha', 100), coop('b', 'Beta', 50)],
  sales: [
    sale('s1', 'a', new Date(2026, 5, 14), 300),
    sale('s2', 'a', new Date(2026, 5, 10), 200, false),
    sale('old', 'a', new Date(2026, 0, 2), 999),
  ],
  expenses: [
    expense('e1', 'a', new Date(2026, 5, 12), 120),
    expense('e2', 'b', new Date(2026, 5, 1), 30),
  ],
  mortalities: [
    loss('m1', 'a', new Date(2026, 5, 13), 4),
    loss('m2', 'b', new Date(2026, 4, 1), 2),
  ],
  eggRecords: [],
};

describe('farm metrics', () => {
  it('computes totals for the selected range only', () => {
    const summary = summarize(DATA, rangeFor('7d', NOW));
    expect(summary.sales).toBe(500);
    expect(summary.unpaidSales).toBe(200);
    expect(summary.expenses).toBe(120);
    expect(summary.profit).toBe(380);
    expect(summary.deaths).toBe(4);
  });

  it('counts live birds as placed minus all recorded deaths', () => {
    expect(summarize(DATA, rangeFor('7d', NOW)).liveBirds).toBe(150 - 6);
  });

  it('builds a daily series for short ranges and monthly for a year', () => {
    const week = summarize(DATA, rangeFor('7d', NOW));
    expect(week.series.length).toBe(7);
    expect(week.series.reduce((sum, point) => sum + point.sales, 0)).toBe(500);
    const year = summarize(DATA, rangeFor('year', NOW));
    expect(year.series.length).toBe(6);
    expect(year.series.reduce((sum, point) => sum + point.sales, 0)).toBe(1499);
  });

  it('summarises each coop with the mobile mortality formula', () => {
    const [alpha, beta] = summarizeByCoop(DATA, rangeFor('month', NOW));
    expect(alpha.coopName).toBe('Alpha');
    expect(alpha.profit).toBe(380);
    expect(alpha.mortalityRate).toBeCloseTo((4 / 104) * 100);
    expect(beta.expenses).toBe(30);
    expect(beta.deaths).toBe(0);
    expect(beta.liveBirds).toBe(48);
  });
});
