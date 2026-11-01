export type PasswordStrength = 'weak' | 'fair' | 'good' | 'strong';

/** A rough, friendly strength hint. The server only requires 6+ characters. */
export function passwordStrength(password: string): { level: PasswordStrength; score: number } {
  if (!password) return { level: 'weak', score: 0 };
  let score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
  if (/\d/.test(password)) score++;
  if (/[^A-Za-z0-9]/.test(password)) score++;
  if (password.length < 6) score = 0;
  const level: PasswordStrength =
    score <= 1 ? 'weak' : score === 2 ? 'fair' : score === 3 ? 'good' : 'strong';
  return { level, score: Math.max(1, Math.min(4, score)) };
}
