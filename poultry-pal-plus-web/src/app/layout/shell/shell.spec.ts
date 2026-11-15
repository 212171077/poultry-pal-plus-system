import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { LayoutMode, LayoutService } from '../layout.service';
import { QuickAddService } from '../quick-add/quick-add.service';
import { Shell } from './shell';

describe('Shell', () => {
  const mode = signal<LayoutMode>('desktop');

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Shell],
      providers: [
        provideRouter([]),
        { provide: LayoutService, useValue: { mode } },
        { provide: QuickAddService, useValue: { open: jasmine.createSpy('open') } },
        {
          provide: AuthService,
          useValue: {
            user: signal(null),
            displayName: signal('Thandi Mokoena'),
            can: () => true,
          },
        },
      ],
    }).compileComponents();
  });

  function render() {
    const fixture = TestBed.createComponent(Shell);
    fixture.detectChanges();
    return fixture.nativeElement as HTMLElement;
  }

  it('shows the full side navigation on desktop', () => {
    mode.set('desktop');
    const el = render();
    expect(el.querySelector('app-side-nav')?.classList).not.toContain('collapsed');
    expect(el.querySelector('app-bottom-nav')).toBeNull();
    expect(el.querySelector('main#main-content')).not.toBeNull();
  });

  it('collapses the navigation into a rail on tablets', () => {
    mode.set('tablet');
    const el = render();
    expect(el.querySelector('app-side-nav')?.classList).toContain('collapsed');
    expect(el.querySelector('app-bottom-nav')).toBeNull();
  });

  it('uses the bottom navigation on phones', () => {
    mode.set('handset');
    const el = render();
    expect(el.querySelector('app-bottom-nav')).not.toBeNull();
  });

  describe('N shortcut', () => {
    function press(target: EventTarget, init: KeyboardEventInit = {}): KeyboardEvent {
      const event = new KeyboardEvent('keydown', {
        key: 'n',
        bubbles: true,
        cancelable: true,
        ...init,
      });
      target.dispatchEvent(event);
      return event;
    }

    it('opens Quick Add', () => {
      mode.set('desktop');
      render();
      const event = press(document.body);
      expect(event.defaultPrevented).toBeTrue();
      expect(TestBed.inject(QuickAddService).open).toHaveBeenCalled();
    });

    it('ignores typing and modifier keys', () => {
      mode.set('desktop');
      const el = render();
      const input = document.createElement('input');
      el.appendChild(input);
      expect(press(input).defaultPrevented).toBeFalse();
      expect(press(document.body, { ctrlKey: true }).defaultPrevented).toBeFalse();
      expect(document.querySelector('.mat-mdc-menu-panel')).toBeNull();
    });
  });
});
