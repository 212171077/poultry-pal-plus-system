import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { CoopSummary } from '../../../features/analytics/farm-metrics';
import { formatMoney } from '../../format/money';

interface Bar {
  readonly label: string;
  readonly amount: string;
  readonly percent: number;
  readonly color: string;
}

/** Per-coop overview: flock health ring, bird counts and a sales / expenses / profit summary. */
@Component({
  selector: 'app-coop-summary-card',
  imports: [MatIconModule],
  template: `
    <article class="pp-surface-card card" [attr.aria-label]="coop().coopName + ' summary'">
      <header>
        <h3>{{ coop().coopName }}</h3>
        <span class="type">{{ coop().coopType }}</span>
      </header>

      <div class="flock">
        <div
          class="ring"
          role="img"
          [attr.aria-label]="'Flock health ' + health() + ' percent'"
          [style.--score]="health()"
          [style.--tone]="healthTone()"
        >
          <span class="score">{{ health() }}%</span>
          <span class="caption">Health</span>
        </div>
        <dl class="stats">
          <div>
            <mat-icon aria-hidden="true">flutter_dash</mat-icon>
            <dt>Total</dt>
            <dd>{{ coop().totalBirds.toLocaleString() }}</dd>
          </div>
          <div>
            <mat-icon aria-hidden="true" class="ok">check_circle</mat-icon>
            <dt>Available</dt>
            <dd>{{ coop().liveBirds.toLocaleString() }}</dd>
          </div>
          <div>
            <mat-icon aria-hidden="true" class="bad">warning</mat-icon>
            <dt>Mortality</dt>
            <dd>{{ coop().totalDeaths.toLocaleString() }}</dd>
          </div>
          @if (coop().chickenAge) {
            <div>
              <mat-icon aria-hidden="true" class="info">timer</mat-icon>
              <dt>Age</dt>
              <dd>{{ coop().chickenAge }}</dd>
            </div>
          }
        </dl>
      </div>

      <section class="money" aria-label="Financial summary">
        <h4><mat-icon aria-hidden="true">bar_chart</mat-icon> Financial summary</h4>
        @if (bars().length > 0) {
          @for (bar of bars(); track bar.label) {
            <div class="bar">
              <span class="name">{{ bar.label }}</span>
              <span class="track"
                ><span
                  class="fill"
                  [style.width.%]="bar.percent"
                  [style.background]="bar.color"
                ></span
              ></span>
              <span class="amount" [style.color]="bar.color">{{ bar.amount }}</span>
            </div>
          }
        } @else {
          <p class="none">No financial data in this period</p>
        }
      </section>
    </article>
  `,
  styles: `
    :host {
      display: block;
    }
    .card {
      padding: var(--pp-space-md);
    }
    header,
    .flock {
      display: flex;
      align-items: center;
      gap: var(--pp-space-md);
    }
    header {
      justify-content: space-between;
      margin-bottom: var(--pp-space-md);
    }
    h3 {
      margin: 0;
      font-size: 1rem;
      color: var(--pp-brand);
    }
    .type {
      padding: 2px 10px;
      border: 1px solid var(--pp-border);
      border-radius: var(--pp-radius-pill);
      font-size: 0.7rem;
      font-weight: 700;
    }
    .ring {
      display: grid;
      flex: none;
      place-content: center;
      width: 80px;
      height: 80px;
      border-radius: 50%;
      text-align: center;
      background:
        radial-gradient(closest-side, var(--mat-sys-surface) 78%, transparent 80%),
        conic-gradient(var(--tone) calc(var(--score) * 1%), var(--pp-border) 0);
    }
    .score {
      color: var(--tone);
      font-size: 0.9rem;
      font-weight: 700;
    }
    .caption {
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.6rem;
    }
    .stats {
      display: grid;
      flex: 1;
      gap: 2px;
      margin: 0;
      min-width: 0;
    }
    .stats div {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.75rem;
    }
    .stats mat-icon {
      width: 16px;
      height: 16px;
      font-size: 16px;
      color: var(--pp-warning);
    }
    .stats .ok {
      color: var(--pp-success);
    }
    .stats .bad {
      color: var(--pp-error);
    }
    .stats .info {
      color: var(--pp-info);
    }
    dt {
      color: var(--mat-sys-on-surface-variant);
    }
    dd {
      margin: 0;
      font-weight: 600;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .money {
      margin-top: var(--pp-space-md);
      padding-top: var(--pp-space-sm);
      border-top: 1px solid var(--pp-border);
    }
    h4 {
      display: flex;
      align-items: center;
      gap: 4px;
      margin: 0 0 var(--pp-space-sm);
      color: var(--pp-brand);
      font-size: 0.75rem;
    }
    h4 mat-icon {
      width: 16px;
      height: 16px;
      font-size: 16px;
    }
    .bar {
      display: grid;
      grid-template-columns: 56px 1fr minmax(64px, auto);
      align-items: center;
      gap: var(--pp-space-sm);
      margin-bottom: 6px;
      font-size: 0.7rem;
    }
    .track {
      height: 8px;
      border-radius: 4px;
      background: var(--pp-border);
      overflow: hidden;
    }
    .fill {
      display: block;
      height: 100%;
      border-radius: 4px;
    }
    .amount {
      font-weight: 600;
      text-align: right;
    }
    .none {
      margin: 0;
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.75rem;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CoopSummaryCard {
  readonly coop = input.required<CoopSummary>();
  readonly currency = input<string | null | undefined>();

  /** Share of the flock still available, as on the mobile dashboard. */
  protected readonly health = computed(() => {
    const { totalBirds, liveBirds } = this.coop();
    return totalBirds > 0 ? Math.round(Math.min(100, (liveBirds / totalBirds) * 100)) : 0;
  });
  protected readonly healthTone = computed(() => {
    const score = this.health();
    if (score >= 80) return 'var(--pp-success)';
    return score >= 60 ? 'var(--pp-warning)' : 'var(--pp-error)';
  });

  protected readonly bars = computed<readonly Bar[]>(() => {
    const { sales, expenses, profit } = this.coop();
    const max = Math.max(Math.abs(sales), Math.abs(expenses), Math.abs(profit));
    if (max < 1) return [];
    const bar = (label: string, value: number, color: string): Bar => ({
      label,
      amount: formatMoney(value, this.currency()),
      percent: (Math.abs(value) / max) * 100,
      color,
    });
    return [
      bar('Sales', sales, 'var(--pp-success)'),
      bar('Expenses', expenses, 'var(--pp-error)'),
      bar('Profit', profit, profit >= 0 ? 'var(--pp-info)' : 'var(--pp-error)'),
    ];
  });
}
