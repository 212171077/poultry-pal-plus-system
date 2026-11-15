import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

export interface ChartMarker {
  readonly value: number;
  readonly label: string;
  /** A CSS color, normally a `var(--pp-*)` token. */
  readonly color: string;
}

/** Small SVG line chart with optional dashed reference lines; renders offline. */
@Component({
  selector: 'app-line-chart',
  template: `
    <svg
      role="img"
      [attr.aria-label]="summary()"
      [attr.viewBox]="'0 0 ' + width + ' ' + height"
      preserveAspectRatio="none"
    >
      <line class="axis" x1="0" [attr.x2]="width" [attr.y1]="baseline" [attr.y2]="baseline" />
      @for (marker of lines(); track marker.label) {
        <line
          class="marker"
          x1="0"
          [attr.x2]="width"
          [attr.y1]="marker.y"
          [attr.y2]="marker.y"
          [style.stroke]="marker.color"
        />
      }
      <path class="area" [attr.d]="area()" [style.fill]="color()" />
      <path class="line" [attr.d]="path()" [style.stroke]="color()" />
    </svg>
    <div class="labels" aria-hidden="true">
      <span>{{ labels()[0] }}</span>
      <span>{{ labels().at(-1) }}</span>
    </div>
    <ul class="legend">
      <li><span class="swatch" [style.background]="color()"></span>{{ name() }}</li>
      @for (marker of markers(); track marker.label) {
        <li>
          <span class="swatch dash" [style.background]="marker.color"></span>{{ marker.label }}
        </li>
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
      height: 180px;
    }
    .axis {
      stroke: var(--pp-border);
    }
    .marker {
      stroke-dasharray: 6 4;
      opacity: 0.8;
    }
    .axis,
    .marker,
    .line {
      stroke-width: 2;
      vector-effect: non-scaling-stroke;
    }
    .line {
      fill: none;
      stroke-linejoin: round;
    }
    .area {
      opacity: 0.12;
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
    .dash {
      height: 3px;
      vertical-align: middle;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LineChart {
  readonly labels = input.required<readonly string[]>();
  readonly values = input.required<readonly number[]>();
  readonly name = input('Value');
  readonly color = input('var(--pp-brand)');
  readonly markers = input<readonly ChartMarker[]>([]);
  readonly summary = input('Line chart');

  protected readonly width = 600;
  protected readonly height = 180;
  protected readonly baseline = this.height - 1;
  private readonly top = 8;

  private readonly max = computed(
    () => Math.max(1, ...this.values(), ...this.markers().map((m) => m.value)) * 1.1,
  );
  private readonly yOf = (value: number) =>
    this.baseline - (value / this.max()) * (this.baseline - this.top);

  protected readonly lines = computed(() =>
    this.markers().map((marker) => ({ ...marker, y: this.yOf(marker.value) })),
  );

  private readonly points = computed(() => {
    const values = this.values();
    const step = values.length > 1 ? this.width / (values.length - 1) : 0;
    return values.map((value, index) => ({
      x: values.length > 1 ? index * step : this.width / 2,
      y: this.yOf(value),
    }));
  });
  protected readonly path = computed(() =>
    this.points()
      .map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)} ${p.y.toFixed(1)}`)
      .join(' '),
  );
  protected readonly area = computed(() => {
    const points = this.points();
    if (points.length < 2) return '';
    return `${this.path()} L${points.at(-1)!.x.toFixed(1)} ${this.baseline} L0 ${this.baseline} Z`;
  });
}
