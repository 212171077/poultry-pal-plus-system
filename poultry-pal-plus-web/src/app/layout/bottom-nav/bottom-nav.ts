import { ChangeDetectionStrategy, Component, output, viewChild } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule, MatMenuTrigger } from '@angular/material/menu';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { injectQuickActions } from '../quick-actions';

@Component({
  selector: 'app-bottom-nav',
  imports: [RouterLink, RouterLinkActive, MatButtonModule, MatIconModule, MatMenuModule],
  templateUrl: './bottom-nav.html',
  styleUrl: './bottom-nav.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BottomNav {
  readonly moreClick = output<void>();

  protected readonly quickActions = injectQuickActions();
  private readonly quickAddTrigger = viewChild.required(MatMenuTrigger);

  openQuickAdd(): boolean {
    this.quickAddTrigger().openMenu();
    return true;
  }
}
