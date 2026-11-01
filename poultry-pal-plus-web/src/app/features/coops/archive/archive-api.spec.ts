import { ArchivedBatch, batchMortalityRate, batchProfit } from './archive-api';

const batch: ArchivedBatch = {
  id: 'a1',
  numberOfChickens: 200,
  totalSales: 1500,
  totalExpenses: 900,
  totalDeaths: 10,
  totalEggs: 0,
  salesCount: 3,
  expensesCount: 4,
  mortalityCount: 2,
  eggRecordCount: 0,
};

describe('archived batch helpers', () => {
  it('computes profit', () => {
    expect(batchProfit(batch)).toBe(600);
  });

  it('computes the mortality rate', () => {
    expect(batchMortalityRate(batch)).toBe(5);
    expect(batchMortalityRate({ ...batch, numberOfChickens: 0 })).toBe(0);
  });
});
