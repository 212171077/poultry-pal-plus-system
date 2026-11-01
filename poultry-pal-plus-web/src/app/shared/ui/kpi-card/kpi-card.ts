import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { Skeleton } from '../skeleton/skeleton';

export type KpiTone = 'brand' | 'accent' | 'success' | 'warning' | 'error' | 'info';

@Component({
  selector: 'app-kpi-card',
  imports: [MatIconModule, Skeleton],
  templateUrl: './kpi-card.html',
  styleUrl: './kpi-card.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'pp-surface-card', '[attr.data-tone]': 'tone()' },
})
export class KpiCard {
  readonly label = input.required<string>();
  readonly value = input<string | number | null>(null);
  readonly icon = input('insights');
  readonly hint = input<string>();
  readonly tone = input<KpiTone>('brand');
  readonly loading = input(false);
}
