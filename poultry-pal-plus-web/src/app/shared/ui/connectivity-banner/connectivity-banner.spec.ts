import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ConnectivityService } from '../../../core/network/connectivity.service';
import { ConnectivityBanner } from './connectivity-banner';

describe('ConnectivityBanner', () => {
  const online = signal(true);

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ConnectivityBanner],
      providers: [{ provide: ConnectivityService, useValue: { online } }],
    }).compileComponents();
  });

  it('announces offline mode in a live region', () => {
    online.set(true);
    const fixture = TestBed.createComponent(ConnectivityBanner);
    fixture.detectChanges();
    const region = fixture.nativeElement.querySelector('[role="status"]') as HTMLElement;
    expect(region.textContent?.trim()).toBe('');

    online.set(false);
    fixture.detectChanges();
    expect(region.textContent).toContain("You're offline");
  });
});
