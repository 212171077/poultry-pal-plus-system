import { TestBed } from '@angular/core/testing';
import { ThemeService } from './theme.service';

describe('ThemeService', () => {
  const classes = document.documentElement.classList;

  beforeEach(() => {
    localStorage.removeItem('pp.theme');
    classes.remove('theme-meadow', 'theme-dark', 'theme-sunlight');
  });

  afterEach(() => {
    localStorage.removeItem('pp.theme');
    classes.remove('theme-meadow', 'theme-dark', 'theme-sunlight');
  });

  it('defaults to the system preference without forcing a theme class', () => {
    const service = TestBed.inject(ThemeService);
    TestBed.tick();
    expect(service.preference()).toBe('system');
    expect(classes.contains('theme-meadow')).toBeFalse();
    expect(classes.contains('theme-dark')).toBeFalse();
  });

  it('applies and persists an explicit preference', () => {
    const service = TestBed.inject(ThemeService);
    service.setPreference('dark');
    TestBed.tick();
    expect(service.isDark()).toBeTrue();
    expect(classes.contains('theme-dark')).toBeTrue();
    expect(localStorage.getItem('pp.theme')).toBe('dark');

    service.setPreference('meadow');
    TestBed.tick();
    expect(service.isDark()).toBeFalse();
    expect(classes.contains('theme-meadow')).toBeTrue();
    expect(classes.contains('theme-dark')).toBeFalse();
  });

  it('applies the high-contrast sunlight theme as a light theme', () => {
    const service = TestBed.inject(ThemeService);
    service.setPreference('sunlight');
    TestBed.tick();
    expect(service.isDark()).toBeFalse();
    expect(classes.contains('theme-sunlight')).toBeTrue();
    expect(classes.contains('theme-dark')).toBeFalse();
    expect(localStorage.getItem('pp.theme')).toBe('sunlight');

    service.setPreference('system');
    TestBed.tick();
    expect(classes.contains('theme-sunlight')).toBeFalse();
  });

  it('restores the stored preference', () => {
    localStorage.setItem('pp.theme', 'dark');
    expect(TestBed.inject(ThemeService).preference()).toBe('dark');
  });

  it('ignores invalid stored values', () => {
    localStorage.setItem('pp.theme', 'purple');
    expect(TestBed.inject(ThemeService).preference()).toBe('system');
  });
});
