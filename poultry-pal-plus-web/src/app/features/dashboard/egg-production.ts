import { addDays, format, startOfDay } from 'date-fns';
import { DateRange, FarmData, summarizeByCoop } from '../analytics/farm-metrics';

export type ProductionLevel = 'peak' | 'normal' | 'below';

/** Hen-day production (eggs per hen per day, %). Rules of thumb for commercial layers. */
export const PEAK_RATE = 85;
export const NORMAL_RATE = 70;

export interface EggProduction {
  /** Active layer birds available now. */
  readonly hens: number;
  readonly labels: readonly string[];
  readonly eggsPerDay: readonly number[];
  /** Days in the period that have egg records. */
  readonly recordedDays: number;
  readonly averageEggs: number;
  /** Average eggs per hen per day, in %. */
  readonly rate: number;
  readonly level: ProductionLevel | null;
}

export function levelFor(rate: number): ProductionLevel {
  if (rate >= PEAK_RATE) return 'peak';
  return rate >= NORMAL_RATE ? 'normal' : 'below';
}

/** Daily egg collection for the active layer coops, judged against the birds still available. */
export function eggProduction(data: FarmData, range: DateRange, now: Date): EggProduction | null {
  const layers = data.coops.filter((coop) => coop.coopType === 'LAYERS' && coop.active !== false);
  if (layers.length === 0) return null;
  const ids = new Set(layers.map((coop) => coop.id));
  const hens = summarizeByCoop(data, range)
    .filter((coop) => ids.has(coop.coopId))
    .reduce((sum, coop) => sum + coop.liveBirds, 0);

  const perDay = new Map<number, number>();
  for (const record of data.eggRecords) {
    if (!ids.has(record.coopId)) continue;
    const time = new Date(record.createdDate).getTime();
    if (time < range.from.getTime() || time > range.to.getTime()) continue;
    const day = startOfDay(new Date(record.createdDate)).getTime();
    perDay.set(day, (perDay.get(day) ?? 0) + (record.totalEggs ?? 0));
  }

  const labels: string[] = [];
  const eggsPerDay: number[] = [];
  const last = startOfDay(range.to < now ? range.to : now);
  for (let day = startOfDay(range.from); day <= last; day = addDays(day, 1)) {
    labels.push(format(day, 'd MMM'));
    eggsPerDay.push(perDay.get(day.getTime()) ?? 0);
  }

  const recordedDays = perDay.size;
  const total = [...perDay.values()].reduce((sum, eggs) => sum + eggs, 0);
  const averageEggs = recordedDays > 0 ? total / recordedDays : 0;
  const rate = hens > 0 ? (averageEggs / hens) * 100 : 0;
  return {
    hens,
    labels,
    eggsPerDay,
    recordedDays,
    averageEggs,
    rate,
    level: recordedDays > 0 && hens > 0 ? levelFor(rate) : null,
  };
}
