import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

export interface ChartSeries {
  readonly name: string;
  /** A CSS color, normally a `var(--pp-*)` token. */
  readonly color: string;
  readonly values: readonly number[];
}

/**
 * Small grouped bar chart drawn in SVG, so it needs no chart library and renders offline. The
 * `summary` is read by screen readers in place of the graphic.
 */
@Component({
  selector: 'app-bar-chart',
  template: `
    <svg
      role="img"
      [attr.aria-label]="summary()"
      [attr.viewBox]="'0 0 ' + width + ' ' + height"
      preserveAspectRatio="none"
    >
      <line
        class="axis"
        [attr.x1]="0"
        [attr.x2]="width"
        [attr.y1]="baseline"
        [attr.y2]="baseline"
      />
      @for (bar of bars(); track bar.key) {
        <rect
          [attr.x]="bar.x"
          [attr.y]="bar.y"
          [attr.width]="bar.width"
          [attr.height]="bar.height"
          [style.fill]="bar.color"
          rx="2"
        />
      }
    </svg>
    <div class="labels" aria-hidden="true">
      <span>{{ firstLabel() }}</span>
      <span>{{ lastLabel() }}</span>
    </div>
    <ul class="legend">
      @for (item of series(); track item.name) {
        <li><span class="swatch" [style.background]="item.color"></span>{{ item.name }}</li>
      }
    </ul>
  `,
  styles: `
    :host {
      display: block;
    }
    svg {
      display: block;
      width: 100%;
      height: 160px;
    }
    .axis {
      stroke: var(--pp-border);
      stroke-width: 1;
      vector-effect: non-scaling-stroke;
    }
    .labels {
      display: flex;
      justify-content: space-between;
      color: var(--mat-sys-on-surface-variant);
      font: var(--mat-sys-label-small);
    }
    .legend {
      display: flex;
      flex-wrap: wrap;
      gap: var(--pp-space-md);
      margin: var(--pp-space-sm) 0 0;
      padding: 0;
      list-style: none;
      font: var(--mat-sys-label-medium);
    }
    .swatch {
      display: inline-block;
      width: 10px;
      height: 10px;
      margin-right: 6px;
      border-radius: 2px;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BarChart {
  readonly labels = input.required<readonly string[]>();
  readonly series = input.required<readonly ChartSeries[]>();
  readonly summary = input('Chart');

  protected readonly width = 600;
  protected readonly height = 160;
  protected readonly baseline = this.height - 1;

  protected readonly firstLabel = computed(() => this.labels()[0] ?? '');
  protected readonly lastLabel = computed(() => this.labels().at(-1) ?? '');

  protected readonly bars = computed(() => {
    const series = this.series();
    const count = this.labels().length;
    const max = Math.max(1, ...series.flatMap((item) => item.values));
    if (count === 0 || series.length === 0) return [];
    const slot = this.width / count;
    const gap = Math.min(4, slot * 0.2);
    const barWidth = Math.max(1, (slot - gap) / series.length);
    const usable = this.baseline - 4;
    return series.flatMap((item, seriesIndex) =>
      item.values.map((value, index) => {
        const barHeight = value > 0 ? Math.max(2, (value / max) * usable) : 0;
        return {
          key: `${seriesIndex}-${index}`,
          x: index * slot + gap / 2 + seriesIndex * barWidth,
          y: this.baseline - barHeight,
          width: barWidth,
          height: barHeight,
          color: item.color,
        };
      }),
    );
  });
}
