import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { format } from 'date-fns';
import { EmailLogApi, EmailLogEntry } from '../admin/email-log-api';

/** System-admin view of the most recent outgoing emails and whether they were delivered. */
@Component({
  selector: 'app-email-log-panel',
  imports: [MatButtonModule, MatIconModule],
  templateUrl: './email-log-panel.html',
  styleUrl: './email-log-panel.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class EmailLogPanel {
  private readonly api = inject(EmailLogApi);

  protected readonly entries = signal<readonly EmailLogEntry[]>([]);
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);

  constructor() {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.entries.set(await this.api.recent());
    } catch {
      this.error.set('Could not load the email log. Check your connection and try again.');
    } finally {
      this.loading.set(false);
    }
  }

  protected when(entry: EmailLogEntry): string {
    return entry.sentAt ? format(new Date(entry.sentAt), 'd MMM yyyy, HH:mm') : '—';
  }
}
