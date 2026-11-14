import { Page } from '@playwright/test';

export interface Finding {
  rule: string;
  detail: string;
}

/** In-page audit. Runs in the browser, so it must not reference anything outside its body. */
async function audit(page: Page, minTarget: number): Promise<Finding[]> {
  return page.evaluate((min) => {
    const findings: { rule: string; detail: string }[] = [];
    const add = (rule: string, el: Element | string, extra = '') => {
      const label =
        typeof el === 'string'
          ? el
          : `${el.tagName.toLowerCase()}${el.id ? '#' + el.id : ''}${
              typeof el.className === 'string' && el.className.trim()
                ? '.' + el.className.trim().split(/\s+/).slice(0, 2).join('.')
                : ''
            } "${(el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 30)}"`;
      findings.push({ rule, detail: `${label}${extra ? ' ' + extra : ''}` });
    };
    const visible = (el: Element): boolean => {
      const r = el.getBoundingClientRect();
      const s = getComputedStyle(el);
      return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
    };
    const inScroller = (el: Element): boolean => {
      for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
        const o = getComputedStyle(p).overflowX;
        if ((o === 'auto' || o === 'scroll' || o === 'hidden') && p.scrollWidth > p.clientWidth) {
          return true;
        }
      }
      return false;
    };
    const name = (el: Element): string => {
      const aria = el.getAttribute('aria-label');
      if (aria?.trim()) return aria.trim();
      const by = el.getAttribute('aria-labelledby');
      if (by) {
        const t = by
          .split(/\s+/)
          .map((id) => document.getElementById(id)?.textContent ?? '')
          .join(' ')
          .trim();
        if (t) return t;
      }
      if (el.id) {
        const l = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
        if (l?.textContent?.trim()) return l.textContent.trim();
      }
      const wrap = el.closest('label');
      if (wrap?.textContent?.trim()) return wrap.textContent.trim();
      if (el.getAttribute('title')?.trim()) return el.getAttribute('title')!.trim();
      if (el.getAttribute('placeholder')?.trim()) return el.getAttribute('placeholder')!.trim();
      return (
        (el.textContent ?? '').trim() || el.querySelector('img[alt]')?.getAttribute('alt') || ''
      );
    };

    const root = document.documentElement;
    if (root.scrollWidth > root.clientWidth + 1) {
      add('horizontal-overflow', 'page', `scrollWidth ${root.scrollWidth} > ${root.clientWidth}`);
    }
    if (!root.lang) add('html-lang', 'html', 'has no lang attribute');

    const vw = root.clientWidth;
    const interactive = Array.from(
      document.querySelectorAll<HTMLElement>(
        'button, a[href], input:not([type=hidden]), select, textarea, [role=button], [role=tab], [role=combobox]',
      ),
    ).filter(visible);

    for (const el of interactive) {
      const r = el.getBoundingClientRect();
      if (!inScroller(el) && (r.right > vw + 1 || r.left < -1)) {
        add('outside-viewport', el, `x ${Math.round(r.left)}..${Math.round(r.right)} of ${vw}`);
      }
      const isText =
        (el.tagName === 'A' && el.closest('p, li > span, td')) ||
        el.classList.contains('skip-link') ||
        (el.tagName === 'INPUT' && el.closest('mat-form-field'));
      const isNativeInput =
        el.tagName === 'INPUT' && /checkbox|radio/.test((el as HTMLInputElement).type);
      if (!isText && !isNativeInput && Math.max(r.height, 0) < min) {
        add('touch-target', el, `${Math.round(r.width)}x${Math.round(r.height)}px (< ${min})`);
      }
      if (!name(el)) add('no-accessible-name', el);
    }

    for (const img of Array.from(document.images).filter(visible)) {
      if (!img.hasAttribute('alt')) add('image-alt', img, img.getAttribute('src') ?? '');
    }
    const h1 = Array.from(document.querySelectorAll('h1')).filter(visible);
    if (h1.length !== 1) add('single-h1', 'page', `${h1.length} visible h1 elements`);
    const ids = new Map<string, number>();
    document.querySelectorAll('[id]').forEach((e) => ids.set(e.id, (ids.get(e.id) ?? 0) + 1));
    for (const [id, n] of ids) if (n > 1) add('duplicate-id', `#${id}`, `used ${n} times`);
    return findings;
  }, minTarget);
}

export const auditPage = audit;

/**
 * Focuses each tabbable control with the keyboard modality and compares pixels around it with
 * and without focus. Material draws its focus ring on pseudo elements, so computed styles of
 * the element itself cannot be trusted.
 */
export async function focusIndicators(
  page: Page,
  limit = 14,
  skipToggles = true,
): Promise<Finding[]> {
  const findings: Finding[] = [];
  await page.keyboard.press('Shift');
  const handles = await page
    .locator(
      'main a[href], main button, main input, main select, [role=banner] button, header button, header a',
    )
    .elementHandles();
  let checked = 0;
  for (const handle of handles) {
    if (checked >= limit) break;
    const box = await handle.boundingBox();
    const viewport = page.viewportSize()!;
    const toggle = await handle.evaluate((el) => !!el.closest('mat-button-toggle'));
    if (skipToggles && toggle) continue;
    if (!box || box.width < 4 || box.y < 0 || box.y + box.height > viewport.height - 80) continue;
    checked++;
    const clip = {
      x: Math.max(box.x - 6, 0),
      y: Math.max(box.y - 6, 0),
      width: Math.min(box.width + 12, viewport.width - Math.max(box.x - 6, 0)),
      height: Math.min(box.height + 12, viewport.height - Math.max(box.y - 6, 0)),
    };
    await handle.evaluate((el) => (el as HTMLElement).blur());
    const before = await page.screenshot({ clip, animations: 'disabled' });
    await handle.evaluate((el) => (el as HTMLElement).focus());
    await page.waitForTimeout(150);
    const after = await page.screenshot({ clip, animations: 'disabled' });
    if (before.equals(after)) {
      const label = await handle.evaluate(
        (el) =>
          `${el.tagName.toLowerCase()} "${(
            el.getAttribute('aria-label') ??
            (el.textContent || el.getAttribute('formcontrolname') || el.getAttribute('type')) ??
            ''
          )
            .trim()
            .replace(/\\s+/g, ' ')
            .slice(0, 30)}"`,
      );
      findings.push({ rule: 'focus-visible', detail: label });
    }
  }
  return findings;
}

export function format(findings: Finding[]): string {
  const unique = [...new Set(findings.map((f) => `${f.rule}: ${f.detail}`))];
  return unique.slice(0, 40).join('\n');
}
