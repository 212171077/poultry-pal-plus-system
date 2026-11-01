import { provideHttpClient, withFetch, withInterceptors } from '@angular/common/http';
import {
  ApplicationConfig,
  inject,
  isDevMode,
  provideAppInitializer,
  provideBrowserGlobalErrorListeners,
  provideZoneChangeDetection,
} from '@angular/core';
import {
  TitleStrategy,
  provideRouter,
  withComponentInputBinding,
  withInMemoryScrolling,
} from '@angular/router';
import { provideServiceWorker } from '@angular/service-worker';

import { routes } from './app.routes';
import { AuthService } from './core/auth/auth.service';
import { apiInterceptor } from './core/http/api.interceptor';
import { provideIcons } from './core/icons/icons';
import { PageTitleStrategy } from './core/routing/page-title.strategy';
import { ThemeService } from './core/theme/theme.service';
import { SyncEngine } from './data/sync/sync-engine';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(
      routes,
      withComponentInputBinding(),
      withInMemoryScrolling({ scrollPositionRestoration: 'enabled' }),
    ),
    { provide: TitleStrategy, useClass: PageTitleStrategy },
    provideHttpClient(withFetch(), withInterceptors([apiInterceptor])),
    provideIcons(),
    provideAppInitializer(async () => {
      inject(ThemeService);
      const engine = inject(SyncEngine);
      const auth = inject(AuthService);
      // Nobody signed in on this device: don't sync until someone does.
      if (!(await auth.restore())) engine.suspend();
      engine.start();
    }),
    provideServiceWorker('ngsw-worker.js', {
      enabled: !isDevMode(),
      registrationStrategy: 'registerWhenStable:30000',
    }),
  ],
};
