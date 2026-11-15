import { ChangeDetectionStrategy, Component, Injector, inject, input } from '@angular/core';
import { MatIconButton } from '@angular/material/button';
import { MatIcon } from '@angular/material/icon';

/** Page title block. Project action buttons into it; they wrap below the title on small screens. */
@Component({
  selector: 'app-page-header',
  imports: [MatIconButton, MatIcon],
  template: `
    <div class="text">
      <h1 class="title">
        {{ heading() }}
        @if (info()) {
          <button
            mat-icon-button
            type="button"
            class="info-button"
            aria-haspopup="dialog"
            aria-label="About this page"
            (click)="openInfo()"
          >
            <mat-icon>info</mat-icon>
          </button>
        }
      </h1>
      @if (subtitle()) {
        <p class="subtitle">{{ subtitle() }}</p>
      }
    </div>
    <div class="actions"><ng-content /></div>
  `,
  styles: `
    :host {
      display: flex;
      flex-wrap: wrap;
      align-items: flex-end;
      justify-content: space-between;
      gap: var(--pp-space-md);
      margin-bottom: var(--pp-space-lg);
    }
    .title {
      font-size: clamp(1.5rem, 1.2rem + 1vw, 2rem);
      font-weight: 600;
      line-height: 1.2;
    }
    .subtitle {
      margin-top: var(--pp-space-xs);
      color: var(--mat-sys-on-surface-variant);
    }
    .info-button {
      vertical-align: middle;
      color: var(--mat-sys-primary);
    }
    .actions {
      display: flex;
      flex-wrap: wrap;
      gap: var(--pp-space-sm);
    }
    @media (max-width: 599.98px) {
      .actions {
        width: 100%;
      }
    }
    .actions:empty {
      display: none;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PageHeader {
  readonly heading = input.required<string>();
  readonly subtitle = input<string>();
  /** Explains what the page records or does; shown in a popup from an info icon beside the title. */
  readonly info = input<string>();
  private readonly injector = inject(Injector);

  protected async openInfo(): Promise<void> {
    const [{ MatDialog }, { InfoDialog }] = await Promise.all([
      import('@angular/material/dialog'),
      import('./info-dialog'),
    ]);
    this.injector.get(MatDialog).open(InfoDialog, {
      data: { title: this.heading(), message: this.info() ?? '' },
      maxWidth: '440px',
    });
  }
}
