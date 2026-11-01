import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { SyncStatusService } from '../../../core/sync/sync-status.service';
import { SyncBadge } from './sync-badge';

describe('SyncBadge', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SyncBadge],
      providers: [provideRouter([])],
    }).compileComponents();
  });

  it('shows the current sync state and links to the sync center', () => {
    const fixture = TestBed.createComponent(SyncBadge);
    fixture.detectChanges();
    const link = fixture.nativeElement.querySelector('a') as HTMLAnchorElement;
    expect(link.getAttribute('href')).toBe('/sync');

    TestBed.inject(SyncStatusService).report({ failedCount: 2 });
    fixture.detectChanges();
    expect(link.dataset['state']).toBe('attention');
    expect(link.textContent).toContain('2 need attention');
  });

  it('hides the label in compact mode but keeps an accessible name', () => {
    const fixture = TestBed.createComponent(SyncBadge);
    fixture.componentRef.setInput('compact', true);
    fixture.detectChanges();
    const link = fixture.nativeElement.querySelector('a') as HTMLAnchorElement;
    expect(link.querySelector('span')).toBeNull();
    expect(link.getAttribute('aria-label')).toContain('Sync status');
  });
});
