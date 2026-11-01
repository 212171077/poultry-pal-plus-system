import { Signal, computed, inject } from '@angular/core';
import { AuthService } from '../core/auth/auth.service';
import { QUICK_ACTIONS, QuickAction } from './navigation';

/** The quick actions the signed-in user may use. Call from an injection context. */
export function injectQuickActions(): Signal<readonly QuickAction[]> {
  const auth = inject(AuthService);
  return computed(() => {
    auth.user();
    return QUICK_ACTIONS.filter((action) => !action.requires || auth.can(action.requires));
  });
}
