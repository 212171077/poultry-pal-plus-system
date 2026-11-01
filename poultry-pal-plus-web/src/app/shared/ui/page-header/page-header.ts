import { ChangeDetectionStrategy, Component, input } from '@angular/core';

/** Page title block. Project action buttons into it; they wrap below the title on small screens. */
@Component({
  selector: 'app-page-header',
  template: `
    <div class="text">
      <h1 class="title">{{ heading() }}</h1>
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
    .actions {
      display: flex;
      flex-wrap: wrap;
      gap: var(--pp-space-sm);
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
}
