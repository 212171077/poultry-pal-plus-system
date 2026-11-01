import { TestBed } from '@angular/core/testing';
import { ConnectivityService } from './connectivity.service';

describe('ConnectivityService', () => {
  it('follows browser online/offline events', () => {
    const service = TestBed.inject(ConnectivityService);

    window.dispatchEvent(new Event('offline'));
    expect(service.online()).toBeFalse();

    window.dispatchEvent(new Event('online'));
    expect(service.online()).toBeTrue();
  });

  it('is offline while the server is unreachable, until the network comes back', () => {
    const service = TestBed.inject(ConnectivityService);
    window.dispatchEvent(new Event('online'));

    service.reportServerReachable(false);
    expect(service.browserOnline()).toBeTrue();
    expect(service.online()).toBeFalse();

    window.dispatchEvent(new Event('online'));
    expect(service.online()).toBeTrue();
  });
});
