/**
 * Formats an amount in the farm's currency. Settings may hold an ISO code (`ZAR`) or a symbol
 * (`R`), as the mobile app allows both.
 */
export function formatMoney(amount: number, currency?: string | null): string {
  const code = currency?.trim() ?? '';
  if (/^[A-Z]{3}$/.test(code)) {
    try {
      return new Intl.NumberFormat(undefined, { style: 'currency', currency: code }).format(amount);
    } catch {
      // Unknown code: fall through to the plain format.
    }
  }
  const value = amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return code ? `${code} ${value}` : value;
}
