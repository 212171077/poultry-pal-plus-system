import { BrowserContext, Page, TestInfo } from '@playwright/test';

export interface Issue {
  kind: 'console-error' | 'page-error' | 'request-failed' | 'http-5xx' | 'http-4xx';
  page: string;
  message: string;
  url?: string;
  status?: number;
}

export interface ExpectedIssue {
  kind?: Issue['kind'];
  status?: number;
  /** Matched against the request URL or the message. */
  match?: RegExp;
}

/**
 * Records everything that goes wrong in the browser while a test runs: console errors, uncaught
 * exceptions, failed requests and 4xx/5xx API responses. Nothing is ignored silently: unexpected
 * console/page errors, failed requests and 5xx responses fail the test; 4xx responses fail it too
 * unless the test declared them with {@link Diagnostics.expect} (negative scenarios).
 */
export class Diagnostics {
  readonly issues: Issue[] = [];
  private readonly expected: ExpectedIssue[] = [];

  attach(context: BrowserContext): void {
    context.on('page', (page) => this.watch(page));
    context.pages().forEach((page) => this.watch(page));
  }

  /** Declares an issue that the scenario provokes on purpose, e.g. a 401 for a wrong password. */
  expect(issue: ExpectedIssue): void {
    this.expected.push(issue);
  }

  unexpected(): Issue[] {
    return this.issues.filter(
      (issue) =>
        !this.expected.some(
          (e) =>
            (!e.kind || e.kind === issue.kind) &&
            (e.status === undefined || e.status === issue.status) &&
            (!e.match || e.match.test(issue.url ?? '') || e.match.test(issue.message)),
        ),
    );
  }

  private record(issue: Issue): void {
    this.issues.push(issue);
  }

  private watch(page: Page): void {
    const where = (): string => {
      try {
        return new URL(page.url()).pathname;
      } catch {
        return page.url();
      }
    };
    page.on('console', (message) => {
      if (message.type() !== 'error') return;
      const url = message.location().url || undefined;
      // The browser logs every failed network response as a console error; the response
      // listener below reports those with their status, so skip the duplicate.
      if (/^Failed to load resource/.test(message.text())) return;
      this.record({ kind: 'console-error', page: where(), message: message.text(), url });
    });
    page.on('pageerror', (error) =>
      this.record({ kind: 'page-error', page: where(), message: error.message }),
    );
    page.on('requestfailed', (request) => {
      const reason = request.failure()?.errorText ?? 'unknown';
      // Navigations away from a page abort in-flight requests; that is not a defect.
      if (reason === 'net::ERR_ABORTED') return;
      this.record({ kind: 'request-failed', page: where(), message: reason, url: request.url() });
    });
    page.on('response', (response) => {
      const status = response.status();
      if (status < 400) return;
      const url = response.url();
      if (!url.includes('/api/')) return;
      this.record({
        kind: status >= 500 ? 'http-5xx' : 'http-4xx',
        page: where(),
        message: `${response.request().method()} ${status}`,
        url,
        status,
      });
    });
  }

  async attachTo(testInfo: TestInfo): Promise<void> {
    if (this.issues.length === 0) return;
    await testInfo.attach('browser-diagnostics.json', {
      body: JSON.stringify(this.issues, null, 2),
      contentType: 'application/json',
    });
  }

  format(issues: Issue[]): string {
    return issues
      .map((i) => `- [${i.kind}] ${i.page} ${i.message}${i.url ? ` (${i.url})` : ''}`)
      .join('\n');
  }
}
