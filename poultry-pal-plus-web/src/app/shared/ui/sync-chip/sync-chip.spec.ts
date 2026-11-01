import { ComponentFixture, TestBed } from '@angular/core/testing';
import { SyncChip } from './sync-chip';

describe('SyncChip', () => {
  let fixture: ComponentFixture<SyncChip>;

  beforeEach(() => {
    fixture = TestBed.createComponent(SyncChip);
  });

  it('labels each sync status', () => {
    const expected = {
      synced: 'Synced',
      pending: 'Waiting to sync',
      failed: 'Sync failed',
      conflict: 'Needs review',
    } as const;
    for (const [status, label] of Object.entries(expected)) {
      fixture.componentRef.setInput('status', status);
      fixture.detectChanges();
      const host = fixture.nativeElement as HTMLElement;
      expect(host.textContent).toContain(label);
      expect(host.classList).toContain(status);
    }
  });

  it('shows only the icon for synced records when compact, keeping the label for screen readers', () => {
    fixture.componentRef.setInput('status', 'synced');
    fixture.componentRef.setInput('compact', true);
    fixture.detectChanges();
    const srOnly = (fixture.nativeElement as HTMLElement).querySelector('.pp-sr-only');
    expect(srOnly?.textContent).toContain('Synced');
  });
});
