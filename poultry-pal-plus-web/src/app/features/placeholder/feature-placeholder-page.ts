import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';

/** Temporary page for features that are scheduled in later roadmap phases. Driven by route data. */
@Component({
  selector: 'app-feature-placeholder-page',
  imports: [PageHeader, EmptyState, MatButtonModule, MatIconModule, RouterLink],
  template: `
    <div class="pp-page">
      <app-page-header [heading]="heading()" [subtitle]="description()" />
      <section class="pp-surface-card">
        <app-empty-state
          [icon]="icon()"
          heading="Coming soon"
          [message]="
            'This section is being built (roadmap ' +
            phase() +
            '). Your farm data stays safe in the meantime.'
          "
        >
          <a mat-stroked-button routerLink="/dashboard">
            <mat-icon>space_dashboard</mat-icon>
            Back to dashboard
          </a>
        </app-empty-state>
      </section>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class FeaturePlaceholderPage {
  readonly heading = input.required<string>();
  readonly description = input<string>();
  readonly icon = input('construction');
  readonly phase = input('a later phase');
}
