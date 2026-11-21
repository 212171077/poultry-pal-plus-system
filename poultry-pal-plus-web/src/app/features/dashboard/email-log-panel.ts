import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { format } from 'date-fns';
import { EmailLogApi, EmailLogEntry } from '../admin/email-log-api';

const PAGE_SIZE = 10;

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

  protected readonly page = signal(0);
  protected readonly hasNext = signal(false);

  constructor() {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    await this.load(this.page());
  }

  protected async load(page: number): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const entries = await this.api.recent(PAGE_SIZE, page);
      // A full page may be the last one; an empty page after the first means we overshot.
      if (entries.length === 0 && page > 0) {
        this.hasNext.set(false);
        return;
      }
      this.entries.set(entries);
      this.page.set(page);
      this.hasNext.set(entries.length === PAGE_SIZE);
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
