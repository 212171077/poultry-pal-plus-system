const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/** `{MON}{DD}-{eggs set}` from an ISO start date, e.g. `NOV03-1000`; empty until both are known. */
export function batchReference(startDate: string, eggsSet: number | null | undefined): string {
  const match = /^\d{4}-(\d{2})-(\d{2})$/.exec(startDate ?? '');
  if (!match || !eggsSet || eggsSet < 1) return '';
  const month = MONTHS[Number(match[1]) - 1];
  return month ? `${month}${match[2]}-${eggsSet}` : '';
}
