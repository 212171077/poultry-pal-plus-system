import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { LocalUser } from '../../data/models/local';
import { authGuard, guestGuard, permissionGuard } from './auth.guards';
import { AuthService } from './auth.service';
import { CanDirective } from './can.directive';
import { hasPermission } from './permissions';

@Component({ template: '' })
class Blank {}

@Component({
  imports: [CanDirective],
  template: `<button *appCan="'FARM_MANAGER'">Add coop</button>`,
})
class CanHost {}

describe('auth guards and appCan', () => {
  const user = signal<LocalUser | null>(null);
  const fakeAuth = {
    restore: () => Promise.resolve(user() !== null),
    signedIn: () => user() !== null,
    can: (permission: 'FARM_MANAGER' | 'FARM_OWNER') => hasPermission(user(), permission),
  };

  beforeEach(() => {
    user.set(null);
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: fakeAuth },
        provideRouter([
          { path: 'login', component: Blank, canActivate: [guestGuard] },
          { path: 'dashboard', component: Blank, canActivate: [authGuard] },
          {
            path: 'team',
            component: Blank,
            canActivate: [authGuard, permissionGuard('FARM_MANAGER')],
          },
        ]),
      ],
    });
  });

  async function navigate(url: string): Promise<string> {
    const router = TestBed.inject(Router);
    await router.navigateByUrl(url);
    return router.url;
  }

  it('sends signed-out visitors to the sign-in page with a return URL', async () => {
    expect(await navigate('/team')).toBe('/login?returnUrl=%2Fteam');
  });

  it('skips the sign-in page for a signed-in user', async () => {
    user.set({ id: 'u1', farmOwner: true });
    expect(await navigate('/login')).toBe('/dashboard');
  });

  it('keeps workers out of manager pages', async () => {
    user.set({ id: 'u2', roles: ['ROLE_USER'] });
    expect(await navigate('/team')).toBe('/dashboard');
    user.set({ id: 'u3', roles: ['ROLE_FARM_MANAGER'] });
    expect(await navigate('/team')).toBe('/team');
  });

  it('shows manager-only actions only to managers', () => {
    const fixture = TestBed.createComponent(CanHost);
    fixture.detectChanges();
    const el = fixture.nativeElement as HTMLElement;
    expect(el.querySelector('button')).toBeNull();

    user.set({ id: 'u1', farmOwner: true });
    fixture.detectChanges();
    expect(el.querySelector('button')?.textContent).toContain('Add coop');
  });
});
