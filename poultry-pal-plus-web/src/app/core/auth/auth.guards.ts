import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';
import { Permission } from './permissions';

/** The app shell needs a session on this device (it may be offline). */
export const authGuard: CanActivateFn = async (_route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.restore();
  return auth.signedIn()
    ? true
    : router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};

/** Sign-in and registration are skipped when someone is already signed in. */
export const guestGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.restore();
  return auth.signedIn() ? router.createUrlTree(['/dashboard']) : true;
};

/** Pages only some roles may open; others land on the dashboard. */
export function permissionGuard(permission: Permission): CanActivateFn {
  return async () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    await auth.restore();
    return auth.can(permission) ? true : router.createUrlTree(['/dashboard']);
  };
}
