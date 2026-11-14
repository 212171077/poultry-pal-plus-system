import type {
  FullConfig,
  FullResult,
  Reporter,
  Suite,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, relative, resolve } from 'node:path';
import { OUTPUT_DIR } from './env';

interface Row {
  spec: string;
  project: string;
  title: string;
  outcome: 'passed' | 'failed' | 'flaky' | 'skipped' | 'known-defect';
  durationMs: number;
  error?: string;
}

const REPORT = resolve(OUTPUT_DIR, 'reports', 'summary.md');

const seconds = (ms: number): string => `${(ms / 1000).toFixed(1)}s`;
const minutes = (ms: number): string =>
  `${Math.floor(ms / 60000)}m ${Math.round((ms % 60000) / 1000)}s`;
const clean = (text: string): string =>
  // eslint-disable-next-line no-control-regex
  text.replace(/\u001b\[[0-9;]*m/g, '').replace(/\|/g, '\\|');
const link = (path: string): string => relative(resolve(OUTPUT_DIR, 'reports'), path);

/**
 * Writes test-results/reports/summary.md: totals, duration, results per page and per project,
 * known defects (tests declared with test.fail), unexpected failures, screenshot index and
 * backend errors from the captured stack log.
 */
export default class SummaryReporter implements Reporter {
  private readonly rows: Row[] = [];
  private startedAt = 0;
  private result?: FullResult;

  private suite?: Suite;

  onBegin(_config: FullConfig, suite: Suite): void {
    this.startedAt = Date.now();
    this.suite = suite;
  }

  onEnd(result: FullResult): void {
    this.result = result;
    for (const test of this.suite?.allTests() ?? []) {
      const outcome = test.outcome();
      const last = test.results[test.results.length - 1];
      let mapped: Row['outcome'];
      if (outcome === 'skipped') mapped = 'skipped';
      else if (outcome === 'flaky') mapped = 'flaky';
      else if (outcome === 'unexpected') mapped = 'failed';
      else mapped = test.expectedStatus === 'failed' ? 'known-defect' : 'passed';
      this.rows.push(this.row(test, last, mapped));
    }
  }

  // Runs after global teardown, so the backend log has been written by then.
  onExit(): void {
    mkdirSync(resolve(OUTPUT_DIR, 'reports'), { recursive: true });
    writeFileSync(REPORT, this.render());
  }

  private id(test: TestCase): string {
    return test.titlePath().filter(Boolean).join(' > ');
  }

  private row(test: TestCase, result: TestResult | undefined, outcome: Row['outcome']): Row {
    const parts = test.titlePath().filter(Boolean);
    return {
      spec: basename(test.location.file).replace(/\.spec\.ts$/, ''),
      project: parts[0] ?? '',
      title: this.id(test),
      outcome,
      durationMs: test.results.reduce((sum, r) => sum + r.duration, 0),
      error: result?.error?.message ? clean(result.error.message).split('\n')[0] : undefined,
    };
  }

  private render(): string {
    const wall = Date.now() - this.startedAt;
    const count = (outcome: Row['outcome'], rows = this.rows): number =>
      rows.filter((r) => r.outcome === outcome).length;
    const lines: string[] = [];
    lines.push('# Live E2E summary', '');
    lines.push(`Status: **${this.result?.status ?? 'unknown'}**  `);
    lines.push(`Duration: ${minutes(wall)}  `);
    lines.push(`Generated: ${new Date().toISOString()}`, '');

    lines.push('## Totals', '', '| Passed | Known defects | Flaky | Failed | Skipped | Total |');
    lines.push('|---|---|---|---|---|---|');
    lines.push(
      `| ${count('passed')} | ${count('known-defect')} | ${count('flaky')} | ${count('failed')} | ${count('skipped')} | ${this.rows.length} |`,
      '',
    );
    lines.push(
      'Known defects are tests declared with `test.fail`: they pass while the defect exists and fail once it is fixed.',
      '',
    );

    lines.push(
      '## By project',
      '',
      '| Project | Passed | Known defects | Flaky | Failed | Skipped |',
    );
    lines.push('|---|---|---|---|---|---|');
    for (const project of [...new Set(this.rows.map((r) => r.project))].sort()) {
      const rows = this.rows.filter((r) => r.project === project);
      lines.push(
        `| ${project} | ${count('passed', rows)} | ${count('known-defect', rows)} | ${count('flaky', rows)} | ${count('failed', rows)} | ${count('skipped', rows)} |`,
      );
    }

    lines.push(
      '',
      '## By page / spec',
      '',
      '| Spec | Passed | Known defects | Flaky | Failed | Skipped | Time |',
    );
    lines.push('|---|---|---|---|---|---|---|');
    for (const spec of [...new Set(this.rows.map((r) => r.spec))].sort()) {
      const rows = this.rows.filter((r) => r.spec === spec);
      const time = rows.reduce((sum, r) => sum + r.durationMs, 0);
      lines.push(
        `| ${spec} | ${count('passed', rows)} | ${count('known-defect', rows)} | ${count('flaky', rows)} | ${count('failed', rows)} | ${count('skipped', rows)} | ${seconds(time)} |`,
      );
    }

    const section = (heading: string, outcome: Row['outcome'], withError: boolean): void => {
      const rows = this.rows.filter((r) => r.outcome === outcome);
      if (!rows.length) return;
      lines.push('', `## ${heading} (${rows.length})`, '');
      for (const r of rows) {
        lines.push(`- \`${r.title}\`${withError && r.error ? ` - ${r.error}` : ''}`);
      }
    };
    section('Unexpected failures', 'failed', true);
    section('Flaky tests', 'flaky', false);
    section('Known defects (test.fail)', 'known-defect', false);

    lines.push('', '## Documented defects', '');
    const defectDir = resolve(OUTPUT_DIR, 'defects');
    const defects = existsSync(defectDir)
      ? readdirSync(defectDir)
          .filter((f) => /^DEF-.*\.md$/.test(f))
          .sort()
      : [];
    if (!defects.length) lines.push('None documented.');
    for (const file of defects) {
      const heading = readFileSync(resolve(defectDir, file), 'utf8').match(/^#\s+(.+)$/m)?.[1];
      lines.push(`- [${heading ?? file}](${link(resolve(defectDir, file))})`);
    }

    lines.push('', '## Screenshots', '');
    for (const project of ['desktop', 'mobile']) {
      const dir = resolve(OUTPUT_DIR, 'screenshots', project);
      const count = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.png')).length : 0;
      lines.push(`- ${project}: ${count} screenshots in [screenshots/${project}](${link(dir)})`);
    }
    const failures = resolve(OUTPUT_DIR, 'screenshots', 'failures');
    if (existsSync(failures)) lines.push(`- failures: [screenshots/failures](${link(failures)})`);

    lines.push('', '## Backend errors', '');
    const log = resolve(OUTPUT_DIR, 'logs', 'stack.log');
    if (!existsSync(log)) {
      lines.push('Backend log not captured.');
    } else {
      const errors = readFileSync(log, 'utf8')
        .split('\n')
        .filter((l) => /\b(ERROR|Exception)\b/.test(l));
      lines.push(`Full log: [logs/stack.log](${link(log)}). ${errors.length} error line(s).`);
      if (errors.length) {
        lines.push('', '```');
        for (const e of errors.slice(0, 30)) lines.push(clean(e).slice(0, 300));
        if (errors.length > 30) lines.push(`... ${errors.length - 30} more`);
        lines.push('```');
      }
    }

    lines.push('', '## Links', '');
    lines.push(`- [HTML report](${link(resolve(OUTPUT_DIR, 'reports', 'html', 'index.html'))})`);
    lines.push(
      `- [Artifacts (traces, videos, failure shots)](${link(resolve(OUTPUT_DIR, 'artifacts'))})`,
    );
    return `${lines.join('\n')}\n`;
  }
}
