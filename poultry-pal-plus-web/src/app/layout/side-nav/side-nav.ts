import { NgOptimizedImage, NgTemplateOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject, input, output } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { NavItem, PRIMARY_NAV, SECONDARY_NAV } from '../navigation';

@Component({
  selector: 'app-side-nav',
  imports: [
    NgOptimizedImage,
    NgTemplateOutlet,
    RouterLink,
    RouterLinkActive,
    MatIconModule,
    MatTooltipModule,
  ],
  templateUrl: './side-nav.html',
  styleUrl: './side-nav.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class.collapsed]': 'collapsed()' },
})
export class SideNav {
  /** Rail mode: icons with short labels. */
  readonly collapsed = input(false);
  readonly navigated = output<void>();

  private readonly auth = inject(AuthService);
  protected readonly primary = computed(() => this.visible(PRIMARY_NAV));
  protected readonly secondary = computed(() => this.visible(SECONDARY_NAV));

  private visible(items: readonly NavItem[]): readonly NavItem[] {
    return items.filter((item) => !item.requires || this.auth.can(item.requires));
  }
}
