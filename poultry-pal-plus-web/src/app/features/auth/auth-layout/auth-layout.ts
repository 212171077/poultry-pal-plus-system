import { NgOptimizedImage } from '@angular/common';
import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

/** Split screen for sign-in and registration: brand story on the left, the form card on the right. */
@Component({
  selector: 'app-auth-layout',
  imports: [NgOptimizedImage, MatIconModule],
  templateUrl: './auth-layout.html',
  styleUrl: './auth-layout.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AuthLayout {
  readonly heading = input.required<string>();
  readonly subheading = input('');
  readonly wide = input(false);

  protected readonly highlights = [
    {
      icon: 'cloud_off',
      text: 'Keeps working without internet and syncs when you are back online',
    },
    { icon: 'egg', text: 'Batches, eggs, sales, mortality and expenses in one place' },
    { icon: 'groups', text: 'Your whole team on the same, up-to-date farm records' },
  ] as const;
}
