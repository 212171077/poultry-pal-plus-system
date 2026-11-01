import { DOCUMENT, DestroyRef, Injectable, computed, effect, inject, signal } from '@angular/core';

export type ThemePreference = 'system' | 'light' | 'dark' | 'sunlight';

const PREFERENCES: readonly ThemePreference[] = ['system', 'light', 'dark', 'sunlight'];

const STORAGE_KEY = 'pp.theme';
const DARK_QUERY = '(prefers-color-scheme: dark)';

/**
 * Applies the light, dark or high-contrast "sunlight" theme. "system" follows the operating
 * system's light/dark setting.
 */
@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly document = inject(DOCUMENT);
  private readonly window = this.document.defaultView;
  private readonly systemPrefersDark = signal(
    this.window?.matchMedia?.(DARK_QUERY).matches ?? false,
  );
  private readonly preferenceState = signal<ThemePreference>(this.readPreference());

  readonly preference = this.preferenceState.asReadonly();
  readonly isDark = computed(() => {
    const preference = this.preferenceState();
    return preference === 'dark' || (preference === 'system' && this.systemPrefersDark());
  });

  constructor() {
    const media = this.window?.matchMedia?.(DARK_QUERY);
    if (media) {
      const listener = (event: MediaQueryListEvent) => this.systemPrefersDark.set(event.matches);
      media.addEventListener('change', listener);
      inject(DestroyRef).onDestroy(() => media.removeEventListener('change', listener));
    }

    effect(() => {
      const classes = this.document.documentElement.classList;
      const preference = this.preferenceState();
      classes.toggle('theme-light', preference === 'light');
      classes.toggle('theme-dark', preference === 'dark');
      classes.toggle('theme-sunlight', preference === 'sunlight');
    });
  }

  setPreference(preference: ThemePreference): void {
    this.preferenceState.set(preference);
    try {
      this.window?.localStorage.setItem(STORAGE_KEY, preference);
    } catch {
      // Storage can be unavailable (private mode); the choice then lasts for this session only.
    }
  }

  private readPreference(): ThemePreference {
    try {
      const stored = this.window?.localStorage.getItem(STORAGE_KEY);
      return PREFERENCES.find((preference) => preference === stored) ?? 'system';
    } catch {
      return 'system';
    }
  }
}
