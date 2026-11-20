import {
  addDays,
  differenceInCalendarDays,
  endOfDay,
  format,
  startOfDay,
  startOfMonth,
  startOfWeek,
  startOfYear,
  subDays,
} from 'date-fns';
import { AppDb } from '../../data/db/app-db';
import {
  LocalCoop,
  LocalEggRecord,
  LocalExpense,
  LocalMortality,
  LocalSale,
} from '../../data/models/local';

export type RangeKey = '7d' | 'month' | '90d' | 'year' | 'all';

export interface RangeOption {
  readonly key: RangeKey;
  readonly label: string;
  readonly icon: string;
  /** Completes "Summary for …". */
  readonly summary: string;
}

export const RANGE_OPTIONS: readonly RangeOption[] = [
  { key: 'all', label: 'All', icon: 'all_inclusive', summary: 'all recorded data' },
  { key: '7d', label: '7 days', icon: 'date_range', summary: 'the last 7 days' },
  { key: 'month', label: 'Month', icon: 'calendar_month', summary: 'this month' },
  { key: '90d', label: '90 days', icon: 'calendar_view_month', summary: 'the last 90 days' },
  { key: 'year', label: 'Year', icon: 'event_note', summary: 'this year' },
];

export function rangeSummaryLabel(key: RangeKey): string {
  const option = RANGE_OPTIONS.find((o) => o.key === key);
  return `Summary for ${option?.summary ?? ''}`.trim();
}

/** Inclusive date range. */
export interface DateRange {
  readonly from: Date;
  readonly to: Date;
}

/** Start of the earliest record in `data`, or the start of this year when there are none. */
function earliestRecord(data: FarmData | undefined, now: Date): Date {
  const dates = data
    ? [
        ...data.sales.map((r) => r.saleDate),
        ...data.expenses.map((r) => r.expenseDate),
        ...data.mortalities.map((r) => r.dateOccurred),
        ...data.eggRecords.map((r) => r.createdDate),
      ]
    : [];
  const times = dates.map((d) => new Date(d).getTime()).filter((t) => Number.isFinite(t));
  return times.length > 0 ? startOfDay(new Date(Math.min(...times))) : startOfYear(now);
}

export function rangeFor(key: RangeKey, now: Date, data?: FarmData): DateRange {
  const to = endOfDay(now);
  switch (key) {
    case '7d':
      return { from: subDays(startOfDay(now), 6), to };
    case '90d':
      return { from: subDays(startOfDay(now), 89), to };
    case 'month':
      return { from: startOfMonth(now), to };
    case 'year':
      return { from: startOfYear(now), to };
    case 'all':
      return { from: earliestRecord(data, now), to };
  }
}

export function rangeLabel(range: DateRange): string {
  return `${format(range.from, 'd MMM yyyy')} – ${format(range.to, 'd MMM yyyy')}`;
}

/** Everything the dashboard and reports need, read from the local store. */
export interface FarmData {
  readonly coops: readonly LocalCoop[];
  readonly sales: readonly LocalSale[];
  readonly mortalities: readonly LocalMortality[];
  readonly expenses: readonly LocalExpense[];
  readonly eggRecords: readonly LocalEggRecord[];
}

export async function loadFarmData(db: AppDb): Promise<FarmData> {
  const [coops, sales, mortalities, expenses, eggRecords] = await Promise.all([
    db.coops.toArray(),
    db.sales.toArray(),
    db.mortalities.toArray(),
    db.expenses.toArray(),
    db.eggRecords.toArray(),
  ]);
  return { coops, sales, mortalities, expenses, eggRecords };
}

export interface SeriesPoint {
  readonly label: string;
  readonly sales: number;
  readonly expenses: number;
  readonly deaths: number;
  readonly eggs: number;
}

export interface FarmSummary {
  readonly sales: number;
  readonly unpaidSales: number;
  readonly expenses: number;
  readonly profit: number;
  readonly eggs: number;
  readonly deaths: number;
  readonly liveBirds: number;
  readonly series: readonly SeriesPoint[];
}

export interface CoopSummary {
  readonly coopId: string;
  readonly coopName: string;
  readonly coopType: string;
  readonly totalBirds: number;
  readonly liveBirds: number;
  readonly chickenAge: string;
  /** Deaths recorded against the current batch, regardless of the selected period. */
  readonly totalDeaths: number;
  readonly sales: number;
  readonly expenses: number;
  readonly profit: number;
  readonly eggs: number;
  readonly deaths: number;
  readonly mortalityRate: number;
}

type Granularity = 'day' | 'week' | 'month';
type Measure = 'sales' | 'expenses' | 'deaths' | 'eggs';

function granularityFor(range: DateRange): Granularity {
  const days = differenceInCalendarDays(range.to, range.from) + 1;
  if (days <= 31) return 'day';
  if (days <= 120) return 'week';
  return 'month';
}

function bucketStart(date: Date, granularity: Granularity): Date {
  if (granularity === 'day') return startOfDay(date);
  if (granularity === 'week') return startOfWeek(date, { weekStartsOn: 1 });
  return startOfMonth(date);
}

function nextBucket(date: Date, granularity: Granularity): Date {
  if (granularity === 'day') return addDays(date, 1);
  if (granularity === 'week') return addDays(date, 7);
  return startOfMonth(addDays(date, 32));
}

