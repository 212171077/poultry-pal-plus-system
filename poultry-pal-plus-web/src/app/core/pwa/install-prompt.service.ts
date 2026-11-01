import { DOCUMENT, DestroyRef, Injectable, inject, signal } from '@angular/core';

/** Chromium's `beforeinstallprompt` event (not yet in the TypeScript DOM typings). */
interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  readonly userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

/**
 * Captures the browser's install prompt so we can offer "Install app" in the UI. Installing
 * matters offline: browsers are less likely to evict local data of installed apps.
 */
@Injectable({ providedIn: 'root' })
export class InstallPromptService {
  private readonly window = inject(DOCUMENT).defaultView;
  private deferredPrompt: BeforeInstallPromptEvent | null = null;
  private readonly canInstallState = signal(false);

  readonly canInstall = this.canInstallState.asReadonly();

  constructor() {
    const win = this.window;
    if (!win) {
      return;
    }
    const onPrompt = (event: Event) => {
      event.preventDefault();
      this.deferredPrompt = event as BeforeInstallPromptEvent;
      this.canInstallState.set(true);
    };
    const onInstalled = () => {
      this.deferredPrompt = null;
      this.canInstallState.set(false);
    };
    win.addEventListener('beforeinstallprompt', onPrompt);
    win.addEventListener('appinstalled', onInstalled);
    inject(DestroyRef).onDestroy(() => {
      win.removeEventListener('beforeinstallprompt', onPrompt);
      win.removeEventListener('appinstalled', onInstalled);
    });
  }

  async promptInstall(): Promise<boolean> {
    const prompt = this.deferredPrompt;
    if (!prompt) {
      return false;
    }
    this.deferredPrompt = null;
    this.canInstallState.set(false);
    await prompt.prompt();
    const { outcome } = await prompt.userChoice;
    return outcome === 'accepted';
  }
}
