import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ConnectivityService } from '../network/connectivity.service';
import { SyncStatusService } from './sync-status.service';

describe('SyncStatusService', () => {
  const online = signal(true);
  let service: SyncStatusService;

  beforeEach(() => {
    online.set(true);
    TestBed.configureTestingModule({
      providers: [{ provide: ConnectivityService, useValue: { online } }],
    });
    service = TestBed.inject(SyncStatusService);
  });

  it('is syncing until the first sync completes, then synced when nothing is pending', () => {
    expect(service.state()).toBe('syncing');

    service.report({ lastSyncedAt: new Date() });
    expect(service.state()).toBe('synced');
  });

  it('reports pending, syncing and offline states', () => {
    service.report({ pendingCount: 3, lastSyncedAt: new Date() });
    expect(service.state()).toBe('pending');

    service.report({ syncing: true });
    expect(service.state()).toBe('syncing');

    online.set(false);
    expect(service.state()).toBe('offline');
  });

  it('puts failures and auth problems ahead of everything else', () => {
    online.set(false);
    service.report({ authRequired: true });
    expect(service.state()).toBe('auth-required');

    service.report({ failedCount: 1 });
    expect(service.state()).toBe('attention');
  });
});