function inRange(value: string | null | undefined, range: DateRange): boolean {
  if (!value) return false;
  const time = new Date(value).getTime();
  return time >= range.from.getTime() && time <= range.to.getTime();
}

function liveBirdsOf(coops: readonly LocalCoop[], mortalities: readonly LocalMortality[]): number {
  const active = new Set(coops.filter((coop) => coop.active !== false).map((coop) => coop.id));
  const placed = coops
    .filter((coop) => active.has(coop.id))
    .reduce((total, coop) => total + (coop.numberOfChickens ?? 0), 0);
  // Deaths are recorded against the current batch only (a new batch archives them).
  const dead = mortalities
    .filter((loss) => active.has(loss.coopId))
    .reduce((total, loss) => total + (loss.numberOfDeaths ?? 0), 0);
  return Math.max(0, placed - dead);
}

const total = <T>(items: readonly T[], value: (item: T) => number | null | undefined): number =>
  items.reduce((acc, item) => acc + (value(item) ?? 0), 0);

/** Totals and a time series for the records inside `range`. */
export function summarize(data: FarmData, range: DateRange): FarmSummary {
  const sales = data.sales.filter((r) => inRange(r.saleDate, range));
  const expenses = data.expenses.filter((r) => inRange(r.expenseDate, range));
  const deaths = data.mortalities.filter((r) => inRange(r.dateOccurred, range));
  const eggs = data.eggRecords.filter((r) => inRange(r.createdDate, range));

  const granularity = granularityFor(range);
  const multiYear = differenceInCalendarDays(range.to, range.from) > 365;
  const labelFormat = granularity === 'month' ? (multiYear ? 'MMM yy' : 'MMM') : 'd MMM';
  const buckets = new Map<number, Record<Measure, number>>();
  for (
    let cursor = bucketStart(range.from, granularity);
    cursor.getTime() <= range.to.getTime();
    cursor = nextBucket(cursor, granularity)
  ) {
    buckets.set(cursor.getTime(), { sales: 0, expenses: 0, deaths: 0, eggs: 0 });
  }
  const add = (date: string, measure: Measure, amount: number | null | undefined) => {
    const bucket = buckets.get(bucketStart(new Date(date), granularity).getTime());
    if (bucket) bucket[measure] += amount ?? 0;
  };
  sales.forEach((r) => add(r.saleDate, 'sales', r.totalSaleAmount));
  expenses.forEach((r) => add(r.expenseDate, 'expenses', r.amount));
  deaths.forEach((r) => add(r.dateOccurred, 'deaths', r.numberOfDeaths));
  eggs.forEach((r) => add(r.createdDate, 'eggs', r.totalEggs));

  const salesTotal = total(sales, (r) => r.totalSaleAmount);
  const expensesTotal = total(expenses, (r) => r.amount);
  return {
    sales: salesTotal,
    unpaidSales: total(
      sales.filter((r) => r.paymentStatus === 'PENDING'),
      (r) => r.totalSaleAmount,
    ),
    expenses: expensesTotal,
    profit: salesTotal - expensesTotal,
    eggs: total(eggs, (r) => r.totalEggs),
    deaths: total(deaths, (r) => r.numberOfDeaths),
    liveBirds: liveBirdsOf(data.coops, data.mortalities),
    series: [...buckets.entries()]
      .sort(([a], [b]) => a - b)
      .map(([time, values]) => ({
        label: format(new Date(time), labelFormat),
        ...values,
      })),
  };
}

/** Per-coop figures for the records inside `range`. */
export function summarizeByCoop(data: FarmData, range: DateRange): CoopSummary[] {
  return [...data.coops]
    .sort((a, b) => a.coopName.localeCompare(b.coopName))
    .map((coop) => {
      const own = <T extends { coopId: string }>(items: readonly T[]) =>
        items.filter((item) => item.coopId === coop.id);
      const allDeaths = total(own(data.mortalities), (r) => r.numberOfDeaths);
      const placed = coop.numberOfChickens ?? 0;
      const sales = total(
        own(data.sales).filter((r) => inRange(r.saleDate, range)),
        (r) => r.totalSaleAmount,
      );
      const expenses = total(
        own(data.expenses).filter((r) => inRange(r.expenseDate, range)),
        (r) => r.amount,
      );
      return {
        coopId: coop.id,
        coopName: coop.coopName,
        coopType: coop.coopType === 'LAYERS' ? 'Layers' : 'Broilers',
        totalBirds: placed,
        chickenAge: coop.chickenAge ?? '',
        totalDeaths: allDeaths,
        liveBirds: coop.active === false ? 0 : Math.max(0, placed - allDeaths),
        sales,
        expenses,
        profit: sales - expenses,
        eggs: total(
          own(data.eggRecords).filter((r) => inRange(r.createdDate, range)),
          (r) => r.totalEggs,
        ),
        deaths: total(
          own(data.mortalities).filter((r) => inRange(r.dateOccurred, range)),
          (r) => r.numberOfDeaths,
        ),
        // Same formula as the mobile app: deaths / (birds + deaths).
        mortalityRate: placed + allDeaths > 0 ? (allDeaths / (placed + allDeaths)) * 100 : 0,
      };
    });
}
