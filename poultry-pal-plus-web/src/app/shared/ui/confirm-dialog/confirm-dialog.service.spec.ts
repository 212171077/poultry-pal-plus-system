import { TestBed } from '@angular/core/testing';
import { MatDialog } from '@angular/material/dialog';
import { of } from 'rxjs';
import { ConfirmDialogService } from './confirm-dialog.service';

describe('ConfirmDialogService', () => {
  function setup(result: unknown) {
    const dialog = jasmine.createSpyObj<MatDialog>('MatDialog', ['open']);
    dialog.open.and.returnValue({ afterClosed: () => of(result) } as never);
    TestBed.configureTestingModule({ providers: [{ provide: MatDialog, useValue: dialog }] });
    return TestBed.inject(ConfirmDialogService);
  }

  it('resolves true only on explicit confirmation', (done) => {
    setup(true)
      .confirm({ title: 'Delete?', message: 'Sure?' })
      .subscribe((confirmed) => {
        expect(confirmed).toBeTrue();
        done();
      });
  });

  it('treats dismissal as cancel', (done) => {
    setup(undefined)
      .confirm({ title: 'Delete?', message: 'Sure?' })
      .subscribe((confirmed) => {
        expect(confirmed).toBeFalse();
        done();
      });
  });
});
