import type { FullConfig, FullResult, Reporter, Suite, TestCase } from '@playwright/test/reporter';
import { copyFileSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { OUTPUT_DIR } from './env';

export const DEFECT_VIDEO_DIR = resolve(OUTPUT_DIR, 'defect-videos');

// eslint-disable-next-line no-control-regex
const plain = (text: string): string => text.replace(/\u001b\[[0-9;]*m/g, '');

/**
 * Copies each defect reproduction's video to test-results/defect-videos/DEF-###-<project>.webm
 * and writes an index.md with what each video shows and the assertion that exposes the defect.
 */
export default class DefectVideoReporter implements Reporter {
  private suite?: Suite;

  onBegin(_config: FullConfig, suite: Suite): void {
    this.suite = suite;
    rmSync(DEFECT_VIDEO_DIR, { recursive: true, force: true });
    mkdirSync(DEFECT_VIDEO_DIR, { recursive: true });
  }

  onEnd(_result: FullResult): void {
    const lines = [
      '# Defect reproductions',
      '',
      'Each video replays the test that exposes the defect. The test asserts the CORRECT behaviour, so the assertion shown as "Defect shows as" is the point where the application misbehaves. Details are in `test-results/defects/DEF-###-*.md`.',
      '',
      '| Defect | Project | Video | Defect shows as |',
      '|---|---|---|---|',
    ];
    const tests = (this.suite?.allTests() ?? []).sort((a, b) =>
      this.id(a).localeCompare(this.id(b)),
    );
    for (const test of tests) {
      const id = this.id(test);
      const project = test.titlePath().filter(Boolean)[0];
      const result = test.results[test.results.length - 1];
      const video = result?.attachments.find((a) => a.name === 'video' && a.path);
      let name = '-';
      if (video?.path && test.outcome() !== 'skipped') {
        name = `${id}-${project}.webm`;
        copyFileSync(video.path, resolve(DEFECT_VIDEO_DIR, name));
      }
      const outcome =
        test.outcome() === 'skipped'
          ? 'skipped on this project'
          : result?.error?.message
            ? plain(result.error.message).split('\n').slice(0, 3).join(' ').replace(/\|/g, '\\|')
            : 'the test passed, so the defect may be fixed';
      lines.push(`| ${id} | ${project} | ${name} | ${outcome.slice(0, 300)} |`);
    }
    writeFileSync(resolve(DEFECT_VIDEO_DIR, 'index.md'), `${lines.join('\n')}\n`);
    console.log(`\nDefect videos: ${DEFECT_VIDEO_DIR}`);
  }

  private id(test: TestCase): string {
    return test.tags.find((t) => t.startsWith('@DEF-'))?.slice(1) ?? 'DEF-unknown';
  }
}
