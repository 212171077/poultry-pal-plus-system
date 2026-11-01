import { ChangeDetectionStrategy, Component, input } from '@angular/core';

/** Loading placeholder with a shimmer. */
@Component({
  selector: 'app-skeleton',
  template: '',
  styles: `
    :host {
      display: block;
      border-radius: var(--pp-radius-sm);
      background: linear-gradient(
        90deg,
        var(--pp-skeleton) 25%,
        var(--pp-skeleton-shine) 50%,
        var(--pp-skeleton) 75%
      );
      background-size: 200% 100%;
      animation: pp-shimmer 1.4s ease-in-out infinite;
    }
    :host(.circle) {
      border-radius: 50%;
    }
    @keyframes pp-shimmer {
      from {
        background-position: 200% 0;
      }
      to {
        background-position: -200% 0;
      }
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    'aria-hidden': 'true',
    '[style.width]': 'width()',
    '[style.height]': 'height()',
    '[class.circle]': 'shape() === "circle"',
  },
})
export class Skeleton {
  readonly width = input('100%');
  readonly height = input('1rem');
  readonly shape = input<'rect' | 'circle'>('rect');
}
