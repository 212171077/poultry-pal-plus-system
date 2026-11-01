import { ChangeDetectionStrategy, Component } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';

@Component({
  selector: 'app-not-found-page',
  imports: [EmptyState, MatButtonModule, MatIconModule, RouterLink],
  template: `
    <div class="pp-page">
      <app-empty-state
        icon="explore_off"
        heading="We couldn't find that page"
        message="The link may be broken or the page may have moved."
      >
        <a mat-flat-button routerLink="/dashboard">
          <mat-icon>space_dashboard</mat-icon>
          Go to dashboard
        </a>
      </app-empty-state>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class NotFoundPage {}
