import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { ApiError } from '../../core/http/api-error';
import { ConnectivityService } from '../../core/network/connectivity.service';
import LoginPage from './login-page';

describe('LoginPage', () => {
  const online = signal(true);
  let signIn: jasmine.Spy;

  beforeEach(async () => {
    online.set(true);
    signIn = jasmine.createSpy('signIn').and.resolveTo('signed-in');
    await TestBed.configureTestingModule({
      imports: [LoginPage],
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: AuthService, useValue: { signIn } },
        { provide: ConnectivityService, useValue: { browserOnline: online } },
      ],
    }).compileComponents();
  });

  function render() {
    const fixture = TestBed.createComponent(LoginPage);
    fixture.componentRef.setInput('returnUrl', '/expenses');
    fixture.detectChanges();
    const el = fixture.nativeElement as HTMLElement;
    const type = (selector: string, value: string) => {
      const input = el.querySelector(selector) as HTMLInputElement;
      input.value = value;
      input.dispatchEvent(new Event('input'));
    };
    const submit = async () => {
      el.querySelector('form')!.dispatchEvent(new Event('submit'));
      await fixture.whenStable();
      fixture.detectChanges();
    };
    return { fixture, el, type, submit };
  }

  it('signs in and returns to the requested page', async () => {
    const { type, submit } = render();
    const navigate = spyOn(TestBed.inject(Router), 'navigateByUrl').and.resolveTo(true);
    type('input[type="email"]', 'thandi@farm.test');
    type('input[formControlName="password"]', 'secret1');
    await submit();

    expect(signIn).toHaveBeenCalledWith(
      { email: 'thandi@farm.test', password: 'secret1', rememberMe: true },
      jasmine.any(Function),
    );
    expect(navigate).toHaveBeenCalledWith('/expenses');
  });

  it('explains wrong credentials in plain words', async () => {
    signIn.and.rejectWith(new ApiError('unauthorized', 401, 'Bad', 'INVALID_CREDENTIALS'));
    const { el, type, submit } = render();
    type('input[type="email"]', 'thandi@farm.test');
    type('input[formControlName="password"]', 'nope');
    await submit();

    expect(el.querySelector('[role="alert"]')?.textContent).toContain(
      'Email or password is incorrect.',
    );
  });

  it('explains that signing in needs internet', () => {
    online.set(false);
    const { el } = render();
    expect(el.querySelector('.notice')?.textContent).toContain('You are offline');
    expect((el.querySelector('button[type="submit"]') as HTMLButtonElement).disabled).toBeTrue();
  });
});
