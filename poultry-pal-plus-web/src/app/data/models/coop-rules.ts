import { CoopType, GrowthPhase, LocalCoop } from './local';

/**
 * Coop rules shared by the web app, kept in line with the backend (`FarmServiceImpl.builCoopList`,
 * `PoultryPalUtil.getChickenPhase`) and the mobile app, so every client shows the same numbers.
 */

export const COOP_TYPES: readonly { readonly value: CoopType; readonly label: string }[] = [
  { value: 'LAYERS', label: 'Layers' },
  { value: 'BROILER', label: 'Broiler' },
];

export const GROWTH_PHASES: readonly { readonly value: GrowthPhase; readonly label: string }[] = [
  { value: 'BROODING_PHASE', label: 'Brooding Phase' },
  { value: 'GROWING_REARING_PHASE', label: 'Growing Phase' },
  { value: 'PRODUCTION_FINISHING_PHASE', label: 'Production or Finishing Phase' },
];

export function coopTypeLabel(type: CoopType | null | undefined): string {
  return COOP_TYPES.find((t) => t.value === type)?.label ?? 'Unknown';
}

export function growthPhaseLabel(phase: GrowthPhase | null | undefined): string {
  return GROWTH_PHASES.find((p) => p.value === phase)?.label ?? 'Unknown';
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** Whole days since the flock arrived, or `null` when the arrival date is unknown. */
export function flockAgeDays(arrival: string | null | undefined, now = new Date()): number | null {
  if (!arrival) return null;
  const time = new Date(arrival).getTime();
  if (Number.isNaN(time)) return null;
  return Math.floor(Math.abs(now.getTime() - time) / DAY_MS);
}

/** Flock age in the backend's wording, e.g. "3 weeks and 2 days". */
export function flockAgeLabel(arrival: string | null | undefined, now = new Date()): string {
  const days = flockAgeDays(arrival, now);
  if (days === null) return 'Unknown';
  const weeks = Math.floor(days / 7);
  const rest = days % 7;
  if (weeks === 0) return days === 0 ? 'Less than a day' : days === 1 ? '1 day' : `${days} days`;
  const head = `${weeks} ${weeks === 1 ? 'week' : 'weeks'}`;
  return rest > 0 ? `${head} and ${rest} ${rest === 1 ? 'day' : 'days'}` : head;
}

/** A coop is active once its flock has arrived and it still holds chickens. */
export function isCoopActive(
  coop: Pick<LocalCoop, 'chickenArrivalDate' | 'numberOfChickens'>,
  now = new Date(),
): boolean {
  if (!coop.chickenArrivalDate || coop.numberOfChickens <= 0) return false;
  return new Date(coop.chickenArrivalDate).getTime() <= now.getTime();
}

/** The phase a flock should be in for its age (broilers 3/6 weeks, layers 6/12 weeks). */
export function expectedGrowthPhase(
  arrival: string | null | undefined,
  type: CoopType,
  now = new Date(),
): GrowthPhase | null {
  const days = flockAgeDays(arrival, now);
  if (days === null || new Date(arrival!).getTime() > now.getTime()) return null;
  const weeks = Math.floor(days / 7);
  const [brooding, growing] = type === 'LAYERS' ? [6, 12] : [3, 6];
  if (weeks < brooding) return 'BROODING_PHASE';
  if (weeks < brooding + growing) return 'GROWING_REARING_PHASE';
  return 'PRODUCTION_FINISHING_PHASE';
}

/** The phase change a coop is due for, or `null` when it is in the right phase. */
export function duePhaseChange(coop: LocalCoop, now = new Date()): GrowthPhase | null {
  if (coop.numberOfChickens <= 0) return null;
  const expected = expectedGrowthPhase(coop.chickenArrivalDate, coop.coopType, now);
  return expected && expected !== coop.growthPhase ? expected : null;
}

/** Coops a flock can move into: same type, a different coop, and empty. */
export function transitionTargets(coop: LocalCoop, coops: readonly LocalCoop[]): LocalCoop[] {
  return coops.filter(
    (other) =>
      other.id !== coop.id && other.coopType === coop.coopType && other.numberOfChickens === 0,
  );
}

/** Mortality rate as the mobile app shows it: deaths / (birds + deaths) × 100. */
export function mortalityRate(birds: number, deaths: number): number {
  const total = birds + deaths;
  return total > 0 ? (deaths / total) * 100 : 0;
}

/** Above this mortality rate (in %) a coop is flagged in red. */
export const MORTALITY_ALERT_RATE = 5;
